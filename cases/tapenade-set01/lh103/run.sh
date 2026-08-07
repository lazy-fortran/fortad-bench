#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=$(cd "${FORTAD_REPO:-$root/../fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
required_fortad_commit=ba15d9fc2445e7aa8e8cd130484bd0984ceb2fc1
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/lh103
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-lh103.XXXXXX)

command -v "$fc" >/dev/null
command -v python3 >/dev/null
command -v java >/dev/null
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad" && test -x "$tapenade"
for source in program.f program_b.f program_b.msg; do test -s "$source_dir/$source"; done

strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fsyntax-only)
legacy=(-std=legacy -ffixed-form -ffixed-line-length-none -Wall -Wextra -Wimplicit-interface -fsyntax-only)
run_status() { local label=$1; shift; local status=0; "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?; printf '%s\n' "$status" >"$out/$label.status"; }
status() { cat "$out/$1.status"; }

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse" "$out/fortad"
run_status exact-strict "$fc" "${strict[@]}" "$source_dir/program.f"
run_status stored-strict "$fc" "${strict[@]}" "$source_dir/program_b.f"
run_status exact-legacy "$fc" "${legacy[@]}" "$source_dir/program.f"
run_status stored-legacy "$fc" "${legacy[@]}" "$source_dir/program_b.f"
test "$(status exact-strict)" -eq 0; test "$(status stored-strict)" -eq 0
test "$(status exact-legacy)" -eq 0; test "$(status stored-legacy)" -eq 0

for mode in parser forward reverse; do
    case "$mode" in parser) flag=-p; suffix=p ;; forward) flag=-d; suffix=d ;; reverse) flag=-b; suffix=b ;; esac
    run_status "tapenade-$mode" bash -c "cd '$out/fresh/$mode' && '$tapenade' '$flag' -O . -o lh103 '$source_dir/program.f'"
    test "$(status tapenade-$mode)" -eq 0
    test -s "$out/fresh/$mode/lh103_${suffix}.f"; test -s "$out/fresh/$mode/lh103_${suffix}.msg"
    run_status "compile-$mode" "$fc" "${strict[@]}" "$out/fresh/$mode/lh103_${suffix}.f"
    test "$(status compile-$mode)" -eq 0
done
diff -I '^C  Tapenade ' "$source_dir/program_b.f" "$out/fresh/reverse/lh103_b.f" >/dev/null
cmp "$source_dir/program_b.msg" "$out/fresh/reverse/lh103_b.msg"

run_status fortad-check "$fortad" check --proc h --output "$out/fortad/check.f" "$source_dir/program.f"
fortad_strict=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fsyntax-only)
run_status compile-fortad-check "$fc" "${fortad_strict[@]}" "$out/fortad/check.f"
run_status fortad-forward "$fortad" --mode forward --indep A,B,C,r --name h_d --module h_d_mod --output "$out/fortad/forward.f" "$source_dir/program.f"
run_status compile-fortad-forward "$fc" "${fortad_strict[@]}" "$out/fortad/forward.f"
run_status fortad-reverse "$fortad" --mode reverse --indep A,B,C,r --dep r --name h_b --module h_b_mod --output "$out/fortad/reverse.f" "$source_dir/program.f"
test "$(status fortad-check)" -eq 0; test "$(status compile-fortad-check)" -eq 0
test "$(status fortad-forward)" -eq 0; test "$(status compile-fortad-forward)" -eq 0
test "$(status fortad-reverse)" -ne 0; test ! -e "$out/fortad/reverse.f"
grep -Fq "per-iteration storage" "$out/fortad-reverse.stderr"

python3 "$case_dir/oracle.py" "$source_dir" >"$out/oracle.txt"
grep -Fq 'oracle_status: pass' "$out/oracle.txt"

{
    printf 'case: Tapenade nonRegressions/set01/lh103\n'
    printf 'classification: runnable-upstream-fortad-forward-pass-reverse-storage-boundary\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'compiler: %s\n' "$("$fc" --version | head -1)"
    printf 'upstream_entry_point: h(a,b,c,r)\n'
    printf 'strict_compile: exact=%s stored_reverse=%s fresh_parser=%s fresh_forward=%s fresh_reverse=%s fortad_check=%s fortad_forward=%s\n' "$(status exact-strict)" "$(status stored-strict)" "$(status compile-parser)" "$(status compile-forward)" "$(status compile-reverse)" "$(status compile-fortad-check)" "$(status compile-fortad-forward)"
    printf 'legacy_compile: exact=%s stored_reverse=%s\n' "$(status exact-legacy)" "$(status stored-legacy)"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' "$(status tapenade-parser)" "$(status tapenade-forward)" "$(status tapenade-reverse)"
    printf 'tapenade_reverse_reference: fresh-body-equals-stored-after-banner-normalization message-byte-equal\n'
    printf 'fortad_exact_behavior: check=pass forward_jvp=pass reverse_vjp=expected-refusal-per-iteration-storage-no-output\n'
    cat "$out/oracle.txt"
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/program.f "$source_rel"/program_b.f "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/lh103_p.f parser/lh103_p.msg forward/lh103_d.f forward/lh103_d.msg reverse/lh103_b.f reverse/lh103_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
