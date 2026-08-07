#!/usr/bin/env bash
# Validate the pinned Tapenade set01/B03 exact-source boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=$(cd "${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
required_fortad_commit=8137837b6c474708c20ea86ad02b086aa15322fd
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/B03
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-B03.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -e "$fortad_repo/.git"
test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse --abbrev-ref HEAD)" = main
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"
test -x "$tapenade"

for source in Options program.f program_p.f program_p.msg program_d.f program_d.msg \
    program_b.f program_b.msg; do
    test -s "$source_dir/$source"
done

strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)
legacy_fixed=(-std=legacy -ffixed-form -ffixed-line-length-none -Wall -Wextra
    -Wimplicit-interface -fno-lto -fsyntax-only)

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_fixed() {
    local label=$1
    local flags_name=$2
    local source=$3
    local status=0
    if [ "$flags_name" = strict ]; then
        "$fc" "${strict_fixed[@]}" "$source" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    else
        "$fc" "${legacy_fixed[@]}" "$source" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    fi
    printf '%s\n' "$status" >"$out/$label.status"
}

for source in program.f program_p.f program_d.f program_b.f; do
    stem=${source%.f}
    compile_fixed "$stem-strict" strict "$source_dir/$source"
    compile_fixed "$stem-legacy" legacy "$source_dir/$source"
    test "$(cat "$out/$stem-strict.status")" -ne 0
    test "$(cat "$out/$stem-legacy.status")" -eq 0
done

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"
(
    cd "$tapenade_repo"
    run_status tapenade-parser "$tapenade" -p -root viscflux -O "$out/fresh/parser" \
        -o b03b01 "$source_dir/program.f"
)
(
    cd "$tapenade_repo"
    run_status tapenade-forward "$tapenade" -d -root viscflux -O "$out/fresh/forward" \
        -o b03b01 "$source_dir/program.f"
)
(
    cd "$tapenade_repo"
    run_status tapenade-reverse "$tapenade" -b -root viscflux -O "$out/fresh/reverse" \
        -o b03b01 "$source_dir/program.f"
)

for mode in parser forward reverse; do
    case "$mode" in
        parser) suffix=p ;;
        forward) suffix=d ;;
        reverse) suffix=b ;;
    esac
    test "$(cat "$out/tapenade-$mode.status")" -eq 0
    generated="$out/fresh/$mode/b03b01_${suffix}.f"
    test -s "$generated"
    test -s "$out/fresh/$mode/b03b01_${suffix}.msg"
    compile_fixed "fresh-$mode-strict" strict "$generated"
    compile_fixed "fresh-$mode-legacy" legacy "$generated"
    test "$(cat "$out/fresh-$mode-strict.status")" -ne 0
    test "$(cat "$out/fresh-$mode-legacy.status")" -eq 0
done

run_status fortad-check "$fortad" check --proc viscflux \
    --output "$out/fortad-check.f90" "$source_dir/program.f"
run_status fortad-forward "$fortad" --mode forward --proc viscflux \
    --indep qpi1,qi1,qli1,qi2,qli2,qpi2,vres6,fn --dep fn \
    --name b03b01_jvp --output "$out/fortad-forward.f90" "$source_dir/program.f"
run_status fortad-reverse "$fortad" --mode reverse --proc viscflux \
    --indep qpi1,qi1,qli1,qi2,qli2,qpi2,vres6,fn --dep fn \
    --name b03b01_vjp --output "$out/fortad-reverse.f90" "$source_dir/program.f"
for mode in check forward reverse; do
    test "$(cat "$out/fortad-$mode.status")" -eq 1
    grep -Fqx "fortad: unsupported statement at line 33" "$out/fortad-$mode.stderr"
    test ! -e "$out/fortad-$mode.f90"
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
{
    printf 'case: Tapenade nonRegressions set01 B03/B03\n'
    printf 'classification: expected-refusal-fortad-unsupported-common-line-33\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_fixed[*]}"
    printf 'legacy_fixed_flags: %s\n' "${legacy_fixed[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'required_tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_entry_point: viscflux(npdes,ewt,ubn,nl,beta,xi1,qi1,xdoti1,qli1,qpi1,disti1,epst,xi2,qi2,xdoti2,qli2,qpi2,disti2,vres6,fn,second_order)\n'
    printf 'tapenade_options: parser=-p/-root viscflux forward=-d/-root viscflux reverse=-b/-root viscflux -O DIR -o b03b01\n'
    printf 'exact_and_stored_compile: program=%s/%s program_p=%s/%s program_d=%s/%s program_b=%s/%s\n' \
        "$(cat "$out/program-strict.status")" "$(cat "$out/program-legacy.status")" \
        "$(cat "$out/program_p-strict.status")" "$(cat "$out/program_p-legacy.status")" \
        "$(cat "$out/program_d-strict.status")" "$(cat "$out/program_d-legacy.status")" \
        "$(cat "$out/program_b-strict.status")" "$(cat "$out/program_b-legacy.status")"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/tapenade-parser.status")" "$(cat "$out/tapenade-forward.status")" \
        "$(cat "$out/tapenade-reverse.status")"
    printf 'tapenade_fresh_strict_compile: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-strict.status")" "$(cat "$out/fresh-forward-strict.status")" \
        "$(cat "$out/fresh-reverse-strict.status")"
    printf 'tapenade_fresh_legacy_compile: parser=%s forward=%s reverse=%s\n' \
        "$(cat "$out/fresh-parser-legacy.status")" "$(cat "$out/fresh-forward-legacy.status")" \
        "$(cat "$out/fresh-reverse-legacy.status")"
    printf 'fortad_exact_parser: expected-refusal status=%s diagnostic="unsupported statement at line 33" output=none\n' "$(cat "$out/fortad-check.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic="unsupported statement at line 33" output=none\n' "$(cat "$out/fortad-forward.status")"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic="unsupported statement at line 33" output=none\n' "$(cat "$out/fortad-reverse.status")"
    printf 'independent_oracle:\n'
    sed 's/^/  /' <<<"$oracle_output"
    printf 'no_repaired_port: common-block-and-external-low-boundary\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/program.f \
        "$source_rel"/program_p.f "$source_rel"/program_p.msg "$source_rel"/program_d.f \
        "$source_rel"/program_d.msg "$source_rel"/program_b.f "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh/parser" && sha256sum b03b01_p.f b03b01_p.msg)
    (cd "$out/fresh/forward" && sha256sum b03b01_d.f b03b01_d.msg)
    (cd "$out/fresh/reverse" && sha256sum b03b01_b.f b03b01_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
