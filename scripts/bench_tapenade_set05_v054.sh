#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
fc=${FC:-gfortran}
result="$root/results/tapenade_set05_v054_validation.txt"
source="$tapenade_repo/nonRegressions/set05/v054/program.f90"
strict=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)
command -v "$fc" >/dev/null; command -v java >/dev/null
test -x "$fortad"; test -x "$tapenade"; test -f "$source"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = e59864cab441d4175df75383b3ff58c3dcd26df9
out=$(mktemp -d /var/tmp/tapenade-set05-v054.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out"/mod/{exact,parser,forward,reverse,fortad-forward,fortad-reverse,harness} "$out"/tapenade/{parser,forward,reverse}
compile() { "$fc" "${strict[@]}" -J"$3" -I"$3" -c "$1" -o "$2"; }
compile "$source" "$out/exact.o" "$out/mod/exact"
(cd "$(dirname "$source")" && "$tapenade" -p -root f_vector -O "$out/tapenade/parser" -o v054 program.f90)
(cd "$(dirname "$source")" && "$tapenade" -d -root f_vector -O "$out/tapenade/forward" -o v054 program.f90)
(cd "$(dirname "$source")" && "$tapenade" -b -root f_vector -O "$out/tapenade/reverse" -o v054 program.f90)
for mode in parser forward reverse; do
  generated=$(find "$out/tapenade/$mode" -name '*.f90' -print -quit)
  test -s "$generated"
  compile "$generated" "$out/$mode.o" "$out/mod/$mode"
done
fortad_exec() { (cd "$fortad_repo" && fo exec --no-build fortad "$@"); }
fortad_exec jvp x --proc f_vector --name f_vector_jvp --module tapenade_set05_v054_forward_ad --output "$out/fortad-forward.f90" "$root/cases/tapenade-set05/v054.f90"
fortad_exec vjp x --dep y --proc f_vector --name f_vector_vjp --module tapenade_set05_v054_reverse_ad --output "$out/fortad-reverse.f90" "$root/cases/tapenade-set05/v054.f90"
compile "$out/fortad-forward.f90" "$out/fortad-forward.o" "$out/mod/fortad-forward"
compile "$out/fortad-reverse.f90" "$out/fortad-reverse.o" "$out/mod/fortad-reverse"
compile "$root/cases/tapenade-set05/v054.f90" "$out/port.o" "$out/mod/exact"
compile "$root/cases/tapenade-set05/hand_derivative_v054.f90" "$out/hand.o" "$out/mod/exact"
"$fc" "${strict[@]}" -J"$out/mod/harness" -I"$out/mod/harness" -I"$out/mod/exact" -I"$out/mod/fortad-forward" -I"$out/mod/fortad-reverse" -c "$root/harness/bench_tapenade_set05_v054.f90" -o "$out/harness.o"
"$fc" "${strict[@]}" -J"$out/mod/harness" -I"$out/mod/exact" -I"$out/mod/fortad-forward" -I"$out/mod/fortad-reverse" -o "$out/run" "$out/port.o" "$out/hand.o" "$out/fortad-forward.o" "$out/fortad-reverse.o" "$out/harness.o"
run_output=$("$out/run")
grep -Fqx 'oracle_status: pass' <<<"$run_output"
mkdir -p "$(dirname "$result")"
{
  printf 'suite: Tapenade nonRegressions set05 v054 f_vector\n'
  printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'compiler: %s\n' "$($fc --version | head -1)"
  printf 'strict_flags: %s\n' "${strict[*]}"
  printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
  printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
  printf 'entry_point: f_vector(x)\n'
  printf 'upstream_exact_strict_compile: pass\n'
  printf 'tapenade_generation: parser=0 tangent=0 reverse=0\n'
  printf 'tapenade_generated_strict_compile: parser=0 tangent=0 reverse=0\n'
  printf 'fortad_transformation: jvp=0 vjp=0\n'
  printf 'fortad_generated_strict_compile: jvp=0 vjp=0\n'
  printf 'independent_oracle: hand JVP/VJP, central-difference sweep, adjoint identity\n'
  printf '%s\n' "$run_output"
  printf 'upstream_sha256:\n'
  sha256sum "$source" "$tapenade_repo/nonRegressions/set05/v054/program_p.f90" "$tapenade_repo/nonRegressions/set05/v054/program_p.msg"
  printf 'stored_case_sha256:\n'
  (cd "$root" && sha256sum cases/tapenade-set05/v054.f90 cases/tapenade-set05/hand_derivative_v054.f90 cases/tapenade-set05/tranche-v054-manifest.toml cases/tapenade-set05/tranche-v054.md harness/bench_tapenade_set05_v054.f90 scripts/bench_tapenade_set05_v054.sh)
} >"$result"
cat "$result"
