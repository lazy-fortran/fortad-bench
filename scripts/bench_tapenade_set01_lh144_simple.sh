#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../cases/tapenade-set01-lh144-simple" && pwd)
bench_root=$(cd "$case_dir/../.." && pwd)
fortad_repo=$(cd "${FORTAD_REPO:-$bench_root/../fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$bench_root/upstream/tapenade}" && pwd)
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
fc=${FC:-gfortran}
source_file="$tapenade_repo/nonRegressions/set01/lh144/program.f"
result="$bench_root/results/tapenade_set01_lh144_simple.txt"
out=$(mktemp -d /var/tmp/fortad-bench-set01-lh144.XXXXXX)
trap 'rm -rf "$out"' EXIT

test -x "$fortad" && test -x "$tapenade"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "e6ba3ecfd4484682143ade1a0fdfedd694b18798"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "e59864cab441d4175df75383b3ff58c3dcd26df9"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -s "$source_file"

strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -fsyntax-only)
mkdir -p "$out/tapenade" "$out/fortad"
"$fc" "${strict[@]}" "$source_file"
for mode in p d b; do
  "$tapenade" "-$mode" -root top -O "$out/tapenade" -o lh144 "$source_file"
  generated="$out/tapenade/lh144_${mode}.f"
  test -s "$generated"
  "$fc" "${strict[@]}" "$generated"
done

"$fortad" check --proc top --output "$out/fortad/check.f90" "$source_file"
"$fortad" --mode forward --proc top --indep x,y --dep x --name top_jvp \
  --module top_jvp_mod --output "$out/fortad/forward.f90" "$source_file"
"$fc" -std=f2018 -ffree-line-length-none -pedantic-errors -Wall -Wextra \
  -fsyntax-only "$out/fortad/forward.f90"
if "$fortad" --mode reverse --proc top --indep x,y --dep x --name top_vjp \
  --module top_vjp_mod --output "$out/fortad/reverse.f90" "$source_file"; then
  "$fc" -std=f2018 -ffree-line-length-none -pedantic-errors -Wall -Wextra \
    -fsyntax-only "$out/fortad/reverse.f90" && exit 1
fi
grep -Fq "subroutine top_vjp(x, y, x_b, x_b, y_b)" "$out/fortad/reverse.f90"

"$fc" -std=f2018 -ffree-line-length-none -O0 -o "$out/oracle" \
  "$case_dir/harness.f90"
"$out/oracle" | grep -Fqx 'oracle_status: pass'
python3 "$case_dir/oracle.py" | grep -Fqx 'oracle_status: pass'

mkdir -p "$(dirname "$result")"
{
  printf 'case: Tapenade nonRegressions/set01/lh144\n'
  printf 'classification: expected-refusal-fortad-generated-duplicate-adjoint\n'
  printf 'runner_result: pass\n'
  printf 'fortad_revision: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
  printf 'tapenade_revision: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
  printf 'tapenade_modes: parser forward reverse strict-compile-pass\n'
  printf 'fortad_check: pass\nfortad_forward: generated-and-strict-compile-pass\n'
  printf 'fortad_reverse: expected-refusal-generated-duplicate-x_b\n'
  printf 'independent_oracle: hand-primal jvp-finite-difference vjp-dot-product\n'
  printf 'oracle_status: pass\n'
  printf 'source_sha256: '; sha256sum "$source_file"
} >"$result"
cat "$result"
