#!/usr/bin/env bash
# Validate lh016 forward complex arithmetic and its reverse-mode refusal.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh016_refusal_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
required_fortad_commit=40b8085e6ab66a338211d263b436b7ec9ea918fb
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
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

python3 - "$case_dir/tranche-j-lh016-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
case = manifest["case"][0]
if manifest["runner"] != "scripts/bench_tapenade_set01_lh016.sh":
    raise SystemExit("set01 lh016 manifest names a different runner")
if case["ported_entry_point"] != "set01_lh016(input,output)":
    raise SystemExit("lh016 manifest entry point differs from runner")
if case["independent"] != ["input"] or case["dependent"] != ["output"]:
    raise SystemExit("lh016 derivative contract differs from runner")
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-tranche-j.XXXXXX")
mkdir -p "$out/mod" "$out/tapenade/forward" "$out/tapenade/reverse"
upstream_dir="$tapenade_repo/nonRegressions/set01/lh016"

setup_start=$(date +%s.%N)
(cd "$fortad_repo" && fo build) >"$out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

upstream_start=$(date +%s.%N)
for source in program.f program_d.f program_b.f; do
    "$fc" -std=f2018 -pedantic-errors -ffixed-line-length-none -c \
        "$upstream_dir/$source" -o "$out/upstream-$source.o"
done
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" \
    'BEGIN {printf "%.6f", b-a}')

export PATH="$tapenade_repo/bin:$PATH"
tapenade_start=$(date +%s.%N)
"$tapenade_repo/bin/tapenade" -d -root ctest \
    -O "$out/tapenade/forward" -o ctest_d "$upstream_dir/program.f" \
    >"$out/tapenade-forward.stdout" 2>"$out/tapenade-forward.stderr"
"$tapenade_repo/bin/tapenade" -b -root ctest \
    -O "$out/tapenade/reverse" -o ctest_b "$upstream_dir/program.f" \
    >"$out/tapenade-reverse.stdout" 2>"$out/tapenade-reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" \
    'BEGIN {printf "%.6f", b-a}')
fresh_forward="$out/tapenade/forward/ctest_d_d.f"
fresh_reverse="$out/tapenade/reverse/ctest_b_b.f"
test -s "$fresh_forward"
test -s "$fresh_reverse"
"$fc" -std=f2018 -pedantic-errors -ffixed-line-length-none -c \
    "$fresh_forward" -o "$out/fresh-forward.o"
"$fc" -std=f2018 -pedantic-errors -ffixed-line-length-none -c \
    "$fresh_reverse" -o "$out/fresh-reverse.o"

expected_exact='fortad: unsupported expression at line 6'
for mode in forward reverse; do
    output="$out/exact-$mode.f90"
    set +e
    if test "$mode" = forward; then
        (cd "$fortad_repo" && fo exec --no-build fortad --mode forward \
            --indep in --proc ctest --name ctest_jvp \
            --module exact_lh016_forward_ad --output "$output" \
            "$upstream_dir/program.f") \
            >"$out/exact-$mode.stdout" 2>"$out/exact-$mode.stderr"
    else
        (cd "$fortad_repo" && fo exec --no-build fortad --mode reverse \
            --indep in --dep out --proc ctest --name ctest_vjp \
            --module exact_lh016_reverse_ad --output "$output" \
            "$upstream_dir/program.f") \
            >"$out/exact-$mode.stdout" 2>"$out/exact-$mode.stderr"
    fi
    status=$?
    set -e
    test "$status" -ne 0
    grep -Fqx "$expected_exact" "$out/exact-$mode.stderr"
    test ! -e "$output"
done

forward_start=$(date +%s.%N)
(cd "$fortad_repo" && fo exec --no-build fortad --mode forward \
    --indep input --proc set01_lh016 --name lh016_jvp \
    --module lh016_forward_ad --output "$out/lh016_forward.f90" \
    "$case_dir/lh016.f90") >"$out/forward.stdout" 2>"$out/forward.stderr"
forward_stop=$(date +%s.%N)
forward_seconds=$(awk -v a="$forward_start" -v b="$forward_stop" \
    'BEGIN {printf "%.6f", b-a}')

