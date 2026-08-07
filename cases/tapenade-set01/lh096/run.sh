#!/usr/bin/env bash
set -euo pipefail
case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bench_root=$(cd "$case_dir/../../.." && pwd)
fortad_repo=$(cd "${FORTAD_REPO:-/home/ert/code/lazy-fortran/fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$bench_root/upstream/tapenade}" && pwd)
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
source_dir="$tapenade_repo/nonRegressions/set01/lh096"
result="$case_dir/result.txt"
out=$(mktemp -d /var/tmp/fortad-bench-lh096.XXXXXX)
trap 'rm -rf "$out"' EXIT
required_fortad_commit=a1c9f25f87eaadf700ba47ee3e841a0fb41585a3
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -fsyntax-only -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)
legacy_fixed=(-std=legacy -ffixed-form -ffixed-line-length-none -fsyntax-only -Wall -Wextra -Wimplicit-interface -fno-lto)
strict_free=(-std=f2018 -ffree-form -fsyntax-only -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)
test -x "$fortad"; test -x "$tapenade"; command -v gfortran >/dev/null; command -v python3 >/dev/null
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
for source in program.f program_p.f program_d.f program_b.f program_dv.f; do test -s "$source_dir/$source"; done
test ! -e "$source_dir/DIFFSIZES.inc"
compile_status() {
    local label=$1; shift
    if gfortran "$@" >"$out/$label.log" 2>&1; then printf '0'; else printf '%s' "$?"; fi
}
for source in program.f program_p.f program_d.f program_b.f; do
    strict=$(compile_status "strict-$source" "${strict_fixed[@]}" "$source_dir/$source")
    legacy=$(compile_status "legacy-$source" "${legacy_fixed[@]}" "$source_dir/$source")
    test "$strict" = 0; test "$legacy" = 0
done
dv_strict=$(compile_status strict-dv "${strict_fixed[@]}" "$source_dir/program_dv.f")
dv_legacy=$(compile_status legacy-dv "${legacy_fixed[@]}" "$source_dir/program_dv.f")
test "$dv_strict" -ne 0; test "$dv_legacy" -ne 0
grep -Fq DIFFSIZES.inc "$out/strict-dv.log"; grep -Fq DIFFSIZES.inc "$out/legacy-dv.log"
for mode in p d b; do
    mkdir -p "$out/tapenade/$mode"
    "$tapenade" "-$mode" -root testliveness -O "$out/tapenade/$mode" -o lh096 "$source_dir/program.f" >"$out/tapenade-$mode.log" 2>&1
    generated="$out/tapenade/$mode/lh096_${mode}.f"
    test -s "$generated"
    test "$(compile_status "fresh-$mode-strict" "${strict_fixed[@]}" "$generated")" = 0
    test "$(compile_status "fresh-$mode-legacy" "${legacy_fixed[@]}" "$generated")" = 0
done
"$fortad" check --proc testliveness --output "$out/source-check.f90" "$source_dir/program.f" >"$out/source-check.log" 2>&1
source_check=$(compile_status source-check-free "${strict_free[@]}" "$out/source-check.f90")
test "$source_check" -ne 0; grep -Eiq "no IMPLICIT type|has no IMPLICIT type" "$out/source-check-free.log"
"$fortad" --mode forward --indep a --dep d --proc testliveness --name jvp --module m --output "$out/source-forward.f90" "$source_dir/program.f" >"$out/source-forward.log" 2>&1
test "$(compile_status source-forward-free "${strict_free[@]}" "$out/source-forward.f90")" = 0
set +e
"$fortad" --mode reverse --indep a --dep d --proc testliveness --name vjp --module m --output "$out/source-reverse.f90" "$source_dir/program.f" >"$out/source-reverse.log" 2>&1
source_reverse=$?
set -e
test "$source_reverse" -ne 0; grep -Fq "assignment to undeclared 'sub1'" "$out/source-reverse.log"
for mode in p d; do
    mkdir -p "$out/compat-$mode"
    "$fortad" "-$mode" -root testliveness -O "$out/compat-$mode" -o lh096 "$source_dir/program.f" >"$out/compat-$mode.log" 2>&1
    generated="$out/compat-$mode/lh096_${mode}.f90"
    test -s "$generated"
    compat_status=$(compile_status "compat-$mode-free" "${strict_free[@]}" "$generated")
    if [ "$mode" = p ]; then
        test "$compat_status" -ne 0
        grep -Eiq "no IMPLICIT type|has no IMPLICIT type" "$out/compat-$mode-free.log"
    else
        test "$compat_status" = 0
    fi
done
mkdir -p "$out/compat-b"
set +e
"$fortad" -b -root testliveness -O "$out/compat-b" -o lh096 "$source_dir/program.f" >"$out/compat-b.log" 2>&1
compat_b=$?
set -e
test "$compat_b" -ne 0; grep -Fq "could not infer Tapenade dependent" "$out/compat-b.log"
oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir/program.f")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"
{
    printf 'case: Tapenade nonRegressions/set01/lh096\nclassification: expected-boundary-fortad-sub1-compatibility-and-missing-vector-include\nrunner_result: pass\nrecorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'fortad_commit: %s\ntapenade_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)" "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'exact_and_fresh_fixed_gates: pass; program_dv: strict=%s legacy=%s missing-DIFFSIZES.inc\n' "$dv_strict" "$dv_legacy"
    printf 'fortad_source_first: check=status-%s-invalid-free-strict forward=pass-free-strict reverse=status-%s-undeclared-sub1\n' "$source_check" "$source_reverse"
    printf 'fortad_compatibility: parser=pass-invalid-free-strict forward=pass-free-strict reverse=status-%s-dependent-inference\n' "$compat_b"
    printf 'missing_dependency: no unambiguous authoritative DIFFSIZES.inc; no repair\n%s\n' "$oracle_output"
    printf 'upstream_sha256:\n'; (cd "$source_dir" && sha256sum program.f program_p.f program_p.msg program_d.f program_d.msg program_b.f program_b.msg program_dv.f program_dv.msg)
    printf 'case_artifact_sha256:\n'; (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
