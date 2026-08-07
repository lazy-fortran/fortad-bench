#!/usr/bin/env bash
# Validate the pinned Tapenade todoF90/REFERENCES/bd11 boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_checkout=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
if test ! -e "$fortad_checkout/.git" && test -e /home/ert/code/lazy-fortran/fortad/.git; then
    fortad_checkout=/home/ert/code/lazy-fortran/fortad
fi
if test ! -e "$tapenade_repo/.git" && test -e /mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade/.git; then
    tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi
fortad_checkout=$(cd "$fortad_checkout" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
free_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface)
source_dir="$tapenade_repo/todoF90/REFERENCES/bd11"
out=$(mktemp -d /var/tmp/fortad-bench-bd11.XXXXXX)
trap 'rm -rf "$out"' EXIT

command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_checkout/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_checkout" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_checkout" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
fortad_worktree=clean-and-pinned
tapenade_worktree=clean-and-pinned

for source in program.f90 Options; do
    test -s "$source_dir/$source"
done
test -x "$tapenade_repo/bin/tapenade"

mkdir -p "$out/mod" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse" "$out/exact" "$out/port"

compile_source() {
    local source=$1 label=$2
    set +e
    "$fc" "${free_flags[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
        -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

run_tapenade() {
    local mode=$1
    shift
    local output_mode=$mode
    if test "$mode" = tangent; then
        output_mode=forward
    fi
    set +e
    (cd "$tapenade_repo" && "$tapenade_repo/bin/tapenade" "$@" \
        -O "$out/tapenade/$output_mode" -o bd11 "$source_dir/program.f90") \
        >"$out/tapenade-$mode.stdout" 2>"$out/tapenade-$mode.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/tapenade-$mode.status"
}

fortad_exec() {
    local label=$1
    shift
    set +e
    (cd "$fortad_checkout" && fo exec --no-build fortad "$@") \
        >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_source "$source_dir/program.f90" upstream_program
test "$(cat "$out/upstream_program.status")" -eq 0

run_tapenade parser -p -nolib -ext REFERENCES/lh09/NoInlineABS
run_tapenade tangent -d -root top -nolib -ext REFERENCES/lh09/NoInlineABS
run_tapenade reverse -b -root top -nolib -ext REFERENCES/lh09/NoInlineABS
for mode in parser tangent reverse; do
    test "$(cat "$out/tapenade-$mode.status")" -eq 0
done
for generated in \
    "$out/tapenade/parser/bd11_p.f90" \
    "$out/tapenade/forward/bd11_d.f90" \
    "$out/tapenade/reverse/bd11_b.f90"; do
    test -s "$generated"
done
compile_source "$out/tapenade/parser/bd11_p.f90" fresh_parser
compile_source "$out/tapenade/forward/bd11_d.f90" fresh_tangent
compile_source "$out/tapenade/reverse/bd11_b.f90" fresh_reverse
for label in fresh_parser fresh_tangent fresh_reverse; do
    test "$(cat "$out/$label.status")" -eq 0
done

fortad_exec exact_parser check --proc top --output "$out/exact/parser.f90" \
    "$source_dir/program.f90"
fortad_exec exact_forward --mode forward --indep i1,i2,i3 --proc top \
    --name bd11_exact_jvp --module bd11_exact_forward_ad \
    --output "$out/exact/forward.f90" "$source_dir/program.f90"
fortad_exec exact_reverse --mode reverse --indep i1,i2,i3 --dep i1 \
    --proc top --name bd11_exact_vjp --module bd11_exact_reverse_ad \
    --output "$out/exact/reverse.f90" "$source_dir/program.f90"
for label in exact_parser exact_forward exact_reverse; do
    test "$(cat "$out/$label.status")" -ne 0
done
for output in "$out/exact/parser.f90" "$out/exact/forward.f90" \
    "$out/exact/reverse.f90"; do
    test ! -e "$output"
done
for label in exact_parser exact_forward exact_reverse; do
    grep -Fq 'fortad: unsupported array section at line 6: noncontiguous and overlapping storage identity is not tracked' \
        "$out/$label.stderr"
done

fortad_exec bounded_forward --mode forward --indep i1,i2,i3 --proc top_bd11 \
    --name bd11_jvp --module bd11_forward_ad \
    --output "$out/port/forward.f90" "$case_dir/port.f90"
fortad_exec bounded_reverse --mode reverse --indep i1,i2,i3 --dep objective \
    --proc top_bd11 --name bd11_vjp --module bd11_reverse_ad \
    --output "$out/port/reverse.f90" "$case_dir/port.f90"
test "$(cat "$out/bounded_forward.status")" -eq 0
test "$(cat "$out/bounded_reverse.status")" -eq 0
test -s "$out/port/forward.f90"
test -s "$out/port/reverse.f90"

compile_source "$case_dir/port.f90" bounded_port
compile_source "$case_dir/hand.f90" bounded_hand
compile_source "$out/port/forward.f90" bounded_forward_generated
compile_source "$out/port/reverse.f90" bounded_reverse_generated
compile_source "$case_dir/harness.f90" harness
for label in bounded_port bounded_hand bounded_forward_generated \
    bounded_reverse_generated harness; do
    test "$(cat "$out/$label.status")" -eq 0
done
"$fc" "${free_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/harness" \
    "$out/bounded_port.o" "$out/bounded_hand.o" \
    "$out/bounded_forward_generated.o" "$out/bounded_reverse_generated.o" \
    "$out/harness.o" >"$out/link.stdout" 2>"$out/link.stderr"
"$out/harness" >"$out/harness.run"
grep -Fq 'harness_status: pass' "$out/harness.run"
oracle_output=$(python3 "$case_dir/oracle.py")
grep -Fq 'oracle_status: pass' <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES bd11\n'
    printf 'classification: expected-refusal-with-bounded-array-section-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_free_flags: %s\n' "${free_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_checkout" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: %s\n' "$fortad_worktree"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'tapenade_worktree: %s\n' "$tapenade_worktree"
    printf 'upstream_entry_point: top(i1,i2,i3)\n'
    printf 'upstream_exact_strict_compile: program.f90=%s\n' "$(cat "$out/upstream_program.status")"
    printf 'stored_references: none\n'
    printf 'tapenade_options: -nolib -ext REFERENCES/lh09/NoInlineABS\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" \
        "$(cat "$out/tapenade-tangent.status")" \
        "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_fresh_outputs: parser=bd11_p.f90 tangent=bd11_d.f90 reverse=bd11_b.f90\n'
    printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
        "$(cat "$out/fresh_parser.status")" \
        "$(cat "$out/fresh_tangent.status")" \
        "$(cat "$out/fresh_reverse.status")"
    printf 'tapenade_generation_diagnostics:\n'
    for mode in parser tangent reverse; do
        printf '%s:\n' "$mode"
        sed 's/[[:space:]]*$//' "$out/tapenade-$mode.stdout"
        sed 's/[[:space:]]*$//' "$out/tapenade-$mode.stderr"
    done
    for label in exact_parser exact_forward exact_reverse; do
        printf 'fortad_%s: expected-refusal status=%s diagnostic="%s"\n' \
            "$label" "$(cat "$out/$label.status")" \
            "$(grep -F 'fortad: unsupported array section' "$out/$label.stderr" | tail -1)"
    done
    printf 'fortad_bounded_forward: transform=%s compile=%s runtime=pass\n' \
        "$(cat "$out/bounded_forward.status")" \
        "$(cat "$out/bounded_forward_generated.status")"
    printf 'fortad_bounded_reverse_objective: transform=%s compile=%s runtime=pass\n' \
        "$(cat "$out/bounded_reverse.status")" \
        "$(cat "$out/bounded_reverse_generated.status")"
    printf 'bounded_port_compile: port=%s hand=%s harness=%s link=0\n' \
        "$(cat "$out/bounded_port.status")" \
        "$(cat "$out/bounded_hand.status")" \
        "$(cat "$out/harness.status")"
    cat "$out/harness.run"
    printf 'independent_oracle: hand JVP, central-difference sweep, and adjoint identity\n'
    printf '%s\n' "$oracle_output"
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum Options program.f90)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/tapenade/parser" && sha256sum bd11_p.f90 bd11_p.msg)
    (cd "$out/tapenade/forward" && sha256sum bd11_d.f90 bd11_d.msg)
    (cd "$out/tapenade/reverse" && sha256sum bd11_b.f90 bd11_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/bd11/manifest.toml \
        cases/tapenade-set01/bd11/notes.md cases/tapenade-set01/bd11/port.f90 \
        cases/tapenade-set01/bd11/hand.f90 cases/tapenade-set01/bd11/oracle.py \
        cases/tapenade-set01/bd11/harness.f90 cases/tapenade-set01/bd11/run.sh \
        cases/tapenade-set01/bd11/test_contract.py)
} >"$result"
cat "$result"
