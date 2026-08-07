#!/usr/bin/env bash
# Validate the testMemSizef runtime probe and its no-active-data refusal.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-first-aid-kit/testMemSizef"
result="$root/results/tapenade_firstaid_memsize_refusal_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
required_fortad_commit=40b8085e6ab66a338211d263b436b7ec9ea918fb
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
cc=${CC:-gcc}
fortran_flags=(-O3 -std=legacy -ffixed-line-length-none -fno-align-commons)
c_flags=(-O3 -std=c11 -Wall -Wextra -pedantic)

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v "$cc" >/dev/null
command -v python3 >/dev/null
test -x /usr/bin/time
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
git -C "$fortad_repo" cat-file -e "$required_fortad_commit^{commit}"
if ! git -C "$fortad_repo" merge-base --is-ancestor \
    "$required_fortad_commit" HEAD; then
    printf 'FortAD HEAD must contain %s\n' "$required_fortad_commit" >&2
    exit 1
fi
if test -n "$(git -C "$fortad_repo" status --porcelain \
    --untracked-files=no)"; then
    printf 'FortAD checkout has tracked changes; refusing an ambiguous run\n' >&2
    exit 1
fi
if test "$(git -C "$tapenade_repo" rev-parse HEAD)" != \
    "$required_tapenade_commit"; then
    printf 'Tapenade checkout must be pinned at %s\n' \
        "$required_tapenade_commit" >&2
    exit 1
fi
if test -n "$(git -C "$tapenade_repo" status --porcelain \
    --untracked-files=no)"; then
    printf 'Tapenade checkout has tracked changes; refusing an ambiguous run\n' >&2
    exit 1
fi

python3 - "$case_dir/manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
case = manifest["case"][0]
if manifest["runner"] != "scripts/bench_tapenade_firstaid_memsize.sh":
    raise SystemExit("testMemSizef manifest names a different runner")
if manifest["upstream_revision"] != \
        "e59864cab441d4175df75383b3ff58c3dcd26df9":
    raise SystemExit("testMemSizef manifest revision differs from runner")
if case["entry_point"] != "program testmemsize":
    raise SystemExit("testMemSizef manifest entry point differs from runner")
if case["independent"] or case["dependent"]:
    raise SystemExit("testMemSizef must not invent active data")
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-firstaid-memsize.XXXXXX")
upstream_fortran="$tapenade_repo/ADFirstAidKit/testMemSizef.f"
upstream_c="$tapenade_repo/ADFirstAidKit/testMemSizec.c"

setup_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo build
) >"$out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

set +e
"$fc" -std=f2018 -pedantic-errors -ffixed-form -fsyntax-only \
    "$upstream_fortran" >"$out/strict.stdout" 2>"$out/strict.stderr"
strict_status=$?
set -e
test "$strict_status" -ne 0

upstream_build_start=$(date +%s.%N)
"$cc" "${c_flags[@]}" -c "$upstream_c" -o "$out/testMemSizec.o"
"$fc" "${fortran_flags[@]}" "$upstream_fortran" \
    "$out/testMemSizec.o" -o "$out/testMemSize-upstream"
