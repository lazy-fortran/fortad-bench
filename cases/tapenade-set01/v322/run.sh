#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v322 invalid-source boundary.
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
fc=${FC:-gfortran}
source_dir="$tapenade_repo/todoF90/REFERENCES/v322"
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
for source in DIFFSIZES.f90 Options program.f90 program_b.f90 program_b.msg simtest1.mod; do
    test -s "$source_dir/$source"
done

if test ! -x "$fortad"; then
    (cd "$fortad_repo" && fo build) >/var/tmp/fortad-bench-v322-fortad-build.log 2>&1
fi
test -x "$fortad"
test -x "$tapenade"

out=$(mktemp -d /var/tmp/fortad-bench-todof90-v322.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/upstream/mod" "$out/fresh/parser/mod" \
    "$out/fresh/forward/mod" "$out/fresh/reverse/mod" "$out/exact"

strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
legacy_flags=(-std=legacy -ffree-form -ffree-line-length-none -Wall -Wextra
    -Wimplicit-interface -cpp)

compile_source() {
    local label=$1
    local source=$2
    shift 2
    local status=0
    "$fc" "$@" "$source" -c -o "$out/$label.o" \
        >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_source upstream_diffsizes "$source_dir/DIFFSIZES.f90" \
    "${strict_flags[@]}" -I"$source_dir" -J"$out/upstream/mod"
compile_source upstream_program "$source_dir/program.f90" \
    "${strict_flags[@]}" -I"$source_dir" -I"$out/upstream/mod" \
    -J"$out/upstream/mod"
compile_source upstream_stored_reverse "$source_dir/program_b.f90" \
    "${strict_flags[@]}" -I"$source_dir" -I"$out/upstream/mod" \
    -J"$out/upstream/mod"
compile_source legacy_program "$source_dir/program.f90" \
    "${legacy_flags[@]}" -I"$source_dir" -I"$out/upstream/mod" \
    -J"$out/upstream/mod"
compile_source legacy_stored_reverse "$source_dir/program_b.f90" \
    "${legacy_flags[@]}" -I"$source_dir" -I"$out/upstream/mod" \
    -J"$out/upstream/mod"
test "$(cat "$out/upstream_diffsizes.status")" -eq 0
test "$(cat "$out/upstream_program.status")" -ne 0
test "$(cat "$out/upstream_stored_reverse.status")" -ne 0
test "$(cat "$out/legacy_program.status")" -eq 0
test "$(cat "$out/legacy_stored_reverse.status")" -ne 0
grep -Fq "Nonstandard type declaration REAL*8" "$out/upstream_program.stderr"
grep -Fq "Nonstandard type declaration REAL*8" "$out/upstream_stored_reverse.stderr"
grep -Fq "admm_tapenade_interface.mod" "$out/legacy_stored_reverse.stderr"

generate_tapenade() {
    local label=$1
    local mode=$2
    local status=0
    if (cd "$out/fresh/$label" && "$tapenade" -nolib "$mode" -root solvereal \
        -O . -o v322 "$source_dir/program.f90") \
        >"$out/tapenade-$label.stdout" 2>"$out/tapenade-$label.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/tapenade-$label.status"
}

generate_tapenade parser -p
generate_tapenade forward -d
generate_tapenade reverse -b
test -s "$out/fresh/parser/v322_p.f90"
test -s "$out/fresh/parser/v322_p.msg"
test -s "$out/fresh/forward/v322_d.f90"
test -s "$out/fresh/forward/v322_d.msg"
test -s "$out/fresh/reverse/v322_b.f90"
test -s "$out/fresh/reverse/v322_b.msg"
for label in parser forward reverse; do
    test "$(cat "$out/tapenade-$label.status")" -eq 0
done

compile_source fresh_parser "$out/fresh/parser/v322_p.f90" \
    "${strict_flags[@]}" -I"$source_dir" -J"$out/fresh/parser/mod"
compile_source fresh_forward "$out/fresh/forward/v322_d.f90" \
    "${strict_flags[@]}" -I"$source_dir" -J"$out/fresh/forward/mod"
compile_source fresh_reverse "$out/fresh/reverse/v322_b.f90" \
    "${strict_flags[@]}" -I"$source_dir" -J"$out/fresh/reverse/mod"
test "$(cat "$out/fresh_parser.status")" -ne 0
test "$(cat "$out/fresh_forward.status")" -ne 0
test "$(cat "$out/fresh_reverse.status")" -ne 0
grep -Fq "Nonstandard type declaration REAL*8" "$out/fresh_parser.stderr"
grep -Fq "Nonstandard type declaration REAL*8" "$out/fresh_forward.stderr"
grep -Fq "Nonstandard type declaration REAL*8" "$out/fresh_reverse.stderr"

run_fortad() {
    local label=$1
    shift
    local status=0
    "$fortad" "$@" >"$out/fortad-$label.stdout" \
        2>"$out/fortad-$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/fortad-$label.status"
}

run_fortad parser check --proc solvereal --output "$out/exact/parser.f90" \
    "$source_dir/program.f90"
run_fortad forward --mode forward --proc solvereal --indep this,c \
    --name solvereal_d --module v322_forward_mod \
    --output "$out/exact/forward.f90" "$source_dir/program.f90"
run_fortad reverse --mode reverse --proc solvereal --indep this,c --dep c \
    --name solvereal_b --module v322_reverse_mod \
    --output "$out/exact/reverse.f90" "$source_dir/program.f90"
for label in parser forward reverse; do
    test "$(cat "$out/fortad-$label.status")" -ne 0
    test ! -e "$out/exact/$label.f90"
    grep -Fq "unsupported allocation lifetime construct 'allocatable declaration/component' at line 6" \
        "$out/fortad-$label.stderr"
done

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
kind_diag=$(grep -F "Nonstandard type declaration REAL*8" "$out/upstream_program.stderr" | head -1)
missing_diag=$(grep -F "admm_tapenade_interface.mod" "$out/legacy_stored_reverse.stderr" | head -1)
fortad_diag="fortad: unsupported allocation lifetime construct 'allocatable declaration/component' at line 6; active allocation state is not represented yet"
{
    printf 'case: Tapenade todoF90/REFERENCES/v322\n'
    printf 'classification: expected-refusal-invalid-upstream\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_flags: %s\n' "${strict_flags[*]}"
    printf 'legacy_flags: %s\n' "${legacy_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: solvereal(this,c); private qcalc(this,Cmob)\n'
    printf 'upstream_exact_strict_compile: DIFFSIZES.f90=%s program.f90=%s program_b.f90=%s\n' \
        "$(cat "$out/upstream_diffsizes.status")" "$(cat "$out/upstream_program.status")" \
        "$(cat "$out/upstream_stored_reverse.status")"
    printf 'upstream_legacy_compile: program.f90=%s program_b.f90=%s\n' \
        "$(cat "$out/legacy_program.status")" "$(cat "$out/legacy_stored_reverse.status")"
    printf 'upstream_strict_diagnostic: %s\n' "$kind_diag"
    printf 'upstream_legacy_reference_diagnostic: %s\n' "$missing_diag"
    printf 'stored_references: program_b.f90=present program_b.msg=present program_p.f90=missing program_d.f90=missing program_dv.f90=missing\n'
    printf 'tapenade_options: -nolib; parser=-p/-root solvereal forward=-d/-root solvereal reverse=-b/-root solvereal\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" "$(cat "$out/tapenade-forward.status")" \
        "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_fresh_outputs: parser=v322_p.f90 tangent=v322_d.f90 reverse=v322_b.f90\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh_parser.status")" "$(cat "$out/fresh_forward.status")" \
        "$(cat "$out/fresh_reverse.status")"
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="%s"\n' \
        "$(cat "$out/fortad-parser.status")" "$fortad_diag"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="%s"\n' \
        "$(cat "$out/fortad-forward.status")" "$fortad_diag"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="%s"\n' \
        "$(cat "$out/fortad-reverse.status")" "$fortad_diag"
    printf 'bounded_port: not-claimed reason=invalid-legacy-kinds-missing-reference-dependency-and-allocatable-derived-type-state\n'
    printf 'oracle_status: pass strict-compiler-legacy-dependency-diagnostic-and-exact-FortAD-boundary\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum DIFFSIZES.f90 Options program.f90 program_b.f90 program_b.msg simtest1.mod)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum v322_p.f90 v322_p.msg)
    (cd "$out/fresh/forward" && sha256sum v322_d.f90 v322_d.msg)
    (cd "$out/fresh/reverse" && sha256sum v322_b.f90 v322_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md run.sh test_contract.py)
} >"$result"
cat "$result"
