#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v377 MPI boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
if test ! -e "$fortad_repo/.git" && test -e /mnt/storage/code/lazy-fortran/fortad/.git; then
    fortad_repo=/mnt/storage/code/lazy-fortran/fortad
fi
if test ! -e "$tapenade_repo/.git" && test -e /mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade/.git; then
    tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-mpifort}
source_rel=todoF90/REFERENCES/v377
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v377.XXXXXX)
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
for source in program.f90 program_d.f90 program_d.msg program_b.f90 program_b.msg topd.f90 topb.f90; do
    test -s "$source_dir/$source"
done
if test ! -x "$fortad"; then
    command -v fo >/dev/null
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
fi
if test ! -x "$tapenade"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
test -x "$fortad"
test -x "$tapenade"

mkdir -p "$out/upstream" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/tapenade/support" "$out/exact"
strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)

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

compile_source upstream_program "$source_dir/program.f90" "$out/upstream/program-mod"
compile_source upstream_tangent "$source_dir/program_d.f90" "$out/upstream/tangent-mod"
compile_source upstream_reverse "$source_dir/program_b.f90" "$out/upstream/reverse-mod"
compile_source upstream_topd "$source_dir/topd.f90" "$out/upstream/topd-mod"
compile_source upstream_topb "$source_dir/topb.f90" "$out/upstream/topb-mod"

compile_source tapenade_admpi "$tapenade_repo/ADFirstAidKit/adMPI.f90" \
    "$out/tapenade/support"

for mode in parser forward reverse; do
    case "$mode" in
        parser) tap_mode=-p ;;
        forward) tap_mode=-d ;;
        reverse) tap_mode=-b ;;
    esac
    run_status "tapenade-$mode-generation" bash -c \
        "cd '$out/tapenade/$mode' && '$tapenade' '$tap_mode' -root test -O . -o v377 '$source_dir/program.f90'"
done
test -s "$out/tapenade/parser/v377_p.f90"
test -s "$out/tapenade/parser/v377_p.msg"
test -s "$out/tapenade/forward/v377_d.f90"
test -s "$out/tapenade/forward/v377_d.msg"
test -s "$out/tapenade/reverse/v377_b.f90"
test -s "$out/tapenade/reverse/v377_b.msg"

compile_source tapenade_parser "$out/tapenade/parser/v377_p.f90" \
    "$out/tapenade/parser/mod"
compile_source tapenade_tangent "$out/tapenade/forward/v377_d.f90" \
    "$out/tapenade/forward/mod" -I"$out/tapenade/support"
compile_source tapenade_reverse "$out/tapenade/reverse/v377_b.f90" \
    "$out/tapenade/reverse/mod" -I"$out/tapenade/support"
test "$(cat "$out/tapenade-parser-generation.status")" -eq 0
test "$(cat "$out/tapenade-forward-generation.status")" -eq 0
test "$(cat "$out/tapenade-reverse-generation.status")" -eq 0
test "$(cat "$out/tapenade_admpi.status")" -eq 0
test "$(cat "$out/tapenade_parser.status")" -ne 0
test "$(cat "$out/tapenade_tangent.status")" -eq 0
test "$(cat "$out/tapenade_reverse.status")" -eq 0
grep -Fq "More actual than formal arguments" "$out/tapenade_parser.stderr"

run_status fortad-parser "$fortad" check --proc test \
    --output "$out/exact/parser.f90" "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward --proc test --indep ce \
    --name v377_forward --module v377_forward_mod \
    --output "$out/exact/forward.f90" "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse --proc test --indep ce --dep ce \
    --name v377_reverse --module v377_reverse_mod \
    --output "$out/exact/reverse.f90" "$source_dir/program.f90"
test "$(cat "$out/fortad-parser.status")" -eq 0
test -s "$out/exact/parser.f90"
compile_source fortad_parser_compile "$out/exact/parser.f90" "$out/exact/parser-mod"
test "$(cat "$out/fortad_parser_compile.status")" -ne 0
test "$(cat "$out/fortad-forward.status")" -ne 0
test ! -e "$out/exact/forward.f90"
test "$(cat "$out/fortad-reverse.status")" -ne 0
test ! -e "$out/exact/reverse.f90"
grep -Fq "no derivative rule for the call to 'MPI_irecv'" "$out/fortad-forward.stderr"
grep -Fq "this loop accumulates nothing" "$out/fortad-reverse.stderr"
grep -Fq "More actual than formal arguments" "$out/fortad_parser_compile.stderr"

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v377 MPI boundary\n'
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
    printf 'upstream_entry_points: test(ce,rank); main\n'
    printf 'tapenade_options: parser=-p/-root test forward=-d/-root test reverse=-b/-root test\n'
    printf 'upstream_exact_strict_compile: program=%s tangent=%s reverse=%s topd=%s topb=%s admpi_support=%s\n' \
        "$(cat "$out/upstream_program.status")" "$(cat "$out/upstream_tangent.status")" \
        "$(cat "$out/upstream_reverse.status")" "$(cat "$out/upstream_topd.status")" \
        "$(cat "$out/upstream_topb.status")" "$(cat "$out/tapenade_admpi.status")"
    printf 'upstream_diagnostic: MPI_SEND explicit-interface-argument-count-and-rank-mismatch\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v377_p.f90 tangent=v377_d.f90 reverse=v377_b.f90\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s admpi_support=%s\n' \
        "$(cat "$out/tapenade_parser.status")" "$(cat "$out/tapenade_tangent.status")" \
        "$(cat "$out/tapenade_reverse.status")" "$(cat "$out/tapenade_admpi.status")"
    printf 'tapenade_fresh_parser_diagnostic: '
    grep -F 'Error:' "$out/tapenade_parser.stderr" | head -1 | sed 's/^[[:space:]]*//' || true
    printf 'fortad_exact_parser: transform=%s generated=strict-compile-%s diagnostic="MPI_SEND explicit-interface-argument-count-and-rank-mismatch"\n' \
        "$(cat "$out/fortad-parser.status")" "$(cat "$out/fortad_parser_compile.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="no derivative rule for the call to MPI_irecv"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="reverse loop accumulates nothing"\n' \
        "$(cat "$out/fortad-reverse.status")"
    printf 'independent_oracle: %s\n' "$(cat "$out/oracle.txt")"
    printf 'port_result: not-applicable-no-standard-conforming-semantics-to-preserve\n'
    printf 'closure: no bounded port; repairing MPI argument count or communication matching would change the candidate\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f90 "$source_rel"/program_d.f90 \
        "$source_rel"/program_d.msg "$source_rel"/program_b.f90 "$source_rel"/program_b.msg \
        "$source_rel"/topd.f90 "$source_rel"/topb.f90)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade" && find . -type f \( -name '*.f90' -o -name '*.msg' \) -print0 | sort -z | xargs -0 sha256sum)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/v377/manifest.toml \
        cases/tapenade-set01/v377/notes.md cases/tapenade-set01/v377/oracle.py \
        cases/tapenade-set01/v377/run.sh cases/tapenade-set01/v377/test_contract.py)
} >"$result"
cat "$result"
