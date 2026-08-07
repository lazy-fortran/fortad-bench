#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v422 boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=todoF90/REFERENCES/v422
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v422.XXXXXX)
trap 'rm -rf "$out"' EXIT

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"
for source in Options example3.mod m1.mod program.f90 program_Rd.f90 program_Rd.msg; do
    test -s "$source_dir/$source"
done

mkdir -p "$out/exact" "$out/exact/primal-mod" "$out/exact/stored-mod" \
    "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse" \
    "$out/fresh/parser-mod" "$out/fresh/forward-mod" "$out/fresh/reverse-mod" \
    "$out/fortad/parser-mod" "$out/fortad/forward-mod" "$out/fortad/reverse-mod"
strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_source() {
    local label=$1
    local source=$2
    local moddir=$3
    mkdir -p "$moddir"
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" \
        -J"$moddir" -c "$source" -o "$out/$label.o"
}

# Contract test 1: exact primal and stored reference behavior.
compile_source upstream_primal "$source_dir/program.f90" "$out/exact/primal-mod"
compile_source upstream_stored "$source_dir/program_Rd.f90" "$out/exact/stored-mod"
test "$(cat "$out/upstream_primal.status")" -eq 0
test "$(cat "$out/upstream_stored.status")" -eq 0
grep -Fq "Return value of function" "$out/upstream_primal.stderr"
grep -Fq "Return value of function" "$out/upstream_stored.stderr"
grep -Fq "Unused variable" "$out/upstream_stored.stderr"

# Contract test 2: fresh parser, tangent, and reverse generation plus compile.
for mode in p d b; do
    case "$mode" in
        p) label=parser ;;
        d) label=forward ;;
        b) label=reverse ;;
    esac
    run_status "fresh-$label-generation" bash -c \
        "cd '$out/fresh/$label' && '$tapenade' -association byaddress '-$mode' \
         -root f4 -O . -o v422 '$source_dir/program.f90'"
    test "$(cat "$out/fresh-$label-generation.status")" -eq 0
    test -s "$out/fresh/$label/v422_${mode}.f90"
    test -s "$out/fresh/$label/v422_${mode}.msg"
    compile_source "fresh-$label" "$out/fresh/$label/v422_${mode}.f90" \
        "$out/fresh/$label-mod"
    test "$(cat "$out/fresh-$label.status")" -eq 0
    grep -Fq "Return value" "$out/fresh-$label.stderr"
done

# Contract test 3: exact FortAD parser/forward/reverse behavior.
run_status fortad-parser "$fortad" check --proc f4 \
    --output "$out/exact/parser.f90" "$source_dir/program.f90"
test "$(cat "$out/fortad-parser.status")" -eq 0
test -s "$out/exact/parser.f90"
compile_source fortad-parser-compile "$out/exact/parser.f90" \
    "$out/fortad/parser-mod"
test "$(cat "$out/fortad-parser-compile.status")" -ne 0
grep -Fq "Invalid character in name" "$out/fortad-parser-compile.stderr"

run_status fortad-forward "$fortad" --mode forward --proc f4 --indep t \
    --name v422_forward --module v422_forward_mod \
    --output "$out/exact/forward.f90" "$source_dir/program.f90"
test "$(cat "$out/fortad-forward.status")" -eq 0
test -s "$out/exact/forward.f90"
compile_source fortad-forward-compile "$out/exact/forward.f90" \
    "$out/fortad/forward-mod"
test "$(cat "$out/fortad-forward-compile.status")" -ne 0
grep -Fq "Invalid character in name" "$out/fortad-forward-compile.stderr"

run_status fortad-reverse "$fortad" --mode reverse --proc f4 --indep t --dep t \
    --name v422_reverse --module v422_reverse_mod \
    --output "$out/exact/reverse.f90" "$source_dir/program.f90"
test "$(cat "$out/fortad-reverse.status")" -eq 0
test -s "$out/exact/reverse.f90"
compile_source fortad-reverse-compile "$out/exact/reverse.f90" \
    "$out/fortad/reverse-mod"
test "$(cat "$out/fortad-reverse-compile.status")" -ne 0
grep -Fq "Duplicate symbol" "$out/fortad-reverse-compile.stderr"

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90/REFERENCES/v422 undefined-result boundary\n'
    printf 'classification: expected-refusal-undefined-function-result-and-codegen\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_points: m1.f4(t)\n'
    printf 'tapenade_options: -association byaddress -p/-d/-b -root f4\n'
    printf 'upstream_exact_strict_compile: program=%s stored_program_Rd=%s\n' \
        "$(cat "$out/upstream_primal.status")" "$(cat "$out/upstream_stored.status")"
    printf 'upstream_diagnostic: f4-function-result-not-set-warning\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-generation.status")" \
        "$(cat "$out/fresh-forward-generation.status")" \
        "$(cat "$out/fresh-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v422_p.f90 tangent=v422_d.f90 reverse=v422_b.f90\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser.status")" "$(cat "$out/fresh-forward.status")" \
        "$(cat "$out/fresh-reverse.status")"
    printf 'fortad_exact_parser: transform=%s generated=strict-compile-%s diagnostic="result() and blank declaration"\n' \
        "$(cat "$out/fortad-parser.status")" "$(cat "$out/fortad-parser-compile.status")"
    printf 'fortad_exact_forward: transform=%s generated=strict-compile-%s diagnostic="blank dependent argument"\n' \
        "$(cat "$out/fortad-forward.status")" "$(cat "$out/fortad-forward-compile.status")"
    printf 'fortad_exact_reverse: transform=%s generated=strict-compile-%s diagnostic="duplicate t_b argument"\n' \
        "$(cat "$out/fortad-reverse.status")" "$(cat "$out/fortad-reverse-compile.status")"
    printf 'oracle: %s\n' "$(cat "$out/oracle.txt")"
    printf 'port_result: not-applicable-undefined-function-result\n'
    printf 'closure: no bounded port; assigning f4 or changing the dependent would define a different candidate\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum \
        "$source_rel"/Options "$source_rel"/example3.mod "$source_rel"/m1.mod \
        "$source_rel"/program.f90 "$source_rel"/program_Rd.f90 "$source_rel"/program_Rd.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && find . -type f \( -name '*.f90' -o -name '*.msg' \) -print0 | sort -z | xargs -0 sha256sum)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/v422/manifest.toml \
        cases/tapenade-set01/v422/notes.md cases/tapenade-set01/v422/oracle.py \
        cases/tapenade-set01/v422/run.sh cases/tapenade-set01/v422/test_contract.py)
} >"$result"
cat "$result"
