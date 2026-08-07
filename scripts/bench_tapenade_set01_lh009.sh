#!/usr/bin/env bash
# Record the invalid-source refusal for Tapenade set01 lh009.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh009_refusal_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -ffixed-line-length-none)
compile_flags=(-std=f2018 -O2 -ffree-line-length-none -fno-lto)

command -v "$fc" >/dev/null
command -v java >/dev/null
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

python3 - "$case_dir/lh009-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
case = manifest["case"][0]
assert manifest["runner"] == "scripts/bench_tapenade_set01_lh009.sh"
assert manifest["upstream_revision"] == \
    "e59864cab441d4175df75383b3ff58c3dcd26df9"
assert manifest["classification"] == "expected-refusal-invalid-upstream"
assert case["ported_entry_point"] == \
    "set01_lh009(a_in,b_in,s,a_out,b_out)"
assert case["expected_diagnostic"] == \
    "Symbol a already has basic type of REAL"
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-lh009.XXXXXX")
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/mod"

strict_refusal() {
    local source=$1
    local label=$2
    set +e
    "$fc" "${strict_flags[@]}" -c "$source" -o "$out/$label.o" \
        >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    test "$status" -ne 0
    grep -Fq "already has basic type" "$out/$label.stderr"
    printf '%s\n' "$status" >"$out/$label.status"
}

upstream_dir="$tapenade_repo/nonRegressions/set01/lh009"
strict_refusal "$upstream_dir/program.f" upstream-program
strict_refusal "$upstream_dir/program_d.f" upstream-tangent
strict_refusal "$upstream_dir/program_b.f" upstream-reverse

if test ! -x "$tapenade_repo/bin/tapenade" || \
        test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
tapenade="$tapenade_repo/bin/tapenade"

"$tapenade" -p -root cfgloop1 -O "$out/tapenade/parser" -o lh009 \
    "$upstream_dir/program.f" >"$out/tapenade-parser.stdout" \
    2>"$out/tapenade-parser-generation.stderr"
"$tapenade" -d -root cfgloop1 -O "$out/tapenade/forward" -o lh009 \
    "$upstream_dir/program.f" >"$out/tapenade-forward.stdout" \
    2>"$out/tapenade-forward-generation.stderr"
"$tapenade" -b -root cfgloop1 -O "$out/tapenade/reverse" -o lh009 \
    "$upstream_dir/program.f" >"$out/tapenade-reverse.stdout" \
    2>"$out/tapenade-reverse-generation.stderr"

test -s "$out/tapenade/parser/lh009_p.f"
test -s "$out/tapenade/forward/lh009_d.f"
test -s "$out/tapenade/reverse/lh009_b.f"
strict_refusal "$out/tapenade/parser/lh009_p.f" generated-parser
strict_refusal "$out/tapenade/forward/lh009_d.f" generated-forward
strict_refusal "$out/tapenade/reverse/lh009_b.f" generated-reverse

compile_start=$(date +%s.%N)
for source in "$case_dir/lh009.f90" \
    "$case_dir/hand_derivative_lh009.f90"; do
    base=$(basename "$source" .f90)
    "$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
        "$source" -o "$out/$base.o"
done
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
    "$root/harness/bench_tapenade_set01_lh009.f90" -o "$out/harness.o"
"$fc" "${compile_flags[@]}" -o "$out/bench" "$out/lh009.o" \
    "$out/hand_derivative_lh009.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" \
    2>"$out/run.stderr"
grep -Fqx 'refusal_oracle_status: pass' "$out/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh009 invalid-source refusal\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_exact_source_compile_statuses:\n'
    for status in "$out"/upstream-*.status; do
        printf '%s %s\n' "${status##*/}" "$(cat "$status")"
    done
    printf 'upstream_exact_source_diagnostics:\n'
    for log in "$out"/upstream-*.stderr; do
        printf '%s:\n' "${log##*/}"
        grep -F 'Error:' "$log" || true
    done
    printf 'tapenade_generation_status: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_generated_strict_compile_statuses:\n'
    for status in "$out"/generated-*.status; do
        printf '%s %s\n' "${status##*/}" "$(cat "$status")"
    done
    printf 'tapenade_generated_strict_diagnostics:\n'
    for log in "$out"/generated-*.stderr; do
        printf '%s:\n' "${log##*/}"
        grep -F 'Error:' "$log" || true
    done
    printf 'independent_oracle: bounded standard-conforming primal, hand JVP/VJP, '
    printf '%s\n' 'four-step central-difference sweep, and adjoint identity'
    printf 'port_result: independent-oracle-only-not-counted-as-support\n'
    printf 'fortad_result: not-run-invalid-upstream-source\n'
    printf 'refusal_reason: exact upstream and fresh Tapenade outputs contain '
    printf '%s\n' 'the REAL/CHARACTER conflict for A; repairing it would change the candidate'
    printf 'bounded_port_compile_and_link_seconds: %s\n' "$compile_seconds"
    cat "$out/runtime-metrics.txt"
    printf 'refusal_oracle_status: pass\n'
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/lh009.f90 \
        cases/tapenade-set01/hand_derivative_lh009.f90 \
        cases/tapenade-set01/lh009-manifest.toml \
        cases/tapenade-set01/lh009.md \
        harness/bench_tapenade_set01_lh009.f90 \
        scripts/bench_tapenade_set01_lh009.sh)
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"

cat "$result"
