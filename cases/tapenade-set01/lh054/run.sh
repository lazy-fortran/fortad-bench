#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_checkout=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_checkout=$(cd "$fortad_checkout" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
fortad_pin=0e156041c1f92736c1e35f8164b37992c4c8d780
tapenade_pin=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface)
free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/nonRegressions/set01/lh054"
out=$(mktemp -d /var/tmp/fortad-set01-lh054.XXXXXX)
clean_fortad_repo=

cleanup() {
    if test -n "$clean_fortad_repo"; then
        rm -rf "$clean_fortad_repo"
    fi
    rm -rf "$out"
}
trap cleanup EXIT

command -v "$fc" >/dev/null
command -v python3 >/dev/null
command -v java >/dev/null
command -v fo >/dev/null
test -x "$tapenade_repo/bin/tapenade"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$tapenade_pin"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for f in program.f program_p.f program_d.f program_b.f program_dv.f \
         program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -f "$source_dir/$f"
done

fortad_original_commit=$(git -C "$fortad_checkout" rev-parse HEAD)
fortad_dirty_paths=$(git -C "$fortad_checkout" status --porcelain --untracked-files=no)
if test "$fortad_original_commit" != "$fortad_pin" || test -n "$fortad_dirty_paths"; then
    clean_fortad_repo=$(mktemp -d "$(dirname "$fortad_checkout")/fortad-lh054-clean.XXXXXX")
    rmdir "$clean_fortad_repo"
    git clone --shared --quiet "$fortad_checkout" "$clean_fortad_repo"
    git -C "$clean_fortad_repo" checkout --detach --quiet "$fortad_pin"
    fortad_repo="$clean_fortad_repo"
    fortad_worktree="temporary clean clone pinned to required commit"
else
    fortad_repo="$fortad_checkout"
    fortad_worktree="supplied checkout clean and pinned"
fi
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$fortad_pin"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"

if test ! -x "$fortad_repo/build/fo/bin/fortad"; then
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
fi
fortad="$fortad_repo/build/fo/bin/fortad"
test -x "$fortad"
if test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
tapenade="$tapenade_repo/bin/tapenade"
test -x "$tapenade"

mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse" "$out/mod"

compile_fixed_capture() {
    local source=$1 label=$2 include_dir=${3:-}
    local -a flags=("${fixed[@]}")
    if test -n "$include_dir"; then
        flags+=("-I$include_dir")
    fi
    set +e
    "$fc" "${flags[@]}" -J"$out/mod" -c "$source" -o "$out/$label.o" >"$out/$label.log" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status"
}

compile_free_capture() {
    local source=$1 label=$2
    set +e
    "$fc" "${free[@]}" -J"$out/mod" -I"$out/mod" -c "$source" -o "$out/$label.o" >"$out/$label.log" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status"
}

exact_status=$(compile_fixed_capture "$source_dir/program.f" upstream_exact)
parser_stored_status=$(compile_fixed_capture "$source_dir/program_p.f" upstream_parser_stored)
forward_stored_status=$(compile_fixed_capture "$source_dir/program_d.f" upstream_forward_stored)
reverse_stored_status=$(compile_fixed_capture "$source_dir/program_b.f" upstream_reverse_stored)
multidirectional_stored_status=$(compile_fixed_capture "$source_dir/program_dv.f" upstream_multidirectional_stored "$source_dir")
test "$exact_status" -eq 0
test "$parser_stored_status" -eq 0
test "$forward_stored_status" -eq 0
test "$reverse_stored_status" -eq 0
test "$multidirectional_stored_status" -ne 0
grep -Fq 'Cannot open included file' "$out/upstream_multidirectional_stored.log"

(cd "$out/tapenade/parser" && "$tapenade" -p -o lh054 "$source_dir/program.f") >"$out/tapenade-parser.log" 2>&1
(cd "$out/tapenade/forward" && "$tapenade" -d -root test -o lh054 "$source_dir/program.f") >"$out/tapenade-forward.log" 2>&1
(cd "$out/tapenade/reverse" && "$tapenade" -b -root test -o lh054 "$source_dir/program.f") >"$out/tapenade-reverse.log" 2>&1
for generated in "$out/tapenade/parser/lh054_p.f" "$out/tapenade/forward/lh054_d.f" "$out/tapenade/reverse/lh054_b.f"; do
    test -s "$generated"
done
parser_generated_status=$(compile_fixed_capture "$out/tapenade/parser/lh054_p.f" tapenade_parser_generated)
forward_generated_status=$(compile_fixed_capture "$out/tapenade/forward/lh054_d.f" tapenade_forward_generated)
reverse_generated_status=$(compile_fixed_capture "$out/tapenade/reverse/lh054_b.f" tapenade_reverse_generated)
test "$parser_generated_status" -eq 0
test "$forward_generated_status" -eq 0
test "$reverse_generated_status" -eq 0

fortad_transform() {
    local mode=$1 output=$2 log=$3
    local status
    set +e
    if test "$mode" = forward; then
        "$fortad" --mode forward --indep b --proc test --name lh054_exact_forward \
            --module lh054_exact_forward_mod --output "$output" "$source_dir/program.f" >"$log" 2>&1
    else
        "$fortad" --mode reverse --indep b --dep b --proc test --name lh054_exact_reverse \
            --module lh054_exact_reverse_mod --output "$output" "$source_dir/program.f" >"$log" 2>&1
    fi
    status=$?
    set -e
    printf '%s\n' "$status"
}

