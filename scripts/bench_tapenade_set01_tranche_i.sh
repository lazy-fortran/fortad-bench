#!/usr/bin/env bash
# Validate Tapenade set01 lh019's AA-type active-component slice.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_tranche_i_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
required_fortad_commit=571c86da9516739653a558fabbd8277e796caec8
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
compile_flags=(-std=f2018 -O3 -ffree-line-length-none -fno-lto)

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v python3 >/dev/null
test -x /usr/bin/time
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
git -C "$fortad_repo" cat-file -e "$required_fortad_commit^{commit}"
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_commit" HEAD
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

python3 - "$case_dir/tranche-i-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
case = manifest["case"][0]
if manifest["runner"] != "scripts/bench_tapenade_set01_tranche_i.sh":
    raise SystemExit("set01 tranche H manifest names a different runner")
if case["ported_entry_point"] != "set01_lh019(x,y,n,output)":
    raise SystemExit("lh019 manifest entry point differs from runner")
if case["independent"] != ["x%v", "y%v"] or case["dependent"] != "output":
    raise SystemExit("lh019 component derivative contract differs from runner")
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-tranche-i.XXXXXX")
mkdir -p "$out/mod" "$out/include"

setup_start=$(date +%s.%N)
(cd "$fortad_repo" && fo build) >"$out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" 'BEGIN {printf "%.6f", b-a}')

upstream_start=$(date +%s.%N)
"$fc" -std=f2018 -pedantic-errors -ffixed-line-length-none -c \
    "$tapenade_repo/nonRegressions/set01/lh019/program.f" \
    -o "$out/upstream-program.o"
for source in AATypes_aad.f03 program_aad.f03 AATypes_aab.f03 program_aab.f03; do
    "$fc" -std=f2018 -pedantic-errors -ffree-line-length-none \
        -J"$out" -I"$out" -c \
        "$tapenade_repo/nonRegressions/set01/lh019/$source" \
        -o "$out/upstream-$source.o"
done
for source in program_d.f program_b.f; do
    "$fc" -std=legacy -ffixed-line-length-none -c \
        "$tapenade_repo/nonRegressions/set01/lh019/$source" \
        -o "$out/upstream-$source.o"
done
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" 'BEGIN {printf "%.6f", b-a}')

forward_start=$(date +%s.%N)
(cd "$fortad_repo" && fo exec --no-build fortad --mode forward \
    --indep 'x%v,y%v' --proc set01_lh019 --name lh019_jvp \
    --module lh019_forward_ad --output "$out/lh019_forward.raw.f90" \
    "$case_dir/lh019.f90") >"$out/forward.stdout" 2>"$out/forward.stderr"
forward_stop=$(date +%s.%N)
forward_seconds=$(awk -v a="$forward_start" -v b="$forward_stop" 'BEGIN {printf "%.6f", b-a}')

reverse_start=$(date +%s.%N)
(cd "$fortad_repo" && fo exec --no-build fortad --mode reverse \
    --indep 'x%v,y%v' --dep output --proc set01_lh019 --name lh019_vjp \
    --module lh019_reverse_ad --output "$out/lh019_reverse.raw.f90" \
    "$case_dir/lh019.f90") >"$out/reverse.stdout" 2>"$out/reverse.stderr"
reverse_stop=$(date +%s.%N)
reverse_seconds=$(awk -v a="$reverse_start" -v b="$reverse_stop" 'BEGIN {printf "%.6f", b-a}')

# Generated modules intentionally require the source module's derived type in
# scope.  Inject that single use statement without changing generated code.
for mode in forward reverse; do
    module="lh019_${mode}_ad"
    awk 'BEGIN { added=0 }
        /^    implicit none$/ && added == 0 {
            print "    use tapenade_set01_lh019_case, only: real8_diff"
            added=1
        }
        { print }' "$out/lh019_${mode}.raw.f90" >"$out/lh019_${mode}.f90"
done

compile_start=$(date +%s.%N)
for source in "$case_dir/lh019.f90" "$out/lh019_forward.f90" \
    "$out/lh019_reverse.f90" "$case_dir/hand_derivatives_lh019.f90"; do
    base=$(basename "$source" .f90)
    "$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
        -o "$out/$base.o"
done
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
    "$root/harness/bench_tapenade_set01_tranche_i.f90" -o "$out/harness.o"
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/lh019.o" "$out/lh019_forward.o" "$out/lh019_reverse.o" \
    "$out/hand_derivatives_lh019.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" 'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime_metrics.txt" "$out/bench" >"$out/run.txt" 2>"$out/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/run.txt"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh019 AA-type component slice\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fo: %s\n' "$(fo version)"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'fortad_setup_seconds: %s\n' "$setup_seconds"
    printf 'upstream_strict_compile_seconds: %s\n' "$upstream_seconds"
    printf 'forward_transform_seconds: %s\n' "$forward_seconds"
    printf 'reverse_transform_seconds: %s\n' "$reverse_seconds"
    printf 'generated_compile_and_link_seconds: %s\n' "$compile_seconds"
    printf 'generated_forward_source_bytes: %s\n' "$(wc -c <"$out/lh019_forward.raw.f90")"
    printf 'generated_reverse_source_bytes: %s\n' "$(wc -c <"$out/lh019_reverse.raw.f90")"
    cat "$out/runtime_metrics.txt"
    printf 'upstream_compiler_oracle: unmodified primal, association-by-address '
    printf '%s\n' 'forward/reverse references compile; legacy references use -std=legacy'
    printf 'oracle: independent hand JVP/VJP, four-step central differences on '
    printf '%s\n' 'n=6 product and n=3 pass-through branches, plus the adjoint identity'
    printf 'tapenade_result: stored AATypes/program_aad/program_aab references '
    printf '%s\n' 'compile; current Tapenade executable not rerun'
    printf 'transform_method: date +%%s.%%N around one fo exec --no-build call per mode\n'
    printf 'runtime_method: system_clock over 500000 JVP/VJP pairs; /usr/bin/time wraps executable\n'
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh019.f90 \
        cases/tapenade-set01/hand_derivatives_lh019.f90 \
        cases/tapenade-set01/tranche-i-manifest.toml \
        cases/tapenade-set01/tranche-i.md \
        harness/bench_tapenade_set01_tranche_i.f90 \
        scripts/bench_tapenade_set01_tranche_i.sh)
    printf 'generated_source_sha256:\n'
    sha256sum "$out/lh019_forward.raw.f90" "$out/lh019_reverse.raw.f90" \
        | sed "s#$out/##"
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"

cat "$result"
