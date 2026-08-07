#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v425 boundary.
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
source_rel=todoF90/REFERENCES/v425
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"

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
for source in Options program.f90 program_Rd.f90 program_Rd.msg; do
    test -s "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/fortad-bench-v425.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/exact-mod" "$out/fresh/parser" "$out/fresh/forward" \
    "$out/fresh/reverse" "$out/fresh-mod/parser" "$out/fresh-mod/forward" \
    "$out/fresh-mod/reverse" "$out/fortad"

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
    local module_dir=$3
    mkdir -p "$module_dir"
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" \
        -J"$module_dir" -c "$source" -o "$out/$label.o"
}

# Contract test 1: exact primal and stored reference behavior.
compile_source upstream_primal "$source_dir/program.f90" "$out/exact-mod"
compile_source stored_program_Rd "$source_dir/program_Rd.f90" "$out/exact-mod"
test "$(cat "$out/upstream_primal.status")" -eq 0
test "$(cat "$out/stored_program_Rd.status")" -eq 0

# Contract test 2: fresh parser, tangent, and reverse generation plus compile.
for mode in parser forward reverse; do
    case "$mode" in
        parser) tap_mode=-p; suffix=p ;;
        forward) tap_mode=-d; suffix=d ;;
        reverse) tap_mode=-b; suffix=b ;;
    esac
    run_status "fresh-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' -association byaddress '$tap_mode' \
         -root addvector -O . -o v425 '$source_dir/program.f90'"
    test "$(cat "$out/fresh-$mode-generation.status")" -eq 0
    test -s "$out/fresh/$mode/v425_${suffix}.f90"
    test -s "$out/fresh/$mode/v425_${suffix}.msg"
    compile_source "fresh-$mode-compile" \
        "$out/fresh/$mode/v425_${suffix}.f90" "$out/fresh-mod/$mode"
    test "$(cat "$out/fresh-$mode-compile.status")" -eq 0
done

# Contract test 3: exact FortAD parser, forward, and reverse refusal.
run_status fortad-parser "$fortad" check --proc addvector \
    --output "$out/fortad/parser.f90" "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward \
    --indep 'a%w%x(1),b%w%x(2)' --proc addvector --name v425_forward \
    --module v425_forward_mod --output "$out/fortad/forward.f90" \
    "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse \
    --indep 'a%w%x(1),b%w%x(2)' --dep 'c%w%x(1)' --proc addvector \
    --name v425_reverse --module v425_reverse_mod \
    --output "$out/fortad/reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    test ! -e "$out/fortad/$mode.f90"
    grep -Fq 'unsupported statement at line 1' "$out/fortad-$mode.stderr"
done

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq 'oracle_status: pass' "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v425 module parser boundary\n'
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
    printf 'upstream_entry_point: m.addvector(a,b,c)\n'
    printf 'selected_entry_point: addvector(a,b,c); independent: a%%w%%x(1),b%%w%%x(2); dependent: c%%w%%x(1)\n'
    printf 'tapenade_options: Options=-association byaddress; parser=-p/-root addvector forward=-d/-root addvector reverse=-b/-root addvector\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_Rd.f90=%s\n' \
        "$(cat "$out/upstream_primal.status")" "$(cat "$out/stored_program_Rd.status")"
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-generation.status")" \
        "$(cat "$out/fresh-forward-generation.status")" \
        "$(cat "$out/fresh-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v425_p.f90 tangent=v425_d.f90 reverse=v425_b.f90\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-compile.status")" \
        "$(cat "$out/fresh-forward-compile.status")" \
        "$(cat "$out/fresh-reverse-compile.status")"
    printf 'fortad_exact_parser: expected-refusal status=%s output=none line=1 diagnostic="unsupported statement"\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none line=1 diagnostic="unsupported statement"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none line=1 diagnostic="unsupported statement"\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_oracle:\n'
    cat "$out/oracle.txt"
    printf 'port_result: not-applicable-exact-module-refusal\n'
    printf 'excluded_runtime_path: uninitialized local fichier is read by LEN(TRIM(fichier))\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options \
        "$source_rel"/program.f90 "$source_rel"/program_Rd.f90 \
        "$source_rel"/program_Rd.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/v425_p.f90 parser/v425_p.msg \
        forward/v425_d.f90 forward/v425_d.msg reverse/v425_b.f90 reverse/v425_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