exact_forward_transform_status=$(fortad_transform forward "$out/exact_forward.f90" "$out/exact-forward.log")
exact_reverse_transform_status=$(fortad_transform reverse "$out/exact_reverse.f90" "$out/exact-reverse.log")
test "$exact_forward_transform_status" -eq 0
test "$exact_reverse_transform_status" -eq 0
test -s "$out/exact_forward.f90"
test -s "$out/exact_reverse.f90"
exact_forward_compile_status=$(compile_free_capture "$out/exact_forward.f90" fortad_exact_forward)
exact_reverse_compile_status=$(compile_free_capture "$out/exact_reverse.f90" fortad_exact_reverse)
test "$exact_forward_compile_status" -ne 0
test "$exact_reverse_compile_status" -ne 0
grep -Fq 'Invalid character in name' "$out/fortad_exact_forward.log"
grep -Fq 'Duplicate symbol' "$out/fortad_exact_reverse.log"

# Run the bounded port explicitly so its source and generated names are
# visible in the result.
set +e
"$fortad" --mode forward --indep b --proc set01_lh054 --name lh054_port_forward \
    --module lh054_port_forward_mod --output "$out/port_forward.f90" "$case_dir/port.f90" >"$out/port-forward.log" 2>&1
port_forward_transform_status=$?
"$fortad" --mode reverse --indep b --dep b --proc set01_lh054 --name lh054_port_reverse \
    --module lh054_port_reverse_mod --output "$out/port_reverse.f90" "$case_dir/port.f90" >"$out/port-reverse.log" 2>&1
port_reverse_transform_status=$?
set -e
test "$port_forward_transform_status" -eq 0
test "$port_reverse_transform_status" -eq 0
test -s "$out/port_forward.f90"
test -s "$out/port_reverse.f90"
port_status=$(compile_free_capture "$case_dir/port.f90" bounded_port)
port_forward_compile_status=$(compile_free_capture "$out/port_forward.f90" fortad_port_forward)
port_reverse_compile_status=$(compile_free_capture "$out/port_reverse.f90" fortad_port_reverse)
test "$port_status" -eq 0
test "$port_forward_compile_status" -eq 0
test "$port_reverse_compile_status" -ne 0
grep -Fq 'Duplicate symbol' "$out/fortad_port_reverse.log"

harness_compile_status=$(compile_free_capture "$case_dir/harness.f90" harness)
test "$harness_compile_status" -eq 0
"$fc" "${free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/harness" \
    "$out/fortad_port_forward.o" "$out/harness.o" >"$out/link.log" 2>&1
"$out/harness" >"$out/harness.log"
grep -Fq 'harness_status: pass' "$out/harness.log"
oracle_output=$(python3 "$case_dir/oracle.py")
grep -Fq 'oracle_status: pass' <<<"$oracle_output"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh054\n'
    printf 'classification: fortad-semantic-mismatch-with-bounded-forward-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${fixed[*]}"
    printf 'strict_free_flags: %s\n' "${free[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$fortad_pin"
    printf 'fortad_worktree: %s\n' "$fortad_worktree"
    printf 'tapenade_commit: %s\n' "$tapenade_pin"
    printf 'upstream_exact_strict_compile: pass status=%s\n' "$exact_status"
    printf 'upstream_stored_references_strict_compile: program_p.f=pass program_d.f=pass program_b.f=pass program_dv.f=expected-refusal status=%s missing-DIFFSIZES.inc\n' "$multidirectional_stored_status"
    printf 'tapenade_options: parser=-p forward=-d/-root test reverse=-b/-root test\n'
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_generated_strict_compile: parser=pass tangent=pass reverse=pass\n'
    printf 'fortad_exact_transform: forward=pass status=%s reverse=pass status=%s\n' "$exact_forward_transform_status" "$exact_reverse_transform_status"
    printf 'fortad_exact_generated_strict_compile: forward=expected-refusal status=%s diagnostic=invalid-character-in-omitted-declarations reverse=expected-refusal status=%s diagnostic=duplicate-b_b-formal\n' "$exact_forward_compile_status" "$exact_reverse_compile_status"
    printf 'fortad_bounded_port: source_compile=pass status=%s forward_transform=pass status=%s forward_compile=pass status=%s reverse_transform=pass status=%s reverse_compile=expected-refusal status=%s diagnostic=duplicate-b_b-formal\n' "$port_status" "$port_forward_transform_status" "$port_forward_compile_status" "$port_reverse_transform_status" "$port_reverse_compile_status"
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, and adjoint identity\n'
    printf '%s\n' "$oracle_output"
    cat "$out/harness.log"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$out/tapenade/parser/lh054_p.f" "$out/tapenade/parser/lh054_p.msg" "$out/tapenade/forward/lh054_d.f" "$out/tapenade/forward/lh054_d.msg" "$out/tapenade/reverse/lh054_b.f" "$out/tapenade/reverse/lh054_b.msg"
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh054/manifest.toml cases/tapenade-set01/lh054/notes.md cases/tapenade-set01/lh054/port.f90 cases/tapenade-set01/lh054/oracle.py cases/tapenade-set01/lh054/harness.f90 cases/tapenade-set01/lh054/run.sh cases/tapenade-set01/lh054/test_contract.py)
} >"$result"
cat "$result"
