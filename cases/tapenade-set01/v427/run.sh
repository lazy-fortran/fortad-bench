#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v427 boundary.
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
source_rel=todoF90/REFERENCES/v427
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v427.XXXXXX)
trap 'rm -rf "$out"' EXIT

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
if test ! -x "$fortad"; then
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
fi
test -x "$fortad"
test -x "$tapenade"
for source in Options m.mod program.f90 program_Rd.f90 program_Rd.msg; do
    test -s "$source_dir/$source"
done

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
mkdir -p "$out/exact/primal-mod" "$out/exact/stored-mod" \
    "$out/fresh/parser" "$out/fresh/parser-mod" \
    "$out/fresh/forward" "$out/fresh/reverse" "$out/fortad"

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
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" \
        -J"$moddir" -c "$source" -o "$out/$label.o"
}

# Contract test 1: exact primal and stored reverse behavior.
compile_source upstream-primal "$source_dir/program.f90" "$out/exact/primal-mod"
compile_source upstream-stored "$source_dir/program_Rd.f90" "$out/exact/stored-mod"
test "$(cat "$out/upstream-primal.status")" -eq 0
test "$(cat "$out/upstream-stored.status")" -eq 0

# Contract test 2: fresh parser, tangent, and reverse generation.
run_status fresh-parser-generation bash -c \
    "cd '$out/fresh/parser' && '$tapenade' -association byaddress -p -root setupData \
     -O . -o v427 '$source_dir/program.f90'"
test "$(cat "$out/fresh-parser-generation.status")" -eq 0
test -s "$out/fresh/parser/v427_p.f90"
test -s "$out/fresh/parser/v427_p.msg"
compile_source fresh-parser "$out/fresh/parser/v427_p.f90" "$out/fresh/parser-mod"
test "$(cat "$out/fresh-parser.status")" -eq 0

for mode in forward reverse; do
    case "$mode" in
        forward) tap_mode=-d; suffix=d ;;
        reverse) tap_mode=-b; suffix=b ;;
    esac
    run_status "fresh-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' -association byaddress '$tap_mode' \
         -root setupData -O . -o v427 '$source_dir/program.f90'"
    test "$(cat "$out/fresh-$mode-generation.status")" -eq 0
    test -s "$out/fresh/$mode/v427_${suffix}.msg"
    test ! -e "$out/fresh/$mode/v427_${suffix}.f90"
    grep -Fq "AD06" "$out/fresh/$mode/v427_${suffix}.msg"
done

# Contract test 3: exact FortAD parser/forward/reverse behavior.
run_status fortad-parser "$fortad" check --proc setupData \
    --output "$out/fortad/parser.f90" "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward --proc setupData --indep dim \
    --name v427_forward --module v427_forward_mod \
    --output "$out/fortad/forward.f90" "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse --proc setupData --indep dim \
    --dep someTData --name v427_reverse --module v427_reverse_mod \
    --output "$out/fortad/reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    test ! -e "$out/fortad/$mode.f90"
    grep -Fq "unsupported allocation lifetime construct 'allocatable declaration/component' at line 2" \
        "$out/fortad-$mode.stderr"
done

PYTHONDONTWRITEBYTECODE=1 python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v427 allocatable-module-state boundary\n'
    printf 'classification: expected-refusal-allocatable-module-state-and-no-active-derivative\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: m.setupData(dim)\n'
    printf 'tapenade_options: -association byaddress -p/-d/-b -root setupData\n'
    printf 'upstream_exact_strict_compile: program.f90=%s program_Rd.f90=%s\n' \
        "$(cat "$out/upstream-primal.status")" "$(cat "$out/upstream-stored.status")"
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-generation.status")" \
        "$(cat "$out/fresh-forward-generation.status")" \
        "$(cat "$out/fresh-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v427_p.f90 tangent=none(AD06) reverse=none(AD06)\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=not-applicable reverse=not-applicable\n' \
        "$(cat "$out/fresh-parser.status")"
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="allocatable declaration/component line 2"\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="allocatable declaration/component line 2"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="allocatable declaration/component line 2"\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_oracle: allocation-state model with extent and repeated-allocation checks\n'
    cat "$out/oracle.txt"
    printf 'port_result: not-applicable-allocatable-module-state\n'
    printf 'closure: no bounded port; replacing allocatables or adding a numeric result changes the candidate\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/m.mod \
        "$source_rel"/program.f90 "$source_rel"/program_Rd.f90 "$source_rel"/program_Rd.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/v427_p.f90 parser/v427_p.msg \
        forward/v427_d.msg reverse/v427_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/v427/manifest.toml \
        cases/tapenade-set01/v427/notes.md cases/tapenade-set01/v427/oracle.py \
        cases/tapenade-set01/v427/run.sh cases/tapenade-set01/v427/test_contract.py)
} >"$result"
cat "$result"
