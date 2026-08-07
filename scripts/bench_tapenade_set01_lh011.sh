#!/usr/bin/env bash
# Record the exact-source refusal boundary for Tapenade set01 lh011.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
result="$root/results/tapenade_set01_lh011_refusal_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_bench_commit=4ee2f9457ff13c4cf345bbf7e0f61190b7c24a6e
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -ffixed-line-length-none -Wall -Wextra)
source="$tapenade_repo/nonRegressions/set01/lh011/program.f"

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v python3 >/dev/null
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
git -C "$fortad_repo" cat-file -e "$required_fortad_commit^{commit}"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
git -C "$tapenade_repo" cat-file -e "$required_tapenade_commit^{commit}"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
git -C "$root" cat-file -e "$required_bench_commit^{commit}"
git -C "$root" merge-base --is-ancestor "$required_bench_commit" HEAD
test -s "$source"
test -x "$tapenade_repo/bin/tapenade"

python3 - "$root/cases/tapenade-set01/tranche-q-lh011-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
case = manifest["case"][0]
assert manifest["runner"] == "scripts/bench_tapenade_set01_lh011.sh"
assert manifest["upstream_revision"] == \
    "e59864cab441d4175df75383b3ff58c3dcd26df9"
assert manifest["baseline_fortad_commit"] == \
    "db0050259520b618e2a0aeba203c85a7613943b5"
assert case["upstream_path"] == "nonRegressions/set01/lh011/program.f"
assert case["upstream_entry_point"] == "s1(a,b)"
assert case["ported_entry_point"] == "none"
assert case["classification"] == "expected-refusal"
assert case["expected_diagnostic"] == \
    "fortad: unsupported statement at line 6"
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-lh011.XXXXXX")
mkdir -p "$out/oracle/mod" "$out/tapenade/parser" \
    "$out/tapenade/forward" "$out/tapenade/reverse"

compile_source() {
    local input=$1 output=$2
    set +e
    "$fc" "${strict_flags[@]}" -c "$input" -o "$output" \
        >"$output.stdout" 2>"$output.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status"
}

compile_expected() {
    local input=$1 output=$2 expected=$3
    local status
    status=$(compile_source "$input" "$output")
    test "$status" = "$expected"
    printf '%s\n' "$status"
}

printf '%s\n' '--- strict exact and stored-reference compilation ---'
upstream_program_status=$(compile_expected "$source" "$out/upstream-program.o" 0)
upstream_d_status=$(compile_expected "${source%/*}/program_d.f" \
    "$out/upstream-program_d.o" 0)
upstream_b_status=$(compile_expected "${source%/*}/program_b.f" \
    "$out/upstream-program_b.o" 1)
grep -Fq 'GNU Extension: Nonstandard type declaration INTEGER*4' \
    "$out/upstream-program_b.o.stderr"
grep -Fq 'Symbol ‘branch’' "$out/upstream-program_b.o.stderr"

printf '%s\n' '--- fresh pinned Tapenade generation ---'
"$tapenade_repo/bin/tapenade" -p -O "$out/tapenade/parser" -o lh011 \
    "$source" >"$out/tapenade-parser.stdout" \
    2>"$out/tapenade-parser.stderr"
"$tapenade_repo/bin/tapenade" -d -root s1 -O "$out/tapenade/forward" \
    -o lh011 "$source" >"$out/tapenade-forward.stdout" \
    2>"$out/tapenade-forward.stderr"
"$tapenade_repo/bin/tapenade" -b -root s1 -O "$out/tapenade/reverse" \
    -o lh011 "$source" >"$out/tapenade-reverse.stdout" \
    2>"$out/tapenade-reverse.stderr"
test -s "$out/tapenade/parser/lh011_p.f"
test -s "$out/tapenade/forward/lh011_d.f"
test -s "$out/tapenade/reverse/lh011_b.f"

printf '%s\n' '--- strict fresh Tapenade output compilation ---'
tapenade_parser_status=$(compile_expected \
    "$out/tapenade/parser/lh011_p.f" "$out/tapenade/lh011_p.o" 0)
tapenade_forward_status=$(compile_expected \
    "$out/tapenade/forward/lh011_d.f" "$out/tapenade/lh011_d.o" 0)
tapenade_reverse_status=$(compile_expected \
    "$out/tapenade/reverse/lh011_b.f" "$out/tapenade/lh011_b.o" 1)
grep -Fq 'GNU Extension: Nonstandard type declaration INTEGER*4' \
    "$out/tapenade/lh011_b.o.stderr"
grep -Fq 'Symbol ‘branch’' "$out/tapenade/lh011_b.o.stderr"

printf '%s\n' '--- independent bounded behavioral oracle ---'
"$fc" "${strict_flags[@]}" -ffree-line-length-none \
    -J"$out/oracle/mod" -I"$out/oracle/mod" -c \
    "$root/cases/tapenade-set01/hand_derivative_lh011.f90" \
    -o "$out/oracle/hand_derivative.o"
