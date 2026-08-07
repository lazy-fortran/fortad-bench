#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v414 derived-type boundary.
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
source_rel=todoF90/REFERENCES/v414
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"
for source in Options program.f90 program_Rd.f90 program_Rd.msg; do
    test -s "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/fortad-bench-v414.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/exact" "$out/upstream/mod" "$out/fresh/parser" \
    "$out/fresh/forward" "$out/fresh/reverse" "$out/fresh/parser-mod" \
    "$out/fresh/forward-mod" "$out/fresh/reverse-mod" "$out/fortad/parser-mod" \
    "$out/fortad/forward-mod" "$out/fortad/reverse-mod"

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

compile_source upstream_primal "$source_dir/program.f90" "$out/upstream/mod"
compile_source upstream_stored_tangent "$source_dir/program_Rd.f90" "$out/upstream/mod"
test "$(cat "$out/upstream_primal.status")" -eq 0
test "$(cat "$out/upstream_stored_tangent.status")" -eq 0

generate_tapenade() {
    local label=$1
    local mode=$2
    run_status "tapenade-$label-generation" bash -c \
        "cd '$out/fresh/$label' && '$tapenade' -association byaddress '$mode' \
         -root addvector -O . -o v414 '$source_dir/program.f90'"
}

generate_tapenade parser -p
generate_tapenade forward -d
generate_tapenade reverse -b
for generated in \
    "$out/fresh/parser/v414_p.f90" "$out/fresh/parser/v414_p.msg" \
    "$out/fresh/forward/v414_d.f90" "$out/fresh/forward/v414_d.msg" \
    "$out/fresh/reverse/v414_b.f90" "$out/fresh/reverse/v414_b.msg"; do
    test -s "$generated"
done
compile_source fresh_parser "$out/fresh/parser/v414_p.f90" "$out/fresh/parser-mod"
compile_source fresh_forward "$out/fresh/forward/v414_d.f90" "$out/fresh/forward-mod"
compile_source fresh_reverse "$out/fresh/reverse/v414_b.f90" "$out/fresh/reverse-mod"
test "$(cat "$out/fresh_parser.status")" -eq 0
test "$(cat "$out/fresh_forward.status")" -eq 0
test "$(cat "$out/fresh_reverse.status")" -eq 0

run_status fortad_parser "$fortad" check --proc addvector \
    --output "$out/fortad/parser.f90" "$source_dir/program.f90"
run_status fortad_forward "$fortad" --mode forward --indep 'a%x,b%x' \
    --proc addvector --name v414_forward --module v414_forward_mod \
    --output "$out/fortad/forward.f90" "$source_dir/program.f90"
run_status fortad_reverse "$fortad" --mode reverse --indep 'a%x,b%x' \
    --dep addvector --proc addvector --name v414_reverse \
    --module v414_reverse_mod --output "$out/fortad/reverse.f90" \
    "$source_dir/program.f90"
for generated in "$out/fortad/parser.f90" "$out/fortad/forward.f90" \
                 "$out/fortad/reverse.f90"; do
    test -s "$generated"
done
compile_source fortad_parser_compile "$out/fortad/parser.f90" "$out/fortad/parser-mod"
compile_source fortad_forward_compile "$out/fortad/forward.f90" "$out/fortad/forward-mod"
compile_source fortad_reverse_compile "$out/fortad/reverse.f90" "$out/fortad/reverse-mod"
test "$(cat "$out/fortad_parser.status")" -eq 0
test "$(cat "$out/fortad_forward.status")" -eq 0
test "$(cat "$out/fortad_reverse.status")" -eq 0
test "$(cat "$out/fortad_parser_compile.status")" -ne 0
test "$(cat "$out/fortad_forward_compile.status")" -ne 0
test "$(cat "$out/fortad_reverse_compile.status")" -ne 0
grep -Fq 'result()' "$out/fortad_parser_compile.stderr"
grep -Fq 'Derived type' "$out/fortad_parser_compile.stderr"
grep -Fq 'Invalid character in name' "$out/fortad_forward_compile.stderr"
grep -Fq 'Derived type' "$out/fortad_forward_compile.stderr"
grep -Fq 'addvector%x_b' "$out/fortad_reverse_compile.stderr"
grep -Fq 'Derived type' "$out/fortad_reverse_compile.stderr"

oracle_output=$(python3 "$case_dir/oracle.py")
grep -Fq 'oracle_status: pass' <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v414 derived-type output boundary\n'
    printf 'classification: expected-refusal-without-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: example3.addvector(a,b)\n'
    printf 'selected_entry_point: addvector(a,b); defined observable: addvector%%x; unassigned: addvector%%y\n'
    printf 'tapenade_options: -association byaddress; parser=-p/-root addvector forward=-d/-root addvector reverse=-b/-root addvector\n'
    printf 'upstream_exact_strict_compile: primal=%s stored_tangent=%s\n' \
        "$(cat "$out/upstream_primal.status")" "$(cat "$out/upstream_stored_tangent.status")"
    printf 'upstream_stored_tangent_diagnostic: %s\n' \
        "$(grep -F 'Warning:' "$out/upstream_stored_tangent.stderr" | head -1 || true)"
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh_parser.status")" "$(cat "$out/fresh_forward.status")" \
        "$(cat "$out/fresh_reverse.status")"
    printf 'fortad_exact_parser: transform=%s strict_compile=%s output=present diagnostic="empty result() and missing VECTOR context"\n' \
        "$(cat "$out/fortad_parser.status")" "$(cat "$out/fortad_parser_compile.status")"
    printf 'fortad_exact_forward: transform=%s strict_compile=%s output=present diagnostic="blank derivative dummy and missing VECTOR context"\n' \
        "$(cat "$out/fortad_forward.status")" "$(cat "$out/fortad_forward_compile.status")"
    printf 'fortad_exact_reverse: transform=%s strict_compile=%s output=present diagnostic="invalid addvector%%x_b declaration and missing VECTOR context"\n' \
        "$(cat "$out/fortad_reverse.status")" "$(cat "$out/fortad_reverse_compile.status")"
    printf 'independent_oracle:\n%s\n' "$oracle_output"
    printf 'port_result: not-claimed\n'
    printf 'closure: no repaired type context, y assignment, or bounded port; those would change the exact case\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/program.f90 \
        "$source_rel"/program_Rd.f90 "$source_rel"/program_Rd.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum v414_p.f90 v414_p.msg)
    (cd "$out/fresh/forward" && sha256sum v414_d.f90 v414_d.msg)
    (cd "$out/fresh/reverse" && sha256sum v414_b.f90 v414_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
