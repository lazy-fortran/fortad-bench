#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v418 MPI boundary.
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
fc=${FC:-mpifort}
source_rel=todoF90/REFERENCES/v418
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v418.XXXXXX)

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
for source in Options mpif.h program.f90 program_Rd.f90 program_Rd.msg rund topd.f90; do
    test -e "$source_dir/$source"
done

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
mkdir -p "$out/exact/rd-mod" "$out/exact/topd-mod" "$out/fresh/support-mod" \
    "$out/fresh/parser" "$out/fresh/tangent" "$out/fresh/reverse" \
    "$out/fresh/parser-mod" "$out/fresh/tangent-mod" "$out/fresh/reverse-mod" \
    "$out/fortad/msg1-mod" "$out/fortad/msg2-mod"

run_status() {
    local label=$1
    shift
    local status
    if "$@" >"$out/$label.stdout" 2>"$out/$label.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_source() {
    local label=$1
    local source=$2
    local moddir=$3
    shift 3
    mkdir -p "$moddir"
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" "$@" \
        -J"$moddir" -c "$source" -o "$out/$label.o"
}

# Contract test 1: compile every exact source/reference in its required order.
compile_source exact-primal "$source_dir/program.f90" "$out/exact/primal-mod"
compile_source stored-tangent "$source_dir/program_Rd.f90" "$out/exact/rd-mod"
compile_source stored-driver "$source_dir/topd.f90" "$out/exact/topd-mod" \
    -I"$out/exact/rd-mod"
test "$(cat "$out/exact-primal.status")" -ne 0
test "$(cat "$out/stored-tangent.status")" -eq 0
test "$(cat "$out/stored-driver.status")" -ne 0
grep -Fq "More actual than formal arguments" "$out/exact-primal.stderr"
grep -Fq "Rank mismatch in argument" "$out/exact-primal.stderr"
grep -Fq "real4rdtype" "$out/stored-driver.stderr"

# Contract test 2: fresh pinned Tapenade parser/tangent/reverse generation.
compile_source tapenade-admpi "$tapenade_repo/ADFirstAidKit/adMPI.f90" \
    "$out/fresh/support-mod"
test "$(cat "$out/tapenade-admpi.status")" -eq 0
for mode in parser tangent reverse; do
    case "$mode" in
        parser) tap_mode=-p; suffix=p ;;
        tangent) tap_mode=-d; suffix=d ;;
        reverse) tap_mode=-b; suffix=b ;;
    esac
    run_status "fresh-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' -association byaddress '$tap_mode' \
         -root msg1 -root msg2 -O . -o v418 '$source_dir/program.f90'"
    test "$(cat "$out/fresh-$mode-generation.status")" -eq 0
    test -s "$out/fresh/$mode/v418_${suffix}.f90"
    test -e "$out/fresh/$mode/v418_${suffix}.msg"
done
compile_source fresh-parser "$out/fresh/parser/v418_p.f90" \
    "$out/fresh/parser-mod"
compile_source fresh-tangent "$out/fresh/tangent/v418_d.f90" \
    "$out/fresh/tangent-mod" -I"$out/fresh/support-mod"
compile_source fresh-reverse "$out/fresh/reverse/v418_b.f90" \
    "$out/fresh/reverse-mod" -I"$out/fresh/support-mod"
test "$(cat "$out/fresh-parser.status")" -ne 0
test "$(cat "$out/fresh-tangent.status")" -eq 0
test "$(cat "$out/fresh-reverse.status")" -eq 0
grep -Fq "More actual than formal arguments" "$out/fresh-parser.stderr"

# Contract test 3: exact FortAD parser/forward/reverse behavior for both roots.
run_status fortad-msg1-parser "$fortad" check --proc msg1 \
    --output "$out/fortad/msg1-parser.f90" "$source_dir/program.f90"
run_status fortad-msg2-parser "$fortad" check --proc msg2 \
    --output "$out/fortad/msg2-parser.f90" "$source_dir/program.f90"
compile_source fortad-msg1-parser-compile "$out/fortad/msg1-parser.f90" \
    "$out/fortad/msg1-mod"
compile_source fortad-msg2-parser-compile "$out/fortad/msg2-parser.f90" \
    "$out/fortad/msg2-mod"
test "$(cat "$out/fortad-msg1-parser.status")" -eq 0
test "$(cat "$out/fortad-msg2-parser.status")" -eq 0
test "$(cat "$out/fortad-msg1-parser-compile.status")" -eq 0
test "$(cat "$out/fortad-msg2-parser-compile.status")" -ne 0
grep -Fq "More actual than formal arguments" \
    "$out/fortad-msg2-parser-compile.stderr"

