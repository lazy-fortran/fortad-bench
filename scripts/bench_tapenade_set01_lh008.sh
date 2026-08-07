#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh008_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=571c86da9516739653a558fabbd8277e796caec8
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
compile_flags=(-std=f2018 -O3 -ffree-line-length-none -fno-lto)

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v java >/dev/null
test -x /usr/bin/time
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
git -C "$fortad_repo" cat-file -e "$required_fortad_commit^{commit}"
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_commit" HEAD
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

python3 - "$case_dir/lh008-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path
with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
case = manifest["case"][0]
assert manifest["runner"] == "scripts/bench_tapenade_set01_lh008.sh"
assert manifest["upstream_revision"] == "e59864cab441d4175df75383b3ff58c3dcd26df9"
assert case["ported_entry_point"] == "set01_lh008(y,x,z,objective)"
assert case["independent"] == ["y"] and case["dependent"] == "objective"
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-lh008.XXXXXX")
mkdir -p "$out/mod" "$out/tapenade"
upstream_dir="$tapenade_repo/nonRegressions/set01/lh008"

setup_start=$(date +%s.%N)
(cd "$fortad_repo" && fo build) >"$out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" 'BEGIN {printf "%.6f", b-a}')

upstream_start=$(date +%s.%N)
for source in "$upstream_dir/program.f" "$upstream_dir/program_d.f" "$upstream_dir/program_b.f"; do
    base=$(basename "$source")
    "$fc" -std=f2018 -pedantic-errors -ffixed-line-length-none -c "$source" -o "$out/upstream-$base.o"
done
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" 'BEGIN {printf "%.6f", b-a}')

forward_start=$(date +%s.%N)
(cd "$fortad_repo" && fo exec --no-build fortad --mode forward --indep y --proc set01_lh008 --name lh008_jvp --module lh008_forward_ad --output "$out/lh008_forward.f90" "$case_dir/lh008.f90") >"$out/fortad-forward.stdout" 2>"$out/fortad-forward.stderr"
forward_stop=$(date +%s.%N)
forward_seconds=$(awk -v a="$forward_start" -v b="$forward_stop" 'BEGIN {printf "%.6f", b-a}')

reverse_start=$(date +%s.%N)
(cd "$fortad_repo" && fo exec --no-build fortad --mode reverse --indep y --dep objective --proc set01_lh008 --name lh008_vjp --module lh008_reverse_ad --output "$out/lh008_reverse.f90" "$case_dir/lh008.f90") >"$out/fortad-reverse.stdout" 2>"$out/fortad-reverse.stderr"
reverse_stop=$(date +%s.%N)
reverse_seconds=$(awk -v a="$reverse_start" -v b="$reverse_stop" 'BEGIN {printf "%.6f", b-a}')

compile_start=$(date +%s.%N)
for source in "$case_dir/lh008.f90" "$out/lh008_forward.f90" "$out/lh008_reverse.f90" "$case_dir/hand_derivatives_lh008.f90"; do
    base=$(basename "$source" .f90)
    "$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c "$source" -o "$out/${base}.o"
done
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c "$root/harness/bench_tapenade_set01_lh008.f90" -o "$out/harness.o"
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" "$out/lh008.o" "$out/lh008_forward.o" "$out/lh008_reverse.o" "$out/hand_derivatives_lh008.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" 'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' -o "$out/runtime_metrics.txt" "$out/bench" >"$out/run.txt" 2>"$out/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/run.txt"

if test ! -x "$tapenade_repo/bin/tapenade" || test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
tapenade_bin="$tapenade_repo/bin/tapenade"

tapenade_forward_start=$(date +%s.%N)
(cd "$out/tapenade" && "$tapenade_bin" -d -head adjblock1 -o lh008_tapenade_forward.f "$upstream_dir/program.f") >"$out/tapenade-forward.log" 2>&1
tapenade_forward_stop=$(date +%s.%N)
tapenade_forward_seconds=$(awk -v a="$tapenade_forward_start" -v b="$tapenade_forward_stop" 'BEGIN {printf "%.6f", b-a}')
tapenade_forward_generated="$out/tapenade/lh008_tapenade_forward.f_d.f"
test -s "$tapenade_forward_generated"

tapenade_reverse_start=$(date +%s.%N)
(cd "$out/tapenade" && "$tapenade_bin" -b -head adjblock1 -o lh008_tapenade_reverse.f "$upstream_dir/program.f") >"$out/tapenade-reverse.log" 2>&1
tapenade_reverse_stop=$(date +%s.%N)
tapenade_reverse_seconds=$(awk -v a="$tapenade_reverse_start" -v b="$tapenade_reverse_stop" 'BEGIN {printf "%.6f", b-a}')
tapenade_reverse_generated="$out/tapenade/lh008_tapenade_reverse.f_b.f"
test -s "$tapenade_reverse_generated"
"$fc" -std=f2018 -pedantic-errors -ffixed-line-length-none -c "$tapenade_forward_generated" -o "$out/tapenade-forward.o"
"$fc" -std=f2018 -pedantic-errors -ffixed-line-length-none -c "$tapenade_reverse_generated" -o "$out/tapenade-reverse.o"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh008\n'
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
    printf 'tapenade_forward_transform_seconds: %s\n' "$tapenade_forward_seconds"
    printf 'tapenade_reverse_transform_seconds: %s\n' "$tapenade_reverse_seconds"
    printf 'tapenade_generated_compile: pass-strict\n'
    printf 'oracle: independent hand JVP/VJP, four-step central differences, and adjoint identity\n'
    printf 'tapenade_result: parser and generated forward/reverse references compile under strict fixed-form mode\n'
    cat "$out/runtime_metrics.txt"
    printf 'generated_forward_source_bytes: %s\n' "$(wc -c <"$out/lh008_forward.f90")"
    printf 'generated_reverse_source_bytes: %s\n' "$(wc -c <"$out/lh008_reverse.f90")"
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh008.f90 cases/tapenade-set01/hand_derivatives_lh008.f90 cases/tapenade-set01/lh008-manifest.toml cases/tapenade-set01/lh008.md harness/bench_tapenade_set01_lh008.f90 scripts/bench_tapenade_set01_lh008.sh)
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"
cat "$result"
