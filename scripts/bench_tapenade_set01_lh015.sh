#!/usr/bin/env bash
# Validate the exact-source and generated-code refusal boundary for lh015.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh015_refusal_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -ffixed-line-length-none)
oracle_flags=(-std=f2018 -pedantic-errors -Wall -Wextra -ffree-line-length-none -fno-lto)
upstream_dir="$tapenade_repo/nonRegressions/set01/lh015"

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v python3 >/dev/null
command -v java >/dev/null
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
git -C "$fortad_repo" cat-file -e "$required_fortad_commit^{commit}"
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_commit" HEAD
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$tapenade_repo/bin/tapenade"

python3 - "$case_dir/tranche-lh015-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
case = manifest["case"][0]
if manifest["runner"] != "scripts/bench_tapenade_set01_lh015.sh":
    raise SystemExit("lh015 manifest names a different runner")
if manifest["upstream_revision"] != \
        "e59864cab441d4175df75383b3ff58c3dcd26df9":
    raise SystemExit("lh015 manifest has the wrong Tapenade revision")
if case["upstream_source"] != "nonRegressions/set01/lh015/program.f":
    raise SystemExit("lh015 manifest names a different upstream source")
if case["classification"] != "unsupported-invalid-upstream-fortran":
    raise SystemExit("lh015 must remain an upstream-source refusal")
if case["ported_entry_point"] != "none":
    raise SystemExit("lh015 must not claim a repaired port")
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-lh015.XXXXXX")
mkdir -p "$out/mod" "$out/oracle" "$out/parser" "$out/forward" "$out/reverse"
source="$upstream_dir/program.f"

(cd "$fortad_repo" && fo build) >"$out/fortad-build.stdout" \
    2>"$out/fortad-build.stderr" < /dev/null

compile_expected() {
    local input=$1 label=$2 expected=$3 flags_name=$4
    local object="$out/$label.o"
    local log="$out/$label"
    local -n flags_ref=$flags_name
    set +e
    "$fc" "${flags_ref[@]}" -c "$input" -o "$object" \
        >"$log.stdout" 2>"$log.stderr"
    local status=$?
    set -e
    printf '%s %s\n' "$label" "$status" >"$log.status"
    test "$status" -eq "$expected"
}

compile_expected "$source" upstream-program 1 strict_flags
compile_expected "$upstream_dir/program_d.f" upstream-program_d 1 strict_flags
compile_expected "$upstream_dir/program_b.f" upstream-program_b 0 strict_flags
grep -Fq "argument of" "$out/upstream-program.stderr"
grep -Fq "Deleted feature: End expression in DO loop" \
    "$out/upstream-program_d.stderr"

run_tapenade() {
    local mode=$1 output_dir=$2
    shift 2
    set +e
    "$tapenade_repo/bin/tapenade" "$@" >"$out/$mode.stdout" \
        2>"$out/$mode.stderr"
    local status=$?
    set -e
    printf '%s %s\n' "$mode" "$status" >"$out/$mode.status"
    test "$status" -eq 0
}

run_tapenade parser "$out/parser" -p -O "$out/parser" -o lh015 "$source"
run_tapenade forward "$out/forward" -d -root s2 -O "$out/forward" \
    -o lh015 "$source"
run_tapenade reverse "$out/reverse" -b -root s2 -O "$out/reverse" \
    -o lh015 "$source"
grep -Fq "TC07" "$out/parser/lh015_p.msg"
grep -Fq "DF03" "$out/forward/lh015_d.msg"
grep -Fq "TC16" "$out/reverse/lh015_b.msg"

compile_expected "$out/parser/lh015_p.f" tapenade-parser 1 strict_flags
compile_expected "$out/forward/lh015_d.f" tapenade-forward 1 strict_flags
compile_expected "$out/reverse/lh015_b.f" tapenade-reverse 0 strict_flags
grep -Fq "Deleted feature: End expression in DO loop" \
    "$out/tapenade-parser.stderr"
grep -Fq "Deleted feature: End expression in DO loop" \
    "$out/tapenade-forward.stderr"

