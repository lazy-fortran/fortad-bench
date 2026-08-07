#!/usr/bin/env bash
# Validate the pinned todoF90/REFERENCES/v05 invalid-source boundary.
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/mnt/storage/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
if test -z "${TAPENADE_REPO+x}" && test ! -e "$tapenade_repo/.git"; then
    common_git_dir=$(git -C "$root" rev-parse --git-common-dir)
    shared_root=$(cd "$(dirname "$common_git_dir")" && pwd)
    if test -e "$shared_root/upstream/tapenade/.git"; then
        tapenade_repo="$shared_root/upstream/tapenade"
    fi
fi
tapenade_repo=$(cd "$tapenade_repo" && pwd)

required_fortad_commit=b9e87636b66b481c6dc6887ac7f7e14c86ef5f4a
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -ffree-form -ffree-line-length-none -fsyntax-only
    -pedantic-errors -Wall -Wextra -Wimplicit-interface)
legacy_flags=(-std=legacy -ffree-form -ffree-line-length-none -fsyntax-only
    -Wall -Wextra -Wimplicit-interface)
source_rel=todoF90/REFERENCES/v05/program.f90
source="$tapenade_repo/$source_rel"
out=$(mktemp -d /var/tmp/fortad-bench-v05.XXXXXX)
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
test -s "$source"

fortad="$fortad_repo/build/fo/bin/fortad"
if test ! -x "$fortad"; then
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.stdout" 2>"$out/fortad-build.stderr"
fi
test -x "$fortad"
tapenade="$tapenade_repo/bin/tapenade"
if test ! -x "$tapenade"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi
test -x "$tapenade"

run_status() {
    local label=$1
    shift
    local status
    if "$@" >"$out/$label.stdout" 2>"$out/$label.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/$label.status"
}

compile_source() {
    local label=$1
    local flags_name=$2
    local path=$3
    local -a flags
    if test "$flags_name" = strict; then
        flags=("${strict_flags[@]}")
    else
        flags=("${legacy_flags[@]}")
    fi
    run_status "$label" "$fc" "${flags[@]}" "$path"
}

compile_source upstream_strict strict "$source"
compile_source upstream_legacy legacy "$source"
test "$(cat "$out/upstream_strict.status")" -ne 0
test "$(cat "$out/upstream_legacy.status")" -ne 0
grep -Fq "Return type mismatch of function" "$out/upstream_strict.stderr"
grep -Fq "Return type mismatch of function" "$out/upstream_legacy.stderr"

for root_name in RETARD COMP_PRECIPITATION; do
    root_key=$(printf '%s' "$root_name" | tr '[:upper:]' '[:lower:]')
    for mode in parser tangent reverse; do
        case "$mode" in
            parser) tap_mode=-p; suffix=p ;;
            tangent) tap_mode=-d; suffix=d ;;
            reverse) tap_mode=-b; suffix=b ;;
        esac
        dir="$out/tapenade/${root_key}/${mode}"
        mkdir -p "$dir"
        run_status "tapenade_${root_key}_${mode}" bash -c \
            "cd '$dir' && '$tapenade' '$tap_mode' -root '$root_name' -O . -o v05 '$source'"
        test "$(cat "$out/tapenade_${root_key}_${mode}.status")" -eq 0
        test -e "$dir/v05_${suffix}.msg"
        generated="$dir/v05_${suffix}.f90"
        if test -s "$generated"; then
            compile_source "fresh_${root_key}_${mode}" strict "$generated"
        else
            printf '%s\n' not-applicable-no-source >"$out/fresh_${root_key}_${mode}.status"
        fi
    done
done

