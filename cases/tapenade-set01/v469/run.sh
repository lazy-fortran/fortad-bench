#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v469 boundary and port.
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
source_rel=todoF90/REFERENCES/v469
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v469.XXXXXX)
trap 'rm -rf "$out"' EXIT

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)

command -v "$fc" >/dev/null
command -v fo >/dev/null
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
for source in Options all_globals_mod.mod anothermodule.mod program.f90 \
    program_Rd.f90 program_Rd.msg program_Rb.f90 program_Rb.msg; do
    test -s "$source_dir/$source"
done

mkdir -p "$out/exact" "$out/exact-mod/primal" "$out/exact-mod/rd" \
    "$out/exact-mod/rb" "$out/fresh/parser" "$out/fresh/tangent" \
    "$out/fresh/reverse" "$out/fresh-mod/parser" "$out/fresh-mod/tangent" \
    "$out/fresh-mod/reverse" "$out/fortad" "$out/fortad-mod/parser" \
    "$out/fortad-mod/forward" "$out/fortad-mod/reverse" \
    "$out/port-generated" "$out/port-mod"

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
    local module_dir=$3
    shift 3
    mkdir -p "$module_dir"
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" \
        -I"$module_dir" -J"$module_dir" -c "$source" -o "$out/$label.o" "$@"
}

fortad_run() {
    (cd "$fortad_repo" && fo exec --no-build fortad "$@")
}

# Contract test 1: compile every exact source and stored reference strictly.
compile_source exact-primal "$source_dir/program.f90" "$out/exact-mod/primal"
compile_source exact-stored-tangent "$source_dir/program_Rd.f90" "$out/exact-mod/rd"
compile_source exact-stored-reverse "$source_dir/program_Rb.f90" "$out/exact-mod/rb"
test "$(cat "$out/exact-primal.status")" -ne 0
grep -Fq "Nonconforming tab character" "$out/exact-primal.stderr"
test "$(cat "$out/exact-stored-tangent.status")" -eq 0
test "$(cat "$out/exact-stored-reverse.status")" -eq 0

# Contract test 2: fresh pinned Tapenade parser, tangent, and reverse output.
for mode in parser tangent reverse; do
    case "$mode" in
        parser) tap_mode=-p; suffix=p ;;
        tangent) tap_mode=-d; suffix=d ;;
        reverse) tap_mode=-b; suffix=b ;;
    esac
    run_status "fresh-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' -association byaddress '$tap_mode' \
         -root head -O . -o v469 '$source_dir/program.f90'"
    test "$(cat "$out/fresh-$mode-generation.status")" -eq 0
    test -s "$out/fresh/$mode/v469_${suffix}.f90"
    test -s "$out/fresh/$mode/v469_${suffix}.msg"
    compile_source "fresh-$mode-compile" "$out/fresh/$mode/v469_${suffix}.f90" \
        "$out/fresh-mod/$mode"
    test "$(cat "$out/fresh-$mode-compile.status")" -eq 0
done

# Contract test 3: exact FortAD products, bounded port runtime, and oracle.
run_status fortad-exact-parser fortad_run check --proc head \
    --output "$out/fortad/parser.f90" "$source_dir/program.f90"
run_status fortad-exact-forward fortad_run --mode forward --indep x --dep y \
    --proc head --name v469_forward --module v469_forward_mod \
    --output "$out/fortad/forward.f90" "$source_dir/program.f90"
run_status fortad-exact-reverse fortad_run --mode reverse --indep x --dep y \
    --proc head --name v469_reverse --module v469_reverse_mod \
    --output "$out/fortad/reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-exact-$mode.status")" -eq 0
    test -s "$out/fortad/$mode.f90"
    compile_source "fortad-exact-$mode-compile" "$out/fortad/$mode.f90" \
        "$out/fortad-mod/$mode"
    test "$(cat "$out/fortad-exact-$mode-compile.status")" -eq 0
done

run_status fortad-port-forward fortad_run --mode forward --indep x --dep y \
    --proc v469_head --name v469_port_forward --module v469_port_forward_mod \
    --output "$out/port-generated/forward.f90" "$case_dir/port.f90"
