#!/usr/bin/env bash
# Transform, compile, check, and measure three pinned Tapenade set01 cases.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_rel=cases/tapenade-set01
case_dir="$root/$case_rel"
result="$root/results/tapenade_set01_support_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
required_fortad_commit=571c86da9516739653a558fabbd8277e796caec8
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
compile_flags=(-std=f2018 -O3 -ffree-line-length-none -fno-lto)
case_ids=(lh023 lh032 lh134)
independent=(a,b x x)

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
python3 - "$case_dir/manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
expected = {
    "lh023": ("set01_lh023(a,b,c)", ["a", "b"], "c"),
    "lh032": ("set01_lh032(x,y)", ["x"], "y"),
    "lh134": ("set01_lh134(x,f)", ["x"], "f"),
}
actual = {
    case["id"]: (
        case["ported_entry_point"], case["independent"], case["dependent"]
    )
    for case in manifest["case"]
}
if actual != expected:
    raise SystemExit("Tapenade set01 manifest and runner contract differ")
if manifest["runner"] != "scripts/bench_tapenade_set01.sh":
    raise SystemExit("Tapenade set01 manifest names a different runner")
if manifest["upstream_revision"] != \
        "e59864cab441d4175df75383b3ff58c3dcd26df9":
    raise SystemExit("Tapenade set01 manifest revision differs from runner")
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-support.XXXXXX")
mkdir -p "$out/mod"

setup_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo build
) >"$out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

forward_start=$(date +%s.%N)
for i in "${!case_ids[@]}"; do
    id=${case_ids[$i]}
    (
        cd "$fortad_repo"
        fo exec --no-build fortad --mode forward \
            --indep "${independent[$i]}" --proc "set01_$id" \
            --name "set01_${id}_jvp" --module "set01_${id}_ad" \
            --output "$out/${id}_jvp.f90" "$case_dir/$id.f90"
    ) >"$out/${id}_forward.stdout" 2>"$out/${id}_forward.stderr"
done
forward_stop=$(date +%s.%N)
forward_seconds=$(awk -v a="$forward_start" -v b="$forward_stop" \
    'BEGIN {printf "%.6f", b-a}')

reverse_start=$(date +%s.%N)
for i in "${!case_ids[@]}"; do
    id=${case_ids[$i]}
    (
        cd "$fortad_repo"
        fo exec --no-build fortad --mode reverse \
            --indep "${independent[$i]}" --proc "set01_$id" \
            --name "set01_${id}_vjp" --module "set01_${id}_reverse_ad" \
            --output "$out/${id}_vjp.f90" "$case_dir/$id.f90"
    ) >"$out/${id}_reverse.stdout" 2>"$out/${id}_reverse.stderr"
done
reverse_stop=$(date +%s.%N)
reverse_seconds=$(awk -v a="$reverse_start" -v b="$reverse_stop" \
    'BEGIN {printf "%.6f", b-a}')

upstream_compile_start=$(date +%s.%N)
for id in "${case_ids[@]}"; do
    "$fc" -std=f2018 -pedantic-errors -c \
        "$tapenade_repo/nonRegressions/set01/$id/program.f" \
        -o "$out/${id}_upstream.o"
done
upstream_compile_stop=$(date +%s.%N)
upstream_compile_seconds=$(awk -v a="$upstream_compile_start" \
    -v b="$upstream_compile_stop" 'BEGIN {printf "%.6f", b-a}')

jvp_compile_start=$(date +%s.%N)
for id in "${case_ids[@]}"; do
    "$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
        -fopt-info-all="$out/${id}_jvp_optimization.txt" \
        -c "$out/${id}_jvp.f90" -o "$out/${id}_jvp.o"
done
jvp_compile_stop=$(date +%s.%N)
jvp_compile_seconds=$(awk -v a="$jvp_compile_start" \
    -v b="$jvp_compile_stop" 'BEGIN {printf "%.6f", b-a}')

vjp_compile_start=$(date +%s.%N)
for id in "${case_ids[@]}"; do
    "$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
        -fopt-info-all="$out/${id}_vjp_optimization.txt" \
        -c "$out/${id}_vjp.f90" -o "$out/${id}_vjp.o"
done
vjp_compile_stop=$(date +%s.%N)
vjp_compile_seconds=$(awk -v a="$vjp_compile_start" \
    -v b="$vjp_compile_stop" 'BEGIN {printf "%.6f", b-a}')