test -s "$out/tapenade/retard/parser/v05_p.f90"
test -s "$out/tapenade/retard/tangent/v05_d.f90"
test -s "$out/tapenade/retard/reverse/v05_b.f90"
test -s "$out/tapenade/comp_precipitation/parser/v05_p.f90"
test ! -e "$out/tapenade/comp_precipitation/tangent/v05_d.f90"
test ! -e "$out/tapenade/comp_precipitation/reverse/v05_b.f90"
test "$(cat "$out/fresh_retard_parser.status")" -ne 0
test "$(cat "$out/fresh_retard_tangent.status")" -eq 0
test "$(cat "$out/fresh_retard_reverse.status")" -eq 0
test "$(cat "$out/fresh_comp_precipitation_parser.status")" -ne 0
test "$(cat "$out/fresh_comp_precipitation_tangent.status")" = not-applicable-no-source
test "$(cat "$out/fresh_comp_precipitation_reverse.status")" = not-applicable-no-source
grep -Fq "Explicit interface required" "$out/fresh_retard_parser.stderr"
grep -Fq "Explicit interface required" "$out/fresh_comp_precipitation_parser.stderr"
grep -Fq "AD06" "$out/tapenade/comp_precipitation/tangent/v05_d.msg"
grep -Fq "AD06" "$out/tapenade/comp_precipitation/reverse/v05_b.msg"

run_status fortad_check_retard "$fortad" check --proc RETARD \
    --output "$out/fortad_check_retard.f90" "$source"
run_status fortad_check_comp "$fortad" check --proc COMP_PRECIPITATION \
    --output "$out/fortad_check_comp.f90" "$source"
run_status fortad_forward_retard "$fortad" --mode forward --proc RETARD \
    --indep CK --name v05_retard_forward --output "$out/fortad_forward_retard.f90" "$source"
run_status fortad_reverse_retard "$fortad" --mode reverse --proc RETARD \
    --indep CK --name v05_retard_reverse --output "$out/fortad_reverse_retard.f90" "$source"
run_status fortad_forward_comp "$fortad" --mode forward \
    --proc COMP_PRECIPITATION --indep CK --name v05_comp_forward \
    --output "$out/fortad_forward_comp.f90" "$source"
run_status fortad_reverse_comp "$fortad" --mode reverse \
    --proc COMP_PRECIPITATION --indep CK --name v05_comp_reverse \
    --output "$out/fortad_reverse_comp.f90" "$source"

