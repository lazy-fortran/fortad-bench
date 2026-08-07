#!/usr/bin/env bash
# Validate Tapenade set01 lh068 support and record reproducible measurements.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_tranche_d_validation.txt"
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
if ! git -C "$fortad_repo" merge-base --is-ancestor \
    "$required_fortad_commit" HEAD; then
    printf 'FortAD HEAD must contain %s\n' "$required_fortad_commit" >&2
    exit 1
fi
if test -n "$(git -C "$fortad_repo" status --porcelain \
    --untracked-files=no)"; then
    printf 'FortAD checkout has tracked changes; refusing an ambiguous run\n' >&2
    exit 1
fi
if test "$(git -C "$tapenade_repo" rev-parse HEAD)" != \
    "$required_tapenade_commit"; then
    printf 'Tapenade checkout must be pinned at %s\n' \
        "$required_tapenade_commit" >&2
    exit 1
fi
if test -n "$(git -C "$tapenade_repo" status --porcelain \
    --untracked-files=no)"; then
    printf 'Tapenade checkout has tracked changes; refusing an ambiguous run\n' >&2
    exit 1
fi
python3 - "$case_dir/tranche-d-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
case = manifest["case"][0]
if manifest["runner"] != "scripts/bench_tapenade_set01_tranche_d.sh":
    raise SystemExit("set01 tranche D manifest names a different runner")
if manifest["upstream_revision"] != \
        "e59864cab441d4175df75383b3ff58c3dcd26df9":
    raise SystemExit("set01 tranche D manifest revision differs from runner")
if case["ported_entry_point"] != \
        "set01_lh068_split(a,b,c,c3,c7)":
    raise SystemExit("lh068 manifest entry point differs from runner")
if case["independent"] != ["a", "b", "c"] or \
        case["dependent"] != ["c3", "c7"]:
    raise SystemExit("lh068 manifest derivative contract differs from runner")
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-tranche-d.XXXXXX")
mkdir -p "$out/mod" "$out/include"
cp "$tapenade_repo/nonRegressions/DIFFSIZES.f" "$out/include/DIFFSIZES.inc"

setup_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo build
) >"$out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

upstream_start=$(date +%s.%N)
for source in \
    "$tapenade_repo/nonRegressions/set01/lh068/program.f" \
    "$tapenade_repo/nonRegressions/set01/lh068/program_d.f" \
    "$tapenade_repo/nonRegressions/set01/lh068/program_dv.f" \
    "$tapenade_repo/nonRegressions/set01/lh068/program_p.f"; do
    base=$(basename "$source")
    "$fc" -std=f2018 -pedantic-errors -I"$out/include" -c "$source" \
        -o "$out/upstream-$base.o"
done
# Tapenade's stored reverse reference uses the legacy INTEGER*4 spelling.
# Keep the primary and forward/multidirectional references strict, while
# compiling that historical file under the compiler's explicit legacy mode.
"$fc" -std=legacy -ffixed-line-length-none -I"$out/include" -c \
    "$tapenade_repo/nonRegressions/set01/lh068/program_b.f" \
    -o "$out/upstream-program_b.f.o"
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" \
    'BEGIN {printf "%.6f", b-a}')

forward_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode forward --indep a,b,c \
        --proc set01_lh068_split --name lh068_jvp --module lh068_forward_ad \
        --output "$out/lh068_forward.f90" "$case_dir/lh068.f90"
) >"$out/forward.stdout" 2>"$out/forward.stderr"
forward_stop=$(date +%s.%N)
forward_seconds=$(awk -v a="$forward_start" -v b="$forward_stop" \
    'BEGIN {printf "%.6f", b-a}')

reverse_c3_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode reverse --indep a,b,c --dep c3 \
        --proc set01_lh068_split --name lh068_vjp_c3 \
        --module lh068_reverse_c3_ad --output "$out/lh068_reverse_c3.f90" \
        "$case_dir/lh068.f90"
) >"$out/reverse_c3.stdout" 2>"$out/reverse_c3.stderr"
reverse_c3_stop=$(date +%s.%N)
reverse_c3_seconds=$(awk -v a="$reverse_c3_start" -v b="$reverse_c3_stop" \
    'BEGIN {printf "%.6f", b-a}')

