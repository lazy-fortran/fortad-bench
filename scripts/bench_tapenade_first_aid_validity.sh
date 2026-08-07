#!/usr/bin/env bash
# Validate Tapenade's validity interval helper and FortAD's exact refusal.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-first-aid"
result="$root/results/tapenade_first_aid_validity_refusal_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
required_fortad_commit=40b8085e6ab66a338211d263b436b7ec9ea918fb
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
upstream_source="$tapenade_repo/ADFirstAidKit/validityTest.f"

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v python3 >/dev/null
test -x /usr/bin/time
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
git -C "$fortad_repo" cat-file -e "$required_fortad_commit^{commit}"
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_commit" HEAD
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

python3 - "$case_dir/manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
if manifest["upstream_revision"] != \
        "e59864cab441d4175df75383b3ff58c3dcd26df9":
    raise SystemExit("validity manifest revision differs from runner")
if manifest["entry_point"] != "validity_domain_real8(t,td)":
    raise SystemExit("validity manifest entry point differs from runner")
if manifest["classification"] != "expected-refusal":
    raise SystemExit("validity manifest classification differs from runner")
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-first-aid-validity.XXXXXX")
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse"

setup_start=$(date +%s.%N)
(cd "$fortad_repo" && fo build) >"$out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

strict_start=$(date +%s.%N)
set +e
"$fc" -std=f2018 -pedantic-errors -ffixed-line-length-none -c \
    "$upstream_source" -o "$out/upstream-strict.o" \
    >"$out/strict.stdout" 2>"$out/strict.stderr"
strict_status=$?
set -e
strict_stop=$(date +%s.%N)
strict_seconds=$(awk -v a="$strict_start" -v b="$strict_stop" \
    'BEGIN {printf "%.6f", b-a}')
test "$strict_status" -ne 0
grep -Fq 'Nonstandard type declaration REAL*8' "$out/strict.stderr"
grep -Fq 'Nonstandard type declaration REAL*4' "$out/strict.stderr"

compile_start=$(date +%s.%N)
"$fc" -std=legacy -O3 -ffixed-line-length-none -fno-lto -c \
    "$upstream_source" -o "$out/upstream.o"
"$fc" -std=f2018 -O3 -fno-lto -c \
    "$root/harness/bench_tapenade_first_aid_validity.f90" \
    -o "$out/harness.o"
"$fc" -O3 -fno-lto -o "$out/bench" "$out/upstream.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

export PATH="$tapenade_repo/bin:$PATH"
tapenade_parser_start=$(date +%s.%N)
"$tapenade_repo/bin/tapenade" -p -O "$out/tapenade/parser" -o validity \
    "$upstream_source" >"$out/tapenade-parser.stdout" \
    2>"$out/tapenade-parser.stderr"
tapenade_parser_stop=$(date +%s.%N)
tapenade_parser_seconds=$(awk -v a="$tapenade_parser_start" \
    -v b="$tapenade_parser_stop" 'BEGIN {printf "%.6f", b-a}')

tapenade_forward_start=$(date +%s.%N)
"$tapenade_repo/bin/tapenade" -d -root validity_domain_real8 \
    -O "$out/tapenade/forward" -o validity "$upstream_source" \
    >"$out/tapenade-forward.stdout" 2>"$out/tapenade-forward.stderr"
tapenade_forward_stop=$(date +%s.%N)
tapenade_forward_seconds=$(awk -v a="$tapenade_forward_start" \
    -v b="$tapenade_forward_stop" 'BEGIN {printf "%.6f", b-a}')

tapenade_reverse_start=$(date +%s.%N)
"$tapenade_repo/bin/tapenade" -b -root validity_domain_real8 \
    -O "$out/tapenade/reverse" -o validity "$upstream_source" \
    >"$out/tapenade-reverse.stdout" 2>"$out/tapenade-reverse.stderr"
