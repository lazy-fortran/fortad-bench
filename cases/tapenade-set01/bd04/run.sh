#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
fortad_repo=${FORTAD_REPO:-/mnt/storage/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
required_fortad_commit=72ca2aa1c6c7d4b171b13a3e13c5190944080032
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/bd04
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
result="$case_dir/result.txt"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-bd04.XXXXXX)
trap 'rm -rf "$out"' EXIT

strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -fsyntax-only
    -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -x "$fortad"
test -x "$tapenade"

for file in program.f program_p.f program_d.f program_b.f; do
    test -s "$source_dir/$file"
done
for file in program_p.msg program_d.msg program_b.msg; do
    test -e "$source_dir/$file"
done
mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"

run_status() {
    local label=$1
    shift
    local status
    set +e
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr"
    status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_fixed() {
    local label=$1
    local source=$2
    run_status "$label" "$fc" "${strict[@]}" "$source"
}

compile_fixed upstream_program "$source_dir/program.f"
compile_fixed stored_parser "$source_dir/program_p.f"
compile_fixed stored_forward "$source_dir/program_d.f"
compile_fixed stored_reverse "$source_dir/program_b.f"
for label in upstream_program stored_parser stored_forward stored_reverse; do
    test "$(cat "$out/$label.status")" -eq 0
done

run_tapenade() {
    local label=$1
    local mode=$2
    local output_dir="$out/fresh/$label"
    local args
    if test "$mode" = p; then
        args=(-p)
    elif test "$mode" = d; then
        args=(-d -root toto)
    else
        args=(-b -root toto)
    fi
    set +e
    (cd "$tapenade_repo" && "$tapenade" "${args[@]}" -O "$output_dir" -o bd04 "$source_dir/program.f") \
        >"$out/tapenade_$label.stdout" 2>"$out/tapenade_$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/tapenade_$label.status"
}

run_tapenade parser p
run_tapenade forward d
run_tapenade reverse b
for label in parser forward reverse; do
    test "$(cat "$out/tapenade_$label.status")" -eq 0
    suffix=p
    if test "$label" = forward; then suffix=d; fi
    if test "$label" = reverse; then suffix=b; fi
    generated="$out/fresh/$label/bd04_$suffix.f"
    test -s "$generated"
    compile_fixed "fresh_$label" "$generated"
    test "$(cat "$out/fresh_$label.status")" -eq 0
done

run_status fortad_exact_parser "$fortad" check \
    --output "$out/fortad_exact_parser.f90" "$source_dir/program.f"
run_status fortad_exact_forward "$fortad" --mode forward --indep a --dep a \
    --proc toto --name bd04_forward --module bd04_forward_mod \
    --output "$out/fortad_exact_forward.f90" "$source_dir/program.f"
run_status fortad_exact_reverse "$fortad" --mode reverse --indep a --dep a \
    --proc toto --name bd04_reverse --module bd04_reverse_mod \
    --output "$out/fortad_exact_reverse.f90" "$source_dir/program.f"
for label in fortad_exact_parser fortad_exact_forward fortad_exact_reverse; do
    test "$(cat "$out/$label.status")" -ne 0
    test ! -e "$out/$label.f90"
    grep -Fq 'fortad: unsupported statement at line 26' \
        "$out/$label.stdout" "$out/$label.stderr"
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fqx 'oracle_status: pass' <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 bd04\n'
    printf 'classification: expected-refusal-fortad-unsupported-print-statement\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: toto(a)\n'
    printf 'upstream_exact_strict_compile: program.f=%s\n' "$(cat "$out/upstream_program.status")"
    printf 'stored_strict_compile: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/stored_parser.status")" \
        "$(cat "$out/stored_forward.status")" \
        "$(cat "$out/stored_reverse.status")"
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade_parser.status")" \
        "$(cat "$out/tapenade_forward.status")" \
        "$(cat "$out/tapenade_reverse.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh_parser.status")" \
        "$(cat "$out/fresh_forward.status")" \
        "$(cat "$out/fresh_reverse.status")"
    printf 'fortad_exact_parser: expected-refusal status=%s output=none diagnostic="unsupported statement at line 26"\n' \
        "$(cat "$out/fortad_exact_parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="unsupported statement at line 26"\n' \
        "$(cat "$out/fortad_exact_forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="unsupported statement at line 26"\n' \
        "$(cat "$out/fortad_exact_reverse.status")"
    printf 'independent_oracle: DO-control trace, selected-cell update, JVP finite difference, VJP adjoint identity\n'
    printf '%s\n' "$oracle_output"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_p.msg program_d.f \
        program_d.msg program_b.f program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum bd04_p.f bd04_p.msg)
    (cd "$out/fresh/forward" && sha256sum bd04_d.f bd04_d.msg)
    (cd "$out/fresh/reverse" && sha256sum bd04_b.f bd04_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
