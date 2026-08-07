#!/usr/bin/env bash
# Validate exact Tapenade set01 lh007 and its normalized FortAD oracle port.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh007_refusal_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -Wall -Wextra \
    -ffixed-line-length-none -fno-lto)
compile_flags=(-std=f2018 -pedantic-errors -Wall -Wextra -O2 \
    -ffree-line-length-none -fno-lto)

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$tapenade_repo/bin/tapenade"

python3 - "$case_dir/lh007-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
if manifest["runner"] != "scripts/bench_tapenade_set01_lh007.sh":
    raise SystemExit("lh007 manifest names a different runner")
if manifest["upstream_revision"] != \
        "e59864cab441d4175df75383b3ff58c3dcd26df9":
    raise SystemExit("lh007 manifest revision differs from runner")
if manifest["classification"] != "expected-refusal":
    raise SystemExit("lh007 must remain an expected refusal")
if manifest["expected_diagnostic"] != \
        "fortad: unsupported statement at line 6":
    raise SystemExit("lh007 refusal diagnostic changed")
PY

mkdir -p "$root/results"
out=$(mktemp -d /var/tmp/ert/tapenade-set01-lh007.XXXXXX)
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/mod" "$out/tapenade/parser" "$out/tapenade/forward" \
    "$out/tapenade/reverse"

tapenade="$tapenade_repo/bin/tapenade"
upstream_dir="$tapenade_repo/nonRegressions/set01/lh007"

compile_capture() {
    local source=$1 object=$2 status_file=$3 flags_name=$4
    local -a flags
    if test "$flags_name" = strict; then
        flags=("${strict_flags[@]}")
    else
        flags=("${compile_flags[@]}" "-J$out/mod" "-I$out/mod")
    fi
    set +e
    "$fc" "${flags[@]}" -c "$source" -o "$object" \
        >"$object.stdout" 2>"$object.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$status_file"
    test "$status" -eq 0
}

upstream_start=$(date +%s.%N)
for source in "$upstream_dir/program.f" "$upstream_dir/program_p.f" \
        "$upstream_dir/program_d.f" "$upstream_dir/program_b.f"; do
    base=$(basename "$source" .f)
    compile_capture "$source" "$out/upstream-$base.o" \
        "$out/upstream-$base.status" strict
done
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" \
    'BEGIN {printf "%.6f", b-a}')

tapenade_start=$(date +%s.%N)
"$tapenade" -p -O "$out/tapenade/parser" -o lh007_p \
    "$upstream_dir/program.f" >"$out/tapenade/parser.stdout" \
    2>"$out/tapenade/parser.stderr"
"$tapenade" -d -root adj3 -O "$out/tapenade/forward" -o lh007_d \
    "$upstream_dir/program.f" >"$out/tapenade/forward.stdout" \
    2>"$out/tapenade/forward.stderr"
"$tapenade" -b -root adj3 -O "$out/tapenade/reverse" -o lh007_b \
    "$upstream_dir/program.f" >"$out/tapenade/reverse.stdout" \
    2>"$out/tapenade/reverse.stderr"
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" \
    'BEGIN {printf "%.6f", b-a}')

for generated in "$out/tapenade/parser/lh007_p_p.f" \
        "$out/tapenade/forward/lh007_d_d.f" "$out/tapenade/reverse/lh007_b_b.f"; do
    test -s "$generated"
    base=$(basename "$generated" .f)
    compile_capture "$generated" "$out/tapenade-$base.o" \
        "$out/tapenade-$base.status" strict
done
for message in "$out/tapenade/parser/lh007_p_p.msg" \
        "$out/tapenade/forward/lh007_d_d.msg" "$out/tapenade/reverse/lh007_b_b.msg"; do
    test -s "$message"
    grep -Fq 'TC30' "$message"
    grep -Fq 'DF03' "$message"
done
fortad_exact_start=$(date +%s.%N)
set +e
(cd "$fortad_repo" && fo exec --no-build fortad --mode forward \
    --indep z,t --proc adj3 --name lh007_exact_jvp \
    --module lh007_exact_forward --output "$out/lh007_exact_forward.f90" \
    "$upstream_dir/program.f") >"$out/exact-forward.stdout" \
    2>"$out/exact-forward.stderr"
exact_forward_status=$?
(cd "$fortad_repo" && fo exec --no-build fortad --mode reverse \
    --indep z,t --dep t --proc adj3 --name lh007_exact_vjp \
    --module lh007_exact_reverse --output "$out/lh007_exact_reverse.f90" \
    "$upstream_dir/program.f") >"$out/exact-reverse.stdout" \
    2>"$out/exact-reverse.stderr"
exact_reverse_status=$?
set -e
fortad_exact_stop=$(date +%s.%N)
fortad_exact_seconds=$(awk -v a="$fortad_exact_start" -v b="$fortad_exact_stop" \
    'BEGIN {printf "%.6f", b-a}')
