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
source_dir="$tapenade_repo/todoF90/REFERENCES/bd01"
out=$(mktemp -d /var/tmp/fortad-bench-bd01.XXXXXX)
trap 'rm -rf "$out"' EXIT

fixed_free_flags=(-std=f2018 -ffree-form -pedantic-errors -Wall -Wextra
    -Wimplicit-interface -cpp -Wno-error=tabs)
command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
command -v fo >/dev/null
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

for source in program.f90 tata.f90 Options; do
    test -s "$source_dir/$source"
done
mkdir -p "$out/upstream-mod" "$out/tapenade" "$out/exact" "$out/bounded-mod"

compile_status() {
    local label=$1
    local source=$2
    local module_dir=$3
    local status
    mkdir -p "$module_dir"
    if "$fc" "${fixed_free_flags[@]}" -I"$tapenade_repo" -I"$source_dir" \
        -I"$module_dir" -J"$module_dir" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_status upstream_tata "$source_dir/tata.f90" "$out/upstream-mod"
compile_status upstream_program "$source_dir/program.f90" "$out/upstream-mod"
test "$(<"$out/upstream_tata.status")" -eq 0
test "$(<"$out/upstream_program.status")" -eq 0

generate_tapenade() {
    local label=$1
    local mode_flag=$2
    local mode=${mode_flag#-}
    local output_dir="$out/tapenade/$mode"
    local status
    mkdir -p "$output_dir"
    if (cd "$output_dir" && "$tapenade" "$mode_flag" -root titi -O . -o bd01 \
        "$source_dir/program.f90" "$source_dir/tata.f90") \
        >"$out/$label.stdout" 2>"$out/$label.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/$label.status"
}

generate_tapenade fresh_parser -p
generate_tapenade fresh_tangent -d
generate_tapenade fresh_reverse -b
for mode in p d b; do
    test -s "$out/tapenade/$mode/bd01_${mode}.f90"
    compile_status "fresh_${mode}" "$out/tapenade/$mode/bd01_${mode}.f90" \
        "$out/fresh-${mode}-mod"
    test "$(<"$out/fresh_${mode}.status")" -eq 0
done

fortad_run() {
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

fortad_run exact_titi_parser check --proc titi \
    --output "$out/exact/titi_check.f90" "$source_dir/program.f90"
fortad_run exact_toto_parser check --proc toto \
    --output "$out/exact/toto_check.f90" "$source_dir/tata.f90"
compile_status exact_titi_parser "$out/exact/titi_check.f90" "$out/upstream-mod"
compile_status exact_toto_parser "$out/exact/toto_check.f90" "$out/upstream-mod"
test "$(<"$out/exact_titi_parser.status")" -eq 0
test "$(<"$out/exact_toto_parser.status")" -eq 0
test "$(<"$out/exact_titi_parser.status")" -eq 0

fortad_run exact_titi_forward --mode forward --indep a,b,c --proc titi \
    --name bd01_titi_forward --module bd01_titi_forward_mod \
    --output "$out/exact/titi_forward.f90" "$source_dir/program.f90"
fortad_run exact_titi_reverse --mode reverse --indep b,c --dep a --proc titi \
    --name bd01_titi_reverse --module bd01_titi_reverse_mod \
    --output "$out/exact/titi_reverse.f90" "$source_dir/program.f90"
test "$(<"$out/exact_titi_forward.status")" -ne 0
test "$(<"$out/exact_titi_reverse.status")" -ne 0
test ! -e "$out/exact/titi_forward.f90"
test ! -e "$out/exact/titi_reverse.f90"
grep -Fq "no derivative rule for the call to 'TOTO'" "$out/exact_titi_forward.stderr"
grep -Fq "no reverse rule for the call to 'TOTO'" "$out/exact_titi_reverse.stderr"

fortad_run exact_toto_forward --mode forward --indep a,b,c --proc toto \
    --name bd01_toto_forward --module bd01_toto_forward_mod \
    --output "$out/exact/toto_forward.f90" "$source_dir/tata.f90"
fortad_run exact_toto_reverse --mode reverse --indep b,c --dep a --proc toto \
    --name bd01_toto_reverse --module bd01_toto_reverse_mod \
    --output "$out/exact/toto_reverse.f90" "$source_dir/tata.f90"
test "$(<"$out/exact_toto_forward.status")" -eq 0
test "$(<"$out/exact_toto_reverse.status")" -eq 0
compile_status exact_toto_forward "$out/exact/toto_forward.f90" "$out/exact-toto-mod"
compile_status exact_toto_reverse "$out/exact/toto_reverse.f90" "$out/exact-toto-mod"
test "$(<"$out/exact_toto_forward.status")" -eq 0
test "$(<"$out/exact_toto_reverse.status")" -eq 0

fortad_run bounded_forward --mode forward --indep a,b,c --proc set01_bd01 \
    --name bd01_forward --module bd01_forward_mod \
    --output "$out/bounded-forward.f90" "$case_dir/port.f90"
fortad_run bounded_reverse --mode reverse --indep b,c --dep a --proc set01_bd01 \
    --name bd01_reverse --module bd01_reverse_mod \
    --output "$out/bounded-reverse.f90" "$case_dir/port.f90"
test "$(<"$out/bounded_forward.status")" -eq 0
test "$(<"$out/bounded_reverse.status")" -eq 0
compile_status bounded_port "$case_dir/port.f90" "$out/bounded-mod"
compile_status bounded_hand "$case_dir/hand.f90" "$out/bounded-mod"
compile_status bounded_forward "$out/bounded-forward.f90" "$out/bounded-mod"
compile_status bounded_reverse "$out/bounded-reverse.f90" "$out/bounded-mod"
compile_status bounded_harness "$case_dir/harness.f90" "$out/bounded-mod"
for label in bounded_port bounded_hand bounded_forward bounded_reverse bounded_harness; do
    test "$(<"$out/$label.status")" -eq 0
done
"$fc" -o "$out/bd01-harness" "$out/bounded_port.o" "$out/bounded_hand.o" \
    "$out/bounded_forward.o" "$out/bounded_reverse.o" "$out/bounded_harness.o" \
    >"$out/link.stdout" 2>"$out/link.stderr"
"$out/bd01-harness" >"$out/harness.stdout"
grep -Fqx 'harness_status: pass' "$out/harness.stdout"
python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fqx 'oracle_status: pass' "$out/oracle.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES bd01\n'
    printf 'classification: expected-refusal-with-bounded-module-call-specialization\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_free_flags: %s\n' "${fixed_free_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_exact_strict_compile: tata=%s program=%s\n' \
        "$(<"$out/upstream_tata.status")" "$(<"$out/upstream_program.status")"
    printf 'upstream_compile_diagnostic_policy: leading-tabs-warning-not-error\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(<"$out/fresh_parser.status")" "$(<"$out/fresh_tangent.status")" \
        "$(<"$out/fresh_reverse.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(<"$out/fresh_p.status")" "$(<"$out/fresh_d.status")" \
        "$(<"$out/fresh_b.status")"
    printf 'fortad_exact_parser: titi=%s compile=%s toto=%s compile=%s\n' \
        "$(<"$out/exact_titi_parser.status")" "$(<"$out/exact_titi_parser.status")" \
        "$(<"$out/exact_toto_parser.status")" "$(<"$out/exact_toto_parser.status")"
    printf 'fortad_exact_titi_forward: expected-refusal status=%s output=none diagnostic="no derivative rule for the call to TOTO"\n' \
        "$(<"$out/exact_titi_forward.status")"
    printf 'fortad_exact_titi_reverse: expected-refusal status=%s output=none diagnostic="no reverse rule for the call to TOTO"\n' \
        "$(<"$out/exact_titi_reverse.status")"
    printf 'fortad_exact_toto_forward: transform=%s compile=%s\n' \
        "$(<"$out/exact_toto_forward.status")" "$(<"$out/exact_toto_forward.status")"
    printf 'fortad_exact_toto_reverse: transform=%s compile=%s\n' \
        "$(<"$out/exact_toto_reverse.status")" "$(<"$out/exact_toto_reverse.status")"
    printf 'fortad_bounded_forward: transform=%s compile=%s\n' \
        "$(<"$out/bounded_forward.status")" "$(<"$out/bounded_forward.status")"
    printf 'fortad_bounded_reverse: transform=%s compile=%s\n' \
        "$(<"$out/bounded_reverse.status")" "$(<"$out/bounded_reverse.status")"
    printf 'bounded_port_compile: port=%s hand=%s harness=%s link=0 runtime=0\n' \
        "$(<"$out/bounded_port.status")" "$(<"$out/bounded_hand.status")" \
        "$(<"$out/bounded_harness.status")"
    printf 'independent_oracle: hand JVP/VJP, central-difference sweep, and adjoint identity\n'
    cat "$out/oracle.txt"
    cat "$out/harness.stdout"
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum \
        todoF90/REFERENCES/bd01/Options \
        todoF90/REFERENCES/bd01/program.f90 \
        todoF90/REFERENCES/bd01/tata.f90)
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$out/tapenade/p/bd01_p.f90" "$out/tapenade/d/bd01_d.f90" \
        "$out/tapenade/b/bd01_b.f90"
    printf 'fortad_exact_toto_sha256:\n'
    sha256sum "$out/exact/toto_forward.f90" "$out/exact/toto_reverse.f90"
    printf 'fortad_bounded_sha256:\n'
    sha256sum "$out/bounded-forward.f90" "$out/bounded-reverse.f90"
} >"$result"
cat "$result"
