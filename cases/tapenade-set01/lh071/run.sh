#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}

fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
set01_dir="$tapenade_repo/nonRegressions/set01/lh071"
set03_dir="$tapenade_repo/nonRegressions/set03/lh071"
out=$(mktemp -d /var/tmp/fortad-bench-lh071.XXXXXX)
trap 'rm -rf "$out"' EXIT

fixed_flags=(-std=f2018 -ffixed-form -fsyntax-only -pedantic-errors -Wall -Wextra
    -Wimplicit-interface -cpp -I"$tapenade_repo" -I"$set01_dir" -J"$out/mod")
free_flags=(-std=f2018 -ffree-form -fsyntax-only -pedantic-errors -Wall -Wextra
    -Wimplicit-interface -cpp -I"$tapenade_repo" -I"$set03_dir" -J"$out/mod")

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test -x "$tapenade"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
if test ! -x "$fortad"; then
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.stdout" 2>"$out/fortad-build.stderr"
fi
test -x "$fortad"

upstream_sources=(
    nonRegressions/set01/lh071/program.f
    nonRegressions/set01/lh071/program_b.f
    nonRegressions/set01/lh071/program_b.msg
    nonRegressions/set03/lh071/program.f90
    nonRegressions/set03/lh071/program_b.f90
    nonRegressions/set03/lh071/program_b.msg
)
for source in "${upstream_sources[@]}"; do
    test -s "$tapenade_repo/$source"
done
mkdir -p "$out/mod" "$out/tapenade/set01/parser" "$out/tapenade/set01/forward" \
    "$out/tapenade/set01/reverse" "$out/tapenade/set03/parser" \
    "$out/tapenade/set03/forward" "$out/tapenade/set03/reverse" "$out/exact"

compile_strict() {
    local label=$1
    local form=$2
    local source=$3
    local status
    if test "$form" = fixed; then
        if "$fc" "${fixed_flags[@]}" "$source" >"$out/$label.stdout" 2>"$out/$label.stderr"; then
            status=0
        else
            status=$?
        fi
    else
        if "$fc" "${free_flags[@]}" "$source" >"$out/$label.stdout" 2>"$out/$label.stderr"; then
            status=0
        else
            status=$?
        fi
    fi
    printf '%s\n' "$status" >"$out/$label.status"
}

generate_tapenade() {
    local label=$1
    local mode=$2
    local root_name=$3
    local output_dir=$4
    local source=$5
    local status
    if (cd "$output_dir" && "$tapenade" "$mode" -root "$root_name" -O . -o "$label" "$source") \
        >"$out/$label-generation.stdout" 2>"$out/$label-generation.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/$label-generation.status"
}

