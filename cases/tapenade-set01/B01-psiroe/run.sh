#!/usr/bin/env bash
set -eu

case_dir=$(cd "$(dirname "$0")" && pwd)
bench_root=$(cd "$case_dir/../../.." && pwd)
source_dir="$bench_root/upstream/tapenade/nonRegressions/set01/B01"
tapenade_repo="$bench_root/upstream/tapenade"
tapenade="$tapenade_repo/bin/tapenade"
fortad="/home/ert/code/lazy-fortran/fortad/build/fo/bin/fortad"
fc=gfortran
source_file="$source_dir/program.f"
out=$(mktemp -d /tmp/fortad-tapenade-B01-psiroe.XXXXXX)
result="$case_dir/result.txt"

strict_flags="-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fsyntax-only -fno-lto"
legacy_flags="-std=legacy -ffixed-form -ffixed-line-length-none -Wall -Wextra -Wimplicit-interface -fsyntax-only -fno-lto"

fail() {
    echo "B01-psiroe runner: $*" >&2
    exit 1
}

require_file() {
    [ -f "$1" ] || fail "missing required file: $1"
}

require_file "$source_file"
require_file "$source_dir/program_d.f"
require_file "$source_dir/program_b.f"
require_file "$source_dir/program_d.msg"
require_file "$source_dir/program_b.msg"
require_file "$source_dir/Param3D.h"
require_file "$source_dir/Paramopt3D.h"
require_file "$source_dir/Paramopt3D_d.h"
require_file "$source_dir/Paramopt3D_b.h"
require_file "$tapenade"
require_file "$fortad"
[ ! -e "$source_dir/program_p.f" ] || fail "unexpected stored parser reference"
[ ! -e "$source_dir/program_p.msg" ] || fail "unexpected stored parser message"

compile_gate() {
    flags=$1
    input=$2
    log=$3
    if $fc $flags -I"$source_dir" "$input" >"$log" 2>&1; then
        printf '0'
    else
        printf '%s' "$?"
    fi
}

check_status() {
    actual=$1
    expected=$2
    label=$3
    [ "$actual" = "$expected" ] || fail "$label returned $actual, expected $expected"
}

check_real8() {
    grep -Eiq 'real[[:space:]]*\*[[:space:]]*8|real\*8' "$1" || fail "missing REAL*8 diagnostic in $1"
}

program_strict=$(compile_gate "$strict_flags" "$source_dir/program.f" "$out/program-strict.log")
program_legacy=$(compile_gate "$legacy_flags" "$source_dir/program.f" "$out/program-legacy.log")
program_d_strict=$(compile_gate "$strict_flags" "$source_dir/program_d.f" "$out/program-d-strict.log")
program_d_legacy=$(compile_gate "$legacy_flags" "$source_dir/program_d.f" "$out/program-d-legacy.log")
program_b_strict=$(compile_gate "$strict_flags" "$source_dir/program_b.f" "$out/program-b-strict.log")
program_b_legacy=$(compile_gate "$legacy_flags" "$source_dir/program_b.f" "$out/program-b-legacy.log")
check_status "$program_strict" 1 "exact program strict gate"
check_status "$program_legacy" 0 "exact program legacy gate"
check_status "$program_d_strict" 1 "stored forward strict gate"
check_status "$program_d_legacy" 0 "stored forward legacy gate"
check_status "$program_b_strict" 1 "stored reverse strict gate"
check_status "$program_b_legacy" 0 "stored reverse legacy gate"
check_real8 "$out/program-strict.log"
check_real8 "$out/program-d-strict.log"
check_real8 "$out/program-b-strict.log"

run_tapenade() {
    mode=$1
    output_dir="$out/tapenade/$mode"
    mkdir -p "$output_dir"
    if "$tapenade" "$mode" -root psiroe -O "$output_dir" -o B01 "$source_file" >"$output_dir/command.log" 2>&1; then
        printf '0'
    else
        printf '%s' "$?"
    fi
}

tapenade_p=$(run_tapenade -p)
tapenade_d=$(run_tapenade -d)
tapenade_b=$(run_tapenade -b)
check_status "$tapenade_p" 0 "fresh Tapenade parser"
check_status "$tapenade_d" 0 "fresh Tapenade forward"
check_status "$tapenade_b" 0 "fresh Tapenade reverse"
require_file "$out/tapenade/-p/B01_p.f"
require_file "$out/tapenade/-p/B01_p.msg"
require_file "$out/tapenade/-d/B01_d.f"
require_file "$out/tapenade/-d/B01_d.msg"
require_file "$out/tapenade/-d/Paramopt3D_d.h"
require_file "$out/tapenade/-b/B01_b.f"
require_file "$out/tapenade/-b/B01_b.msg"
require_file "$out/tapenade/-b/Paramopt3D_b.h"

