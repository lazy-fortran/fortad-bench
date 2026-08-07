#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
fortad_checkout=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
if test ! -e "$fortad_checkout/.git" && test -e /mnt/storage/code/lazy-fortran/fortad/.git; then
    fortad_checkout=/mnt/storage/code/lazy-fortran/fortad
fi
if test ! -e "$tapenade_repo/.git" && test -e /mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade/.git; then
    tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi
fortad_checkout=$(cd "$fortad_checkout" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_dir="$tapenade_repo/todoF90/REFERENCES/v100"
fortad="$fortad_checkout/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
result="$case_dir/result.txt"

test -e "$fortad_checkout/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_checkout" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_checkout" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -x "$fortad"
test -x "$tapenade"
for source in program.f90 program_Rd.f90 program_Rb.f90 program_Rd.msg program_Rb.msg Options; do
    test -e "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/fortad-bench-todof90-v100.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/exact/parser/mod" "$out/exact/primal_mod" \
    "$out/exact/tangent_mod" "$out/exact/reverse_mod" "$out/fresh/parser/mod" \
    "$out/fresh/forward/mod" "$out/fresh/reverse/mod" "$out/bounded/mod"

strict_flags=(
    -std=f2018
    -ffree-form
    -ffree-line-length-none
    -pedantic-errors
    -Wall
    -Wextra
    -Wimplicit-interface
    -cpp
)

compile_strict() {
    local label=$1
    local source=$2
    local moddir=$3
    local status=0
    (cd "$out" && "$fc" "${strict_flags[@]}" -I"$source_dir" -J"$moddir" \
        -c "$source" -o "$out/$label.o") >"$out/$label.stdout" \
        2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

generate_tapenade() {
    local label=$1
    local mode=$2
    local output_dir=$3
    local status=0
    (cd "$output_dir" && "$tapenade" "$mode" -root head -O . -o v100 \
        "$source_dir/program.f90") >"$out/$label-generation.stdout" \
        2>"$out/$label-generation.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label-generation.status"
}

run_fortad() {
    local label=$1
    shift
    local status=0
    "$fortad" "$@" >"$out/fortad-$label.stdout" \
        2>"$out/fortad-$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/fortad-$label.status"
}

compile_strict exact_primal "$source_dir/program.f90" "$out/exact/primal_mod"
compile_strict stored_tangent "$source_dir/program_Rd.f90" "$out/exact/tangent_mod"
compile_strict stored_reverse "$source_dir/program_Rb.f90" "$out/exact/reverse_mod"

generate_tapenade parser -p "$out/fresh/parser"
generate_tapenade tangent -d "$out/fresh/forward"
generate_tapenade reverse -b "$out/fresh/reverse"
for file in v100_p.f90 v100_p.msg; do test -e "$out/fresh/parser/$file"; done
for file in v100_d.f90 v100_d.msg; do test -e "$out/fresh/forward/$file"; done
for file in v100_b.f90 v100_b.msg; do test -e "$out/fresh/reverse/$file"; done
compile_strict fresh_parser "$out/fresh/parser/v100_p.f90" "$out/fresh/parser/mod"
compile_strict fresh_tangent "$out/fresh/forward/v100_d.f90" "$out/fresh/forward/mod"
compile_strict fresh_reverse "$out/fresh/reverse/v100_b.f90" "$out/fresh/reverse/mod"

run_fortad parser check --proc head -o "$out/exact/parser.f90" \
    "$source_dir/program.f90"
compile_strict exact_parser "$out/exact/parser.f90" "$out/exact/parser/mod"
run_fortad forward --mode forward --indep x --proc head --name v100_forward \
    --module v100_forward_mod --output "$out/exact/forward.f90" \
    "$source_dir/program.f90"
run_fortad reverse --mode reverse --indep x --dep y --proc head \
    --name v100_reverse --module v100_reverse_mod \
    --output "$out/exact/reverse.f90" "$source_dir/program.f90"
test "$(<"$out/fortad-parser.status")" -eq 0
test -s "$out/exact/parser.f90"
test "$(<"$out/exact_parser.status")" -eq 0
test "$(<"$out/fortad-forward.status")" -ne 0
test "$(<"$out/fortad-reverse.status")" -ne 0
test ! -e "$out/exact/forward.f90"
test ! -e "$out/exact/reverse.f90"
grep -Fq "no derivative rule for 'mod'" "$out/fortad-forward.stderr"
grep -Fq "no derivative rule for 'mod'" "$out/fortad-reverse.stderr"

"$fortad" --mode forward --indep x_in --proc head_v100_port \
    --name head_v100_forward --module v100_forward_mod \
    --output "$out/bounded/forward.f90" "$case_dir/port.f90" \
    >"$out/bounded-forward.stdout" 2>"$out/bounded-forward.stderr"
"$fortad" --mode reverse --indep x_in --dep y --proc head_v100_port \
    --name head_v100_reverse --module v100_reverse_mod \
    --output "$out/bounded/reverse.f90" "$case_dir/port.f90" \
    >"$out/bounded-reverse.stdout" 2>"$out/bounded-reverse.stderr"
test -s "$out/bounded/forward.f90"
test -s "$out/bounded/reverse.f90"
compile_strict bounded_port "$case_dir/port.f90" "$out/bounded/mod"
compile_strict bounded_hand "$case_dir/hand.f90" "$out/bounded/mod"
compile_strict bounded_forward "$out/bounded/forward.f90" "$out/bounded/mod"
compile_strict bounded_reverse "$out/bounded/reverse.f90" "$out/bounded/mod"
test "$(<"$out/bounded_port.status")" -eq 0
test "$(<"$out/bounded_hand.status")" -eq 0
test "$(<"$out/bounded_forward.status")" -eq 0
test "$(<"$out/bounded_reverse.status")" -eq 0

"$fc" "${strict_flags[@]}" -J"$out/bounded/mod" -I"$out/bounded/mod" \
    -c "$case_dir/harness.f90" -o "$out/bounded/harness.o" \
    >"$out/bounded-harness.stdout" 2>"$out/bounded-harness.stderr"
"$fc" "${strict_flags[@]}" -J"$out/bounded/mod" -I"$out/bounded/mod" \
    -o "$out/bounded/harness" "$out/bounded_port.o" \
    "$out/bounded_hand.o" "$out/bounded_forward.o" \
    "$out/bounded_reverse.o" "$out/bounded/harness.o" \
    >"$out/bounded-link.stdout" 2>"$out/bounded-link.stderr"
"$out/bounded/harness" >"$out/bounded-harness.run"
grep -Fq 'harness_status: pass' "$out/bounded-harness.run"
oracle_output=$(python3 "$case_dir/oracle.py")
grep -Fq 'oracle_status: pass' <<<"$oracle_output"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
fresh_reverse_diagnostic=$(grep -F 'Warning:' "$out/fresh_reverse.stderr" | head -1 || true)
{
    printf 'case: Tapenade todoF90/REFERENCES/v100\n'
    printf 'classification: expected-refusal-with-bounded-forward-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_checkout" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: head(x,y)\n'
    printf 'bounded_entry_point: head_v100_port(x_in,x_out,y); independent: x_in; dependent: y; domain: 0.2 < x_in(1) < 0.4\n'
    printf 'upstream_exact_strict_compile: primal=%s stored_tangent=%s stored_reverse=%s\n' \
        "$(<"$out/exact_primal.status")" "$(<"$out/stored_tangent.status")" \
        "$(<"$out/stored_reverse.status")"
    printf 'upstream_primal_diagnostic: %s\n' "$(grep -F 'Error:' "$out/exact_primal.stderr" | head -1)"
    printf 'tapenade_options: parser=-p/-root head tangent=-d/-root head reverse=-b/-root head\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(<"$out/parser-generation.status")" "$(<"$out/tangent-generation.status")" \
        "$(<"$out/reverse-generation.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(<"$out/fresh_parser.status")" "$(<"$out/fresh_tangent.status")" \
        "$(<"$out/fresh_reverse.status")"
    printf 'tapenade_fresh_reverse_diagnostic: %s\n' "$fresh_reverse_diagnostic"
    printf 'fortad_exact_parser: transform=%s strict_compile=%s output=present\n' \
        "$(<"$out/fortad-parser.status")" "$(<"$out/exact_parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s output=none diagnostic="no derivative rule for mod"\n' \
        "$(<"$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s output=none diagnostic="no derivative rule for mod"\n' \
        "$(<"$out/fortad-reverse.status")"
    printf 'fortad_bounded_forward: transform=0 compile=%s runtime=pass\n' \
        "$(<"$out/bounded_forward.status")"
    printf 'fortad_bounded_reverse: transform=0 compile=%s runtime=pass\n' \
        "$(<"$out/bounded_reverse.status")"
    printf 'bounded_port_compile: %s hand_compile: %s harness_compile: 0\n' \
        "$(<"$out/bounded_port.status")" "$(<"$out/bounded_hand.status")"
    printf '%s\n' "$oracle_output"
    cat "$out/bounded-harness.run"
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum \
        todoF90/REFERENCES/v100/program.f90 \
        todoF90/REFERENCES/v100/program_Rd.f90 \
        todoF90/REFERENCES/v100/program_Rb.f90 \
        todoF90/REFERENCES/v100/program_Rd.msg \
        todoF90/REFERENCES/v100/program_Rb.msg \
        todoF90/REFERENCES/v100/Options)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum v100_p.f90 v100_p.msg)
    (cd "$out/fresh/forward" && sha256sum v100_d.f90 v100_d.msg)
    (cd "$out/fresh/reverse" && sha256sum v100_b.f90 v100_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md run.sh test_contract.py \
        port.f90 hand.f90 harness.f90 oracle.py)
} >"$result"
cat "$result"