compile_start=$(date +%s.%N)
for id in "${case_ids[@]}"; do
    "$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
        -c "$case_dir/$id.f90" -o "$out/${id}_primal.o"
done
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
    -c "$case_dir/hand_derivatives.f90" -o "$out/hand_derivatives.o"
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" \
    -c "$root/harness/bench_tapenade_set01.f90" -o "$out/harness.o"
"$fc" "${compile_flags[@]}" -o "$out/bench" \
    "$out"/*_primal.o "$out"/*_jvp.o "$out"/*_vjp.o \
    "$out/hand_derivatives.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime_metrics.txt" "$out/bench" \
    >"$out/run.txt" 2>"$out/run.stderr"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
jvp_source_bytes=$(wc -c "$out"/*_jvp.f90 | awk '$2 == "total" {print $1}')
vjp_source_bytes=$(wc -c "$out"/*_vjp.f90 | awk '$2 == "total" {print $1}')
jvp_object_bytes=$(stat -c '%s' "$out"/*_jvp.o | awk '{sum += $1} END {print sum}')
vjp_object_bytes=$(stat -c '%s' "$out"/*_vjp.o | awk '{sum += $1} END {print sum}')
jvp_text_bytes=$(size -A "$out"/*_jvp.o | \
    awk '$1 == ".text" {sum += $2} END {print sum}')
vjp_text_bytes=$(size -A "$out"/*_vjp.o | \
    awk '$1 == ".text" {sum += $2} END {print sum}')
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)

{
    printf 'case: Tapenade nonRegressions set01 lh023 lh032 lh134\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$("$fc" --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fo: %s\n' "$(fo version)"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'fortad_setup_seconds_cached_or_incremental: %s\n' "$setup_seconds"
    printf 'jvp_transform_seconds_three_cases: %s\n' "$forward_seconds"
    printf 'vjp_transform_seconds_three_cases: %s\n' "$reverse_seconds"
    printf 'upstream_fixed_form_compile_seconds: %s\n' \
        "$upstream_compile_seconds"
    printf 'generated_jvp_object_compile_seconds: %s\n' "$jvp_compile_seconds"
    printf 'generated_vjp_object_compile_seconds: %s\n' "$vjp_compile_seconds"
    printf 'case_compile_and_link_seconds: %s\n' "$compile_seconds"
    printf 'generated_jvp_source_bytes: %s\n' "$jvp_source_bytes"
    printf 'generated_vjp_source_bytes: %s\n' "$vjp_source_bytes"
    printf 'generated_jvp_object_bytes: %s\n' "$jvp_object_bytes"
    printf 'generated_vjp_object_bytes: %s\n' "$vjp_object_bytes"
    printf 'generated_jvp_object_text_bytes: %s\n' "$jvp_text_bytes"
    printf 'generated_vjp_object_text_bytes: %s\n' "$vjp_text_bytes"
    cat "$out/runtime_metrics.txt"
    printf 'upstream_compiler_oracle: all three unmodified fixed-form sources '
    printf 'compile with -std=f2018 -pedantic-errors\n'
    printf 'tapenade_result: stored upstream d/b references present; current '
    printf 'Tapenade executable not rerun\n'
    printf 'oracle: hand JVP/VJP, four-step central differences, fixed values, '
    printf 'and JVP/VJP adjoint identity\n'
    printf 'transform_method: date +%%s.%%N around three fo exec --no-build '
    printf 'calls per mode; engine setup timed separately\n'
    printf 'runtime_method: Fortran system_clock over 1000000 repetitions of '
    printf 'all six derivatives; /usr/bin/time %%e and %%M wrap the executable\n'
    printf 'source_sha256:\n'
    (
        cd "$root"
        sha256sum "$case_rel/lh023.f90" "$case_rel/lh032.f90" \
            "$case_rel/lh134.f90" "$case_rel/hand_derivatives.f90" \
            "$case_rel/manifest.toml" harness/bench_tapenade_set01.f90 \
            scripts/bench_tapenade_set01.sh
    )
    printf 'generated_source_sha256:\n'
    sha256sum "$out"/*_jvp.f90 "$out"/*_vjp.f90 | sed "s#$out/##"
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"

cat "$result"
