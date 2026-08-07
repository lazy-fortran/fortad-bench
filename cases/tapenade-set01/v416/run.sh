#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v416 boundary and port.
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
source_rel=todoF90/REFERENCES/v416
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v416.XXXXXX)
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
for source in Options program.f90 program_Rd.f90 program_Rd.msg; do
    test -s "$source_dir/$source"
done

mkdir -p "$out/exact" "$out/exact-mod-primal" "$out/exact-mod-stored" \
    "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse" \
    "$out/fresh-mod/parser" "$out/fresh-mod/forward" "$out/fresh-mod/reverse" \
    "$out/port-mod" "$out/port-generated" "$out/port-generated-mod"

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
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" -I"$module_dir" \
        -J"$module_dir" -c "$source" -o "$out/$label.o" "$@"
}

fortad_run() {
    (cd "$fortad_repo" && fo exec --no-build fortad "$@")
}

# Contract 1: exact pinned source and stored tangent strict behavior.
compile_source exact_primal "$source_dir/program.f90" "$out/exact-mod-primal"
compile_source exact_stored_tangent "$source_dir/program_Rd.f90" "$out/exact-mod-stored"
test "$(cat "$out/exact_primal.status")" -ne 0
grep -Eq "used before it is typed|GNU Extension.*nm_ha" "$out/exact_primal.stderr"
test "$(cat "$out/exact_stored_tangent.status")" -eq 0
grep -Fq "Integer division truncated" "$out/exact_stored_tangent.stderr"

# Contract 2: fresh pinned parser, tangent, and reverse generation plus strict compile.
for mode in parser forward reverse; do
    case "$mode" in
        parser) tap_mode=-p; suffix=p ;;
        forward) tap_mode=-d; suffix=d ;;
        reverse) tap_mode=-b; suffix=b ;;
    esac
    run_status "fresh-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$tap_mode' -root precechcin -O . -o v416 '$source_dir/program.f90'"
    test "$(cat "$out/fresh-$mode-generation.status")" -eq 0
    test -s "$out/fresh/$mode/v416_${suffix}.f90"
    test -s "$out/fresh/$mode/v416_${suffix}.msg"
    compile_source "fresh-$mode-compile" "$out/fresh/$mode/v416_${suffix}.f90" \
        "$out/fresh-mod/$mode"
    test "$(cat "$out/fresh-$mode-compile.status")" -eq 0
done

# Contract 3a: exact FortAD parser/forward/reverse transform behavior.
run_status fortad-exact-parser fortad_run check --proc precechcin \
    --output "$out/exact/parser.f90" "$source_dir/program.f90"
run_status fortad-exact-forward fortad_run --mode forward --proc precechcin \
    --indep x,Tm_ha --name v416_forward --module v416_forward_mod \
    --output "$out/exact/forward.f90" "$source_dir/program.f90"
run_status fortad-exact-reverse fortad_run --mode reverse --proc precechcin \
    --indep x,Tm_ha --dep y --name v416_reverse --module v416_reverse_mod \
    --output "$out/exact/reverse.f90" "$source_dir/program.f90"
test "$(cat "$out/fortad-exact-parser.status")" -eq 0
test -s "$out/exact/parser.f90"
compile_source fortad-exact-parser-compile "$out/exact/parser.f90" "$out/exact-mod-parser"
test "$(cat "$out/fortad-exact-parser-compile.status")" -ne 0
grep -Eq "used before it is typed|GNU Extension.*nm_ha" "$out/fortad-exact-parser-compile.stderr"
for mode in forward reverse; do
    test "$(cat "$out/fortad-exact-$mode.status")" -eq 0
    test -s "$out/exact/$mode.f90"
    compile_source "fortad-exact-$mode-compile" "$out/exact/$mode.f90" "$out/exact-mod-$mode"
    test "$(cat "$out/fortad-exact-$mode-compile.status")" -eq 0
done

# Contract 3b: bounded port, FortAD products, strict compilation, and runtime.
run_status fortad-port-forward fortad_run --mode forward --proc set01_v416 \
    --indep x,Tm_ha --name v416_port_forward --module v416_port_forward_mod \
    --output "$out/port-generated/forward.f90" "$case_dir/port.f90"
run_status fortad-port-reverse fortad_run --mode reverse --proc set01_v416 \
    --indep x,Tm_ha --dep y --name v416_port_reverse --module v416_port_reverse_mod \
    --output "$out/port-generated/reverse.f90" "$case_dir/port.f90"
test "$(cat "$out/fortad-port-forward.status")" -eq 0
test "$(cat "$out/fortad-port-reverse.status")" -eq 0
compile_source port "$case_dir/port.f90" "$out/port-generated-mod"
compile_source port-forward "$out/port-generated/forward.f90" "$out/port-generated-mod"
compile_source port-reverse "$out/port-generated/reverse.f90" "$out/port-generated-mod"
compile_source harness "$case_dir/harness.f90" "$out/port-generated-mod"
for label in port port-forward port-reverse harness; do
    test "$(cat "$out/$label.status")" -eq 0
done
"$fc" -o "$out/v416-harness" "$out/port.o" "$out/port-forward.o" \
    "$out/port-reverse.o" "$out/harness.o" >"$out/link.stdout" 2>"$out/link.stderr"
"$out/v416-harness" >"$out/harness.stdout"
grep -Fqx "harness_status: pass" "$out/harness.stdout"

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fqx "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v416 declaration-order boundary\n'
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
    printf 'upstream_entry_point: precechcin(x,y,nm_ha,Tm_ha)\n'
    printf 'tapenade_options: association-byaddress parser=-p/-root precechcin forward=-d/-root precechcin reverse=-b/-root precechcin\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_Rd.f90=%s\n' \
        "$(cat "$out/exact_primal.status")" "$(cat "$out/exact_stored_tangent.status")"
    printf 'upstream_exact_diagnostics: program.f90=nm_ha-used-before-typed program_Rd.f90=integer-division-warning\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-generation.status")" \
        "$(cat "$out/fresh-forward-generation.status")" \
        "$(cat "$out/fresh-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v416_p.f90 tangent=v416_d.f90 reverse=v416_b.f90\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-compile.status")" \
        "$(cat "$out/fresh-forward-compile.status")" \
        "$(cat "$out/fresh-reverse-compile.status")"
    printf 'fortad_exact_parser: transform=%s strict_compile=%s diagnostic="nm_ha-used-before-typed"\n' \
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
    printf 'bounded_domain: nm_ha>=2 and finite nonzero Tm_ha\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum Options program.f90 program_Rd.f90 program_Rd.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/v416_p.f90 parser/v416_p.msg \
        forward/v416_d.f90 forward/v416_d.msg reverse/v416_b.f90 reverse/v416_b.msg)
    printf 'fortad_exact_sha256:\n'
    sha256sum "$out/exact/parser.f90" "$out/exact/forward.f90" "$out/exact/reverse.f90"
    printf 'fortad_bounded_sha256:\n'
    sha256sum "$out/port-generated/forward.f90" "$out/port-generated/reverse.f90"
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md port.f90 harness.f90 oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
