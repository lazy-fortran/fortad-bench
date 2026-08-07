#!/usr/bin/env bash
# Validate Tapenade set01 lh017/lh022/lh028 with fresh engine probes.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh017_032_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=477bd5a80aabe2d0556c3f4c29015e6593b92082
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -ffixed-line-length-none)
compile_flags=(-std=f2018 -O2 -ffree-line-length-none -fno-lto)

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v java >/dev/null
test -x /usr/bin/time
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_commit" HEAD
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

python3 - "$case_dir/tranche-l-lh017-032-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
if manifest["runner"] != "scripts/bench_tapenade_set01_lh017_032.sh":
    raise SystemExit("tranche L runner mismatch")
if manifest["upstream_revision"] != "e59864cab441d4175df75383b3ff58c3dcd26df9":
    raise SystemExit("tranche L Tapenade revision mismatch")
cases = {case["id"]: case for case in manifest["case"]}
if set(cases) != {"lh017", "lh022", "lh028"}:
    raise SystemExit("tranche L case set mismatch")
if cases["lh017"]["classification"] != "runnable-ported":
    raise SystemExit("lh017 must be runnable")
for case_id in ("lh022", "lh028"):
    if cases[case_id]["classification"] != "expected-refusal":
        raise SystemExit(f"{case_id} must remain an expected refusal")
PY

