#!/usr/bin/env bash
# Validate the set01 lh010 sum-plus-product case end to end.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh010_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
required_fortad_commit=40b8085e6ab66a338211d263b436b7ec9ea918fb
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
compile_flags=(-std=f2018 -O3 -ffree-line-length-none -fno-lto)
upstream_dir="$tapenade_repo/nonRegressions/set01/lh010"

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

python3 - "$case_dir/tranche-j-lh010-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
case = manifest["case"][0]
if manifest["runner"] != "scripts/bench_tapenade_set01_lh010.sh":
    raise SystemExit("set01 tranche J manifest names a different runner")
if manifest["upstream_revision"] != \
        "e59864cab441d4175df75383b3ff58c3dcd26df9":
    raise SystemExit("set01 tranche J revision differs from runner")
if case["ported_entry_point"] != "set01_lh010(x,total)":
    raise SystemExit("lh010 manifest entry point differs from runner")
if case["independent"] != ["x"] or case["dependent"] != ["total"]:
    raise SystemExit("lh010 derivative contract differs from runner")
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-tranche-j.XXXXXX")
mkdir -p "$out/mod" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse"

setup_start=$(date +%s.%N)
(cd "$fortad_repo" && fo build) >"$out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

upstream_start=$(date +%s.%N)
for source in "$upstream_dir/program.f" "$upstream_dir/program_d.f" \
    "$upstream_dir/program_b.f"; do
    "$fc" -std=f2018 -pedantic-errors -ffixed-line-length-none -c "$source" \
        -o "$out/upstream-$(basename "$source").o"
done
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" \
    'BEGIN {printf "%.6f", b-a}')

export PATH="$tapenade_repo/bin:$PATH"
tapenade_parser_start=$(date +%s.%N)
"$tapenade_repo/bin/tapenade" -p -O "$out/tapenade/parser" -o lh010 \
    "$upstream_dir/program.f" >"$out/tapenade-parser.stdout" \
    2>"$out/tapenade-parser.stderr"
tapenade_parser_stop=$(date +%s.%N)
tapenade_parser_seconds=$(awk -v a="$tapenade_parser_start" \
    -v b="$tapenade_parser_stop" 'BEGIN {printf "%.6f", b-a}')

tapenade_forward_start=$(date +%s.%N)
"$tapenade_repo/bin/tapenade" -d -root toto -O "$out/tapenade/forward" \
    -o lh010 "$upstream_dir/program.f" >"$out/tapenade-forward.stdout" \
    2>"$out/tapenade-forward.stderr"
tapenade_forward_stop=$(date +%s.%N)
tapenade_forward_seconds=$(awk -v a="$tapenade_forward_start" \
    -v b="$tapenade_forward_stop" 'BEGIN {printf "%.6f", b-a}')

tapenade_reverse_start=$(date +%s.%N)
"$tapenade_repo/bin/tapenade" -b -root toto -O "$out/tapenade/reverse" \
    -o lh010 "$upstream_dir/program.f" >"$out/tapenade-reverse.stdout" \
    2>"$out/tapenade-reverse.stderr"
tapenade_reverse_stop=$(date +%s.%N)
tapenade_reverse_seconds=$(awk -v a="$tapenade_reverse_start" \
    -v b="$tapenade_reverse_stop" 'BEGIN {printf "%.6f", b-a}')

tapenade_compile_start=$(date +%s.%N)
for generated in "$out/tapenade/parser/lh010_p.f" \
    "$out/tapenade/forward/lh010_d.f" "$out/tapenade/reverse/lh010_b.f"; do
    test -s "$generated"
    "$fc" -std=f2018 -pedantic-errors -ffixed-line-length-none -c "$generated" \
        -o "$out/$(basename "$generated").o"
done
tapenade_compile_stop=$(date +%s.%N)
tapenade_compile_seconds=$(awk -v a="$tapenade_compile_start" \
    -v b="$tapenade_compile_stop" 'BEGIN {printf "%.6f", b-a}')

forward_start=$(date +%s.%N)
(cd "$fortad_repo" && fo exec --no-build fortad --mode forward --indep x \
    --proc set01_lh010 --name lh010_jvp --module lh010_forward_ad \
    --output "$out/lh010_forward.f90" "$case_dir/lh010.f90") \
    >"$out/forward.stdout" 2>"$out/forward.stderr"
