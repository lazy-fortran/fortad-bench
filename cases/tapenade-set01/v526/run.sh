#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v526 boundary and port.
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
source_rel=todoF90/REFERENCES/v526
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v526.XXXXXX)
trap 'rm -rf "$out"' EXIT

command -v "$fc" >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"
for source in program.f90 fox_dom_types.mod fox_sax.mod m_precision.mod \
    m_rezomat_t.mod m_sing3_i.mod m_singularite_rezo_i.mod m_singularite_t.mod; do
    test -s "$source_dir/$source"
done

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
mkdir -p "$out/exact" "$out/exact-mod" "$out/stored-mod" \
    "$out/fresh/parser" "$out/fresh/tangent" "$out/fresh/reverse" \
    "$out/fresh-mod/parser" "$out/fresh-mod/tangent" "$out/fresh-mod/reverse" \
    "$out/fortad" "$out/port-generated" "$out/port-mod"

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

# Contract test 1: exact source boundary and every stored module artifact.
compile_source exact-primal "$source_dir/program.f90" "$out/exact-mod"
compile_source stored-module-consumer "$case_dir/stored_modules_probe.f90" \
    "$out/stored-mod"
test "$(cat "$out/exact-primal.status")" -ne 0
grep -Fq "Parameter" "$out/exact-primal.stderr"
grep -Fq "Ambiguous interfaces" "$out/exact-primal.stderr"
grep -Fq "REAL*8" "$out/exact-primal.stderr"
grep -Fq "fox_dom.mod" "$out/exact-primal.stderr"
test "$(cat "$out/stored-module-consumer.status")" -eq 0

# Contract test 2: fresh parser, tangent, and reverse generation plus compile.
for mode in parser tangent reverse; do
    case "$mode" in
        parser) tap_mode=-p; suffix=p ;;
        tangent) tap_mode=-d; suffix=d ;;
        reverse) tap_mode=-b; suffix=b ;;
    esac
    run_status "fresh-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$tap_mode' -root SING3 \
         -O . -o v526 '$source_dir/program.f90'"
    test "$(cat "$out/fresh-$mode-generation.status")" -eq 0
    test -s "$out/fresh/$mode/v526_${suffix}.f90"
    test -s "$out/fresh/$mode/v526_${suffix}.msg"
    compile_source "fresh-$mode-compile" \
        "$out/fresh/$mode/v526_${suffix}.f90" "$out/fresh-mod/$mode"
done
test "$(cat "$out/fresh-parser-compile.status")" -ne 0
grep -Fq "no IMPLICIT type" "$out/fresh-parser-compile.stderr"
test "$(cat "$out/fresh-tangent-compile.status")" -ne 0
test "$(cat "$out/fresh-reverse-compile.status")" -ne 0
grep -Fq "fox_dom.mod" "$out/fresh-tangent-compile.stderr"
grep -Fq "fox_dom.mod" "$out/fresh-reverse-compile.stderr"

# Contract test 3: exact FortAD refusal and bounded SING3 runtime.
run_status fortad-exact-parser "$fortad" check --proc SING3 \
    --output "$out/fortad/exact-parser.f90" "$source_dir/program.f90"
run_status fortad-exact-forward "$fortad" --mode forward --indep DXP,DYP \
    --proc SING3 --name v526_exact_forward --module v526_exact_forward_mod \
    --output "$out/fortad/exact-forward.f90" "$source_dir/program.f90"
run_status fortad-exact-reverse "$fortad" --mode reverse --indep DXP,DYP --dep DYP \
    --proc SING3 --name v526_exact_reverse --module v526_exact_reverse_mod \
    --output "$out/fortad/exact-reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-exact-$mode.status")" -ne 0
    test ! -e "$out/fortad/exact-$mode.f90"
    grep -Fq "unsupported allocation lifetime construct 'allocate' at line 233" \
        "$out/fortad-exact-$mode.stderr"
done

run_status fortad-port-forward "$fortad" --mode forward --indep dxp,dyp_initial --dep dyp \
    --proc v526_sing3 --name v526_port_forward --module v526_port_forward_mod \
    --output "$out/port-generated/forward.f90" "$case_dir/port.f90"
run_status fortad-port-reverse "$fortad" --mode reverse --indep dxp,dyp_initial --dep dyp \
    --proc v526_sing3 --name v526_port_reverse --module v526_port_reverse_mod \
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
"$fc" -o "$out/v526-harness" "$out/port.o" "$out/port-forward.o" \
    "$out/port-reverse.o" "$out/harness.o" >"$out/link.stdout" 2>"$out/link.stderr"
"$out/v526-harness" >"$out/harness.stdout"
grep -Fqx "harness_status: pass" "$out/harness.stdout"

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fqx "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v526 module-bundle boundary and SING3 port\n'
    printf 'classification: expected-refusal-with-bounded-sing3-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: SING3(DXP,DYP,Epaisseur_Seuil)\n'
    printf 'tapenade_options: parser=-p tangent=-d reverse=-b; root=SING3\n'
    printf 'upstream_exact_strict_compile: program.f90=%s\n' \
        "$(cat "$out/exact-primal.status")"
    printf 'exact_diagnostic: undefined-dp-sp; ambiguous-generic; REAL*8; missing-fox_dom.mod\n'
    printf 'stored_module_consumer_strict_compile: %s\n' \
        "$(cat "$out/stored-module-consumer.status")"
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-generation.status")" \
        "$(cat "$out/fresh-tangent-generation.status")" \
        "$(cat "$out/fresh-reverse-generation.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-compile.status")" \
        "$(cat "$out/fresh-tangent-compile.status")" \
        "$(cat "$out/fresh-reverse-compile.status")"
    printf 'fortad_exact_parser: expected-refusal status=%s output=none line=233 diagnostic="allocate"\n' \
        "$(cat "$out/fortad-exact-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none line=233 diagnostic="allocate"\n' \
        "$(cat "$out/fortad-exact-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none line=233 diagnostic="allocate"\n' \
        "$(cat "$out/fortad-exact-reverse.status")"
    printf 'fortad_bounded_forward: transform=%s strict_compile=%s\n' \
        "$(cat "$out/fortad-port-forward.status")" "$(cat "$out/port-forward.status")"
    printf 'fortad_bounded_reverse: transform=%s strict_compile=%s\n' \
        "$(cat "$out/fortad-port-reverse.status")" "$(cat "$out/port-reverse.status")"
    printf 'bounded_port_compile: port=%s harness=%s link=0 runtime=0\n' \
        "$(cat "$out/port.status")" "$(cat "$out/harness.status")"
    cat "$out/oracle.txt"
    cat "$out/harness.stdout"
    printf 'bounded_domain: one-element finite real(8) DXP and DYP_INITIAL; DYP output; Epaisseur_Seuil in {0,1}\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/fox_dom_types.mod \
        "$source_rel"/fox_sax.mod "$source_rel"/m_precision.mod \
        "$source_rel"/m_rezomat_t.mod "$source_rel"/m_sing3_i.mod \
        "$source_rel"/m_singularite_rezo_i.mod "$source_rel"/m_singularite_t.mod \
        "$source_rel"/program.f90)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/v526_p.f90 parser/v526_p.msg \
        tangent/v526_d.f90 tangent/v526_d.msg reverse/v526_b.f90 reverse/v526_b.msg)
    printf 'fortad_bounded_sha256:\n'
    sha256sum "$out/port-generated/forward.f90" "$out/port-generated/reverse.f90"
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md port.f90 harness.f90 \
        stored_modules_probe.f90 oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