out=$(mktemp -d /var/tmp/ert/tapenade-set01-lh017-032.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/mod" "$out/tapenade" "$out/tapenade"/{lh017,lh022,lh028}

(cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1 < /dev/null
if test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1 < /dev/null
fi

declare -A procedure=( [lh017]=test [lh022]=test [lh028]=s1 )
for case_id in lh017 lh022 lh028; do
    upstream_dir="$tapenade_repo/nonRegressions/set01/$case_id"
    case_out="$out/tapenade/$case_id"
    mkdir -p "$case_out/parser" "$case_out/forward" "$case_out/reverse"
    for source in program.f program_d.f program_b.f; do
        set +e
        "$fc" "${strict_flags[@]}" -c "$upstream_dir/$source" \
            -o "$case_out/upstream-$source.o" \
            >"$case_out/upstream-$source.stdout" \
            2>"$case_out/upstream-$source.stderr"
        status=$?
        set -e
        printf '%s\n' "$status" >"$case_out/upstream-$source.status"
    done
    tapenade="$tapenade_repo/bin/tapenade"
    "$tapenade" -p -O "$case_out/parser" -o "$case_id" \
        "$upstream_dir/program.f" >"$case_out/parser.stdout" \
        2>"$case_out/parser.stderr"
    "$tapenade" -d -root "${procedure[$case_id]}" -O "$case_out/forward" \
        -o "$case_id" "$upstream_dir/program.f" >"$case_out/forward.stdout" \
        2>"$case_out/forward.stderr"
    "$tapenade" -b -root "${procedure[$case_id]}" -O "$case_out/reverse" \
        -o "$case_id" "$upstream_dir/program.f" >"$case_out/reverse.stdout" \
        2>"$case_out/reverse.stderr"
    for generated in "$case_out/parser/${case_id}_p.f" \
        "$case_out/forward/${case_id}_d.f" "$case_out/reverse/${case_id}_b.f"; do
        test -s "$generated"
        set +e
        "$fc" "${strict_flags[@]}" -c "$generated" \
            -o "$case_out/$(basename "$generated").o" \
            >"$generated.stdout" 2>"$generated.stderr"
        status=$?
        set -e
        printf '%s\n' "$status" >"$generated.status"
    done
done

fortad_exec() {
    (cd "$fortad_repo" && fo exec --no-build fortad "$@")
}

fortad_exec jvp a1,a2 --proc set01_lh017 --name lh017_jvp \
    --module lh017_forward_ad --output "$out/lh017_forward.f90" \
    "$case_dir/lh017.f90" >"$out/lh017-forward.stdout" 2>"$out/lh017-forward.stderr"
fortad_exec vjp a1,a2 --dep b1 --proc set01_lh017 --name lh017_vjp_b1 \
    --module lh017_reverse_b1_ad --output "$out/lh017_reverse_b1.f90" \
    "$case_dir/lh017.f90" >"$out/lh017-b1.stdout" 2>"$out/lh017-b1.stderr"
fortad_exec vjp a1,a2 --dep b2 --proc set01_lh017 --name lh017_vjp_b2 \
    --module lh017_reverse_b2_ad --output "$out/lh017_reverse_b2.f90" \
    "$case_dir/lh017.f90" >"$out/lh017-b2.stdout" 2>"$out/lh017-b2.stderr"
fortad_exec jvp x,y --proc set01_lh022 --name lh022_jvp \
    --module lh022_forward_ad --output "$out/lh022_forward.f90" \
    "$case_dir/lh022.f90" >"$out/lh022-forward.stdout" 2>"$out/lh022-forward.stderr"
fortad_exec jvp a,b --proc set01_lh028 --name lh028_jvp \
    --module lh028_forward_ad --output "$out/lh028_forward.f90" \
    "$case_dir/lh028.f90" >"$out/lh028-forward.stdout" 2>"$out/lh028-forward.stderr"

set +e
fortad_exec vjp x,y --dep x --proc set01_lh022 --name lh022_vjp \
    --module lh022_reverse_ad --output "$out/lh022_reverse.f90" \
    "$case_dir/lh022.f90" >"$out/lh022-reverse.stdout" 2>"$out/lh022-reverse.stderr"
lh022_status=$?
fortad_exec vjp a,b --dep a --proc set01_lh028 --name lh028_vjp \
    --module lh028_reverse_ad --output "$out/lh028_reverse.f90" \
    "$case_dir/lh028.f90" >"$out/lh028-reverse.stdout" 2>"$out/lh028-reverse.stderr"
lh028_status=$?
set -e
test "$lh022_status" -ne 0
test "$lh028_status" -ne 0
grep -Fqx "fortad: reverse mode: 'y' is both read and written in the same loop; that needs per-iteration storage" \
    <(grep -F 'fortad:' "$out/lh022-reverse.stderr" | tail -1)
grep -Fqx "fortad: reverse mode: a branch inside a loop needs control-flow reversal, which is the next milestone" \
    <(grep -F 'fortad:' "$out/lh028-reverse.stderr" | tail -1)

for source in "$case_dir/lh017.f90" "$case_dir/lh022.f90" "$case_dir/lh028.f90" \
    "$case_dir/hand_derivatives_lh017_032.f90" "$out/lh017_forward.f90" \
    "$out/lh017_reverse_b1.f90" "$out/lh017_reverse_b2.f90" \
    "$out/lh022_forward.f90" "$out/lh028_forward.f90"; do
    base=$(basename "$source" .f90)
    "$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
        -o "$out/$base.o"
done
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
    "$root/harness/bench_tapenade_set01_lh017_032.f90" -o "$out/harness.o"
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/lh017.o" "$out/lh022.o" "$out/lh028.o" \
    "$out/hand_derivatives_lh017_032.o" "$out/lh017_forward.o" \
    "$out/lh017_reverse_b1.o" "$out/lh017_reverse_b2.o" \
    "$out/lh022_forward.o" "$out/lh028_forward.o" "$out/harness.o"
/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" 2>"$out/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/run.txt"

{
    printf 'suite: Tapenade nonRegressions set01 tranche L (lh017, lh022, lh028)\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_compiler_oracle: exact primal and stored references are '
    printf '%s\n' 'attempted under strict flags; statuses are recorded below'
    printf 'tapenade_oracle: fresh parser, tangent, and reverse files generated; '
    printf '%s\n' 'strict compile statuses are recorded below'
    printf 'fortad_oracle: lh017 forward and both reverse seeds compile; '
    printf '%s\n' 'lh022/lh028 forward compile and exact reverse refusals match'
    printf 'independent_oracle: hand JVP/VJP, central differences, and adjoint identities\n'
    printf 'oracle_status: pass\n'
    printf 'lh017_reverse_refusal_status: not-applicable (supported)\n'
    printf 'lh022_reverse_refusal_status: %s\n' "$lh022_status"
    printf 'lh022_diagnostic: %s\n' "$(grep -F 'fortad:' "$out/lh022-reverse.stderr" | tail -1)"
    printf 'lh028_reverse_refusal_status: %s\n' "$lh028_status"
    printf 'lh028_diagnostic: %s\n' "$(grep -F 'fortad:' "$out/lh028-reverse.stderr" | tail -1)"
    printf 'upstream_compile_statuses:\n'
    for status in "$out"/tapenade/*/upstream-*.status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'tapenade_generated_compile_statuses:\n'
    for status in "$out"/tapenade/*/*/*.status; do
        printf '%s %s\n' "${status#"$out/"}" "$(cat "$status")"
    done
    printf 'runtime_metrics:\n'
    cat "$out/runtime-metrics.txt"
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/lh017.f90 cases/tapenade-set01/lh022.f90 \
        cases/tapenade-set01/lh028.f90 \
        cases/tapenade-set01/hand_derivatives_lh017_032.f90 \
        cases/tapenade-set01/tranche-l-lh017-032-manifest.toml \
        cases/tapenade-set01/tranche-l-lh017-032.md \
        harness/bench_tapenade_set01_lh017_032.f90 \
        scripts/bench_tapenade_set01_lh017_032.sh)
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"
cat "$result"
