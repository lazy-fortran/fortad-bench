#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../cases/tapenade-set01-lh136-simple" && pwd)
bench_root=$(cd "$case_dir/../.." && pwd)
fortad_repo=$(cd "${FORTAD_REPO:-$bench_root/../fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$bench_root/upstream/tapenade}" && pwd)
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
fc=${FC:-gfortran}
source_file="$tapenade_repo/nonRegressions/set01/lh136/program.f"
result="$bench_root/results/tapenade_set01_lh136_simple.txt"
out=$(mktemp -d /var/tmp/fortad-bench-set01-lh136.XXXXXX)
trap 'rm -rf "$out"' EXIT

test -x "$fortad" && test -x "$tapenade"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "e6ba3ecfd4484682143ade1a0fdfedd694b18798"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "e59864cab441d4175df75383b3ff58c3dcd26df9"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -fsyntax-only)
"$fc" "${strict[@]}" "$source_file"
mkdir -p "$out/tapenade"
for mode in p d b; do
  "$tapenade" "-$mode" -root eval_f -O "$out/tapenade" -o lh136 "$source_file"
  generated="$out/tapenade/lh136_${mode}.f"
  test -s "$generated"
  "$fc" "${strict[@]}" "$generated"
done

mkdir -p "$out/fortad"
for mode in check forward reverse; do
  if test "$mode" = check; then
    args=(check --proc eval_f --output "$out/fortad/check.f90")
  elif test "$mode" = forward; then
    args=(--mode forward --proc eval_f --indep x --dep y --name eval_f_jvp --module eval_f_jvp_mod --output "$out/fortad/forward.f90")
  else
    args=(--mode reverse --proc eval_f --indep x --dep y --name eval_f_vjp --module eval_f_vjp_mod --output "$out/fortad/reverse.f90")
  fi
  if "$fortad" "${args[@]}" "$source_file" >"$out/$mode.stdout" 2>"$out/$mode.stderr"; then
    echo "FortAD unexpectedly accepted $mode" >&2
    exit 1
  fi
  grep -Fq 'unsupported statement at line 30' "$out/$mode.stdout" "$out/$mode.stderr"
  test ! -e "$out/fortad/$mode.f90"
done

"$fc" -std=f2018 -ffree-line-length-none -O0 -o "$out/oracle" "$case_dir/harness.f90"
"$out/oracle" | grep -Fqx 'oracle_status: pass'
python3 "$case_dir/oracle.py" | grep -Fqx 'oracle_status: pass'

mkdir -p "$(dirname "$result")"
{
  printf 'case: Tapenade nonRegressions/set01/lh136\n'
  printf 'classification: expected-refusal-fortad-unsupported-intrinsic-declaration\n'
  printf 'runner_result: pass\n'
  printf 'fortad_revision: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
  printf 'tapenade_revision: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
  printf 'tapenade_modes: parser forward reverse strict-compile-pass\n'
  printf 'fortad_modes: check forward reverse expected-refusal-line-30\n'
  printf 'independent_oracle: hand-primal central-difference-sweep\n'
  printf 'oracle_status: pass\n'
  printf 'source_sha256: '; sha256sum "$source_file"
} >"$result"
cat "$result"
