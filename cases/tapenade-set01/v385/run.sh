#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v385 boundary.
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
source_rel=todoF90/REFERENCES/v385
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v385.XXXXXX)
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
for source in program.f90 program_d.f90 program_d.msg program_b.f90 program_b.msg; do
    test -s "$source_dir/$source"
done
test -x "$fortad"
test -x "$tapenade"

mkdir -p "$out/exact" "$out/fresh/parser" "$out/fresh/forward" \
    "$out/fresh/reverse" "$out/fresh/admpi" "$out/fresh/support"
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
    shift 3
    mkdir -p "$moddir"
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" "$@" \
        -J"$moddir" -c "$source" -o "$out/$label.o"
}

compile_source upstream_primal "$source_dir/program.f90" "$out/exact/primal-mod"
compile_source upstream_tangent "$source_dir/program_d.f90" "$out/exact/tangent-mod"
compile_source upstream_reverse "$source_dir/program_b.f90" "$out/exact/reverse-mod"

compile_source tapenade_admpi "$tapenade_repo/ADFirstAidKit/adMPI.f90" \
    "$out/fresh/support"
for mode in parser forward reverse; do
    case "$mode" in
        parser) tap_mode=-p ;;
        forward) tap_mode=-d ;;
        reverse) tap_mode=-b ;;
    esac
    run_status "tapenade-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$tap_mode' -root fonctiontTest -O . -o v385 '$source_dir/program.f90'"
done
test -s "$out/fresh/parser/v385_p.f90"
test -s "$out/fresh/parser/v385_p.msg"
test -s "$out/fresh/forward/v385_d.f90"
test -s "$out/fresh/forward/v385_d.msg"
test -s "$out/fresh/reverse/v385_b.f90"
test -s "$out/fresh/reverse/v385_b.msg"

compile_source fresh_parser "$out/fresh/parser/v385_p.f90" "$out/fresh/parser/mod"
compile_source fresh_forward "$out/fresh/forward/v385_d.f90" "$out/fresh/forward/mod" \
    -I"$out/fresh/support"
compile_source fresh_reverse "$out/fresh/reverse/v385_b.f90" "$out/fresh/reverse/mod" \
    -I"$out/fresh/support"
test "$(cat "$out/tapenade-parser-generation.status")" -eq 0
test "$(cat "$out/tapenade-forward-generation.status")" -eq 0
test "$(cat "$out/tapenade-reverse-generation.status")" -eq 0
test "$(cat "$out/tapenade_admpi.status")" -eq 0
test "$(cat "$out/fresh_parser.status")" -ne 0
test "$(cat "$out/fresh_forward.status")" -ne 0
test "$(cat "$out/fresh_reverse.status")" -ne 0
grep -Fq "Nonstandard type declaration REAL*8" "$out/upstream_primal.stderr"
grep -Fq "Nonstandard type declaration REAL*8" "$out/upstream_tangent.stderr"
grep -Fq "Nonstandard type declaration REAL*8" "$out/upstream_reverse.stderr"
grep -Fq "Nonstandard type declaration REAL*8" "$out/fresh_parser.stderr"
grep -Fq "Nonstandard type declaration REAL*8" "$out/fresh_forward.stderr"
grep -Fq "Nonstandard type declaration REAL*8" "$out/fresh_reverse.stderr"

run_status fortad-parser "$fortad" check --proc fonctiontTest \
    --output "$out/exact/parser.f90" "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward --proc fonctiontTest --indep buf \
    --name v385_forward --module v385_forward_mod --output "$out/exact/forward.f90" \
    "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse --proc fonctiontTest --indep buf \
    --dep resultat --name v385_reverse --module v385_reverse_mod \
    --output "$out/exact/reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    test ! -e "$out/exact/$mode.f90"
    grep -Fq "unsupported allocation lifetime construct 'allocatable declaration/component' at line 11" \
        "$out/fortad-$mode.stderr"
done

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
fortad_diag="fortad: unsupported allocation lifetime construct 'allocatable declaration/component' at line 11; active allocation state is not represented yet"
{
    printf 'case: Tapenade todoF90/REFERENCES/v385\n'
    printf 'classification: expected-refusal-invalid-upstream\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: fonctiontTest(buf,resultat)\n'
    printf 'tapenade_options: parser=-p/-root fonctiontTest forward=-d/-root fonctiontTest reverse=-b/-root fonctiontTest\n'
    printf 'upstream_exact_strict_compile: primal=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/upstream_primal.status")" "$(cat "$out/upstream_tangent.status")" \
        "$(cat "$out/upstream_reverse.status")"
    printf 'upstream_strict_diagnostic: Nonstandard type declaration REAL*8\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_sources: parser=v385_p.f90 tangent=v385_d.f90 reverse=v385_b.f90\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s admpi_support=%s\n' \
        "$(cat "$out/fresh_parser.status")" "$(cat "$out/fresh_forward.status")" \
        "$(cat "$out/fresh_reverse.status")" "$(cat "$out/tapenade_admpi.status")"
    printf 'tapenade_generation_diagnostic: conflicting MPI_ISEND actual count; unexpected MPI_TEST primitive\n'
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="%s"\n' \
        "$(cat "$out/fortad-parser.status")" "$fortad_diag"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="%s"\n' \
        "$(cat "$out/fortad-forward.status")" "$fortad_diag"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="%s"\n' \
        "$(cat "$out/fortad-reverse.status")" "$fortad_diag"
    printf 'independent_oracle: %s\n' "$(cat "$out/oracle.txt")"
    printf 'bounded_port: not-claimed reason=invalid-strict-source-and-unsupported-MPI-allocation-state\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f90 program_d.f90 program_d.msg program_b.f90 program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum v385_p.f90 v385_p.msg)
    (cd "$out/fresh/forward" && sha256sum v385_d.f90 v385_d.msg)
    (cd "$out/fresh/reverse" && sha256sum v385_b.f90 v385_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
