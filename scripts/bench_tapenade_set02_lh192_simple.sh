#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../cases/tapenade-set02-lh192-simple" && pwd)
bench_root=$(cd "$case_dir/../.." && pwd)
fortad_repo=$(cd "${FORTAD_REPO:-$bench_root/../fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$bench_root/upstream/tapenade}" && pwd)
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
fc=${FC:-gfortran}
source_file="$tapenade_repo/nonRegressions/set02/lh192/program.f"
result="$bench_root/results/tapenade_set02_lh192_simple.txt"
out=$(mktemp -d /var/tmp/fortad-bench-set02-lh192.XXXXXX)
trap 'rm -rf "$out"' EXIT

test -x "$fortad" && test -x "$tapenade"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "e6ba3ecfd4484682143ade1a0fdfedd694b18798"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "e59864cab441d4175df75383b3ff58c3dcd26df9"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -fsyntax-only)
"$fc" "${strict[@]}" "$source_file"
mkdir -p "$out/tapenade"
for mode in p d b; do
  "$tapenade" "-$mode" -root test -O "$out/tapenade" -o lh192 "$source_file"
  generated="$out/tapenade/lh192_${mode}.f"
  test -s "$generated"
  "$fc" "${strict[@]}" "$generated"
done

mkdir -p "$out/fortad"
"$fortad" check --proc test --output "$out/fortad/check.f90" "$source_file"
"$fortad" --mode forward --proc test --indep x,pkz --dep y --name test_jvp \
  --module test_jvp_mod --output "$out/fortad/forward.f90" "$source_file"
"$fc" -std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors \
  -Wall -Wextra -fsyntax-only "$out/fortad/forward.f90"
grep -Eq 'pkz_d\(i, j, k\)|pkz_d\(i,j,k\)' "$out/fortad/forward.f90"
grep -Eq 'pkz\(i, j, k\)|pkz\(i,j,k\)' "$out/fortad/forward.f90"
if "$fortad" --mode reverse --proc test --indep x,pkz --dep y --name test_vjp \
  --module test_vjp_mod --output "$out/fortad/reverse.f90" "$source_file" \
  >"$out/reverse.stdout" 2>"$out/reverse.stderr"; then
  echo 'FortAD unexpectedly accepted reverse checkpoint loop' >&2
  exit 1
fi
grep -Fq "needs per-iteration storage" "$out/reverse.stdout" "$out/reverse.stderr"
test ! -e "$out/fortad/reverse.f90"

"$fc" -std=f2018 -ffree-line-length-none -O0 -o "$out/oracle" "$case_dir/harness.f90"
"$out/oracle" | grep -Fqx 'oracle_status: pass'
python3 "$case_dir/oracle.py" | grep -Fqx 'oracle_status: pass'

mkdir -p "$(dirname "$result")"
{
  printf 'case: Tapenade nonRegressions/set02/lh192\n'
  printf 'classification: expected-refusal-fortad-checkpoint-loop-storage\n'
  printf 'runner_result: pass\n'
  printf 'fortad_revision: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
  printf 'tapenade_revision: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
  printf 'tapenade_modes: parser forward reverse strict-compile-pass\n'
  printf 'fortad_check: pass\nfortad_forward: syntax-compile-pass-uninitialized-loop-index-evidence\n'
  printf 'fortad_reverse: expected-refusal-per-iteration-storage\n'
  printf 'independent_oracle: hand-primal central-difference-sweep\n'
  printf 'oracle_status: pass\n'
  printf 'source_sha256: '; sha256sum "$source_file"
} >"$result"
cat "$result"
