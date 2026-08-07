#!/usr/bin/env bash
# Validate Tapenade set01 lh074/lh080/lh082 with fresh engine probes.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh070_082_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=72f8fe8
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -ffixed-line-length-none)
compile_flags=(-std=f2018 -O2 -ffree-line-length-none -fno-lto)

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v java >/dev/null
test -x /usr/bin/time
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_commit" HEAD
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

python3 - "$case_dir/tranche-m-lh070-082-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
if manifest["runner"] != "scripts/bench_tapenade_set01_lh070_082.sh":
    raise SystemExit("tranche M runner mismatch")
if manifest["upstream_revision"] != "e59864cab441d4175df75383b3ff58c3dcd26df9":
    raise SystemExit("tranche M Tapenade revision mismatch")
cases = {case["id"]: case for case in manifest["case"]}
if set(cases) != {"lh074", "lh080", "lh082"}:
    raise SystemExit("tranche M case set mismatch")
if cases["lh080"]["classification"] != "runnable-ported":
    raise SystemExit("lh080 must be runnable")
for case_id in ("lh074", "lh082"):
    if cases[case_id]["classification"] != "expected-refusal":
        raise SystemExit(f"{case_id} must remain an expected refusal")
PY

out=$(mktemp -d /var/tmp/ert/tapenade-set01-lh070-082.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/mod" "$out/tapenade"
for case_id in lh074 lh080 lh082; do
    mkdir -p "$out/tapenade/$case_id/parser" \
        "$out/tapenade/$case_id/forward" "$out/tapenade/$case_id/reverse"
done

(cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1 < /dev/null
if test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1 < /dev/null
fi
tapenade="$tapenade_repo/bin/tapenade"

declare -A proc=( [lh074]=fexchem [lh080]=sub1 [lh082]=alias )
declare -A port_proc=( [lh074]=set01_lh074 [lh080]=set01_lh080 [lh082]=set01_lh082 )
declare -A indep=( [lh074]=a,b [lh080]=a [lh082]=a )
declare -A dep=( [lh074]=chem [lh080]=b [lh082]=a )
declare -A expected_upstream=( [lh074]=0 [lh080]=0 [lh082]=0 )

compile_capture() {
    local source=$1 object=$2 status_file=$3 flags_name=$4
    local -a flags
    if test "$flags_name" = strict; then
        flags=("${strict_flags[@]}")
    else
        flags=("${compile_flags[@]}")
    fi
    set +e
    "$fc" "${flags[@]}" -c "$source" -o "$object" \
        >"$object.stdout" 2>"$object.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$status_file"
}

for case_id in lh074 lh080 lh082; do
    upstream_dir="$tapenade_repo/nonRegressions/set01/$case_id"
    case_out="$out/tapenade/$case_id"

    compile_capture "$upstream_dir/program.f" "$case_out/upstream-primal.o" \
        "$case_out/upstream-primal.status" strict
    for stored in program_d.f program_b.f; do
        if test -f "$upstream_dir/$stored"; then
            compile_capture "$upstream_dir/$stored" "$case_out/upstream-$stored.o" \
                "$case_out/upstream-$stored.status" strict
        fi
    done

    "$tapenade" -p -O "$case_out/parser" -o "${case_id}_p" \
        "$upstream_dir/program.f" >"$case_out/parser.stdout" \
        2>"$case_out/parser.stderr"
    "$tapenade" -d -root "${proc[$case_id]}" -O "$case_out/forward" \
        -o "${case_id}_d" "$upstream_dir/program.f" \
        >"$case_out/forward.stdout" 2>"$case_out/forward.stderr"
    "$tapenade" -b -root "${proc[$case_id]}" -O "$case_out/reverse" \
        -o "${case_id}_b" "$upstream_dir/program.f" \
        >"$case_out/reverse.stdout" 2>"$case_out/reverse.stderr"
    parser_source="$case_out/parser/${case_id}_p_p.f"
    forward_source="$case_out/forward/${case_id}_d_d.f"
    reverse_source="$case_out/reverse/${case_id}_b_b.f"
    test -s "$parser_source"
    test -s "$forward_source"
    test -s "$reverse_source"
    compile_capture "$parser_source" "$case_out/parser-generated.o" \
        "$case_out/parser-generated.status" strict
    compile_capture "$forward_source" "$case_out/forward-generated.o" \
        "$case_out/forward-generated.status" strict
    compile_capture "$reverse_source" "$case_out/reverse-generated.o" \
        "$case_out/reverse-generated.status" strict
    test "$(cat "$case_out/upstream-primal.status")" = "${expected_upstream[$case_id]}"
    test "$(cat "$case_out/forward-generated.status")" = 0
    test "$(cat "$case_out/reverse-generated.status")" = 0
done

fortad_exec() {
    (cd "$fortad_repo" && fo exec --no-build fortad "$@")
}

for case_id in lh074 lh080 lh082; do
    output="$out/${case_id}_port_forward.f90"
    fortad_exec jvp "${indep[$case_id]}" --proc "${port_proc[$case_id]}" \
        --name "${case_id}_jvp" --module "${case_id}_forward_ad" \
        --output "$output" "$case_dir/${case_id}.f90" \
        >"$out/${case_id}-port-forward.stdout" \
        2>"$out/${case_id}-port-forward.stderr"
    test -s "$output"
    compile_capture "$output" "$out/${case_id}-port-forward.o" \
        "$out/${case_id}-port-forward.status" normal
    test "$(cat "$out/${case_id}-port-forward.status")" = 0
done

fortad_exec vjp a --dep b --proc set01_lh080 --name lh080_vjp \
    --module lh080_reverse_ad --output "$out/lh080_port_reverse.f90" \
    "$case_dir/lh080.f90" >"$out/lh080-port-reverse.stdout" \
    2>"$out/lh080-port-reverse.stderr"
test -s "$out/lh080_port_reverse.f90"
compile_capture "$out/lh080_port_reverse.f90" "$out/lh080-port-reverse.o" \
    "$out/lh080-port-reverse.status" normal
test "$(cat "$out/lh080-port-reverse.status")" = 0

set +e
fortad_exec jvp a,b --proc fexchem --name lh074_exact_jvp \
    --module lh074_exact_forward_ad --output "$out/lh074_exact_forward.f90" \
    "$tapenade_repo/nonRegressions/set01/lh074/program.f" \
    >"$out/lh074-exact-forward.stdout" 2>"$out/lh074-exact-forward.stderr"
lh074_forward_status=$?
set -e
test "$lh074_forward_status" -ne 0
grep -Fqx "fortad: unsupported statement at line 9" \
    <(grep -F 'fortad:' "$out/lh074-exact-forward.stderr" | tail -1)

set +e
fortad_exec vjp A --dep A --proc alias --name lh082_exact_vjp \
    --module lh082_exact_reverse_ad --output "$out/lh082_exact_reverse.f90" \
    "$tapenade_repo/nonRegressions/set01/lh082/program.f" \
    >"$out/lh082-exact-reverse.stdout" 2>"$out/lh082-exact-reverse.stderr"
lh082_reverse_status=$?
set -e
test "$lh082_reverse_status" -ne 0
grep -Fqx "fortad: reverse mode: 'A' is both read and written in the same loop; that needs per-iteration storage" \
    <(grep -F 'fortad:' "$out/lh082-exact-reverse.stderr" | tail -1)

for source in "$case_dir/lh074.f90" "$case_dir/lh080.f90" \
    "$case_dir/lh082.f90" "$case_dir/hand_derivatives_lh074.f90" \
    "$case_dir/hand_derivatives_lh080.f90" "$case_dir/hand_derivatives_lh082.f90" \
    "$out/lh074_port_forward.f90" "$out/lh080_port_forward.f90" \
    "$out/lh082_port_forward.f90" "$out/lh080_port_reverse.f90"; do
    base=$(basename "$source" .f90)
    "$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
        -o "$out/$base.o"
done
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
    "$root/harness/bench_tapenade_set01_lh070_082.f90" -o "$out/harness.o"
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/lh074.o" "$out/lh080.o" "$out/lh082.o" \
    "$out/hand_derivatives_lh074.o" "$out/hand_derivatives_lh080.o" \
    "$out/hand_derivatives_lh082.o" "$out/lh074_port_forward.o" \
    "$out/lh080_port_forward.o" "$out/lh082_port_forward.o" \
    "$out/lh080_port_reverse.o" "$out/harness.o"

set +e
/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" 2>"$out/run.stderr"
bench_status=$?
set -e
if test "$bench_status" -ne 0; then
    printf 'benchmark exited with status %s\n' "$bench_status" >&2
    cat "$out/run.txt" >&2 || true
    cat "$out/run.stderr" >&2 || true
    exit 1
fi
if ! grep -Fqx 'oracle_status: pass' "$out/run.txt"; then
    printf '%s\n' 'benchmark oracle did not report pass' >&2
    cat "$out/run.txt" >&2 || true
    cat "$out/run.stderr" >&2 || true
    exit 1
fi

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'suite: Tapenade nonRegressions set01 tranche M (lh074, lh080, lh082)\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_exact_source_compile_statuses:\n'
    for status in "$out"/tapenade/*/upstream-*.status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'tapenade_oracle: fresh parser, tangent, and reverse files generated; '
    printf '%s\n' 'all generated sources compile under strict fixed-form flags'
    printf 'tapenade_generated_compile_statuses:\n'
    for status in "$out"/tapenade/*/*-generated.status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'fortad_transform_compile_statuses:\n'
    for status in "$out"/*port*.status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'fortad_lh074_exact_forward_status: %s\n' "$lh074_forward_status"
    printf 'fortad_lh074_exact_diagnostic: unsupported statement at line 9\n'
    printf 'fortad_lh082_exact_reverse_status: %s\n' "$lh082_reverse_status"
    printf 'fortad_lh082_exact_diagnostic: reverse mode: '
    printf '%s\n' "'A' is both read and written in the same loop; that needs per-iteration storage"
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, and adjoint identity\n'
    cat "$out/runtime-metrics.txt"
    printf 'oracle_status: pass\n'
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/lh074.f90 cases/tapenade-set01/lh080.f90 \
        cases/tapenade-set01/lh082.f90 \
        cases/tapenade-set01/hand_derivatives_lh074.f90 \
        cases/tapenade-set01/hand_derivatives_lh080.f90 \
        cases/tapenade-set01/hand_derivatives_lh082.f90 \
        cases/tapenade-set01/tranche-m-lh070-082-manifest.toml \
        cases/tapenade-set01/tranche-m-lh070-082.md \
        harness/bench_tapenade_set01_lh070_082.f90 \
        scripts/bench_tapenade_set01_lh070_082.sh)
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"
cat "$result"
