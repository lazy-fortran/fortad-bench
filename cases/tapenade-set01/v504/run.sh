#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v504 boundary and port.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=todoF90/REFERENCES/v504
source_dir="$tapenade_repo/$source_rel"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v504.XXXXXX)
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
test -x "$fortad_repo/build/fo/bin/fortad"
test -x "$tapenade"
for source in Options m.mod m1_i.mod program.f90 program_d.f90 program_d.msg; do
    test -s "$source_dir/$source"
done
for absent in program_b.f90 program_b.msg; do
    test ! -e "$source_dir/$absent"
done

mkdir -p "$out/exact" "$out/exact-mod" "$out/stored-mod" \
    "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse" \
    "$out/fresh-mod/parser" "$out/fresh-mod/forward" "$out/fresh-mod/reverse" \
    "$out/fortad" "$out/port-generated" "$out/port-mod-forward" \
    "$out/port-mod-reverse" "$out/harness-mod"

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

# Contract 1: exact source and stored tangent preserve their strict refusal.
compile_source exact-upstream "$source_dir/program.f90" "$out/exact-mod"
compile_source exact-stored-tangent "$source_dir/program_d.f90" "$out/stored-mod"
test "$(cat "$out/exact-upstream.status")" -ne 0
test "$(cat "$out/exact-stored-tangent.status")" -ne 0
grep -Fq "ambiguous reference to" "$out/exact-upstream.stderr"
grep -Fq "ambiguous reference to" "$out/exact-stored-tangent.stderr"

# Contract 2: fresh pinned Tapenade parser, tangent, and reverse generation.
for mode in parser forward reverse; do
    case "$mode" in
        parser) tapenade_mode=-p; suffix=p ;;
        forward) tapenade_mode=-d; suffix=d ;;
        reverse) tapenade_mode=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$tapenade_mode' -root top \
         -O . -o v504 '$source_dir/program.f90'"
    test "$(cat "$out/tapenade-$mode-generation.status")" -eq 0
    test -s "$out/fresh/$mode/v504_${suffix}.f90"
    test -e "$out/fresh/$mode/v504_${suffix}.msg"
    compile_source "fresh-$mode-compile" "$out/fresh/$mode/v504_${suffix}.f90" \
        "$out/fresh-mod/$mode"
    test "$(cat "$out/fresh-$mode-compile.status")" -ne 0
    grep -Eq "has no IMPLICIT type|ambiguous reference to|Cannot open module file" \
        "$out/fresh-$mode-compile.stderr"
done

# Contract 3a: exact FortAD parser, forward, and reverse refuse at line 62.
run_status fortad-exact-parser fortad_run check --proc top \
    --output "$out/fortad/exact-parser.f90" "$source_dir/program.f90"
run_status fortad-exact-forward fortad_run --mode forward --indep r,s --dep top \
    --proc top --name v504_exact_forward --module v504_exact_forward_mod \
    --output "$out/fortad/exact-forward.f90" "$source_dir/program.f90"
run_status fortad-exact-reverse fortad_run --mode reverse --indep r,s --dep top \
    --proc top --name v504_exact_reverse --module v504_exact_reverse_mod \
    --output "$out/fortad/exact-reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-exact-$mode.status")" -ne 0
    test ! -e "$out/fortad/exact-$mode.f90"
    grep -Fq "unsupported statement at line 62" \
        "$out/fortad-exact-$mode.stderr"
done

# Contract 3b: bounded port generation, strict compilation, and runtime.
run_status fortad-port-forward fortad_run --mode forward --indep r,s --dep top \
    --proc set01_v504 --name v504_port_forward --module v504_port_forward_mod \
    --output "$out/port-generated/forward.f90" "$case_dir/port.f90"
run_status fortad-port-reverse fortad_run --mode reverse --indep r,s --dep top \
    --proc set01_v504 --name v504_port_reverse --module v504_port_reverse_mod \
    --output "$out/port-generated/reverse.f90" "$case_dir/port.f90"
test "$(cat "$out/fortad-port-forward.status")" -eq 0
test "$(cat "$out/fortad-port-reverse.status")" -eq 0
test -s "$out/port-generated/forward.f90"
test -s "$out/port-generated/reverse.f90"
compile_source port "$case_dir/port.f90" "$out/exact-mod"
compile_source port-forward "$out/port-generated/forward.f90" "$out/port-mod-forward"
compile_source port-reverse "$out/port-generated/reverse.f90" "$out/port-mod-reverse"
compile_source harness "$case_dir/harness.f90" "$out/harness-mod" \
    -I"$out/port-mod-forward" -I"$out/port-mod-reverse"
for label in port port-forward port-reverse harness; do
    test "$(cat "$out/$label.status")" -eq 0
done
"$fc" -o "$out/v504-harness" "$out/port.o" "$out/port-forward.o" \
    "$out/port-reverse.o" "$out/harness.o" >"$out/link.stdout" 2>"$out/link.stderr"
"$out/v504-harness" >"$out/harness.stdout"
grep -Fqx "harness_status: pass" "$out/harness.stdout"

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fqx "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v504 invalid procedure-interface boundary\n'
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
    printf 'upstream_entry_point: top(r,s)\n'
    printf 'selected_entry_points: top ftest compute\n'
    printf 'tapenade_options: Options=-head top parser=-p/-root top forward=-d/-root top reverse=-b/-root top\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_d.f90=%s\n' \
        "$(cat "$out/exact-upstream.status")" "$(cat "$out/exact-stored-tangent.status")"
    printf 'upstream_diagnostics: ambiguous procedure dummies named compute imported from M1_I\n'
    printf 'stored_references: program_d.f90 program_d.msg; missing program_b.f90 program_b.msg\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-compile.status")" \
        "$(cat "$out/fresh-forward-compile.status")" \
        "$(cat "$out/fresh-reverse-compile.status")"
    printf 'fortad_exact_parser: refusal=%s output=none diagnostic="unsupported statement at line 62"\n' \
        "$(cat "$out/fortad-exact-parser.status")"
    printf 'fortad_exact_forward: refusal=%s output=none diagnostic="unsupported statement at line 62"\n' \
        "$(cat "$out/fortad-exact-forward.status")"
    printf 'fortad_exact_reverse: refusal=%s output=none diagnostic="unsupported statement at line 62"\n' \
        "$(cat "$out/fortad-exact-reverse.status")"
    printf 'fortad_bounded_forward: transform=%s strict_compile=%s\n' \
        "$(cat "$out/fortad-port-forward.status")" "$(cat "$out/port-forward.status")"
    printf 'fortad_bounded_reverse: transform=%s strict_compile=%s\n' \
        "$(cat "$out/fortad-port-reverse.status")" "$(cat "$out/port-reverse.status")"
    printf 'bounded_port_compile: port=%s harness=%s link=0 runtime=0\n' \
        "$(cat "$out/port.status")" "$(cat "$out/harness.status")"
    cat "$out/oracle.txt"
    cat "$out/harness.stdout"
    printf 'bounded_domain: finite r and s with finite intermediate products; s derivative zero\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/m.mod \
        "$source_rel"/m1_i.mod "$source_rel"/program.f90 \
        "$source_rel"/program_d.f90 "$source_rel"/program_d.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/v504_p.f90 parser/v504_p.msg \
        forward/v504_d.f90 forward/v504_d.msg reverse/v504_b.f90 reverse/v504_b.msg)
    printf 'fortad_bounded_sha256:\n'
    sha256sum "$out/port-generated/forward.f90" "$out/port-generated/reverse.f90"
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md port.f90 harness.f90 oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