upstream_build_stop=$(date +%s.%N)
upstream_build_seconds=$(awk -v a="$upstream_build_start" \
    -v b="$upstream_build_stop" 'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'upstream_runtime_wall_seconds=%e\nupstream_peak_rss_kb=%M' \
    -o "$out/upstream-metrics.txt" "$out/testMemSize-upstream" \
    >"$out/upstream-run.txt" 2>"$out/upstream-run.stderr"

oracle_build_start=$(date +%s.%N)
"$fc" -std=f2018 -pedantic-errors -O3 \
    "$root/harness/tapenade_firstaid_memsize_oracle.f90" \
    -o "$out/testMemSize-oracle"
oracle_build_stop=$(date +%s.%N)
oracle_build_seconds=$(awk -v a="$oracle_build_start" \
    -v b="$oracle_build_stop" 'BEGIN {printf "%.6f", b-a}')
"$out/testMemSize-oracle" >"$out/oracle-run.txt"

export PATH="$tapenade_repo/bin:$PATH"
mkdir -p "$out/tapenade/parse" "$out/tapenade/forward" \
    "$out/tapenade/reverse"
tapenade_parse_start=$(date +%s.%N)
(
    cd "$out"
    "$tapenade_repo/bin/tapenade" -p -O "$out/tapenade/parse" \
        -o testmemsize_p "$upstream_fortran"
) >"$out/tapenade-parse.stdout" 2>"$out/tapenade-parse.stderr"
tapenade_parse_stop=$(date +%s.%N)
tapenade_parse_seconds=$(awk -v a="$tapenade_parse_start" \
    -v b="$tapenade_parse_stop" 'BEGIN {printf "%.6f", b-a}')
parsed_source="$out/tapenade/parse/testmemsize_p_p.f"
test -s "$parsed_source"
"$fc" "${fortran_flags[@]}" "$parsed_source" \
    "$out/testMemSizec.o" -o "$out/testMemSize-parsed"
"$out/testMemSize-parsed" >"$out/parsed-run.txt"

expected_tapenade='(AD06) Differentiation root procedures (testmemsize) have no active input nor output'
for mode in forward reverse; do
    if test "$mode" = forward; then
        tapenade_mode=-d
        output_name=testmemsize_d
    else
        tapenade_mode=-b
        output_name=testmemsize_b
    fi
    mode_start=$(date +%s.%N)
    (
        cd "$out"
        "$tapenade_repo/bin/tapenade" "$tapenade_mode" \
            -root testmemsize -O "$out/tapenade/$mode" \
            -o "$output_name" "$upstream_fortran"
    ) >"$out/tapenade-$mode.stdout" 2>"$out/tapenade-$mode.stderr"
    mode_stop=$(date +%s.%N)
    awk -v a="$mode_start" -v b="$mode_stop" \
        'BEGIN {printf "%.6f\n", b-a}' >"$out/tapenade-$mode.seconds"
    message="$out/tapenade/$mode/${output_name}_${tapenade_mode#-}.msg"
    # Tapenade's output suffixes are mode-specific: *_d_d.msg and *_b_b.msg.
    if test "$mode" = forward; then
        message="$out/tapenade/forward/testmemsize_d_d.msg"
    else
        message="$out/tapenade/reverse/testmemsize_b_b.msg"
    fi
    grep -Fqx "1 $expected_tapenade" "$message"
    test "$(find "$out/tapenade/$mode" -type f ! -name '*.msg' | wc -l)" -eq 0
done

expected_fortad="fortad: no procedure named 'testmemsize' in this source"
for mode in forward reverse; do
    output="$out/fortad-$mode.f90"
    mode_start=$(date +%s.%N)
    set +e
    (
        cd "$fortad_repo"
        if test "$mode" = forward; then
            fo exec --no-build fortad --mode forward --indep r \
                --proc testmemsize --name testmemsize_jvp \
                --module testmemsize_forward_ad --output "$output" \
                "$upstream_fortran"
        else
            fo exec --no-build fortad --mode reverse --indep r --dep r \
                --proc testmemsize --name testmemsize_vjp \
                --module testmemsize_reverse_ad --output "$output" \
                "$upstream_fortran"
        fi
    ) >"$out/fortad-$mode.stdout" 2>"$out/fortad-$mode.stderr"
    status=$?
    set -e
    mode_stop=$(date +%s.%N)
    test "$status" -ne 0
    grep -Fqx "$expected_fortad" "$out/fortad-$mode.stderr"
    test ! -e "$output"
    printf '%s\n' "$status" >"$out/fortad-$mode.status"
    awk -v a="$mode_start" -v b="$mode_stop" \
        'BEGIN {printf "%.6f\n", b-a}' >"$out/fortad-$mode.seconds"
done

python3 - "$out/upstream-run.txt" "$out/parsed-run.txt" \
    "$out/oracle-run.txt" <<'PY'
import re
import sys
from pathlib import Path

expected_labels = [
    "INTEGER", "INTEGER*8", "REAL", "REAL*4", "REAL(4)", "REAL*8",
    "REAL(8)", "DOUBLE PRECISION", "COMPLEX", "COMPLEX*8", "COMPLEX(8)",
    "COMPLEX*16", "DOUBLE COMPLEX", "LOGICAL", "CHARACTER",
]

def upstream_values(path):
    values = {}
    for line in Path(path).read_text().splitlines():
        match = re.fullmatch(r"\s*(.+?):\s*([0-9]+) bytes\s*", line)
        if match:
            values[match.group(1).strip()] = int(match.group(2))
    return values

def oracle_values(path):
    values = {}
    for line in Path(path).read_text().splitlines():
        label, size = line.rsplit("|", 1)
        values[label] = int(size)
    return values

upstream = upstream_values(sys.argv[1])
parsed = upstream_values(sys.argv[2])
oracle = oracle_values(sys.argv[3])
if list(upstream) != expected_labels:
    raise SystemExit(f"unexpected upstream storage labels: {list(upstream)}")
if upstream != parsed:
    raise SystemExit(f"Tapenade parser round-trip changed output: {upstream} != {parsed}")
if upstream != oracle:
    raise SystemExit(f"storage_size oracle mismatch: {upstream} != {oracle}")
print("runtime_oracle_status: pass")
PY

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
tapenade_version=$({ "$tapenade_repo/bin/tapenade" -version || true; } \
    | head -1)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'case: Tapenade ADFirstAidKit testMemSizef\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'fortran_compiler: %s\n' "$($fc --version | head -1)"
    printf 'c_compiler: %s\n' "$($cc --version | head -1)"
    printf 'fortran_flags: %s\n' "${fortran_flags[*]}"
    printf 'c_flags: %s\n' "${c_flags[*]}"
    printf 'fo: %s\n' "$(cd "$fortad_repo" && fo version)"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'tapenade_version: %s\n' "$tapenade_version"
    printf 'fortad_setup_seconds: %s\n' "$setup_seconds"
    printf 'upstream_strict_compile_status: %s\n' "$strict_status"
    printf 'upstream_legacy_build_seconds: %s\n' "$upstream_build_seconds"
    printf 'oracle_build_seconds: %s\n' "$oracle_build_seconds"
    printf 'tapenade_parser_seconds: %s\n' "$tapenade_parse_seconds"
    printf 'tapenade_forward_seconds: %s\n' \
        "$(cat "$out/tapenade-forward.seconds")"
    printf 'tapenade_reverse_seconds: %s\n' \
        "$(cat "$out/tapenade-reverse.seconds")"
    printf 'fortad_forward_seconds: %s\n' \
        "$(cat "$out/fortad-forward.seconds")"
    printf 'fortad_reverse_seconds: %s\n' \
        "$(cat "$out/fortad-reverse.seconds")"
    printf 'fortad_forward_status: %s\n' \
        "$(cat "$out/fortad-forward.status")"
    printf 'fortad_reverse_status: %s\n' \
        "$(cat "$out/fortad-reverse.status")"
    cat "$out/upstream-metrics.txt"
    printf 'tapenade_generated_derivative_files: 0\n'
    printf 'fortad_generated_derivative_files: 0\n'
    printf 'oracle: unmodified runtime and Tapenade parser round-trip match '
    printf '%s\n' 'an independent Fortran storage_size program for all 15 types'
    printf 'derivative_contract: none; the program has no procedure arguments '
    printf '%s\n' 'and no active input or output, so finite differences and adjoint identities are not applicable'
    printf 'tapenade_diagnostic: %s\n' "$expected_tapenade"
    printf 'fortad_diagnostic: %s\n' "$expected_fortad"
    printf 'source_sha256:\n'
    (
        cd "$root"
        sha256sum \
            cases/tapenade-first-aid-kit/testMemSizef/manifest.toml \
            cases/tapenade-first-aid-kit/testMemSizef/README.md \
            harness/tapenade_firstaid_memsize_oracle.f90 \
            scripts/bench_tapenade_firstaid_memsize.sh
    )
    printf 'upstream_source_sha256:\n'
    sha256sum "$upstream_fortran" "$upstream_c"
    printf 'runtime_output:\n'
    sed 's/[[:space:]]*$//' "$out/upstream-run.txt"
    printf 'refusal_oracle_status: pass\n'
} >"$result"

cat "$result"