"$fc" "${strict_flags[@]}" -ffree-line-length-none \
    -J"$out/oracle/mod" -I"$out/oracle/mod" -c \
    "$root/harness/bench_tapenade_set01_lh011.f90" \
    -o "$out/oracle/harness.o"
"$fc" "${strict_flags[@]}" -o "$out/oracle/bench" \
    "$out/oracle/hand_derivative.o" "$out/oracle/harness.o"
"$out/oracle/bench" >"$out/oracle/run.txt"
grep -Fqx 'oracle_status: pass' "$out/oracle/run.txt"

printf '%s\n' '--- FortAD exact-source boundary ---'
run_fortad_refusal() {
    local mode=$1 output=$2
    local status
    set +e
    if test "$mode" = forward; then
        (cd "$fortad_repo" && fo exec --no-build fortad --mode forward \
            --indep a --proc s1 --name lh011_jvp --module lh011_forward_ad \
            --output "$output" "$source") \
            >"$out/fortad-forward.stdout" \
            2>"$out/fortad-forward.stderr"
    else
        (cd "$fortad_repo" && fo exec --no-build fortad --mode reverse \
            --indep a --dep a --proc s1 --name lh011_vjp \
            --module lh011_reverse_ad --output "$output" "$source") \
            >"$out/fortad-reverse.stdout" \
            2>"$out/fortad-reverse.stderr"
    fi
    status=$?
    set -e
    test "$status" = 1
    test ! -e "$output"
    grep -Fqx 'fortad: unsupported statement at line 6' \
        <(grep -F 'fortad:' "$out/fortad-$mode.stderr" | tail -1)
    printf '%s\n' "$status"
}

fortad_forward_status=$(run_fortad_refusal forward \
    "$out/lh011_forward.f90")
fortad_reverse_status=$(run_fortad_refusal reverse \
    "$out/lh011_reverse.f90")

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh011 exact-source refusal\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$("$fc" --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'bench_baseline_commit: %s\n' "$required_bench_commit"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_program_compile_status: %s\n' "$upstream_program_status"
    printf 'upstream_program_d_compile_status: %s\n' "$upstream_d_status"
    printf 'upstream_program_b_compile_status: %s\n' "$upstream_b_status"
    printf 'upstream_program_diagnostics:\n'
    grep -E 'Error:|Warning:' "$out/upstream-program.o.stderr" || true
    printf 'upstream_program_b_diagnostics:\n'
    grep -E 'Error:|Warning:' "$out/upstream-program_b.o.stderr" || true
    printf 'tapenade_parser_generation: pass\n'
    printf 'tapenade_forward_generation: pass\n'
    printf 'tapenade_reverse_generation: pass\n'
    printf 'tapenade_parser_strict_compile_status: %s\n' \
        "$tapenade_parser_status"
    printf 'tapenade_forward_strict_compile_status: %s\n' \
        "$tapenade_forward_status"
    printf 'tapenade_reverse_strict_compile_status: %s\n' \
        "$tapenade_reverse_status"
    printf 'tapenade_reverse_diagnostics:\n'
    grep -E 'Error:|Warning:' "$out/tapenade/lh011_b.o.stderr" || true
    printf 'fortad_forward_status: %s\n' "$fortad_forward_status"
    printf 'fortad_reverse_status: %s\n' "$fortad_reverse_status"
    printf 'fortad_forward_diagnostic: %s\n' \
        "$(grep -F 'fortad:' "$out/fortad-forward.stderr" | tail -1)"
    printf 'fortad_reverse_diagnostic: %s\n' \
        "$(grep -F 'fortad:' "$out/fortad-reverse.stderr" | tail -1)"
    printf 'independent_oracle: bounded hand JVP/VJP, four-step central '
    printf '%s\n' 'difference sweep, and adjoint identity for explicit safe selectors'
    printf 'fortad_result: expected-refusal-no-transformation-or-runtime-claim\n'
    printf 'refusal_reason: exact source has an uninitialized computed-GOTO '
    printf '%s\n' 'selector and absent alternate-return callees; FortAD line-6 boundary'
    printf 'source_sha256:\n'
    sha256sum "$source" "${source%/*}/program_d.f" \
        "${source%/*}/program_b.f"
    printf 'artifact_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/hand_derivative_lh011.f90 \
        cases/tapenade-set01/tranche-q-lh011-manifest.toml \
        cases/tapenade-set01/tranche-q-lh011.md \
        harness/bench_tapenade_set01_lh011.f90 \
        scripts/bench_tapenade_set01_lh011.sh \
        scripts/test_tapenade_set01_lh011.py)
    printf 'oracle_output:\n'
    cat "$out/oracle/run.txt"
    printf 'refusal_oracle_status: pass\n'
} >"$result"

cat "$result"