forward_stop=$(date +%s.%N)
forward_seconds=$(awk -v a="$forward_start" -v b="$forward_stop" \
    'BEGIN {printf "%.6f", b-a}')

reverse_start=$(date +%s.%N)
(cd "$fortad_repo" && fo exec --no-build fortad --mode reverse --indep x \
    --dep total --proc set01_lh010 --name lh010_vjp \
    --module lh010_reverse_ad --output "$out/lh010_reverse.f90" \
    "$case_dir/lh010.f90") >"$out/reverse.stdout" 2>"$out/reverse.stderr"
reverse_stop=$(date +%s.%N)
reverse_seconds=$(awk -v a="$reverse_start" -v b="$reverse_stop" \
    'BEGIN {printf "%.6f", b-a}')

compile_start=$(date +%s.%N)
for source in "$case_dir/lh010.f90" \
    "$case_dir/hand_derivatives_lh010.f90" "$out/lh010_forward.f90" \
    "$out/lh010_reverse.f90"; do
    base=$(basename "$source" .f90)
    "$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
        -o "$out/${base}.o"
done
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
    "$root/harness/bench_tapenade_set01_lh010.f90" -o "$out/harness.o"
"$fc" "${compile_flags[@]}" -o "$out/bench" "$out/lh010.o" \
    "$out/hand_derivatives_lh010.o" "$out/lh010_forward.o" \
    "$out/lh010_reverse.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" \
    2>"$out/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh010\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'fortad_setup_seconds: %s\n' "$setup_seconds"
    printf 'upstream_strict_compile_seconds: %s\n' "$upstream_seconds"
    printf 'tapenade_parser_seconds: %s\n' "$tapenade_parser_seconds"
    printf 'tapenade_forward_seconds: %s\n' "$tapenade_forward_seconds"
    printf 'tapenade_reverse_seconds: %s\n' "$tapenade_reverse_seconds"
    printf 'tapenade_generated_compile_seconds: %s\n' \
        "$tapenade_compile_seconds"
    printf 'fortad_forward_seconds: %s\n' "$forward_seconds"
    printf 'fortad_reverse_seconds: %s\n' "$reverse_seconds"
    printf 'fortad_generated_compile_and_link_seconds: %s\n' "$compile_seconds"
    printf 'tapenade_forward_source_bytes: %s\n' \
        "$(wc -c <"$out/tapenade/forward/lh010_d.f")"
    printf 'tapenade_reverse_source_bytes: %s\n' \
        "$(wc -c <"$out/tapenade/reverse/lh010_b.f")"
    printf 'fortad_forward_source_bytes: %s\n' \
        "$(wc -c <"$out/lh010_forward.f90")"
    printf 'fortad_reverse_source_bytes: %s\n' \
        "$(wc -c <"$out/lh010_reverse.f90")"
    cat "$out/runtime-metrics.txt"
    printf 'upstream_compiler_oracle: exact primal and stored tangent/adjoint '
    printf '%s\n' 'references compile with -std=f2018 -pedantic-errors'
    printf 'tapenade_oracle: fresh parser, tangent, and adjoint outputs compile '
    printf '%s\n' 'with strict Fortran flags'
    printf 'oracle: independent closed-form product gradient, four-step central '
    printf '%s\n' 'differences, and the JVP/VJP adjoint identity'
    printf 'runtime_method: Fortran system_clock over 200000 calls per mode; '
    printf '%s\n' '/usr/bin/time %e and %M wrap the executable'
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh010.f90 \
        cases/tapenade-set01/hand_derivatives_lh010.f90 \
        cases/tapenade-set01/tranche-j-lh010-manifest.toml \
        cases/tapenade-set01/tranche-j-lh010.md \
        harness/bench_tapenade_set01_lh010.f90 \
        scripts/bench_tapenade_set01_lh010.sh)
    printf 'generated_source_sha256:\n'
    sha256sum "$out/lh010_forward.f90" "$out/lh010_reverse.f90" | \
        sed "s#$out/##"
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"

cat "$result"