fortad_exact() {
    local label=$1
    shift
    local status
    if "$fortad" "$@" >"$out/$label.stdout" 2>"$out/$label.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_strict upstream_set01_program fixed "$set01_dir/program.f"
compile_strict upstream_set01_program_b fixed "$set01_dir/program_b.f"
compile_strict upstream_set03_program free "$set03_dir/program.f90"
compile_strict upstream_set03_program_b free "$set03_dir/program_b.f90"
test "$(<"$out/upstream_set01_program.status")" -ne 0
test "$(<"$out/upstream_set01_program_b.status")" -ne 0
test "$(<"$out/upstream_set03_program.status")" -ne 0
test "$(<"$out/upstream_set03_program_b.status")" -ne 0
grep -Fq 'Rank mismatch in argument' "$out/upstream_set01_program.stderr"
grep -Fq 'Rank mismatch in argument' "$out/upstream_set01_program_b.stderr"
grep -Fq 'Pointer assignment target is neither TARGET nor POINTER' "$out/upstream_set03_program.stderr"
grep -Fq 'Pointer assignment target is neither TARGET nor POINTER' "$out/upstream_set03_program_b.stderr"

generate_tapenade fresh_set01_parser -p adj "$out/tapenade/set01/parser" "$set01_dir/program.f"
generate_tapenade fresh_set01_tangent -d adj "$out/tapenade/set01/forward" "$set01_dir/program.f"
generate_tapenade fresh_set01_reverse -b adj "$out/tapenade/set01/reverse" "$set01_dir/program.f"
generate_tapenade fresh_set03_parser -p nonadjdeadtest "$out/tapenade/set03/parser" "$set03_dir/program.f90"
generate_tapenade fresh_set03_tangent -d nonadjdeadtest "$out/tapenade/set03/forward" "$set03_dir/program.f90"
generate_tapenade fresh_set03_reverse -b nonadjdeadtest "$out/tapenade/set03/reverse" "$set03_dir/program.f90"
for label in fresh_set01_parser fresh_set01_tangent fresh_set01_reverse \
    fresh_set03_parser fresh_set03_tangent fresh_set03_reverse; do
    test "$(<"$out/$label-generation.status")" -eq 0
done
test -s "$out/tapenade/set01/parser/fresh_set01_parser_p.f"
test -s "$out/tapenade/set01/forward/fresh_set01_tangent_d.f"
test -s "$out/tapenade/set01/reverse/fresh_set01_reverse_b.f"
test -s "$out/tapenade/set03/parser/fresh_set03_parser_p.f90"
test -s "$out/tapenade/set03/forward/fresh_set03_tangent_d.f90"
test -s "$out/tapenade/set03/reverse/fresh_set03_reverse_b.f90"

compile_strict fresh_set01_parser fixed "$out/tapenade/set01/parser/fresh_set01_parser_p.f"
compile_strict fresh_set01_tangent fixed "$out/tapenade/set01/forward/fresh_set01_tangent_d.f"
compile_strict fresh_set01_reverse fixed "$out/tapenade/set01/reverse/fresh_set01_reverse_b.f"
compile_strict fresh_set03_parser free "$out/tapenade/set03/parser/fresh_set03_parser_p.f90"
compile_strict fresh_set03_tangent free "$out/tapenade/set03/forward/fresh_set03_tangent_d.f90"
compile_strict fresh_set03_reverse free "$out/tapenade/set03/reverse/fresh_set03_reverse_b.f90"
for label in fresh_set01_parser fresh_set01_tangent fresh_set01_reverse \
    fresh_set03_parser fresh_set03_tangent fresh_set03_reverse; do
    test "$(<"$out/$label.status")" -ne 0
    grep -Eq 'Rank mismatch in argument|Pointer assignment target is neither TARGET nor POINTER' \
        "$out/$label.stderr"
done

fortad_exact exact_set01_forward --mode forward --indep a,b,c,d --proc adj \
    --name lh071_set01_forward --module lh071_set01_forward_mod \
    --output "$out/exact/set01_forward.f90" "$set01_dir/program.f"
fortad_exact exact_set01_reverse --mode reverse --indep a,b,c,d --dep c --proc adj \
    --name lh071_set01_reverse --module lh071_set01_reverse_mod \
    --output "$out/exact/set01_reverse.f90" "$set01_dir/program.f"
fortad_exact exact_set03_forward --mode forward --indep x --proc nonadjdeadtest \
    --name lh071_set03_forward --module lh071_set03_forward_mod \
    --output "$out/exact/set03_forward.f90" "$set03_dir/program.f90"
fortad_exact exact_set03_reverse --mode reverse --indep x --dep y --proc nonadjdeadtest \
    --name lh071_set03_reverse --module lh071_set03_reverse_mod \
    --output "$out/exact/set03_reverse.f90" "$set03_dir/program.f90"
for label in exact_set01_forward exact_set01_reverse exact_set03_forward exact_set03_reverse; do
    test "$(<"$out/$label.status")" -ne 0
    test ! -e "$out/exact/${label#exact_}.f90"
done
grep -Fq 'unsupported statement at line 4' "$out/exact_set01_forward.stderr"
grep -Fq 'unsupported statement at line 4' "$out/exact_set01_reverse.stderr"
grep -Fq "unsupported aliasing declaration 'p' at line 8" "$out/exact_set03_forward.stderr"
grep -Fq "unsupported aliasing declaration 'p' at line 8" "$out/exact_set03_reverse.stderr"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01/set03 lh071\n'
    printf 'classification: expected-refusal-invalid-upstream\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${fixed_flags[*]}"
    printf 'strict_free_flags: %s\n' "${free_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_exact_strict_compile: set01_program=%s set01_program_b=%s set03_program=%s set03_program_b=%s\n' \
        "$(<"$out/upstream_set01_program.status")" "$(<"$out/upstream_set01_program_b.status")" \
        "$(<"$out/upstream_set03_program.status")" "$(<"$out/upstream_set03_program_b.status")"
    printf 'upstream_stored_reference_strict_compile: set01_program_b=%s set03_program_b=%s\n' \
        "$(<"$out/upstream_set01_program_b.status")" "$(<"$out/upstream_set03_program_b.status")"
    printf 'upstream_diagnostics: set01=rank-mismatch-d-and-db; set03=pointer-target-not-TARGET-or-POINTER\n'
    printf 'tapenade_generation: set01_parser=%s set01_tangent=%s set01_reverse=%s set03_parser=%s set03_tangent=%s set03_reverse=%s\n' \
        "$(<"$out/fresh_set01_parser-generation.status")" "$(<"$out/fresh_set01_tangent-generation.status")" \
        "$(<"$out/fresh_set01_reverse-generation.status")" "$(<"$out/fresh_set03_parser-generation.status")" \
        "$(<"$out/fresh_set03_tangent-generation.status")" "$(<"$out/fresh_set03_reverse-generation.status")"
    printf 'tapenade_fresh_strict_compile: set01_parser=%s set01_tangent=%s set01_reverse=%s set03_parser=%s set03_tangent=%s set03_reverse=%s\n' \
        "$(<"$out/fresh_set01_parser.status")" "$(<"$out/fresh_set01_tangent.status")" \
        "$(<"$out/fresh_set01_reverse.status")" "$(<"$out/fresh_set03_parser.status")" \
        "$(<"$out/fresh_set03_tangent.status")" "$(<"$out/fresh_set03_reverse.status")"
    printf 'tapenade_diagnostics: set01=rank-mismatch-d-and-db; set03=pointer-target-not-TARGET-or-POINTER\n'
    printf 'fortad_exact_forward: set01=expected-refusal status=%s output=none diagnostic="unsupported statement at line 4"; set03=expected-refusal status=%s output=none diagnostic="unsupported aliasing declaration p at line 8"\n' \
        "$(<"$out/exact_set01_forward.status")" "$(<"$out/exact_set03_forward.status")"
    printf 'fortad_exact_reverse: set01=expected-refusal status=%s output=none diagnostic="unsupported statement at line 4"; set03=expected-refusal status=%s output=none diagnostic="unsupported aliasing declaration p at line 8"\n' \
        "$(<"$out/exact_set01_reverse.status")" "$(<"$out/exact_set03_reverse.status")"
    printf 'bounded_port: not-claimed reason=repair-would-change-invalid-upstream-semantics\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "${upstream_sources[@]}")
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$out/tapenade/set01/parser/fresh_set01_parser_p.f" \
        "$out/tapenade/set01/forward/fresh_set01_tangent_d.f" \
        "$out/tapenade/set01/reverse/fresh_set01_reverse_b.f" \
        "$out/tapenade/set03/parser/fresh_set03_parser_p.f90" \
        "$out/tapenade/set03/forward/fresh_set03_tangent_d.f90" \
        "$out/tapenade/set03/reverse/fresh_set03_reverse_b.f90"
} >"$result"
cat "$result"
