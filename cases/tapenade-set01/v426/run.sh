#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v426 boundary.
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
source_rel=todoF90/REFERENCES/v426
source_dir="$tapenade_repo/$source_rel"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v426.XXXXXX)

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
for source in Options program.f90 program_Rd.f90 program_Rd.msg; do
    test -e "$source_dir/$source"
done

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
mkdir -p "$out/exact/primal-mod" "$out/exact/stored-mod" \
    "$out/fresh/parser" "$out/fresh/tangent" "$out/fresh/reverse" \
    "$out/fresh-mod/parser" "$out/fresh-mod/tangent" "$out/fresh-mod/reverse"

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
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" \
        -J"$module_dir" -c "$source" -o "$out/$label.o"
}

fortad_run() {
    (cd "$fortad_repo" && fo exec --no-build fortad "$@")
}

# Contract test 1: exact pinned source and stored tangent strict behavior.
compile_source exact-primal "$source_dir/program.f90" "$out/exact/primal-mod"
compile_source exact-stored-tangent "$source_dir/program_Rd.f90" "$out/exact/stored-mod"
test "$(cat "$out/exact-primal.status")" -eq 0
test "$(cat "$out/exact-stored-tangent.status")" -eq 0

# Contract test 2: fresh pinned parser, tangent, and reverse generation plus strict compile.
for mode in parser tangent reverse; do
    case "$mode" in
        parser) tap_mode=-p; suffix=p ;;
        tangent) tap_mode=-d; suffix=d ;;
        reverse) tap_mode=-b; suffix=b ;;
    esac
    run_status "fresh-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' -association byaddress -vars inputs -outvars outputs -context -noisize '$tap_mode' -root head -O . -o v426 '$source_dir/program.f90'"
    test "$(cat "$out/fresh-$mode-generation.status")" -eq 0
    test -e "$out/fresh/$mode/v426_${suffix}.f90"
    test -e "$out/fresh/$mode/v426_${suffix}.msg"
    compile_source "fresh-$mode-compile" "$out/fresh/$mode/v426_${suffix}.f90" \
        "$out/fresh-mod/$mode"
    test "$(cat "$out/fresh-$mode-compile.status")" -eq 0
done

# Contract test 3: exact FortAD parser/forward/reverse refusal and independent oracle.
run_status fortad-exact-parser fortad_run check --proc head \
    --output "$out/exact-parser.f90" "$source_dir/program.f90"
run_status fortad-exact-forward fortad_run --mode forward --indep tDataIn,inputs \
    --proc head --name v426_forward --module v426_forward_mod \
    --output "$out/exact-forward.f90" "$source_dir/program.f90"
run_status fortad-exact-reverse fortad_run --mode reverse --indep tDataIn,inputs \
    --dep outputs --proc head --name v426_reverse --module v426_reverse_mod \
    --output "$out/exact-reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-exact-$mode.status")" -ne 0
    test ! -e "$out/exact-$mode.f90"
    grep -Fq "unsupported allocation lifetime construct 'allocatable declaration/component' at line 4" \
        "$out/fortad-exact-$mode.stderr"
done

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v426 allocatable lifetime boundary\n'
    printf 'classification: expected-refusal-unsupported-allocatable-lifetime\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: head()\n'
    printf 'independent: tDataIn%%v, inputs\n'
    printf 'dependent: outputs\n'
    printf 'tapenade_options: -association byaddress -vars inputs -outvars outputs -context -noisize -p/-d/-b -root head\n'
    printf 'upstream_exact_strict_compile: primal=%s stored_tangent=%s\n' \
        "$(cat "$out/exact-primal.status")" "$(cat "$out/exact-stored-tangent.status")"
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-generation.status")" \
        "$(cat "$out/fresh-tangent-generation.status")" \
        "$(cat "$out/fresh-reverse-generation.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-compile.status")" \
        "$(cat "$out/fresh-tangent-compile.status")" \
        "$(cat "$out/fresh-reverse-compile.status")"
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="allocatable declaration/component at line 4"\n' \
        "$(cat "$out/fortad-exact-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="allocatable declaration/component at line 4"\n' \
        "$(cat "$out/fortad-exact-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="allocatable declaration/component at line 4"\n' \
        "$(cat "$out/fortad-exact-reverse.status")"
    printf 'port_result: not-applicable-no-bounded-port\n'
    printf 'closure: fixed-size storage would remove the allocatable derived-type and saved allocation lifecycle\n'
    printf 'independent_oracle: allocation lifecycle, hand JVP/VJP, central-difference sweep, and adjoint identity\n'
    cat "$out/oracle.txt"
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/program.f90 \
        "$source_rel"/program_Rd.f90 "$source_rel"/program_Rd.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && find . -type f \( -name '*.f90' -o -name '*.msg' \) -print0 | sort -z | xargs -0 sha256sum)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/v426/manifest.toml \
        cases/tapenade-set01/v426/notes.md cases/tapenade-set01/v426/oracle.py \
        cases/tapenade-set01/v426/run.sh cases/tapenade-set01/v426/test_contract.py)
} >"$result"
cat "$result"
