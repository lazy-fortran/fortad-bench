#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh093"
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/mnt/storage/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=ba15d9fc2445e7aa8e8cd130484bd0984ceb2fc1
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_dir="$tapenade_repo/nonRegressions/set01/lh093"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh093.XXXXXX)

command -v "$fc" >/dev/null; command -v java >/dev/null; command -v python3 >/dev/null
test -e "$fortad_repo/.git"; test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad"; test -x "$tapenade"
for source in program.f program_d.f90; do test -s "$source_dir/$source"; done
test -f "$source_dir/program_d.msg"

strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fsyntax-only)
legacy_fixed=(-std=legacy -ffixed-form -ffixed-line-length-none -Wall -Wextra -Wimplicit-interface -fsyntax-only)
strict_free=(-std=f2018 -ffree-form -pedantic-errors -Wall -Wextra -Wimplicit-interface -fsyntax-only)
legacy_free=(-std=legacy -ffree-form -Wall -Wextra -Wimplicit-interface -fsyntax-only)
run_status() { local label=$1; shift; local status=0; "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?; printf '%s\n' "$status" >"$out/$label.status"; }

run_status compile-exact-strict "$fc" "${strict_fixed[@]}" "$source_dir/program.f"
run_status compile-exact-legacy "$fc" "${legacy_fixed[@]}" "$source_dir/program.f"
run_status compile-stored-forward-strict "$fc" "${strict_free[@]}" "$source_dir/program_d.f90"
run_status compile-stored-forward-legacy "$fc" "${legacy_free[@]}" "$source_dir/program_d.f90"
test "$(cat "$out/compile-exact-strict.status")" -ne 0; test "$(cat "$out/compile-exact-legacy.status")" -eq 0
test "$(cat "$out/compile-stored-forward-strict.status")" -ne 0; test "$(cat "$out/compile-stored-forward-legacy.status")" -eq 0
grep -Fqi "comma before i/o item list" "$out/compile-exact-strict.stderr" "$out/compile-stored-forward-strict.stderr"

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"
run_status tapenade-parser "$tapenade" -p -O "$out/fresh/parser" -o lh093 "$source_dir/program.f"
run_status tapenade-forward "$tapenade" -d -root testIOmess -O "$out/fresh/forward" -o lh093 "$source_dir/program.f"
run_status tapenade-reverse "$tapenade" -b -root testIOmess -O "$out/fresh/reverse" -o lh093 "$source_dir/program.f"
for mode in parser forward reverse; do
    case "$mode" in parser) suffix=p;; forward) suffix=d;; reverse) suffix=b;; esac
    generated="$out/fresh/$mode/lh093_${suffix}.f90"
    test "$(cat "$out/tapenade-$mode.status")" -eq 0; test -s "$generated"
    run_status "compile-fresh-$mode-strict" "$fc" "${strict_free[@]}" "$generated"
    run_status "compile-fresh-$mode-legacy" "$fc" "${legacy_free[@]}" "$generated"
    test "$(cat "$out/compile-fresh-$mode-strict.status")" -ne 0
    test "$(cat "$out/compile-fresh-$mode-legacy.status")" -eq 0
done

run_status fortad-check "$fortad" check --output "$out/check.f90" "$source_dir/program.f"
run_status fortad-forward "$fortad" --mode forward --indep a,b,d --dep b,c,d,e --proc testIOmess --name lh093_jvp --module lh093_jvp_mod --output "$out/forward.f90" "$source_dir/program.f"
run_status fortad-reverse "$fortad" --mode reverse --indep a,b,d --dep b,c,d,e --proc testIOmess --name lh093_vjp --module lh093_vjp_mod --output "$out/reverse.f90" "$source_dir/program.f"
for mode in check forward reverse; do test "$(cat "$out/fortad-$mode.status")" -ne 0; grep -Fq "unsupported statement at line 8" "$out/fortad-$mode.stdout" "$out/fortad-$mode.stderr"; done
test ! -e "$out/check.f90"; test ! -e "$out/forward.f90"; test ! -e "$out/reverse.f90"
oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
{
    printf 'case: Tapenade nonRegressions set01 lh093\nclassification: expected-refusal-fortad-unsupported-I-O-line-8\nrunner_result: pass\nrecorded_utc: %s\nmachine: %s\ncpu: %s\ncompiler: %s\nfortad_commit: %s\nrequired_fortad_commit: %s\ntapenade_commit: %s\nrequired_tapenade_commit: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(hostname)" "$cpu_model" "$($fc --version | head -1)" "$(git -C "$fortad_repo" rev-parse HEAD)" "$required_fortad_commit" "$(git -C "$tapenade_repo" rev-parse HEAD)" "$required_tapenade_commit"
    printf 'stored_compilation: exact=strict-refusal-legacy-pass forward=strict-refusal-legacy-pass\ntapenade_generation: parser=%s forward=%s reverse=%s\n' "$(cat "$out/tapenade-parser.status")" "$(cat "$out/tapenade-forward.status")" "$(cat "$out/tapenade-reverse.status")"
    printf 'fresh_legacy_compile: parser=%s forward=%s reverse=%s\n' "$(cat "$out/compile-fresh-parser-legacy.status")" "$(cat "$out/compile-fresh-forward-legacy.status")" "$(cat "$out/compile-fresh-reverse-legacy.status")"
    printf 'fresh_strict_compile: parser=%s forward=%s reverse=%s\n' "$(cat "$out/compile-fresh-parser-strict.status")" "$(cat "$out/compile-fresh-forward-strict.status")" "$(cat "$out/compile-fresh-reverse-strict.status")"
    printf 'fortad_exact_behavior: check=expected-refusal forward=expected-refusal reverse=expected-refusal diagnostic=unsupported-statement-line-8 no-output\nindependent_oracle: source-inventory array-product-jvp reverse-dot-product\n%s\n' "$oracle_output"
    printf 'upstream_sha256:\n'; (cd "$source_dir" && sha256sum program.f program_d.f90 program_d.msg)
    printf 'case_artifact_sha256:\n'; (cd "$root" && sha256sum cases/tapenade-set01/lh093/manifest.toml cases/tapenade-set01/lh093/notes.md cases/tapenade-set01/lh093/oracle.py cases/tapenade-set01/lh093/run.sh cases/tapenade-set01/lh093/test_contract.py)
} >"$result"
cat "$result"
