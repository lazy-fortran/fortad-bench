#!/usr/bin/env bash
# Validate set01 lh057 support and record the bd06 reverse-loop boundary.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_tranche_b_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
required_fortad_commit=571c86da9516739653a558fabbd8277e796caec8
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
compile_flags=(-std=f2018 -O3 -ffree-line-length-none -fno-lto)

command -v fo >/dev/null
command -v "$fc" >/dev/null
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
python3 - "$case_dir/tranche-b-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
cases = {case["id"]: case for case in manifest["case"]}
if manifest["runner"] != "scripts/bench_tapenade_set01_tranche_b.sh":
    raise SystemExit("set01 tranche manifest names a different runner")
if manifest["upstream_revision"] != \
        "e59864cab441d4175df75383b3ff58c3dcd26df9":
    raise SystemExit("set01 tranche manifest revision differs from runner")
if cases["bd06"]["classification"] != "unsupported-reverse-constant-loop":
    raise SystemExit("bd06 must remain an explicit loop boundary")
if cases["lh057"]["ported_entry_point"] != \
        "set01_lh057_split(a,b,c,a_out,c_out)":
    raise SystemExit("lh057 manifest entry point differs from runner")
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-tranche-b.XXXXXX")
mkdir -p "$out/mod" "$out/include"
cp "$tapenade_repo/nonRegressions/DIFFSIZES.f" "$out/include/DIFFSIZES.inc"

setup_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo build
) >"$out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

upstream_start=$(date +%s.%N)
for source in \
    "$tapenade_repo/nonRegressions/set01/bd06/program.f" \
    "$tapenade_repo/nonRegressions/set01/bd06/program_b.f" \
    "$tapenade_repo/nonRegressions/set01/bd06/program_d.f" \
    "$tapenade_repo/nonRegressions/set01/bd06/program_dv.f" \
    "$tapenade_repo/nonRegressions/set01/bd06/program_p.f" \
    "$tapenade_repo/nonRegressions/set01/lh057/program.f" \
    "$tapenade_repo/nonRegressions/set01/lh057/program_b.f" \
    "$tapenade_repo/nonRegressions/set01/lh057/program_d.f" \
    "$tapenade_repo/nonRegressions/set01/lh057/program_dv.f" \
    "$tapenade_repo/nonRegressions/set01/lh057/program_p.f"; do
    base=$(basename "$source")
    parent=$(basename "$(dirname "$source")")
    "$fc" -std=f2018 -pedantic-errors -I"$out/include" -c "$source" \
        -o "$out/upstream-${parent}-${base}.o"
done
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" \
    'BEGIN {printf "%.6f", b-a}')

bd06_forward_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode forward --indep a,b --proc toto \
        --name toto_jvp --module toto_ad --output "$out/bd06_jvp.f90" \
        "$tapenade_repo/nonRegressions/set01/bd06/program.f"
) >"$out/bd06_forward.stdout" 2>"$out/bd06_forward.stderr"
bd06_forward_stop=$(date +%s.%N)
bd06_forward_seconds=$(awk -v a="$bd06_forward_start" \
    -v b="$bd06_forward_stop" 'BEGIN {printf "%.6f", b-a}')

set +e
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode reverse --indep a,b --dep a \
        --proc toto --name toto_vjp --module toto_reverse_ad \
        --output "$out/bd06_vjp.f90" \
        "$tapenade_repo/nonRegressions/set01/bd06/program.f"
) >"$out/bd06_reverse.stdout" 2>"$out/bd06_reverse.stderr"
bd06_reverse_status=$?
set -e
if test "$bd06_reverse_status" -eq 0; then
    printf 'FortAD unexpectedly accepted bd06 reverse mode\n' >&2
    exit 1
fi
grep -F "this loop accumulates nothing, writes no array element" \
    "$out/bd06_reverse.stderr" >/dev/null

lh057_forward_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode forward --indep a,b,c \
        --proc set01_lh057_split --name lh057_forward_a_out \
        --module lh057_forward_a_out_ad --output "$out/lh057_forward.f90" \
        "$case_dir/lh057_tranche_b.f90"
) >"$out/lh057_forward.stdout" 2>"$out/lh057_forward.stderr"
lh057_forward_stop=$(date +%s.%N)
lh057_forward_seconds=$(awk -v a="$lh057_forward_start" \
    -v b="$lh057_forward_stop" 'BEGIN {printf "%.6f", b-a}')

