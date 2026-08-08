#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bench_root=$(cd "$case_dir/../../.." && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$bench_root/upstream/tapenade}" && pwd)
fc=${FC:-gfortran}
result="$case_dir/result.txt"
source_rel=nonRegressions/set02/lh193
source_dir="$tapenade_repo/$source_rel"
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
required_tapenade_tree=17288bdf7e03cb23b82ddc769d884deed9c9575e
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set02-lh193.XXXXXX)
trap 'rm -rf "$out"' EXIT

strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)
legacy=(-std=legacy -ffixed-form -ffixed-line-length-none
    -Wall -Wextra -Wimplicit-interface -fno-lto -fsyntax-only)

for tool in "$fc" python3; do command -v "$tool" >/dev/null; done
test -d "$source_dir"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD^{tree})" = "$required_tapenade_tree"
test "$(git -C "$tapenade_repo" remote get-url origin)" = "https://gitlab.inria.fr/tapenade/tapenade.git"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in Options program.f program_d.f; do test -e "$source_dir/$source"; done
test -f "$tapenade_repo/ADFirstAidKit/ampi/ampif.h"
test ! -f "$tapenade_repo/ADFirstAidKit/mpich/include/mpif.h"
grep -Fqx "       include 'mpif.h'" <(sed -n '8p' "$tapenade_repo/ADFirstAidKit/ampi/ampif.h")

run_capture() {
    local label=$1
    shift
    local status=0
    (cd "$source_dir" && LC_ALL=C "$@") >"$out/$label.txt" 2>&1 || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

status() { cat "$out/$1.status"; }

for flavor in strict legacy; do
    if test "$flavor" = strict; then flags=("${strict[@]}"); else flags=("${legacy[@]}"); fi
    for source in program.f program_d.f; do
        stem=${source%.f}
        run_capture "$flavor-direct-$stem" "$fc" "${flags[@]}" "$source"
        test "$(status "$flavor-direct-$stem")" -eq 1
        grep -Fq "Cannot open included file 'ampi/ampif.h'" "$out/$flavor-direct-$stem.txt"
        run_capture "$flavor-adfirstaid-$stem" "$fc" "${flags[@]}" \
            "-I$tapenade_repo/ADFirstAidKit" "$source"
        test "$(status "$flavor-adfirstaid-$stem")" -eq 1
        grep -Fq "Cannot open included file 'mpif.h'" "$out/$flavor-adfirstaid-$stem.txt"
    done
done

{
    printf 'case: Tapenade nonRegressions/set02/lh193 head(x,y) AMPI dependency boundary\n'
    printf 'classification: blocked-missing-dependency\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'source_form: fixed\n'
    printf 'strict_fixed_flags: %s\n' "${strict[*]}"
    printf 'legacy_fixed_flags: %s\n' "${legacy[*]}"
    printf 'tapenade_origin: %s\n' "$(git -C "$tapenade_repo" remote get-url origin)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'tapenade_tree: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD^{tree})"
    printf 'entry_point: head(x,y); static programs main and main_d\n'
    printf 'tapenade_options: Options=-I ../ADFirstAidKit/mpich/include|-I ../ADFirstAidKit|-context; transformations not-run\n'
    printf 'direct_include_flags: none (case directory only)\n'
    printf 'resolved_header_include_flags: -I upstream/tapenade/ADFirstAidKit\n'
    printf 'upstream_exact_strict_compile: program=%s program_d=%s\n' \
        "$(status strict-direct-program)" "$(status strict-direct-program_d)"
    printf 'upstream_exact_legacy_compile: program=%s program_d=%s\n' \
        "$(status legacy-direct-program)" "$(status legacy-direct-program_d)"
    printf 'resolved_header_strict_compile: program=%s program_d=%s\n' \
        "$(status strict-adfirstaid-program)" "$(status strict-adfirstaid-program_d)"
    printf 'resolved_header_legacy_compile: program=%s program_d=%s\n' \
        "$(status legacy-adfirstaid-program)" "$(status legacy-adfirstaid-program_d)"
    printf 'automatic_compiler_triage: candidate_status=compiler-missing-dependency next_action=resolve-dependency-or-record-refusal\n'
    printf 'automatic_compiler_flags: -std=f2018 -ffixed-form -fsyntax-only -pedantic-errors -Wall -Wextra -Wimplicit-interface -cpp -I. -InonRegressions/set02/lh193 -J<scratch>\n'
    printf 'automatic_compiler_diagnostic_sha256: program=1b4dfc9f2e4cd76a1af41b318c03524981893037349cd607b3ccee1b515560c1 program_d=6adbdafd8d2546912bd87db905087863292b6869b6bd75d54122f4cb4c375548\n'
    printf 'direct_strict_diagnostic_program:\n%s\n' "$(cat "$out/strict-direct-program.txt")"
    printf 'direct_strict_diagnostic_program_d:\n%s\n' "$(cat "$out/strict-direct-program_d.txt")"
    printf 'nested_strict_diagnostic:\n%s\n' "$(cat "$out/strict-adfirstaid-program.txt")"
    printf 'diagnostic_sha256: direct_program=99fb7cae93e4e7aae3759a2fe210f7ee4dfcbc35bc1403d3b4a315da355d2a5d direct_program_d=2918f713d4149d4906ae415392f445b83c1084c519b19ba22c98b09c22dca7e1 nested=dc341cb0d02671f41e9571e53be0bb6a8ac73e5b721ca7dba90e9959d477070f\n'
    printf 'dependency_inventory: ADFirstAidKit/ampi/ampif.h=present; ADFirstAidKit/mpich/include/mpif.h=absent; ampif.h includes mpif.h\n'
    printf 'tapenade_result: not-run-missing-dependency\n'
    printf 'fortad_result: not-run-missing-dependency\n'
    printf 'independent_oracle: not-applicable-transformation-not-reached\n'
    printf 'no_transformation_attempted: true\n'
    printf 'not_invalid_upstream: true\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/program.f \
        "$source_rel"/program_d.f ADFirstAidKit/ampi/ampif.h)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md run.sh test_contract.py)
    printf 'closure: valid fixed-form candidate blocked by the exact pinned AMPI/MPI include chain; no invalid-upstream, Tapenade, FortAD, repaired-source, or derivative claim\n'
} >"$result"
cat "$result"