# FortAD reaches its stable exact-source COMMON boundary before it can repair
# the additional invalid typing and initialization in this candidate.
run_fortad() {
    local mode=$1
    local output="$out/set01_lh015_${mode}.f90"
    set +e
    if test "$mode" = forward; then
        (cd "$fortad_repo" && fo exec --no-build fortad --mode forward \
            --indep p --proc s2 --name set01_lh015_jvp \
            --module set01_lh015_jvp_ad --output "$output" "$source") \
            >"$out/fortad-$mode.stdout" 2>"$out/fortad-$mode.stderr"
    else
        (cd "$fortad_repo" && fo exec --no-build fortad --mode reverse \
            --indep p --dep T1 --proc s2 --name set01_lh015_vjp \
            --module set01_lh015_vjp_ad --output "$output" "$source") \
            >"$out/fortad-$mode.stdout" 2>"$out/fortad-$mode.stderr"
    fi
    local status=$?
    set -e
    printf '%s %s\n' "$mode" "$status" >"$out/fortad-$mode.status"
    test "$status" -ne 0
    grep -Fq "fortad: unsupported statement at line 8" \
        "$out/fortad-$mode.stderr"
    test ! -e "$output"
}

run_fortad forward
run_fortad reverse

# Independent oracle: a bounded, initialized observation of the loop body.
"$fc" "${oracle_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
    "$case_dir/hand_derivative_lh015.f90" -o "$out/oracle/hand.o"
"$fc" "${oracle_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
    "$root/harness/bench_tapenade_set01_lh015.f90" -o "$out/oracle/harness.o"
"$fc" "${oracle_flags[@]}" -J"$out/mod" -I"$out/mod" \
    -o "$out/oracle/bench" "$out/oracle/hand.o" "$out/oracle/harness.o"
"$out/oracle/bench" >"$out/oracle/run.txt"
grep -Fqx "oracle_status: pass" "$out/oracle/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh015\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'oracle_compiler_flags: %s\n' "${oracle_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_compile_statuses:\n'
    cat "$out"/upstream-program*.status
    printf 'tapenade_generation_statuses:\n'
    cat "$out"/parser.status "$out"/forward.status "$out"/reverse.status
    printf 'tapenade_generated_compile_statuses:\n'
    cat "$out"/tapenade-parser.status "$out"/tapenade-forward.status \
        "$out"/tapenade-reverse.status
    printf 'fortad_transform_statuses:\n'
    cat "$out"/fortad-forward.status "$out"/fortad-reverse.status
    printf 'upstream_diagnostics:\n'
    grep -E 'Warning:|Error:' "$out/upstream-program.stderr" | head -8 || true
    grep -E 'Warning:|Error:' "$out/upstream-program_d.stderr" | head -8 || true
    printf 'tapenade_messages:\n'
    cat "$out/parser/lh015_p.msg" "$out/forward/lh015_d.msg" \
        "$out/reverse/lh015_b.msg"
    printf 'fortad_diagnostics:\n'
    grep -F 'fortad:' "$out/fortad-forward.stderr" "$out/fortad-reverse.stderr"
    printf 'oracle: independent bounded primal, hand JVP/VJP, four-step '
    printf '%s\n' 'central-difference sweep, and JVP/VJP adjoint identity'
    printf 'oracle_output:\n'
    cat "$out/oracle/run.txt"
    printf 'source_sha256:\n'
    sha256sum "$upstream_dir"/program*.f
    printf 'artifact_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/hand_derivative_lh015.f90 \
        cases/tapenade-set01/tranche-lh015-manifest.toml \
        cases/tapenade-set01/tranche-lh015.md \
        harness/bench_tapenade_set01_lh015.f90 \
        scripts/bench_tapenade_set01_lh015.sh)
    printf 'status: expected-refusal\n'
    printf 'refusal_reason: invalid exact upstream source plus FortAD COMMON '
    printf '%s\n' 'boundary; no repaired derivative port or runtime claim'
} >"$result"

cat "$result"