lh057_reverse_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode reverse --indep a,b,c --dep a_out \
        --proc set01_lh057_split --name lh057_reverse_a_out \
        --module lh057_reverse_a_out_ad --output "$out/lh057_reverse_a.f90" \
        "$case_dir/lh057_tranche_b.f90"
    fo exec --no-build fortad --mode reverse --indep a,b,c --dep c_out \
        --proc set01_lh057_split --name lh057_reverse_c_out \
        --module lh057_reverse_c_out_ad --output "$out/lh057_reverse_c.f90" \
        "$case_dir/lh057_tranche_b.f90"
) >"$out/lh057_reverse.stdout" 2>"$out/lh057_reverse.stderr"
lh057_reverse_stop=$(date +%s.%N)
lh057_reverse_seconds=$(awk -v a="$lh057_reverse_start" \
    -v b="$lh057_reverse_stop" 'BEGIN {printf "%.6f", b-a}')

compile_start=$(date +%s.%N)
for source in "$case_dir/lh057_tranche_b.f90" "$out/lh057_forward.f90" \
    "$out/lh057_reverse_a.f90" "$out/lh057_reverse_c.f90" \
    "$case_dir/lh057_tranche_b_hand.f90"; do
    base=$(basename "$source" .f90)
    "$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
        "$source" -o "$out/${base}.o"
done
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
    "$root/harness/bench_tapenade_set01_tranche_b.f90" -o "$out/harness.o"
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/lh057_tranche_b.o" "$out/lh057_forward.o" \
    "$out/lh057_reverse_a.o" "$out/lh057_reverse_c.o" \
    "$out/lh057_tranche_b_hand.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime_metrics.txt" "$out/bench" >"$out/run.txt" \
    2>"$out/run.stderr"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 bd06 and lh057\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fo: %s\n' "$(fo version)"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'fortad_setup_seconds: %s\n' "$setup_seconds"
    printf 'upstream_strict_compile_seconds: %s\n' "$upstream_seconds"
    printf 'bd06_forward_transform_seconds: %s\n' "$bd06_forward_seconds"
    printf 'bd06_reverse_status: %s\n' "$bd06_reverse_status"
    printf 'lh057_forward_transform_seconds: %s\n' "$lh057_forward_seconds"
    printf 'lh057_reverse_transform_seconds_two_dependents: %s\n' "$lh057_reverse_seconds"
    printf 'lh057_generated_compile_and_link_seconds: %s\n' "$compile_seconds"
    printf 'lh057_generated_forward_source_bytes: %s\n' "$(wc -c <"$out/lh057_forward.f90")"
    printf 'lh057_generated_reverse_a_source_bytes: %s\n' "$(wc -c <"$out/lh057_reverse_a.f90")"
    printf 'lh057_generated_reverse_c_source_bytes: %s\n' "$(wc -c <"$out/lh057_reverse_c.f90")"
    cat "$out/runtime_metrics.txt"
    printf 'upstream_strict_compiler_oracle: all ten unmodified set01 '
    printf 'primal/reference files compile with -std=f2018 -pedantic-errors '
    printf 'using the pinned DIFFSIZES.f include contract\n'
    printf 'bd06_refusal_oracle: forward transforms; reverse returns status %s ' \
        "$bd06_reverse_status"
    printf 'with FortAD one-trip-loop diagnostic; not counted as support\n'
    printf 'lh057_oracle: hand JVP/VJPs, four-step central differences, '
    printf 'fixed primal outputs, and two adjoint identities\n'
    printf 'tapenade_result: stored upstream d/b references inspected; '
    printf 'current Tapenade executable not rerun\n'
    printf 'source_sha256:\n'
    (
        cd "$root"
        sha256sum cases/tapenade-set01/lh057_tranche_b.f90 \
            cases/tapenade-set01/lh057_tranche_b_hand.f90 \
            cases/tapenade-set01/tranche-b-manifest.toml \
            harness/bench_tapenade_set01_tranche_b.f90 \
            scripts/bench_tapenade_set01_tranche_b.sh
    )
    printf 'generated_source_sha256:\n'
    sha256sum "$out/lh057_forward.f90" "$out/lh057_reverse_a.f90" \
        "$out/lh057_reverse_c.f90" | sed "s#$out/##"
    printf 'bd06_reverse_diagnostic:\n'
    cat "$out/bd06_reverse.stderr"
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"

cat "$result"