reverse_c7_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode reverse --indep a,b,c --dep c7 \
        --proc set01_lh068_split --name lh068_vjp_c7 \
        --module lh068_reverse_c7_ad --output "$out/lh068_reverse_c7.f90" \
        "$case_dir/lh068.f90"
) >"$out/reverse_c7.stdout" 2>"$out/reverse_c7.stderr"
reverse_c7_stop=$(date +%s.%N)
reverse_c7_seconds=$(awk -v a="$reverse_c7_start" -v b="$reverse_c7_stop" \
    'BEGIN {printf "%.6f", b-a}')

compile_start=$(date +%s.%N)
for source in "$case_dir/lh068.f90" "$out/lh068_forward.f90" \
    "$out/lh068_reverse_c3.f90" "$out/lh068_reverse_c7.f90" \
    "$case_dir/hand_derivatives_lh068.f90"; do
    base=$(basename "$source" .f90)
    "$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
        "$source" -o "$out/${base}.o"
done
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
    "$root/harness/bench_tapenade_set01_tranche_d.f90" -o "$out/harness.o"
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/lh068.o" "$out/lh068_forward.o" \
    "$out/lh068_reverse_c3.o" "$out/lh068_reverse_c7.o" \
    "$out/hand_derivatives_lh068.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime_metrics.txt" "$out/bench" >"$out/run.txt" \
    2>"$out/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/run.txt"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh068\n'
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
    printf 'reverse_c3_transform_seconds: %s\n' "$reverse_c3_seconds"
    printf 'reverse_c7_transform_seconds: %s\n' "$reverse_c7_seconds"
    printf 'generated_compile_and_link_seconds: %s\n' "$compile_seconds"
    printf 'generated_forward_source_bytes: %s\n' \
        "$(wc -c <"$out/lh068_forward.f90")"
    printf 'generated_reverse_c3_source_bytes: %s\n' \
        "$(wc -c <"$out/lh068_reverse_c3.f90")"
    printf 'generated_reverse_c7_source_bytes: %s\n' \
        "$(wc -c <"$out/lh068_reverse_c7.f90")"
    cat "$out/runtime_metrics.txt"
    printf 'upstream_compiler_oracle: unmodified primal, forward, '
    printf 'multidirectional, and plain-reference files compile with '
    printf '%s\n' '-std=f2018 -pedantic-errors using the pinned DIFFSIZES.f include '
    printf '%s\n' 'contract; the stored reverse file compiles under -std=legacy '
    printf '%s\n' 'because it uses Tapenade INTEGER*4 syntax'
    printf 'oracle: hand branch-aware JVP/VJP, four-step central differences, '
    printf 'and one active (conv(3)<0) plus one inactive (conv(7)>0) min branch\n'
    printf 'branch_margin: conv(3)=-0.35 and conv(7)=1.0 at the oracle point\n'
    printf 'tapenade_result: stored upstream d/b references inspected; '
    printf 'current Tapenade executable not rerun\n'
    printf 'transform_method: date +%%s.%%N around one fo exec --no-build '
    printf 'call per generated mode; engine setup timed separately\n'
    printf 'runtime_method: Fortran system_clock over 1000000 repetitions '
    printf 'of one JVP and two VJPs; /usr/bin/time %%e and %%M wrap executable\n'
    printf 'source_sha256:\n'
    (
        cd "$root"
        sha256sum cases/tapenade-set01/lh068.f90 \
            cases/tapenade-set01/hand_derivatives_lh068.f90 \
            cases/tapenade-set01/tranche-d-manifest.toml \
            cases/tapenade-set01/tranche-d.md \
            harness/bench_tapenade_set01_tranche_d.f90 \
            scripts/bench_tapenade_set01_tranche_d.sh
    )
    printf 'generated_source_sha256:\n'
    sha256sum "$out/lh068_forward.f90" "$out/lh068_reverse_c3.f90" \
        "$out/lh068_reverse_c7.f90" | sed "s#$out/##"
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"

cat "$result"