tapenade_reverse_stop=$(date +%s.%N)
tapenade_reverse_seconds=$(awk -v a="$tapenade_reverse_start" \
    -v b="$tapenade_reverse_stop" 'BEGIN {printf "%.6f", b-a}')

generated_compile_start=$(date +%s.%N)
for generated in "$out/tapenade/parser/validity_p.f" \
    "$out/tapenade/forward/validity_d.f" \
    "$out/tapenade/reverse/validity_b.f"; do
    test -s "$generated"
    object="$out/$(basename "$generated").o"
    "$fc" -std=legacy -ffixed-line-length-none -c "$generated" -o "$object"
done
generated_compile_stop=$(date +%s.%N)
generated_compile_seconds=$(awk -v a="$generated_compile_start" \
    -v b="$generated_compile_stop" 'BEGIN {printf "%.6f", b-a}')

fortad_start=$(date +%s.%N)
set +e
(cd "$fortad_repo" && fo exec --no-build fortad --mode forward \
    --indep t,td --proc validity_domain_real8 --name validity_domain_real8_d \
    --module validity_domain_forward_ad --output "$out/fortad-forward.f90" \
    "$upstream_source") >"$out/fortad.stdout" 2>"$out/fortad.stderr"
fortad_status=$?
set -e
fortad_stop=$(date +%s.%N)
fortad_seconds=$(awk -v a="$fortad_start" -v b="$fortad_stop" \
    'BEGIN {printf "%.6f", b-a}')
test "$fortad_status" -ne 0
fortad_diagnostic=$(grep -F 'fortad: unsupported statement at line 21' \
    "$out/fortad.stderr" | tail -1)
test "$fortad_diagnostic" = 'fortad: unsupported statement at line 21'
test ! -e "$out/fortad-forward.f90"

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" \
    2>"$out/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'case: Tapenade ADFirstAidKit validityTest.f refusal\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'fortad_setup_seconds: %s\n' "$setup_seconds"
    printf 'upstream_strict_compile_seconds: %s\n' "$strict_seconds"
    printf 'upstream_strict_compile_status: %s\n' "$strict_status"
    printf 'upstream_legacy_compile_and_link_seconds: %s\n' "$compile_seconds"
    printf 'tapenade_parser_seconds: %s\n' "$tapenade_parser_seconds"
    printf 'tapenade_forward_seconds: %s\n' "$tapenade_forward_seconds"
    printf 'tapenade_reverse_seconds: %s\n' "$tapenade_reverse_seconds"
    printf 'tapenade_generated_compile_seconds: %s\n' \
        "$generated_compile_seconds"
    printf 'fortad_forward_seconds: %s\n' "$fortad_seconds"
    printf 'fortad_forward_status: %s\n' "$fortad_status"
    printf 'tapenade_forward_source_bytes: %s\n' \
        "$(wc -c <"$out/tapenade/forward/validity_d.f")"
    printf 'tapenade_reverse_source_bytes: %s\n' \
        "$(wc -c <"$out/tapenade/reverse/validity_b.f")"
    cat "$out/runtime-metrics.txt"
    printf 'upstream_compiler_oracle: exact source compiles and links with '
    printf '%s\n' '-std=legacy; strict F2018 rejects only REAL*8 and REAL*4 extensions'
    printf 'tapenade_oracle: fresh parser, forward, and reverse outputs exist '
    printf '%s\n' 'and compile with -std=legacy'
    printf 'primal_oracle: eight independent lower, upper, inactive, zero-direction, '
    printf '%s\n' 'and real4 interval-state checks'
    printf 'fortad_refusal_oracle: exact nonzero transform status, exact COMMON-line '
    printf '%s\n' 'diagnostic, and no generated source'
    printf 'fortad_diagnostic: %s\n' "$fortad_diagnostic"
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-first-aid/manifest.toml \
        cases/tapenade-first-aid/README.md \
        harness/bench_tapenade_first_aid_validity.f90 \
        scripts/bench_tapenade_first_aid_validity.sh)
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"

cat "$result"
