#!/usr/bin/env bash
set -euo pipefail
case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=$(cd "${FORTAD_REPO:-$root/../fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
required_fortad_commit=ba15d9fc2445e7aa8e8cd130484bd0984ceb2fc1
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}; source_dir="$tapenade_repo/nonRegressions/set01/lh097"
fortad="$fortad_repo/build/fo/bin/fortad"; tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh097.XXXXXX); trap 'rm -rf "$out"' EXIT
command -v "$fc" >/dev/null; command -v java >/dev/null; command -v python3 >/dev/null
test -e "$fortad_repo/.git"; test -e "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -x "$fortad"; test -x "$tapenade"
for source in program.f program_b.f; do test -s "$source_dir/$source"; done; test -f "$source_dir/program_b.msg"
strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -fsyntax-only -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)
legacy=(-std=legacy -ffixed-form -ffixed-line-length-none -fsyntax-only -Wall -Wextra -Wimplicit-interface -fno-lto)
run_status() { local label=$1; shift; local status=0; "$@" >"$out/$label.out" 2>"$out/$label.err" || status=$?; printf '%s\n' "$status" >"$out/$label.status"; }
compile() { local label=$1 flags=$2 source=$3; # shellcheck disable=SC2086
    run_status "compile-$label" "$fc" $flags "$source"; }
mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"
compile exact-strict "${strict[*]}" "$source_dir/program.f"; test "$(cat "$out/compile-exact-strict.status")" -ne 0; grep -Fqi "Comma before i/o item list" "$out/compile-exact-strict.err"
compile exact-legacy "${legacy[*]}" "$source_dir/program.f"; test "$(cat "$out/compile-exact-legacy.status")" -eq 0
compile stored-reverse-strict "${strict[*]}" "$source_dir/program_b.f"; test "$(cat "$out/compile-stored-reverse-strict.status")" -ne 0; grep -Fqi "Comma before i/o item list" "$out/compile-stored-reverse-strict.err"
compile stored-reverse-legacy "${legacy[*]}" "$source_dir/program_b.f"; test "$(cat "$out/compile-stored-reverse-legacy.status")" -eq 0
for mode in parser forward reverse; do
    case "$mode" in parser) opt=-p; suffix=p;; forward) opt=-d; suffix=d;; reverse) opt=-b; suffix=b;; esac
    run_status "tapenade-$mode" bash -c "cd '$out/fresh/$mode' && '$tapenade' '$opt' -root testiotbr -O . -o lh097 '$source_dir/program.f'"
    test "$(cat "$out/tapenade-$mode.status")" -eq 0; generated="$out/fresh/$mode/lh097_${suffix}.f"; test -s "$generated"
    compile "fresh-$mode-legacy" "${legacy[*]}" "$generated"; test "$(cat "$out/compile-fresh-$mode-legacy.status")" -eq 0
    compile "fresh-$mode-strict" "${strict[*]}" "$generated"; test "$(cat "$out/compile-fresh-$mode-strict.status")" -ne 0; grep -Fqi "Comma before i/o item list" "$out/compile-fresh-$mode-strict.err"
done
run_status fortad-check "$fortad" check --output "$out/check.f90" "$source_dir/program.f"
run_status fortad-forward "$fortad" --mode forward --indep a --dep b,c --proc testiotbr --name lh097_jvp --module lh097_jvp_mod --output "$out/forward.f90" "$source_dir/program.f"
run_status fortad-reverse "$fortad" --mode reverse --indep a --dep b,c --proc testiotbr --name lh097_vjp --module lh097_vjp_mod --output "$out/reverse.f90" "$source_dir/program.f"
for mode in check forward reverse; do test "$(cat "$out/fortad-$mode.status")" -ne 0; grep -Fq "unsupported statement at line 7" "$out/fortad-$mode.out" "$out/fortad-$mode.err"; done
test ! -e "$out/check.f90"; test ! -e "$out/forward.f90"; test ! -e "$out/reverse.f90"
oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir"); grep -Fqx "oracle_status: pass" <<<"$oracle_output"
{
    printf 'case: Tapenade nonRegressions/set01/lh097\nclassification: expected-refusal-fortad-unsupported-io-overwrite\nrunner_result: pass\nrecorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'compiler: %s\nstrict_flags: %s\nlegacy_flags: %s\n' "$($fc --version | head -1)" "${strict[*]}" "${legacy[*]}"
    printf 'fortad_commit: %s\nrequired_fortad_commit: %s\ntapenade_commit: %s\nrequired_tapenade_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)" "$required_fortad_commit" "$(git -C "$tapenade_repo" rev-parse HEAD)" "$required_tapenade_commit"
    printf 'upstream_entry_point: testiotbr(a,b,c)\nstrict_compile: exact=expected-refusal stored-reverse=expected-refusal fresh-parser=expected-refusal fresh-forward=expected-refusal fresh-reverse=expected-refusal\nlegacy_compile: exact=pass stored-reverse=pass fresh-parser=pass fresh-forward=pass fresh-reverse=pass\ntapenade_generation: parser=pass tangent=pass reverse=pass\nfortad_exact_behavior: check=expected-refusal forward=expected-refusal reverse=expected-refusal diagnostic=unsupported-statement-line-7 no-output\nindependent_oracle: fixed-read-value tangent-finite-difference reverse-adjoint\n%s\nno_bounded_numerical_port: exact-source-only\nupstream_sha256:\n' "$oracle_output"
    (cd "$source_dir" && sha256sum program.f program_b.f program_b.msg)
    printf 'fresh_tapenade_sha256:\n'; (cd "$out/fresh/parser" && sha256sum lh097_p.f lh097_p.msg); (cd "$out/fresh/forward" && sha256sum lh097_d.f lh097_d.msg); (cd "$out/fresh/reverse" && sha256sum lh097_b.f lh097_b.msg)
    printf 'case_artifact_sha256:\n'; (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