for root_name in msg1 msg2; do
    run_status "fortad-$root_name-forward" "$fortad" --mode forward \
        --indep val1 --dep val2 --proc "$root_name" \
        --name "v418_${root_name}_forward" \
        --module "v418_${root_name}_forward_mod" \
        --output "$out/fortad/${root_name}-forward.f90" "$source_dir/program.f90"
    run_status "fortad-$root_name-reverse" "$fortad" --mode reverse \
        --indep val1 --dep val2 --proc "$root_name" \
        --name "v418_${root_name}_reverse" \
        --module "v418_${root_name}_reverse_mod" \
        --output "$out/fortad/${root_name}-reverse.f90" "$source_dir/program.f90"
    test "$(cat "$out/fortad-$root_name-forward.status")" -ne 0
    test "$(cat "$out/fortad-$root_name-reverse.status")" -ne 0
    test ! -e "$out/fortad/${root_name}-forward.f90"
    test ! -e "$out/fortad/${root_name}-reverse.f90"
done
grep -Fq "no derivative rule for the call to 'MPI_ISEND'" \
    "$out/fortad-msg1-forward.stderr"
grep -Fq "no reverse rule for the call to 'MPI_ISEND'" \
    "$out/fortad-msg1-reverse.stderr"
grep -Fq "no derivative rule for the call to 'MPI_RECV'" \
    "$out/fortad-msg2-forward.stderr"
grep -Fq "no reverse rule for the call to 'MPI_RECV'" \
    "$out/fortad-msg2-reverse.stderr"

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v418 MPI interface boundary\n'
    printf 'classification: expected-refusal-invalid-upstream\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_points: anneau; msg1; msg2; topd\n'
    printf 'tapenade_options: -association byaddress; parser=-p tangent=-d reverse=-b; roots=msg1,msg2\n'
    printf 'upstream_exact_strict_compile: program=%s program_Rd=%s topd=%s\n' \
        "$(cat "$out/exact-primal.status")" "$(cat "$out/stored-tangent.status")" \
        "$(cat "$out/stored-driver.status")"
    printf 'upstream_diagnostic: program.f90=MPI_SEND-eight-actuals-and-status-rank-mismatch topd.f90=undeclared-real4rdtype\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-generation.status")" \
        "$(cat "$out/fresh-tangent-generation.status")" \
        "$(cat "$out/fresh-reverse-generation.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s admpi_support=%s\n' \
        "$(cat "$out/fresh-parser.status")" "$(cat "$out/fresh-tangent.status")" \
        "$(cat "$out/fresh-reverse.status")" "$(cat "$out/tapenade-admpi.status")"
    printf 'fortad_exact_parser: msg1_transform=%s msg1_strict_compile=%s msg2_transform=%s msg2_strict_compile=%s\n' \
        "$(cat "$out/fortad-msg1-parser.status")" \
        "$(cat "$out/fortad-msg1-parser-compile.status")" \
        "$(cat "$out/fortad-msg2-parser.status")" \
        "$(cat "$out/fortad-msg2-parser-compile.status")"
    printf 'fortad_exact_forward: msg1_status=%s diagnostic="no derivative rule for MPI_ISEND" msg2_status=%s diagnostic="no derivative rule for MPI_RECV"\n' \
        "$(cat "$out/fortad-msg1-forward.status")" "$(cat "$out/fortad-msg2-forward.status")"
    printf 'fortad_exact_reverse: msg1_status=%s diagnostic="no reverse rule for MPI_ISEND" msg2_status=%s diagnostic="no reverse rule for MPI_RECV"\n' \
        "$(cat "$out/fortad-msg1-reverse.status")" "$(cat "$out/fortad-msg2-reverse.status")"
    printf 'independent_oracle: %s\n' "$(cat "$out/oracle.txt")"
    printf 'port_result: not-applicable-no-standard-conforming-exact-candidate\n'
    printf 'closure: no bounded port; repairing MPI argument lists or declaring real4rdtype changes the candidate\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/mpif.h \
        "$source_rel"/program.f90 "$source_rel"/program_Rd.f90 \
        "$source_rel"/program_Rd.msg "$source_rel"/rund "$source_rel"/topd.f90)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/v418_p.f90 parser/v418_p.msg \
        tangent/v418_d.f90 tangent/v418_d.msg reverse/v418_b.f90 reverse/v418_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
