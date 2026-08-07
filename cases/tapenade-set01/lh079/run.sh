#!/usr/bin/env bash
# Validate the pinned Tapenade set01/lh079 invalid-source boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
if test ! -e "$fortad_repo/.git" && test -e /home/ert/code/lazy-fortran/fortad/.git; then
    fortad_repo=/home/ert/code/lazy-fortran/fortad
fi
if test ! -e "$tapenade_repo/.git" && test -e /mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade/.git; then
    tapenade_repo=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade
fi
fortad_checkout=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=7adc75030db3fa4422339d82d2725ae29ee13dac
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
fixed_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -cpp)
source_dir="$tapenade_repo/nonRegressions/set01/lh079"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-lh079.XXXXXX)

command -v "$fc" >/dev/null
command -v python3 >/dev/null
test -e "$fortad_checkout/.git"
test -e "$tapenade_repo/.git"
fortad_source_commit=$(git -C "$fortad_checkout" rev-parse HEAD)
fortad_source_dirty=$(git -C "$fortad_checkout" status --porcelain --untracked-files=no)
if test "$fortad_source_commit" != "$required_fortad_commit" || test -n "$fortad_source_dirty"; then
    fortad_clone_parent=$(mktemp -d /var/tmp/fortad-lh079-clean.XXXXXX)
    fortad_repo="$fortad_clone_parent/fortad"
    git clone --shared --quiet "$fortad_checkout" "$fortad_repo"
    for dependency in fortfront fortgen; do
        if test -d "$fortad_checkout/../$dependency"; then
            ln -s "$fortad_checkout/../$dependency" "$fortad_clone_parent/$dependency"
        fi
    done
    git -C "$fortad_repo" checkout --detach --quiet "$required_fortad_commit" || true
    test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
    fortad_worktree="temporary clean checkout pinned to required commit"
else
    fortad_repo="$fortad_checkout"
    fortad_worktree="supplied checkout clean and pinned"
fi
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
fortad="$fortad_repo/build/fo/bin/fortad"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"
for source in program.f program_p.f program_d.f program_b.f program_dv.f; do
    test -s "$source_dir/$source"
done
for message in program_p.msg program_d.msg program_b.msg program_dv.msg; do
    test -f "$source_dir/$message"
done

mkdir -p "$out/mod" "$out/fresh/parser" "$out/fresh/forward" \
    "$out/fresh/reverse" "$out/exact"

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_fixed() {
    local label=$1
    local source=$2
    run_status "$label" "$fc" "${fixed_flags[@]}" -I"$source_dir" \
        -J"$out/mod" -c "$source" -o "$out/$label.o"
}

compile_fixed upstream_primal "$source_dir/program.f"
compile_fixed upstream_parser "$source_dir/program_p.f"
compile_fixed upstream_forward "$source_dir/program_d.f"
compile_fixed upstream_reverse "$source_dir/program_b.f"
compile_fixed upstream_multidirectional "$source_dir/program_dv.f"
test "$(cat "$out/upstream_primal.status")" -ne 0
grep -Fq 'Syntax error in expression' "$out/upstream_primal.stderr"
for label in upstream_parser upstream_forward upstream_reverse; do
    test "$(cat "$out/$label.status")" -eq 0
    test -s "$out/$label.o"
done
test "$(cat "$out/upstream_multidirectional.status")" -ne 0
grep -Fq 'Cannot open included file' "$out/upstream_multidirectional.stderr"

for mode in parser forward reverse; do
    case "$mode" in
        parser) tap_mode=-p; suffix=p ;;
        forward) tap_mode=-d; suffix=d ;;
        reverse) tap_mode=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode-generation" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$tap_mode' -root f -O . -o lh079 '$source_dir/program.f'"
    test "$(cat "$out/tapenade-$mode-generation.status")" -eq 0
    test -s "$out/fresh/$mode/lh079_$suffix.f"
    test -s "$out/fresh/$mode/lh079_$suffix.msg"
    compile_fixed "fresh_$mode" "$out/fresh/$mode/lh079_$suffix.f"
    test "$(cat "$out/fresh_$mode.status")" -eq 0
    test -s "$out/fresh_$mode.o"