run_status fortad-port-reverse fortad_run --mode reverse --indep x --dep y \
    --proc v469_head --name v469_port_reverse --module v469_port_reverse_mod \
    --output "$out/port-generated/reverse.f90" "$case_dir/port.f90"
test "$(cat "$out/fortad-port-forward.status")" -eq 0
test "$(cat "$out/fortad-port-reverse.status")" -eq 0
test -s "$out/port-generated/forward.f90"
test -s "$out/port-generated/reverse.f90"
compile_source port "$case_dir/port.f90" "$out/port-mod"
compile_source port-forward "$out/port-generated/forward.f90" "$out/port-mod"
compile_source port-reverse "$out/port-generated/reverse.f90" "$out/port-mod"
compile_source harness "$case_dir/harness.f90" "$out/port-mod"
for label in port port-forward port-reverse harness; do
    test "$(cat "$out/$label.status")" -eq 0
done
"$fc" -o "$out/v469-harness" "$out/port.o" "$out/port-forward.o" \
    "$out/port-reverse.o" "$out/harness.o" >"$out/link.stdout" 2>"$out/link.stderr"
"$out/v469-harness" >"$out/harness.stdout"
grep -Fqx "harness_status: pass" "$out/harness.stdout"

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v469 strict tab boundary and bounded port\n'
    printf 'classification: runnable-ported-with-exact-source-refusal\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: head(x,y)\n'
    printf 'tapenade_options: -association byaddress; parser=-p tangent=-d reverse=-b; root=head\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_Rd.f90=%s program_Rb.f90=%s\n' \
        "$(cat "$out/exact-primal.status")" "$(cat "$out/exact-stored-tangent.status")" \
        "$(cat "$out/exact-stored-reverse.status")"
    printf 'exact_primal_diagnostic: nonconforming-tab-character-under-pedantic-errors\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-generation.status")" \
        "$(cat "$out/fresh-tangent-generation.status")" \
        "$(cat "$out/fresh-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v469_p.f90 tangent=v469_d.f90 reverse=v469_b.f90\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-compile.status")" \
        "$(cat "$out/fresh-tangent-compile.status")" \
        "$(cat "$out/fresh-reverse-compile.status")"
    printf 'fortad_exact_parser: transform=%s strict_compile=%s\n' \
        "$(cat "$out/fortad-exact-parser.status")" "$(cat "$out/fortad-exact-parser-compile.status")"
    printf 'fortad_exact_forward: transform=%s strict_compile=%s\n' \
        "$(cat "$out/fortad-exact-forward.status")" "$(cat "$out/fortad-exact-forward-compile.status")"
    printf 'fortad_exact_reverse: transform=%s strict_compile=%s\n' \
        "$(cat "$out/fortad-exact-reverse.status")" "$(cat "$out/fortad-exact-reverse-compile.status")"
    printf 'fortad_bounded_forward: transform=%s strict_compile=%s\n' \
        "$(cat "$out/fortad-port-forward.status")" "$(cat "$out/port-forward.status")"
    printf 'fortad_bounded_reverse: transform=%s strict_compile=%s\n' \
        "$(cat "$out/fortad-port-reverse.status")" "$(cat "$out/port-reverse.status")"
    printf 'bounded_port_compile: port=%s harness=%s link=0 runtime=0\n' \
        "$(cat "$out/port.status")" "$(cat "$out/harness.status")"
    cat "$out/oracle.txt"
    cat "$out/harness.stdout"
    printf 'bounded_domain: one-element finite real(8) x and y arrays\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/all_globals_mod.mod \
        "$source_rel"/anothermodule.mod "$source_rel"/program.f90 \
        "$source_rel"/program_Rd.f90 "$source_rel"/program_Rd.msg \
        "$source_rel"/program_Rb.f90 "$source_rel"/program_Rb.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/v469_p.f90 parser/v469_p.msg \
        tangent/v469_d.f90 tangent/v469_d.msg reverse/v469_b.f90 reverse/v469_b.msg)
    printf 'fortad_exact_sha256:\n'
    sha256sum "$out/fortad/parser.f90" "$out/fortad/forward.f90" "$out/fortad/reverse.f90"
    printf 'fortad_bounded_sha256:\n'
    sha256sum "$out/port-generated/forward.f90" "$out/port-generated/reverse.f90"
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md port.f90 harness.f90 oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
