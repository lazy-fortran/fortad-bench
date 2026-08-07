#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/v500 boundary.
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
source_rel=todoF90/REFERENCES/v500
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-v500.XXXXXX)
trap 'rm -rf "$out"' EXIT

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"
for source in Options program.f90 program_b.f90 program_b.msg; do
    test -s "$source_dir/$source"
done

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
    mkdir -p "$moddir"
    run_status "$label" "$fc" "${strict_flags[@]}" -I"$source_dir" \
        -J"$moddir" -c "$source" -o "$out/$label.o"
}

mkdir -p "$out/exact-primal-mod" "$out/exact-stored-mod"

# Contract test 1: exact primal and stored reverse references.
compile_source upstream_primal "$source_dir/program.f90" "$out/exact-primal-mod"
compile_source upstream_stored "$source_dir/program_b.f90" "$out/exact-stored-mod"
test "$(cat "$out/upstream_primal.status")" -eq 0
test "$(cat "$out/upstream_stored.status")" -eq 0
grep -Fq "Unused variable" "$out/upstream_primal.stderr"
grep -Fq "implicit interface" "$out/upstream_stored.stderr"

# Contract test 2: fresh pinned Tapenade parser, tangent, and reverse output.
for mode in p d b; do
    mkdir -p "$out/tapenade/$mode"
    run_status "fresh-$mode-generation" bash -c \
        "cd '$out/tapenade/$mode' && '$tapenade' -association byaddress '-$mode' \\
         -root nl_model_mie_orig -O . -o v500 '$source_dir/program.f90'"
    test "$(cat "$out/fresh-$mode-generation.status")" -eq 0
    test -s "$out/tapenade/$mode/v500_${mode}.f90"
    test -s "$out/tapenade/$mode/v500_${mode}.msg"
    mkdir -p "$out/fresh-$mode-mod"
    compile_source "fresh-$mode-compile" "$out/tapenade/$mode/v500_${mode}.f90" \
        "$out/fresh-$mode-mod"
done
test "$(cat "$out/fresh-p-compile.status")" -eq 0
test "$(cat "$out/fresh-d-compile.status")" -eq 0
test "$(cat "$out/fresh-b-compile.status")" -ne 0
grep -Fq "INTEGER*4" "$out/fresh-b-compile.stderr"

# Contract test 3: exact FortAD parser, forward, and reverse behavior.
run_status fortad-parser "$fortad" check --proc nl_model_mie_orig \
    --output "$out/fortad-parser.f90" "$source_dir/program.f90"
run_status fortad-forward "$fortad" --mode forward --indep alpha_ext \
    --proc nl_model_mie_orig --name v500_forward --module v500_forward_mod \
    --output "$out/fortad-forward.f90" "$source_dir/program.f90"
run_status fortad-reverse "$fortad" --mode reverse --indep alpha_ext --dep alpha_ext \
    --proc nl_model_mie_orig --name v500_reverse --module v500_reverse_mod \
    --output "$out/fortad-reverse.f90" "$source_dir/program.f90"
for mode in parser forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -ne 0
    test ! -e "$out/fortad-$mode.f90"
    grep -Fq "unsupported statement at line 21" "$out/fortad-$mode.stderr"
done

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq "oracle_status: pass singular-pp-normalization" "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES/v500 DATA and singular-output boundary\n'
    printf 'classification: expected-refusal-unsupported-data-and-singular-output\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: nl_model_mie_orig(alpha_ext,PP)\n'
    printf 'tapenade_options: Options="-nooptim nostatictape"; fresh=-association byaddress -p/-d/-b -root nl_model_mie_orig\n'
    printf 'upstream_exact_strict_compile: primal=%s stored_program_b=%s\n' \
        "$(cat "$out/upstream_primal.status")" "$(cat "$out/upstream_stored.status")"
    printf 'exact_diagnostic: primal-and-stored-compile-success; stored-tape-runtime-implicit-interface-warning\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-p-generation.status")" \
        "$(cat "$out/fresh-d-generation.status")" "$(cat "$out/fresh-b-generation.status")"
    printf 'tapenade_fresh_sources: parser=v500_p.f90 tangent=v500_d.f90 reverse=v500_b.f90\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh-p-compile.status")" \
        "$(cat "$out/fresh-d-compile.status")" "$(cat "$out/fresh-b-compile.status")"
    printf 'fresh_reverse_diagnostic: nonstandard-INTEGER*4\n'
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="unsupported statement at line 21"\n' \
        "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="unsupported statement at line 21"\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="unsupported statement at line 21"\n' \
        "$(cat "$out/fortad-reverse.status")"
    cat "$out/oracle.txt"
    printf 'port_result: not-applicable-exact-data-and-singular-normalization-boundary\n'
    printf 'closure: no bounded port; repairing DATA handling or zero sigma_sca would change the exact candidate\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/program.f90 \
        "$source_rel"/program_b.f90 "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade" && find . -type f \( -name '*.f90' -o -name '*.msg' \) -print0 | \
        sort -z | xargs -0 sha256sum)
} >"$result"
cat "$result"