done

run_status fortad-parser "$fortad" check --proc f \
    --output "$out/exact/parser.f90" "$source_dir/program.f"
run_status fortad-forward "$fortad" --mode forward --proc f \
    --indep a,ad,b,bd,x --name lh079_forward --module lh079_forward_mod \
    --output "$out/exact/forward.f90" "$source_dir/program.f"
run_status fortad-reverse "$fortad" --mode reverse --proc f \
    --indep a,ad,b,bd,x --dep f --name lh079_reverse --module lh079_reverse_mod \
    --output "$out/exact/reverse.f90" "$source_dir/program.f"
test "$(cat "$out/fortad-parser.status")" -eq 0
test -s "$out/exact/parser.f90"
test "$(cat "$out/fortad-forward.status")" -ne 0
test ! -e "$out/exact/forward.f90"
grep -Fq "fortad: independent 'ad' is not declared in f" "$out/fortad-forward.stderr"
test "$(cat "$out/fortad-reverse.status")" -ne 0
test ! -e "$out/exact/reverse.f90"
grep -Fq "fortad: dependent 'f' is not declared in f" "$out/fortad-reverse.stderr"

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir/program.f")
grep -Fq 'oracle_status: pass interface=f(t,a,ad,b,bd,x)' <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions/set01/lh079\n'
    printf 'classification: unsupported-invalid-upstream-fortran\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${fixed_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'fortad_worktree: %s\n' "$fortad_worktree"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: f(t,a,ad,b,bd,x)\n'
    printf 'independent_inputs: t,a,ad,b,bd,x\n'
    printf 'dependent_outputs: f,b(2),bd(2)\n'
    printf 'upstream_exact_strict_compile: primal=%s parser=%s forward=%s reverse=%s multidirectional=%s\n' \
        "$(cat "$out/upstream_primal.status")" "$(cat "$out/upstream_parser.status")" \
        "$(cat "$out/upstream_forward.status")" "$(cat "$out/upstream_reverse.status")" \
        "$(cat "$out/upstream_multidirectional.status")"
    printf 'upstream_exact_diagnostic: primal=negative-exponent-syntax; multidirectional=missing-DIFFSIZES.inc\n'
    printf 'tapenade_options: parser=-p/-root f forward=-d/-root f reverse=-b/-root f\n'
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser-generation.status")" \
        "$(cat "$out/tapenade-forward-generation.status")" \
        "$(cat "$out/tapenade-reverse-generation.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/fresh_parser.status")" "$(cat "$out/fresh_forward.status")" \
        "$(cat "$out/fresh_reverse.status")"
    printf 'tapenade_fresh_sources: parser=lh079_p.f forward=lh079_d.f reverse=lh079_b.f\n'
    printf 'fortad_exact_parser: pass status=%s output=generated\n' "$(cat "$out/fortad-parser.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic="fortad: independent ad is not declared in f" output=none\n' "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="fortad: dependent f is not declared in f" output=none\n' "$(cat "$out/fortad-reverse.status")"
    printf 'independent_oracle: %s\n' "$oracle_output"
    printf 'bounded_port: not-claimed reason=repairing-exponent-and-undeclared-xd-changes-exact-source\n'
    printf 'upstream_sha256:\n'
    (cd "$source_dir" && sha256sum program.f program_p.f program_d.f program_b.f program_dv.f \
        program_p.msg program_d.msg program_b.msg program_dv.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum lh079_p.f lh079_p.msg)
    (cd "$out/fresh/forward" && sha256sum lh079_d.f lh079_d.msg)
    (cd "$out/fresh/reverse" && sha256sum lh079_b.f lh079_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
