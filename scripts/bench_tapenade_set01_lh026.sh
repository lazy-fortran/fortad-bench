#!/usr/bin/env bash
# Validate Tapenade set01 lh026 with fresh engine probes and an independent oracle.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh026_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -ffixed-line-length-none)
compile_flags=(-std=f2018 -O2 -ffree-line-length-none -fno-lto)

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
test -x /usr/bin/time
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

python3 - "$case_dir/tranche-lh026-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
case = manifest["case"][0]
if manifest["runner"] != "scripts/bench_tapenade_set01_lh026.sh":
    raise SystemExit("lh026 manifest names a different runner")
if manifest["upstream_revision"] != \
        "e59864cab441d4175df75383b3ff58c3dcd26df9":
    raise SystemExit("lh026 Tapenade revision mismatch")
if manifest["fortad_revision"] != \
        "db0050259520b618e2a0aeba203c85a7613943b5":
    raise SystemExit("lh026 FortAD revision mismatch")
if case["upstream_entry_point"] != "s1(a,b)":
    raise SystemExit("lh026 upstream entry point mismatch")
if case["ported_entry_point"] != "set01_lh026(a,b)":
    raise SystemExit("lh026 port entry point mismatch")
if case["classification"] != "expected-refusal":
    raise SystemExit("lh026 classification must record reverse refusal")
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-lh026.XXXXXX")
trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
mkdir -p "$out/mod" "$out/include" \
    "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse"
cp "$tapenade_repo/nonRegressions/DIFFSIZES.f" "$out/include/DIFFSIZES.inc"

(cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1 < /dev/null
if test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1 < /dev/null
fi
tapenade="$tapenade_repo/bin/tapenade"

compile_capture() {
    local source=$1 object=$2 status_file=$3 flags_name=$4
    local -a flags
    if test "$flags_name" = strict; then
        flags=("${strict_flags[@]}" "-I$out/include")
    else
        flags=("${compile_flags[@]}" "-J$out/mod" "-I$out/mod")
    fi
    set +e
    "$fc" "${flags[@]}" -c "$source" -o "$object" \
        >"$object.stdout" 2>"$object.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$status_file"
}

upstream_dir="$tapenade_repo/nonRegressions/set01/lh026"
for source in "$upstream_dir/program.f" "$upstream_dir/program_d.f" \
    "$upstream_dir/program_b.f" "$upstream_dir/program_dv.f"; do
    base=$(basename "$source")
    compile_capture "$source" "$out/upstream-$base.o" \
        "$out/upstream-$base.status" strict
done
test "$(cat "$out/upstream-program.f.status")" = 0
test "$(cat "$out/upstream-program_d.f.status")" = 0
test "$(cat "$out/upstream-program_b.f.status")" = 1
test "$(cat "$out/upstream-program_dv.f.status")" = 0
grep -Fq 'INTEGER*4' "$out/upstream-program_b.f.o.stderr"

"$tapenade" -p -O "$out/tapenade/parser" -o lh026 \
    "$upstream_dir/program.f" >"$out/tapenade/parser.stdout" \
    2>"$out/tapenade/parser.stderr"
"$tapenade" -d -root s1 -O "$out/tapenade/forward" -o lh026 \
    "$upstream_dir/program.f" >"$out/tapenade/forward.stdout" \
    2>"$out/tapenade/forward.stderr"
"$tapenade" -b -root s1 -O "$out/tapenade/reverse" -o lh026 \
    "$upstream_dir/program.f" >"$out/tapenade/reverse.stdout" \
    2>"$out/tapenade/reverse.stderr"

for generated in "$out/tapenade/parser/lh026_p.f" \
    "$out/tapenade/forward/lh026_d.f" "$out/tapenade/reverse/lh026_b.f"; do
    test -s "$generated"
    compile_capture "$generated" "$generated.o" "$generated.status" strict
done
test "$(cat "$out/tapenade/parser/lh026_p.f.status")" = 0
test "$(cat "$out/tapenade/forward/lh026_d.f.status")" = 0
test "$(cat "$out/tapenade/reverse/lh026_b.f.status")" = 1
grep -Fq 'INTEGER*4' "$out/tapenade/reverse/lh026_b.f.o.stderr"

fortad_exec() { (cd "$fortad_repo" && fo exec --no-build fortad "$@"); }
fortad_exec jvp a,b --proc set01_lh026 --name lh026_jvp \
    --module lh026_forward_ad --output "$out/lh026_forward.f90" \
    "$case_dir/lh026.f90" >"$out/lh026-forward.stdout" \
    2>"$out/lh026-forward.stderr"

set +e
fortad_exec vjp a,b --dep a --proc set01_lh026 --name lh026_vjp \
    --module lh026_reverse_ad --output "$out/lh026_reverse.f90" \
    "$case_dir/lh026.f90" >"$out/lh026-reverse.stdout" \
    2>"$out/lh026-reverse.stderr"
fortad_reverse_status=$?
set -e
test "$fortad_reverse_status" = 1
grep -Fqx \
    'fortad: reverse mode: a branch inside a loop needs control-flow reversal, which is the next milestone' \
    <(grep -F 'fortad:' "$out/lh026-reverse.stderr" | tail -1)

for source in "$case_dir/lh026.f90" \
    "$case_dir/hand_derivatives_lh026.f90" "$out/lh026_forward.f90"; do
    base=$(basename "$source" .f90)
    compile_capture "$source" "$out/$base.o" "$out/$base.status" normal
    test "$(cat "$out/$base.status")" = 0
done
compile_capture "$root/harness/bench_tapenade_set01_lh026.f90" \
    "$out/harness.o" "$out/harness.status" normal
test "$(cat "$out/harness.status")" = 0
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/lh026.o" "$out/hand_derivatives_lh026.o" \
    "$out/lh026_forward.o" "$out/harness.o"

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" \
    2>"$out/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/run.txt"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
{
    printf 'case: Tapenade nonRegressions set01 lh026\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'compile_flags: %s\n' "${compile_flags[*]}"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_strict_compiler_oracle: exact primal, d, b, and dv '
    printf '%s\n' 'references were attempted with the pinned DIFFSIZES.f include contract'
    printf 'tapenade_oracle: fresh parser, tangent, and reverse files generated; '
    printf '%s\n' 'strict statuses are recorded below'
    printf 'fortad_oracle: forward source compiles; reverse refusal matches the '
    printf '%s\n' 'pinned control-flow boundary'
    printf 'independent_oracle: structured reference primal, hand JVP/VJP, '
    printf '%s\n' 'central-difference sweep, component differences, and adjoint identity'
    printf 'classification: expected-refusal\n'
    printf 'fortad_forward_status: 0\n'
    printf 'fortad_reverse_status: %s\n' "$fortad_reverse_status"
    printf 'fortad_reverse_diagnostic: %s\n' \
        "$(grep -F 'fortad:' "$out/lh026-reverse.stderr" | tail -1)"
    printf 'upstream_strict_compile_statuses:\n'
    for status in "$out"/upstream-*.status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'tapenade_generated_compile_statuses:\n'
    find "$out/tapenade" -name '*.status' -print | sort | while read -r status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'fortad_transform_compile_statuses:\n'
    for status in "$out"/*.status; do
        case "$status" in
            *harness.status) continue ;;
        esac
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    cat "$out/runtime-metrics.txt"
    printf 'oracle_status: pass\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum \
        nonRegressions/set01/lh026/program.f \
        nonRegressions/set01/lh026/program_d.f \
        nonRegressions/set01/lh026/program_b.f \
        nonRegressions/set01/lh026/program_dv.f)
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/lh026.f90 \
        cases/tapenade-set01/hand_derivatives_lh026.f90 \
        cases/tapenade-set01/tranche-lh026-manifest.toml \
        cases/tapenade-set01/tranche-lh026.md \
        harness/bench_tapenade_set01_lh026.f90 \
        scripts/bench_tapenade_set01_lh026.sh \
        scripts/test_tapenade_set01_lh026.py)
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"
cat "$result"
