#!/usr/bin/env bash
# Validate the pinned Tapenade set01/ala03 MPI wave/checkpoint boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=$(cd "${FORTAD_REPO:-$root/../fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
required_fortad_commit=72ca2aa1c6c7d4b171b13a3e13c5190944080032
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-mpifort}
mpi_include=${MPI_INCLUDE:-/usr/include}
source_rel=nonRegressions/set01/ala03
source_dir="$tapenade_repo/$source_rel"
support_include="$tapenade_repo/ADFirstAidKit"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-ala03.XXXXXX)
trap 'rm -rf "$out"' EXIT

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse --abbrev-ref HEAD)" = main
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"
test -d "$support_include"
test -e "$mpi_include/mpif.h"
for source in Options program.f program_d.f program_d.msg program_b.f program_b.msg; do
    test -e "$source_dir/$source"
done

strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fsyntax-only -fno-lto
    -I"$mpi_include" -I"$support_include")
legacy=(-std=legacy -ffixed-form -ffixed-line-length-none -Wall -Wextra
    -Wimplicit-interface -fsyntax-only -fno-lto
    -I"$mpi_include" -I"$support_include")

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

status() { cat "$out/$1.status"; }

compile_fixed() {
    local label=$1
    local flags_name=$2
    local source=$3
    if test "$flags_name" = strict; then
        run_status "$label" "$fc" "${strict[@]}" "$source"
    else
        run_status "$label" "$fc" "${legacy[@]}" "$source"
    fi
}

compile_fixed exact-strict-program strict "$source_dir/program.f"
compile_fixed exact-legacy-program legacy "$source_dir/program.f"
compile_fixed stored-d-strict strict "$source_dir/program_d.f"
compile_fixed stored-d-legacy legacy "$source_dir/program_d.f"
compile_fixed stored-b-strict strict "$source_dir/program_b.f"
compile_fixed stored-b-legacy legacy "$source_dir/program_b.f"
test "$(status exact-strict-program)" -ne 0
grep -Fq 'Type mismatch between actual argument' "$out/exact-strict-program.stderr"
test "$(status exact-legacy-program)" -eq 0
test "$(status stored-d-strict)" -eq 0
test "$(status stored-d-legacy)" -eq 0
test "$(status stored-b-strict)" -ne 0
grep -Fq 'Nonstandard type declaration INTEGER*4' "$out/stored-b-strict.stderr"
test "$(status stored-b-legacy)" -eq 0

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"
for mode in parser forward reverse; do
    case "$mode" in
        parser) flag=-p; suffix=p ;;
        forward) flag=-d; suffix=d ;;
        reverse) flag=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$flag' -noisize \\
         -head 'wave_resolution(u_global)/(c)' -I '$support_include' -I '$mpi_include' \\
         -O . -o ala03 '$source_dir/program.f'"
    test "$(status "tapenade-$mode")" -eq 0
    test -s "$out/fresh/$mode/ala03_${suffix}.f"
    test -e "$out/fresh/$mode/ala03_${suffix}.msg"
    compile_fixed "fresh-$mode-strict" strict "$out/fresh/$mode/ala03_${suffix}.f"
    compile_fixed "fresh-$mode-legacy" legacy "$out/fresh/$mode/ala03_${suffix}.f"
done
test "$(status fresh-parser-strict)" -ne 0
grep -Fq 'Type mismatch between actual argument' "$out/fresh-parser-strict.stderr"
test "$(status fresh-parser-legacy)" -eq 0
test "$(status fresh-forward-strict)" -eq 0
test "$(status fresh-forward-legacy)" -eq 0
test "$(status fresh-reverse-strict)" -ne 0
grep -Fq 'Nonstandard type declaration INTEGER*4' "$out/fresh-reverse-strict.stderr"
test "$(status fresh-reverse-legacy)" -eq 0

mkdir -p "$out/fortad"
run_status fortad-check "$fortad" check --proc wave_resolution \
    --output "$out/fortad/check.f90" "$source_dir/program.f"
run_status fortad-forward "$fortad" --mode forward --proc wave_resolution \
    --indep c --dep u_global --name ala03_d --module ala03_d_mod \
    --output "$out/fortad/forward.f90" "$source_dir/program.f"
run_status fortad-reverse "$fortad" --mode reverse --proc wave_resolution \
    --indep c --dep u_global --name ala03_b --module ala03_b_mod \
    --output "$out/fortad/reverse.f90" "$source_dir/program.f"
test "$(status fortad-check)" -eq 0
test -s "$out/fortad/check.f90"
test "$(status fortad-forward)" -ne 0
grep -Fq "no derivative rule for the call to 'update'" "$out/fortad-forward.stderr"
test ! -e "$out/fortad/forward.f90"
test "$(status fortad-reverse)" -ne 0
grep -Fq "no reverse rule for the call to 'update'" "$out/fortad-reverse.stderr"
test ! -e "$out/fortad/reverse.f90"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir/program.f")
grep -Fqx 'oracle_status: pass' <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions/set01/ala03\n'
    printf 'classification: expected-refusal-fortad-external-mpi-update-rules\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_flags: %s\n' "${strict[*]}"
    printf 'legacy_flags: %s\n' "${legacy[*]}"
    printf 'mpi_include: %s\n' "$mpi_include"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_entry_point: wave_resolution(id,p,n_global,n_local,nsteps,c,u_global)\n'
    printf 'tapenade_options: Options=-head wave_resolution(u_global)/(c) -noisize -I ../ADFirstAidKit/mpich/include/; fresh=explicit-head-noisize-with-pinned-support-and-mpi-includes\n'
    printf 'exact_compile: program=%s/%s stored_d=%s/%s stored_b=%s/%s (strict/legacy)\n' \
        "$(status exact-strict-program)" "$(status exact-legacy-program)" \
        "$(status stored-d-strict)" "$(status stored-d-legacy)" \
        "$(status stored-b-strict)" "$(status stored-b-legacy)"
    printf 'exact_diagnostics: program=strict-REAL8-INTEGER4-MPI-mismatch stored_b=strict-INTEGER4\n'
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(status tapenade-parser)" "$(status tapenade-forward)" "$(status tapenade-reverse)"
    printf 'tapenade_fresh_compile: parser=%s/%s forward=%s/%s reverse=%s/%s (strict/legacy)\n' \
        "$(status fresh-parser-strict)" "$(status fresh-parser-legacy)" \
        "$(status fresh-forward-strict)" "$(status fresh-forward-legacy)" \
        "$(status fresh-reverse-strict)" "$(status fresh-reverse-legacy)"
    printf 'tapenade_fresh_diagnostics: parser=strict-REAL8-INTEGER4-MPI-mismatch reverse=strict-INTEGER4\n'
    printf 'fortad_exact_behavior: check=%s output=pass forward=%s reverse=%s diagnostics=external-update-derivative-rules-no-output\n' \
        "$(status fortad-check)" "$(status fortad-forward)" "$(status fortad-reverse)"
    printf 'independent_oracle: serial-p1-primal wave-jvp-central-difference wave-vjp-dot-product\n'
    printf '%s\n' "$oracle_output"
    printf 'no_repaired_port: true\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/program.f \
        "$source_rel"/program_d.f "$source_rel"/program_d.msg \
        "$source_rel"/program_b.f "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/ala03_p.f parser/ala03_p.msg \
        forward/ala03_d.f forward/ala03_d.msg reverse/ala03_b.f reverse/ala03_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