fresh_p_strict=$(compile_gate "$strict_flags" "$out/tapenade/-p/B01_p.f" "$out/fresh-p-strict.log")
fresh_p_legacy=$(compile_gate "$legacy_flags" "$out/tapenade/-p/B01_p.f" "$out/fresh-p-legacy.log")
fresh_d_strict=$(compile_gate "$strict_flags" "$out/tapenade/-d/B01_d.f" "$out/fresh-d-strict.log")
fresh_d_legacy=$(compile_gate "$legacy_flags" "$out/tapenade/-d/B01_d.f" "$out/fresh-d-legacy.log")
fresh_b_strict=$(compile_gate "$strict_flags" "$out/tapenade/-b/B01_b.f" "$out/fresh-b-strict.log")
fresh_b_legacy=$(compile_gate "$legacy_flags" "$out/tapenade/-b/B01_b.f" "$out/fresh-b-legacy.log")
check_status "$fresh_p_strict" 1 "fresh parser strict gate"
check_status "$fresh_p_legacy" 0 "fresh parser legacy gate"
check_status "$fresh_d_strict" 1 "fresh forward strict gate"
check_status "$fresh_d_legacy" 0 "fresh forward legacy gate"
check_status "$fresh_b_strict" 1 "fresh reverse strict gate"
check_status "$fresh_b_legacy" 0 "fresh reverse legacy gate"
check_real8 "$out/fresh-p-strict.log"
check_real8 "$out/fresh-d-strict.log"
check_real8 "$out/fresh-b-strict.log"

run_fortad() {
    mode=$1
    output_dir="$out/fortad/$mode"
    mkdir -p "$output_dir"
    if "$fortad" "$mode" -root psiroe -O "$output_dir" -o B01 "$source_file" >"$output_dir/command.log" 2>&1; then
        printf '0'
    else
        printf '%s' "$?"
    fi
}

fortad_p=$(run_fortad -p)
fortad_d=$(run_fortad -d)
fortad_b=$(run_fortad -b)
check_status "$fortad_p" 1 "FortAD parser refusal"
check_status "$fortad_d" 2 "FortAD forward refusal"
check_status "$fortad_b" 2 "FortAD reverse refusal"
for mode in -p -d -b; do
    grep -Fq 'could not locate the end of this do construct' "$out/fortad/$mode/command.log" \
        || fail "missing labeled-DO diagnostic for FortAD $mode"
    [ -z "$(find "$out/fortad/$mode" -type f ! -name command.log -print -quit)" ] \
        || fail "FortAD $mode emitted an output file"
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_file")
printf '%s\n' "$oracle_output" | grep -Fq 'oracle_status: pass' \
    || fail "independent behavioral oracle failed"

{
    echo "classification: expected-refusal-fortad-unsupported-labeled-do-line-116"
    echo "entry_point: psiroe(ctrl,ctrlno)"
    echo "upstream_revision: $(git -C "$tapenade_repo" rev-parse HEAD)"
    echo "fortad_revision: $(git -C /home/ert/code/lazy-fortran/fortad rev-parse HEAD)"
    echo "source: $source_file"
    echo "source_form: fixed"
    echo "tapenade_commands:"
    echo "  - tapenade -p -root psiroe -O OUT -o B01 program.f: status $tapenade_p; B01_p.f/B01_p.msg generated"
    echo "  - tapenade -d -root psiroe -O OUT -o B01 program.f: status $tapenade_d; B01_d.f/B01_d.msg generated"
    echo "  - tapenade -b -root psiroe -O OUT -o B01 program.f: status $tapenade_b; B01_b.f/B01_b.msg generated"
    echo "fortad_commands:"
    echo "  - fortad -p -root psiroe -O OUT -o B01 program.f: status $fortad_p; refusal at line 116"
    echo "  - fortad -d -root psiroe -O OUT -o B01 program.f: status $fortad_d; refusal at line 116"
    echo "  - fortad -b -root psiroe -O OUT -o B01 program.f: status $fortad_b; refusal at line 116"
    echo "strict_flags: $strict_flags"
    echo "legacy_flags: $legacy_flags"
    echo "exact_compile_status: program.f strict=$program_strict legacy=$program_legacy; program_d.f strict=$program_d_strict legacy=$program_d_legacy; program_b.f strict=$program_b_strict legacy=$program_b_legacy"
    echo "fresh_compile_status: B01_p.f strict=$fresh_p_strict legacy=$fresh_p_legacy; B01_d.f strict=$fresh_d_strict legacy=$fresh_d_legacy; B01_b.f strict=$fresh_b_strict legacy=$fresh_b_legacy"
    echo "fortad_status: -p=$fortad_p -d=$fortad_d -b=$fortad_b"
    echo "fortad_diagnostic: could not locate the end of this do construct at source line 116"
    echo "oracle:"
    printf '%s\n' "$oracle_output"
    echo "upstream_sha256:"
    (cd "$source_dir" && sha256sum Param3D.h Paramopt3D.h Paramopt3D_b.h Paramopt3D_d.h program.f program_b.f program_b.msg program_d.f program_d.msg)
} >"$result"

echo "B01-psiroe runner: pass ($result)"
