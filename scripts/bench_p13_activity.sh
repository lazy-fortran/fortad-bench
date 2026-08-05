#!/usr/bin/env bash
# Measure reverse activity on the plain-array VMEC++ arithmetic kernel.
# Run on a TU Graz host; the workstation is not a benchmark fallback.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
fortad_bin=${FORTAD_BIN:-$(find "$fortad_repo/build" -name fortad -type f -perm -u+x 2>/dev/null | head -1)}
fc=${FC:-gfortran}
out=build/p13-activity
mkdir -p "$out" results

test -x "$fortad_bin"
command -v "$fc" >/dev/null

t0=$(date +%s.%N)
"$fortad_bin" --mode reverse \
  --indep r1e,r1o,z1e,z1o,rue,ruo,zue,zuo --dep loss \
  --name vmec_vjp --module vmec_ad \
  -o "$out/vmec_vjp.f90" cases/vmec-jacobian/primal_plain.f90 \
  2>"$out/transform.err"
t1=$(date +%s.%N)
transform_seconds=$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.6f", b-a }')

"$fc" -O3 -ffree-line-length-none \
  -fopt-info-vec-all="$out/vectorization.txt" -c \
  cases/vmec-jacobian/primal_plain.f90 -o "$out/primal.o"
"$fc" -O3 -ffree-line-length-none \
  -fopt-info-vec-all="$out/vectorization-vjp.txt" -c \
  "$out/vmec_vjp.f90" -o "$out/vmec_vjp.o"
"$fc" -O3 -ffree-line-length-none -c harness/bench_p13_activity.f90 \
  -o "$out/driver.o"
t2=$(date +%s.%N)
"$fc" -O3 -o "$out/bench" "$out/primal.o" "$out/vmec_vjp.o" \
  "$out/driver.o"
t3=$(date +%s.%N)
compile_seconds=$(awk -v a="$t1" -v b="$t3" 'BEGIN { printf "%.6f", b-a }')

"/usr/bin/time" -f 'peak_rss_kb=%M' "$out/bench" >"$out/run.txt" 2>"$out/time.txt"
cat "$out/run.txt"
cat "$out/time.txt"

# Count arithmetic sites, not generated assignments: the reverse sweep also
# recomputes active values, so counting every emitted line would count work
# twice. The first reverse forward sweep is the activity decision we measure.
candidate=$(awk '/^[[:space:]]+do ih =/{inside=1; next} inside && /^[[:space:]]+(r12|ru12|zu12|rs|zs|tau1|tau2|tau|loss)[[:space:]]*=/{n++} END {print n+0}' \
  cases/vmec-jacobian/primal_plain.f90)
emitted=$(awk '/^[[:space:]]+loss_v2 = loss_v1/{inside=1; next} inside && /^[[:space:]]+(ru12_v1|zu12_v1|rs_v1|zs_v1|fad_s2|fad_s1|fad_s3|loss_v2)[[:space:]]*=/{n++} /^[[:space:]]+loss = loss_v2/{inside=0} END {print n+0}' \
  "$out/vmec_vjp.f90")
eliminated=$((candidate-emitted))
fraction=$(awk -v e="$eliminated" -v c="$candidate" 'BEGIN { printf "%.6f", e/c }')
source_bytes=$(wc -c < "$out/vmec_vjp.f90")
object_bytes=$(stat -c '%s' "$out/vmec_vjp.o")
object_text_bytes=$(size -A "$out/vmec_vjp.o" | awk '$1==".text"{print $2}')
vectorized=$(grep -c 'loop vectorized' "$out/vectorization-vjp.txt" || true)

{
  printf 'case: P1.3 reverse activity on the VMEC++ plain-array arithmetic kernel\n'
  printf 'machine: %s\n' "$(hostname)"
  printf 'compiler: %s\n' "$($fc --version | head -1)"
  printf 'shape: nhalf=12, nznT=32\n'
  printf 'candidate derivative statements: %s\n' "$candidate"
  printf 'emitted active derivative statements: %s\n' "$emitted"
  printf 'eliminated statements: %s\n' "$eliminated"
  printf 'eliminated fraction: %s\n' "$fraction"
  printf 'transform_seconds: %s\n' "$transform_seconds"
  printf 'compile_and_link_seconds: %s\n' "$compile_seconds"
  printf 'generated_source_bytes: %s\n' "$source_bytes"
  printf 'generated_object_bytes: %s\n' "$object_bytes"
  printf 'generated_object_text_bytes: %s\n' "$object_text_bytes"
  printf 'peak_rss_kb: %s\n' "$(awk -F= '/peak_rss_kb=/{print $2}' "$out/time.txt")"
  printf 'vectorized_loop_messages: %s\n' "$vectorized"
  printf 'oracle: independent central finite difference of the plain primal\n'
  cat "$out/run.txt"
  printf 'vectorization_report: build/p13-activity/vectorization-vjp.txt\n'
  printf 'note: the derived-type allocation wrapper remains outside fortad\x27s\n'
  printf '      supported source subset; this records the exact kernel arithmetic.\n'
} > results/p13_activity_validation.txt
cat results/p13_activity_validation.txt