expected_reverse='fortad: reverse mode: active complex adjoints are not supported for this expression; the bounded real-coordinate projection path only accepts real(z) or dble(z)'
reverse_start=$(date +%s.%N)
set +e
(cd "$fortad_repo" && fo exec --no-build fortad --mode reverse \
    --indep input --dep output --proc set01_lh016 --name lh016_vjp \
    --module lh016_reverse_ad --output "$out/lh016_reverse.f90" \
    "$case_dir/lh016.f90") >"$out/reverse.stdout" 2>"$out/reverse.stderr"
reverse_status=$?
set -e
reverse_stop=$(date +%s.%N)
reverse_seconds=$(awk -v a="$reverse_start" -v b="$reverse_stop" \
    'BEGIN {printf "%.6f", b-a}')
test "$reverse_status" -ne 0
grep -Fqx "$expected_reverse" "$out/reverse.stderr"
test ! -e "$out/lh016_reverse.f90"

compile_start=$(date +%s.%N)
for source in "$case_dir/lh016.f90" \
    "$case_dir/hand_derivatives_lh016.f90" "$out/lh016_forward.f90"; do
    base=$(basename "$source" .f90)
    "$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
        "$source" -o "$out/$base.o"
done
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
    "$root/harness/bench_tapenade_set01_lh016.f90" -o "$out/harness.o"
"$fc" "${compile_flags[@]}" -o "$out/bench" \
    "$out/lh016.o" "$out/hand_derivatives_lh016.o" \
    "$out/lh016_forward.o" "$out/upstream-program.f.o" \
    "$out/upstream-program_d.f.o" "$out/upstream-program_b.f.o" \
    "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" \
    2>"$out/run.stderr"
grep -Fqx 'refusal_oracle_status: pass' "$out/run.txt"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
tapenade_version=$({ "$tapenade_repo/bin/tapenade" -version || true; } | head -1)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh016 complex arithmetic\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fo: %s\n' "$(cd "$fortad_repo" && fo version)"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'tapenade_version: %s\n' "$tapenade_version"
    printf 'fortad_setup_seconds: %s\n' "$setup_seconds"
    printf 'upstream_strict_compile_seconds: %s\n' "$upstream_seconds"
    printf 'tapenade_forward_reverse_seconds: %s\n' "$tapenade_seconds"
    printf 'fortad_forward_transform_seconds: %s\n' "$forward_seconds"
    printf 'fortad_reverse_transform_seconds: %s\n' "$reverse_seconds"
    printf 'fortad_reverse_status: %s\n' "$reverse_status"
    printf 'generated_compile_and_link_seconds: %s\n' "$compile_seconds"
    printf 'fortad_generated_forward_source_bytes: %s\n' \
        "$(wc -c <"$out/lh016_forward.f90")"
    printf 'fortad_generated_reverse_source_bytes: 0\n'
    printf 'tapenade_generated_forward_source_bytes: %s\n' \
        "$(wc -c <"$fresh_forward")"
    printf 'tapenade_generated_reverse_source_bytes: %s\n' \
        "$(wc -c <"$fresh_reverse")"
    cat "$out/runtime-metrics.txt"
    printf 'upstream_compiler_oracle: exact primal and stored tangent/adjoint '
    printf '%s\n' 'compile with -std=f2018 -pedantic-errors'
    printf 'tapenade_oracle: fresh tangent and adjoint sources generate and compile\n'
    printf 'oracle: hand real-coordinate JVP/VJP, four-step complex directional '
    printf '%s\n' 'central differences, and the real inner-product adjoint identity'
    printf 'exact_source_fortad_diagnostic: %s\n' "$expected_exact"
    printf 'reverse_refusal_diagnostic: %s\n' "$expected_reverse"
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh016.f90 \
        cases/tapenade-set01/hand_derivatives_lh016.f90 \
        cases/tapenade-set01/tranche-j-lh016-manifest.toml \
        cases/tapenade-set01/tranche-j-lh016.md \
        harness/bench_tapenade_set01_lh016.f90 \
        scripts/bench_tapenade_set01_lh016.sh)
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"

cat "$result"