test "$(cat "$out/fortad_check_retard.status")" -eq 0
test -s "$out/fortad_check_retard.f90"
compile_source fortad_check_retard_compile strict "$out/fortad_check_retard.f90"
test "$(cat "$out/fortad_check_retard_compile.status")" -ne 0
test "$(cat "$out/fortad_check_comp.status")" -ne 0
test ! -e "$out/fortad_check_comp.f90"
test "$(cat "$out/fortad_forward_retard.status")" -eq 0
test -s "$out/fortad_forward_retard.f90"
compile_source fortad_forward_retard_compile strict "$out/fortad_forward_retard.f90"
test "$(cat "$out/fortad_forward_retard_compile.status")" -ne 0
test "$(cat "$out/fortad_reverse_retard.status")" -ne 0
test ! -e "$out/fortad_reverse_retard.f90"
test "$(cat "$out/fortad_forward_comp.status")" -ne 0
test ! -e "$out/fortad_forward_comp.f90"
test "$(cat "$out/fortad_reverse_comp.status")" -ne 0
test ! -e "$out/fortad_reverse_comp.f90"
grep -Fq "Invalid character in name" "$out/fortad_check_retard_compile.stderr"
grep -Fq "Invalid character in name" "$out/fortad_forward_retard_compile.stderr"
grep -Fq "fortad: call to RETARD does not match its argument list" "$out/fortad_check_comp.stderr"
grep -Fq "fortad: call to RETARD does not match its argument list" "$out/fortad_forward_comp.stderr"
grep -Fq "fortad: call to RETARD does not match its argument list" "$out/fortad_reverse_comp.stderr"
grep -Fq "fortad: assignment to undeclared 'RETARD'" "$out/fortad_reverse_retard.stderr"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES v05 invalid-source boundary\n'
    printf 'classification: expected-refusal-invalid-upstream\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'legacy_compiler_flags: %s\n' "${legacy_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'fortad_worktree: clean-and-pinned\n'
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_points: RETARD(CK,I_ZONE,SP,TEMPS,IFIM1); COMP_PRECIPITATION(CK,DELTAT)\n'
    printf 'upstream_exact_strict_compile: program.f90=%s\n' "$(cat "$out/upstream_strict.status")"
    printf 'upstream_exact_legacy_compile: program.f90=%s\n' "$(cat "$out/upstream_legacy.status")"
    printf 'upstream_diagnostic: Return type mismatch of function RETARD at the implicit-interface call; CK(1,1) is passed to scalar CK and RETARD has optional dummies\n'
    printf 'tapenade_generation: retard_parser=%s retard_tangent=%s retard_reverse=%s comp_precipitation_parser=%s comp_precipitation_tangent=%s comp_precipitation_reverse=%s\n' \
        "$(cat "$out/tapenade_retard_parser.status")" "$(cat "$out/tapenade_retard_tangent.status")" \
        "$(cat "$out/tapenade_retard_reverse.status")" "$(cat "$out/tapenade_comp_precipitation_parser.status")" \
        "$(cat "$out/tapenade_comp_precipitation_tangent.status")" "$(cat "$out/tapenade_comp_precipitation_reverse.status")"
    printf 'tapenade_fresh_sources: retard=parser:v05_p.f90,tangent:v05_d.f90,reverse:v05_b.f90; comp_precipitation=parser:v05_p.f90,tangent:none,reverse:none\n'
    printf 'tapenade_fresh_strict_compile: retard_parser=%s retard_tangent=%s retard_reverse=%s comp_precipitation_parser=%s comp_precipitation_tangent=%s comp_precipitation_reverse=%s\n' \
        "$(cat "$out/fresh_retard_parser.status")" "$(cat "$out/fresh_retard_tangent.status")" \
        "$(cat "$out/fresh_retard_reverse.status")" "$(cat "$out/fresh_comp_precipitation_parser.status")" \
        "$(cat "$out/fresh_comp_precipitation_tangent.status")" "$(cat "$out/fresh_comp_precipitation_reverse.status")"
    printf 'tapenade_diagnostics: parser=explicit-interface-required-for-RETARD; comp_precipitation-tangent-and-reverse=AD06-no-active-input-or-output-plus-DF03-uninitialized-I_ZONE\n'
    printf 'fortad_exact_parser: retard=transform-status-0-generated-strict-compile-%s; comp_precipitation=refused-status-%s diagnostic="fortad: call to RETARD does not match its argument list"\n' \
        "$(cat "$out/fortad_check_retard_compile.status")" "$(cat "$out/fortad_check_comp.status")"
    printf 'fortad_exact_forward: retard=transform-status-0-generated-strict-compile-%s; comp_precipitation=refused-status-%s diagnostic="fortad: call to RETARD does not match its argument list"\n' \
        "$(cat "$out/fortad_forward_retard_compile.status")" "$(cat "$out/fortad_forward_comp.status")"
    printf 'fortad_exact_reverse: retard=refused-status-%s diagnostic="fortad: assignment to undeclared RETARD"; comp_precipitation=refused-status-%s diagnostic="fortad: call to RETARD does not match its argument list"\n' \
        "$(cat "$out/fortad_reverse_retard.status")" "$(cat "$out/fortad_reverse_comp.status")"
    printf 'independent_oracle: reproducible strict-and-legacy compiler diagnostic plus generated-source strict compilation\n'
    printf 'port_result: not-applicable-no-standard-conforming-semantics-to-preserve\n'
    printf 'closure: no bounded port and no exact-source support claim; repairing the implicit interface or CK(1,1) would change the candidate\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel")
    printf 'fresh_tapenade_sha256:\n'
    find "$out/tapenade" -type f \( -name '*.f90' -o -name '*.msg' \) -print0 | sort -z | xargs -0 sha256sum
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/v05/manifest.toml cases/tapenade-set01/v05/notes.md \
        cases/tapenade-set01/v05/run.sh cases/tapenade-set01/v05/test_contract.py)
} >"$result"

cat "$result"
