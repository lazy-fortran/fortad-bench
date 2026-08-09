#!/usr/bin/env bash
# Build the common Enzyme/Tapenade/FortAD suite and retain per-workload status.
#
# A derivative failure in one workload must not erase valid measurements for
# the other workloads. The driver is compiled only for the intersection of
# workloads that all three engines produced; availability.csv records the
# excluded cases for the runner's explicit gap artifact.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

flang=${FLANG:-flang}
clang=${CLANG:-clang}
opt=${OPT:-opt}
llvm_link=${LLVM_LINK:-llvm-link}
default_plugin=$(python3 -c 'from pathlib import Path; print(Path.home() / "code/enzyme/install-llvm22/lib/LLVMEnzyme-22.so")')
plugin=${ENZYME_PLUGIN:-$default_plugin}
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
fortad_bin=$(find "$fortad_repo/build" -name fortad -type f -perm -u+x 2>/dev/null | head -1 || true)

out=build/enzyme_suite
rm -rf "$out"
mkdir -p "$out" results

all_workloads=(euler rk4 lstm ba bruss)
requested_text=${FORTAD_SWEEP_WORKLOADS:-all}
requested_csv=$(python3 - "$requested_text" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, str(Path("scripts").resolve()))
from enzyme_suite_sweep import parse_workloads
print(",".join(parse_workloads(sys.argv[1])))
PY
)
IFS=, read -r -a requested_workloads <<< "$requested_csv"

availability="$out/availability.csv"
printf 'workload,engine,status,reason\n' > "$availability"
record() {
    local workload=$1 engine=$2 status=$3 reason=$4
    printf '%s,%s,%s,%s\n' "$workload" "$engine" "$status" "$reason" >> "$availability"
}

echo "== Enzyme"
enzyme_ok=1
if ! {
    for k in "${all_workloads[@]}"; do
        "$flang" -O3 -fPIC -S -emit-llvm "cases/enzyme_suite/kernels/${k}_c.f90" \
            -o "$out/$k.ll" -module-dir "$out"
    done
    "$clang" -O3 -fPIC -S -emit-llvm engines/enzyme_suite.c -o "$out/wrapper.ll"
    enzyme_ir=()
    for k in "${all_workloads[@]}"; do enzyme_ir+=("$out/$k.ll"); done
    "$llvm_link" -S "${enzyme_ir[@]}" "$out/wrapper.ll" -o "$out/linked.ll"
    "$opt" -load-pass-plugin="$plugin" -passes=enzyme "$out/linked.ll" -S \
        -o "$out/enzyme.ll"
    "$opt" -O3 "$out/enzyme.ll" -S -o "$out/enzyme_opt.ll"
    "$clang" -O3 -fPIC -c "$out/enzyme_opt.ll" -o "$out/enzyme.o"
}; then
    enzyme_ok=0
    echo "Enzyme build failed; see build/enzyme_suite/*.ll and the caller log" >&2
fi
for k in "${requested_workloads[@]}"; do
    if ((enzyme_ok)); then
        record "$k" enzyme ok ""
    else
        record "$k" enzyme unavailable "Enzyme LLVM build failed"
    fi
done

echo "== fortad"
if [[ -z "$fortad_bin" ]]; then
    for k in "${requested_workloads[@]}"; do
        record "$k" fortad unavailable "FortAD executable not found under $fortad_repo/build"
    done
else
    for k in "${requested_workloads[@]}"; do
        log="$out/${k}_fortad.log"
        if {
            "$fortad_bin" --mode reverse --indep z --name "${k}_vjp" \
                -o "$out/${k}_vjp.f90" "cases/enzyme_suite/kernels/$k.f90"
            "$flang" -O3 -c "$out/${k}_vjp.f90" -o "$out/${k}_vjp.o" -module-dir "$out"
            "$fortad_bin" --mode reverse --indep z --no-primal --name "${k}_grad" \
                -o "$out/${k}_grad.f90" "cases/enzyme_suite/kernels/$k.f90"
            "$flang" -O3 -c "$out/${k}_grad.f90" -o "$out/${k}_grad.o" -module-dir "$out"
        } >"$log" 2>&1; then
            record "$k" fortad ok ""
        else
            record "$k" fortad unavailable "FortAD generated derivative fails flang semantic rank checking (fad_s15/fad_s18 scalar-versus-array assignment); full diagnostic: $log"
            echo "FortAD refused $k; see $log" >&2
        fi
    done
fi

echo "== tapenade"
tap=build/tapenade
tapenade_ok=1
if ! ./scripts/build_tapenade.sh > "$out/tapenade_build.log" 2>&1; then
    tapenade_ok=0
    echo "Tapenade build failed; see $out/tapenade_build.log" >&2
fi
if ((tapenade_ok)) && ! ( cd "$tap/ADFirstAidKit" && clang -O3 -w -c adStack.c -o adStack.o ); then
    tapenade_ok=0
    echo "Tapenade runtime compile failed; see $out/tapenade_build.log" >&2
fi
for k in "${requested_workloads[@]}"; do
    if ((tapenade_ok)) && [[ -f "$tap/${k}_tap_b.f90" ]] && \
        "$flang" -O3 -c "$tap/${k}_tap_b.f90" -o "$tap/${k}_b.o" -module-dir "$tap" \
            >"$out/${k}_tapenade.log" 2>&1; then
        record "$k" tapenade ok ""
    else
        record "$k" tapenade unavailable "Tapenade generation or compile failed; see $out/${k}_tapenade.log"
    fi
done

runnable=()
for k in "${requested_workloads[@]}"; do
    if grep -q "^${k},fortad,ok," "$availability" && \
        grep -q "^${k},enzyme,ok," "$availability" && \
        grep -q "^${k},tapenade,ok," "$availability"; then
        runnable+=("$k")
    fi
done
if ((${#runnable[@]} == 0)); then
    echo "no workload has a complete FortAD/Enzyme/Tapenade build" >&2
    exit 1
fi

runnable_csv=$(IFS=,; echo "${runnable[*]}")
export FORTAD_SWEEP_WORKLOADS="$runnable_csv"
defines=()
for k in "${runnable[@]}"; do
    upper=${k^^}
    defines+=("-DHAVE_FORTAD_${upper}" "-DHAVE_ENZYME_${upper}" "-DHAVE_TAPENADE_${upper}")
done

echo "== driver ($runnable_csv)"
"$flang" -O3 -cpp "${defines[@]}" -o "$out/bench" harness/bench_enzyme_suite.f90 \
    $(for k in "${runnable[@]}"; do echo "$out/${k}_vjp.o" "$out/${k}_grad.o"; done) \
    "$out/enzyme.o" \
    $(for k in "${runnable[@]}"; do echo "$tap/${k}_b.o"; done) \
    "$tap/ADFirstAidKit/adStack.o"
echo "built $out/bench"
