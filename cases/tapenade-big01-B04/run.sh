#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bench_root=$(cd "$case_dir/../.." && pwd)
fortad_repo=$(cd "${FORTAD_REPO:-$bench_root/../fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$bench_root/upstream/tapenade}" && pwd)
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
source_dir="$tapenade_repo/examples/big01/B04"
result="$case_dir/result.txt"
required_fortad_commit=19e8cda7ad71990339f9ed254cc40128fcbff364
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
required_tapenade_tree=17288bdf7e03cb23b82ddc769d884deed9c9575e
fc=${FC:-gfortran}

strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)
legacy=(-std=legacy -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)

command -v "$fc" >/dev/null
command -v fo >/dev/null
command -v python3 >/dev/null
test -x "$fortad"
test -x "$tapenade"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" remote get-url origin)" = "https://gitlab.inria.fr/tapenade/tapenade.git"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD^{tree})" = "$required_tapenade_tree"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in Options program.f program_p.f program_p.msg program_d.f program_d.msg \
              program_dv.f program_dv.msg; do
    test -s "$source_dir/$source"
done
test ! -e "$source_dir/DIFFSIZES.inc"

out=$(mktemp -d /var/tmp/fortad-bench-tapenade-big01-B04.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/tapenade/parser" "$out/tapenade/tangent" "$out/tapenade/reverse" \
    "$out/fortad"

run_capture() {
    local label=$1
    shift
    local status=0
    if "$@" >"$out/$label.stdout" 2>"$out/$label.stderr"; then
        status=0
    else
        status=$?
    fi
    printf '%s\n' "$status" >"$out/$label.status"
}

status() { cat "$out/$1.status"; }

compile_capture() {
    local label=$1
    local flavor=$2
    local source=$3
    shift 3
    local flags=()
    if test "$flavor" = strict; then flags=("${strict[@]}"); else flags=("${legacy[@]}"); fi
    run_capture "$label" "$fc" "${flags[@]}" -I"$source_dir" "$@" "$source"
}

for flavor in strict legacy; do
    compile_capture "$flavor-exact-primal" "$flavor" "$source_dir/program.f"
    compile_capture "$flavor-stored-parser" "$flavor" "$source_dir/program_p.f"
    compile_capture "$flavor-stored-tangent" "$flavor" "$source_dir/program_d.f"
    compile_capture "$flavor-stored-vector" "$flavor" "$source_dir/program_dv.f"
    test "$(status "$flavor-exact-primal")" -ne 0
    test "$(status "$flavor-stored-parser")" -ne 0
    test "$(status "$flavor-stored-tangent")" -ne 0
    test "$(status "$flavor-stored-vector")" -ne 0
done
grep -Fq 'Two main PROGRAMs' "$out/strict-exact-primal.stderr"
grep -Fq 'Two main PROGRAMs' "$out/legacy-exact-primal.stderr"
grep -Fq 'Invalid character in name' "$out/strict-stored-parser.stderr"
grep -Fq 'Invalid character in name' "$out/legacy-stored-parser.stderr"
grep -Fq 'DIFFSIZES.inc' "$out/strict-stored-tangent.stderr"
grep -Fq 'DIFFSIZES.inc' "$out/legacy-stored-tangent.stderr"
grep -Fq 'DIFFSIZES.inc' "$out/strict-stored-vector.stderr"
grep -Fq 'DIFFSIZES.inc' "$out/legacy-stored-vector.stderr"

for mode_spec in "parser -p p" "tangent -d d" "reverse -b b"; do
    set -- $mode_spec
    mode=$1
    option=$2
    suffix=$3
    run_capture "tapenade-$mode-generation" bash -c \
        "cd '$source_dir' && '$tapenade' '$option' -root MOFDER_GEAR -O '$out/tapenade/$mode' -o b04 program.f"
    test "$(status "tapenade-$mode-generation")" -eq 0
    test -s "$out/tapenade/$mode/b04_${suffix}.f"
    test -s "$out/tapenade/$mode/b04_${suffix}.msg"
    for flavor in strict legacy; do
        compile_capture "$flavor-fresh-$mode" "$flavor" \
            "$out/tapenade/$mode/b04_${suffix}.f" \
            -I"$out/tapenade/$mode"
    done
done
test "$(status strict-fresh-parser)" -ne 0
test "$(status legacy-fresh-parser)" -ne 0
test "$(status strict-fresh-tangent)" -eq 0
test "$(status legacy-fresh-tangent)" -eq 0
test "$(status strict-fresh-reverse)" -ne 0
test "$(status legacy-fresh-reverse)" -ne 0
grep -Fq 'Two main PROGRAMs' "$out/strict-fresh-parser.stderr"
grep -Fq 'DIFFSIZES.inc' "$out/strict-fresh-reverse.stderr"

run_capture fortad-parser bash -c \
    "cd '$fortad_repo' && fo exec --no-build fortad check --proc MOFDER_GEAR \
     --output '$out/fortad/parser.f90' '$source_dir/program.f'"
run_capture fortad-forward bash -c \
    "cd '$fortad_repo' && fo exec --no-build fortad --mode forward --indep Y \
     --dep YDOT --proc MOFDER_GEAR --name b04_jvp --module b04_jvp_mod \
     --output '$out/fortad/forward.f90' '$source_dir/program.f'"
run_capture fortad-reverse bash -c \
    "cd '$fortad_repo' && fo exec --no-build fortad --mode reverse --indep Y \
     --dep YDOT --proc MOFDER_GEAR --name b04_vjp --module b04_vjp_mod \
     --output '$out/fortad/reverse.f90' '$source_dir/program.f'"
for mode in parser forward reverse; do
    test "$(status fortad-$mode)" -ne 0
    test ! -e "$out/fortad/$mode.f90"
    grep -Fq 'Invalid character in name at line 20599' "$out/fortad-$mode.stderr"
done

{
    printf 'case: Tapenade examples/big01/B04 MOFDER_GEAR(NEQ,T,Y,YDOT)\n'
    printf 'classification: unsupported-invalid-upstream-fortran\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict[*]}"
    printf 'legacy_fixed_flags: %s\n' "${legacy[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_origin: %s\n' "$(git -C "$tapenade_repo" remote get-url origin)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'tapenade_tree: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD^{tree})"
    printf 'entry_point: MOFDER_GEAR(NEQ,T,Y,YDOT)\n'
    printf 'stored_references: program_p.f program_p.msg program_d.f program_d.msg program_dv.f program_dv.msg\n'
    printf 'missing_dependency: DIFFSIZES.inc absent from exact B04 directory\n'
    printf 'upstream_exact_strict_compile: program.f=%s program_p.f=%s program_d.f=%s program_dv.f=%s\n' \
        "$(status strict-exact-primal)" "$(status strict-stored-parser)" \
        "$(status strict-stored-tangent)" "$(status strict-stored-vector)"
    printf 'upstream_exact_legacy_compile: program.f=%s program_p.f=%s program_d.f=%s program_dv.f=%s\n' \
        "$(status legacy-exact-primal)" "$(status legacy-stored-parser)" \
        "$(status legacy-stored-tangent)" "$(status legacy-stored-vector)"
    printf 'upstream_diagnostics: exact=two-main-programs; stored-parser=invalid-_MAIN_-and-two-main-programs; stored-tangent-vector=missing-DIFFSIZES.inc\n'
    printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
        "$(status tapenade-parser-generation)" "$(status tapenade-tangent-generation)" "$(status tapenade-reverse-generation)"
    printf 'tapenade_fresh_compile_strict: parser=%s tangent=%s reverse=%s\n' \
        "$(status strict-fresh-parser)" "$(status strict-fresh-tangent)" "$(status strict-fresh-reverse)"
    printf 'tapenade_fresh_compile_legacy: parser=%s tangent=%s reverse=%s\n' \
        "$(status legacy-fresh-parser)" "$(status legacy-fresh-tangent)" "$(status legacy-fresh-reverse)"
    printf 'tapenade_fresh_diagnostics: parser=two-main-programs tangent=pass reverse=missing-DIFFSIZES.inc\n'
    printf 'fortad_exact_parser: expected-refusal status=%s diagnostic=invalid-character-line-20599 output=none\n' "$(status fortad-parser)"
    printf 'fortad_exact_forward: expected-refusal status=%s diagnostic=invalid-character-line-20599 output=none\n' "$(status fortad-forward)"
    printf 'fortad_exact_reverse: expected-refusal status=%s diagnostic=invalid-character-line-20599 output=none\n' "$(status fortad-reverse)"
    printf 'independent_oracle: not-applicable-invalid-upstream-no-support-claim\n'
    printf 'no_repaired_source: true\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum examples/big01/B04/Options \
        examples/big01/B04/program.f examples/big01/B04/program_p.f \
        examples/big01/B04/program_p.msg examples/big01/B04/program_d.f \
        examples/big01/B04/program_d.msg examples/big01/B04/program_dv.f \
        examples/big01/B04/program_dv.msg)
    printf 'fresh_tapenade_sha256:\n'
    sha256sum "$out/tapenade/parser/b04_p.f" "$out/tapenade/parser/b04_p.msg" \
        "$out/tapenade/tangent/b04_d.f" "$out/tapenade/tangent/b04_d.msg" \
        "$out/tapenade/reverse/b04_b.f" "$out/tapenade/reverse/b04_b.msg"
    printf 'closure: exact source is available but invalid upstream; no support, repair, or derivative oracle claimed\n'
} >"$result"
cat "$result"
