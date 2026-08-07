#!/usr/bin/env bash
set -euo pipefail
case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
fortad_repo=$(cd "${FORTAD_REPO:-/mnt/storage/code/lazy-fortran/fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
fortad_pin=ba15d9fc2445e7aa8e8cd130484bd0984ceb2fc1
tapenade_pin=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}; source_rel=nonRegressions/set01/lh094; source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"; tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-lh094.XXXXXX); result="$case_dir/result.txt"; trap 'rm -rf "$out"' EXIT
command -v "$fc" >/dev/null; command -v java >/dev/null; command -v python3 >/dev/null
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$fortad_pin"; test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$tapenade_pin"
test -x "$fortad"; test -x "$tapenade"
for file in program.f program_d.f program_d.msg Options MyGeneralLib; do test -s "$source_dir/$file"; done
strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -fsyntax-only -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)
legacy=(-std=legacy -ffixed-form -ffixed-line-length-none -fsyntax-only -Wall -Wextra -Wimplicit-interface -fno-lto)
free=(-std=f2018 -ffree-form -ffree-line-length-none -fsyntax-only -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)
run_status() { local label=$1; shift; set +e; "$@" >"$out/$label.stdout" 2>"$out/$label.stderr"; local status=$?; set -e; echo "$status" >"$out/$label.status"; }
compile_gate() { local label=$1; shift; local flags=$1; shift; run_status "$label" "$fc" $flags "$@"; }
for file in program program_d; do
    compile_gate strict-$file "${strict[*]}" "$source_dir/$file.f"; compile_gate legacy-$file "${legacy[*]}" "$source_dir/$file.f"
    test "$(cat "$out/strict-$file.status")" -eq 0; test "$(cat "$out/legacy-$file.status")" -eq 0
done
mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse"
(cd "$tapenade_repo" && run_status tapenade-parser "$tapenade" -p -ext "$source_rel/MyGeneralLib" -O "$out/fresh/parser" -o lh094 "$source_dir/program.f")
(cd "$tapenade_repo" && run_status tapenade-forward "$tapenade" -d -root test -ext "$source_rel/MyGeneralLib" -O "$out/fresh/forward" -o lh094 "$source_dir/program.f")
(cd "$tapenade_repo" && run_status tapenade-reverse "$tapenade" -b -root test -ext "$source_rel/MyGeneralLib" -O "$out/fresh/reverse" -o lh094 "$source_dir/program.f")
for mode in parser forward reverse; do suffix=p; [ "$mode" = forward ] && suffix=d; [ "$mode" = reverse ] && suffix=b; generated="$out/fresh/$mode/lh094_${suffix}.f"; test "$(cat "$out/tapenade-$mode.status")" -eq 0; test -s "$generated"; compile_gate fresh-$mode "${strict[*]}" "$generated"; test "$(cat "$out/fresh-$mode.status")" -eq 0; done
run_status fortad-check "$fortad" check --output "$out/check.f90" "$source_dir/program.f"; test "$(cat "$out/fortad-check.status")" -eq 0; test -s "$out/check.f90"; compile_gate fortad-check-compile "${free[*]}" "$out/check.f90"; test "$(cat "$out/fortad-check-compile.status")" -ne 0; grep -Fq "has no IMPLICIT type" "$out/fortad-check-compile.stderr"
run_status fortad-forward "$fortad" --mode forward --indep a --dep b --proc test --name lh094_jvp --module lh094_jvp_mod --output "$out/forward.f90" "$source_dir/program.f"
run_status fortad-reverse "$fortad" --mode reverse --indep a --dep b --proc test --name lh094_vjp --module lh094_vjp_mod --output "$out/reverse.f90" "$source_dir/program.f"
for mode in forward reverse; do test "$(cat "$out/fortad-$mode.status")" -ne 0; grep -Fq "no derivative rule for 'DISACTIVATE'" "$out/fortad-$mode.stdout" "$out/fortad-$mode.stderr"; test ! -e "$out/$mode.f90"; done
oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir"); grep -Fqx 'oracle_status: pass' <<<"$oracle_output"
cpu=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
{ echo 'case: Tapenade nonRegressions set01 lh094'; echo 'classification: expected-refusal-fortad-external-derivative-rule'; echo 'runner_result: pass'; echo "recorded_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo "machine: $(hostname)"; echo "cpu: $cpu"; echo "compiler: $($fc --version | head -1)"; echo "strict_fixed_flags: ${strict[*]}"; echo "legacy_fixed_flags: ${legacy[*]}"; echo "fortad_commit: $(git -C "$fortad_repo" rev-parse HEAD)"; echo "tapenade_commit: $(git -C "$tapenade_repo" rev-parse HEAD)"; echo 'upstream_entry_point: test(a,b)'; echo 'stored_compile: strict+legacy program=pass program_d=pass'; echo "tapenade_generation: parser=$(cat "$out/tapenade-parser.status") tangent=$(cat "$out/tapenade-forward.status") reverse=$(cat "$out/tapenade-reverse.status")"; echo "tapenade_fresh_strict_compile: parser=$(cat "$out/fresh-parser.status") tangent=$(cat "$out/fresh-forward.status") reverse=$(cat "$out/fresh-reverse.status")"; echo "fortad_exact_behavior: check=pass check_strict_compile=expected-refusal-no-implicit-type forward=expected-refusal reverse=expected-refusal diagnostic=no-derivative-rule-DISACTIVATE no-output"; echo 'independent_oracle: source-shape identity-summary JVP-finite-difference VJP-dot-product'; echo "$oracle_output"; echo 'no_repaired_port: exact external implementation intentionally absent'; echo 'upstream_sha256:'; (cd "$source_dir" && sha256sum program.f program_d.f program_d.msg Options MyGeneralLib); echo 'fresh_tapenade_sha256:'; (cd "$out/fresh/parser" && sha256sum lh094_p.f lh094_p.msg); (cd "$out/fresh/forward" && sha256sum lh094_d.f lh094_d.msg); (cd "$out/fresh/reverse" && sha256sum lh094_b.f lh094_b.msg); echo 'case_artifact_sha256:'; (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py); } >"$result"
cat "$result"