test "$exact_forward_status" -ne 0
test "$exact_reverse_status" -ne 0
grep -Fq 'fortad: unsupported statement at line 6' \
    "$out/exact-forward.stderr"
grep -Fq 'fortad: unsupported statement at line 6' \
    "$out/exact-reverse.stderr"
test ! -e "$out/lh007_exact_forward.f90"
test ! -e "$out/lh007_exact_reverse.f90"

fortad_port_start=$(date +%s.%N)
(cd "$fortad_repo" && fo exec --no-build fortad jvp \
    z,t,x5,x8,x10,y,u,v --proc set01_lh007 --name lh007_jvp \
    --module lh007_forward --output "$out/lh007_forward.f90" \
    "$case_dir/lh007.f90") >"$out/port-forward.stdout" \
    2>"$out/port-forward.stderr"
(cd "$fortad_repo" && fo exec --no-build fortad vjp \
    z,t,x5,x8,x10,y,u,v --dep t_out --proc set01_lh007 \
    --name lh007_vjp --module lh007_reverse --output "$out/lh007_reverse.f90" \
    "$case_dir/lh007.f90") >"$out/port-reverse.stdout" \
    2>"$out/port-reverse.stderr"
fortad_port_stop=$(date +%s.%N)
fortad_port_seconds=$(awk -v a="$fortad_port_start" -v b="$fortad_port_stop" \
    'BEGIN {printf "%.6f", b-a}')

for source in "$case_dir/lh007.f90" \
        "$case_dir/hand_derivatives_lh007.f90" \
        "$out/lh007_forward.f90" "$out/lh007_reverse.f90"; do
    base=$(basename "$source" .f90)
    compile_capture "$source" "$out/$base.o" "$out/$base.status" normal
done
compile_capture "$root/harness/bench_tapenade_set01_lh007.f90" \
    "$out/harness.o" "$out/harness.status" normal
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/lh007_forward.o" "$out/lh007_reverse.o" \
    "$out/hand_derivatives_lh007.o" "$out/harness.o"

set +e
/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" \
    2>"$out/run.stderr"
run_status=$?
set -e
if test "$run_status" -ne 0 || \
        ! grep -Fqx 'oracle_status: pass' "$out/run.txt"; then
    cat "$out/run.txt" >&2 || true
    cat "$out/run.stderr" >&2 || true
    exit 1
fi

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh007 exact-source refusal\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'compile_flags: %s\n' "${compile_flags[*]}"
    printf 'fo: %s\n' "$(fo version)"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_exact_compile_seconds: %s\n' "$upstream_seconds"
    printf 'tapenade_transform_seconds_total: %s\n' "$tapenade_seconds"
    printf 'fortad_exact_refusal_seconds_total: %s\n' "$fortad_exact_seconds"
    printf 'fortad_port_transform_seconds_total: %s\n' "$fortad_port_seconds"
    printf 'upstream_exact_source_compile_statuses: program.f=0 program_p.f=0 program_d.f=0 program_b.f=0\n'
    printf 'tapenade_result: fresh parser, tangent, and reverse outputs generated; '
    printf '%s\n' 'all generated sources compile under strict fixed-form flags'
    printf 'tapenade_generated_compile_statuses: lh007_p_p.f=0 lh007_d_d.f=0 lh007_b_b.f=0\n'
    printf 'fortad_exact_forward_status: %s\n' "$exact_forward_status"
    printf 'fortad_exact_reverse_status: %s\n' "$exact_reverse_status"
    printf 'fortad_exact_diagnostic: fortad: unsupported statement at line 6\n'
    printf 'fortad_exact_result: expected-refusal; no exact-source support claimed\n'
    printf 'fortad_normalized_port_result: JVP/VJP transform and strict compile pass\n'
    printf 'independent_oracle: hand JVP/VJP, three-step central-difference sweep, and adjoint identity\n'
    cat "$out/runtime-metrics.txt"
    printf 'oracle_status: pass\n'
    printf 'upstream_source_and_reference_sha256:\n'
    (cd "$tapenade_repo" && sha256sum \
        nonRegressions/set01/lh007/program*.f \
        nonRegressions/set01/lh007/program*.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/lh007.f90 \
        cases/tapenade-set01/hand_derivatives_lh007.f90 \
        cases/tapenade-set01/lh007-manifest.toml \
        cases/tapenade-set01/lh007.md \
        harness/bench_tapenade_set01_lh007.f90 \
        scripts/bench_tapenade_set01_lh007.sh)
    printf 'run_output:\n'
    cat "$out/run.txt"
    printf 'tapenade_diagnostics:\n'
    cat "$out/tapenade/parser/lh007_p_p.msg"
} >"$result"
cat "$result"
