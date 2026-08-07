#!/usr/bin/env bash
# Validate the pinned Tapenade set01/lh035 invalid-upstream closure.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -Wall -Wextra \
    -ffixed-line-length-none -fno-lto)

command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -x "$tapenade_repo/bin/tapenade"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

source_dir="$tapenade_repo/nonRegressions/set01/lh035"
for source in program.f program_p.f program_p.msg; do
    test -s "$source_dir/$source"
done
for diagnostic in "(DD02)" "(DD01)" "(TC16)"; do
    grep -Fq "$diagnostic" "$source_dir/program_p.msg"
done

out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh035.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse"

compile_capture() {
    local source=$1 label=$2
    local status
    set +e
    "$fc" "${strict_flags[@]}" -c "$source" -o "$out/$label.o" \
        >"$out/$label.stdout" 2>"$out/$label.stderr"
    status=$?
    set -e
    printf '%s\n' "$status"
}

exact_status=$(compile_capture "$source_dir/program.f" exact)
stored_status=$(compile_capture "$source_dir/program_p.f" stored-parser)
test "$exact_status" -ne 0
test "$stored_status" -ne 0
grep -Fq "Duplicate DIMENSION attribute specified" "$out/exact.stderr"
grep -Fq "Cannot convert CHARACTER(10) to REAL(4)" "$out/exact.stderr"
grep -Fq "already has basic type of REAL" "$out/stored-parser.stderr"
grep -Fq "Cannot convert CHARACTER(10) to REAL(4)" "$out/stored-parser.stderr"

tapenade="$tapenade_repo/bin/tapenade"
set +e
"$tapenade" -p -O "$out/tapenade/parser" -o lh035 "$source_dir/program.f" \
    >"$out/tapenade/parser.stdout" 2>"$out/tapenade/parser.stderr"
parser_generation_status=$?
"$tapenade" -d -root bug7 -O "$out/tapenade/forward" -o lh035 \
    "$source_dir/program.f" >"$out/tapenade/forward.stdout" \
    2>"$out/tapenade/forward.stderr"
forward_generation_status=$?
"$tapenade" -b -root bug7 -O "$out/tapenade/reverse" -o lh035 \
    "$source_dir/program.f" >"$out/tapenade/reverse.stdout" \
    2>"$out/tapenade/reverse.stderr"
reverse_generation_status=$?
set -e
test "$parser_generation_status" -eq 0
test "$forward_generation_status" -eq 0
test "$reverse_generation_status" -eq 0

parser_source="$out/tapenade/parser/lh035_p.f"
forward_source="$out/tapenade/forward/lh035_d.f"
reverse_source="$out/tapenade/reverse/lh035_b.f"
for generated in "$parser_source" "$forward_source" "$reverse_source"; do
    test -s "$generated"
done
for message in "$out/tapenade/parser/lh035_p.msg" \
    "$out/tapenade/forward/lh035_d.msg" \
    "$out/tapenade/reverse/lh035_b.msg"; do
    test -s "$message"
    grep -Fq "(DD02)" "$message"
    grep -Fq "(DD01)" "$message"
    grep -Fq "(TC16)" "$message"
done

parser_status=$(compile_capture "$parser_source" tapenade-parser)
forward_status=$(compile_capture "$forward_source" tapenade-forward)
reverse_status=$(compile_capture "$reverse_source" tapenade-reverse)
test "$parser_status" -ne 0
test "$forward_status" -ne 0
test "$reverse_status" -ne 0
grep -Fq "already has basic type of REAL" "$out/tapenade-parser.stderr"
grep -Fq "already has basic type of REAL" "$out/tapenade-forward.stderr"
grep -Fq "already has basic type of REAL" "$out/tapenade-reverse.stderr"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir" --compiler "$fc")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

fortad_probe() {
    local mode=$1 output=$2 log=$3
    local status
    set +e
    if test "$mode" = forward; then
        (cd "$fortad_repo" && fo exec --no-build fortad --mode forward \
            --indep x --proc bug7 --name lh035_jvp --module lh035_jvp_mod \
            --output "$output" "$source_dir/program.f") >"$log" 2>&1
    else
        (cd "$fortad_repo" && fo exec --no-build fortad --mode reverse \
            --indep x --dep x --proc bug7 --name lh035_vjp \
            --module lh035_vjp_mod --output "$output" \
            "$source_dir/program.f") >"$log" 2>&1
    fi
    status=$?
    set -e
    test "$status" -ne 0
    grep -Fq "fortad: unsupported statement at line 3" "$log"
    test ! -e "$output"
    printf '%s\n' "$status"
}

fortad_forward_status=$(fortad_probe forward "$out/fortad-forward.f90" \
    "$out/fortad-forward.log")
fortad_reverse_status=$(fortad_probe reverse "$out/fortad-reverse.f90" \
    "$out/fortad-reverse.log")

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh035\n'
    printf 'classification: unsupported-invalid-upstream-fortran\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'stored_references: program_p.f program_p.msg\n'
    printf 'diffsizes_include: not-present\n'
    printf 'upstream_exact_strict_compile: expected-refusal status=%s\n' "$exact_status"
    printf 'upstream_stored_parser_strict_compile: expected-refusal status=%s\n' "$stored_status"
    printf 'tapenade_parser_generation: pass status=%s\n' "$parser_generation_status"
    printf 'tapenade_forward_generation: pass status=%s\n' "$forward_generation_status"
    printf 'tapenade_reverse_generation: pass status=%s\n' "$reverse_generation_status"
    printf 'tapenade_parser_strict_compile: expected-refusal status=%s\n' "$parser_status"
    printf 'tapenade_forward_strict_compile: expected-refusal status=%s\n' "$forward_status"
    printf 'tapenade_reverse_strict_compile: expected-refusal status=%s\n' "$reverse_status"
    printf 'tapenade_diagnostics: DD02 DD01 TC16 in parser, forward, and reverse messages\n'
    printf 'stored_program_p_msg: DD02 DD01 TC16\n'
    printf 'fortad_forward: expected-refusal status=%s diagnostic="fortad: unsupported statement at line 3"\n' "$fortad_forward_status"
    printf 'fortad_reverse: expected-refusal status=%s diagnostic="fortad: unsupported statement at line 3"\n' "$fortad_reverse_status"
    printf 'fortad_generated_compile: not-applicable-no-output-on-refusal\n'
    printf 'independent_oracle: strict compiler rejection of exact and stored parser sources; no numerical semantics-preserving port exists\n'
    printf '%s\n' "$oracle_output"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_p.msg)
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$parser_source" "$forward_source" "$reverse_source"
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh035/manifest.toml \
        cases/tapenade-set01/lh035/notes.md cases/tapenade-set01/lh035/oracle.py \
        cases/tapenade-set01/lh035/run.sh cases/tapenade-set01/lh035/test_contract.py)
} >"$result"
cat "$result"
