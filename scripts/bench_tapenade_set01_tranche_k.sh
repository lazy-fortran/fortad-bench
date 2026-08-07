#!/usr/bin/env bash
# Validate exact Tapenade set01 lh003/lh005/lh006 refusal boundaries.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_tranche_k_refusal_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=571c86da9516739653a558fabbd8277e796caec8
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
compile_flags=(-std=f2018 -pedantic-errors -ffixed-line-length-none)

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v java >/dev/null
test -x /usr/bin/time
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
git -C "$fortad_repo" cat-file -e "$required_fortad_commit^{commit}"
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_commit" HEAD
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = \
    "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$tapenade_repo/bin/tapenade"

python3 - "$case_dir/tranche-k-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
if manifest["runner"] != "scripts/bench_tapenade_set01_tranche_k.sh":
    raise SystemExit("set01 tranche K manifest names a different runner")
if manifest["upstream_revision"] != \
        "e59864cab441d4175df75383b3ff58c3dcd26df9":
    raise SystemExit("set01 tranche K revision differs from runner")
cases = {case["id"]: case for case in manifest["case"]}
for case_id, procedure in (("lh003", "adj2"), ("lh005", "adj4"),
                           ("lh006", "adj6")):
    if not cases[case_id]["upstream_entry_point"].startswith(procedure + "("):
        raise SystemExit(f"{case_id} entry point differs from runner")
    if cases[case_id]["classification"] != "unsupported-exact-source":
        raise SystemExit(f"{case_id} must remain an exact-source refusal")
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-tranche-k.XXXXXX")
mkdir -p "$out/oracle" "$out/tapenade"

setup_start=$(date +%s.%N)
(cd "$fortad_repo" && fo build) >"$out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

oracle_start=$(date +%s.%N)
"$fc" "${compile_flags[@]}" -Wall -Wextra -ffree-line-length-none \
    -c "$root/harness/bench_tapenade_set01_tranche_k.f90" \
    -o "$out/oracle/harness.o"
"$fc" "${compile_flags[@]}" -o "$out/oracle/bench" \
    "$out/oracle/harness.o"
"$out/oracle/bench" >"$out/oracle/run.txt"
grep -Fqx 'oracle_status: pass' "$out/oracle/run.txt"
oracle_stop=$(date +%s.%N)
oracle_seconds=$(awk -v a="$oracle_start" -v b="$oracle_stop" \
    'BEGIN {printf "%.6f", b-a}')

declare -A procedure=(
    [lh003]=adj2
    [lh005]=adj4
    [lh006]=adj6
)
declare -A indep=(
    [lh003]='x,y,z'
    [lh005]='y'
    [lh006]='x,y,z'
)
declare -A tapenade_expected_reverse=(
    [lh003]='Unclassifiable statement'
    [lh005]='GNU Extension: Nonstandard type declaration INTEGER*4'
    [lh006]='GNU Extension: Nonstandard type declaration INTEGER*4'
)
declare -A fortad_expected=(
    [lh003]='fortad: unsupported statement at line 11'
    [lh005]='fortad: parse failed: ERROR at line 37, column 7: internal: could not locate the end of this do construct; refusing to drop the statements that follow'
    [lh006]='fortad: parse failed: Unterminated character constant at line 49, column 28'
)

for case_id in lh003 lh005 lh006; do
    upstream_dir="$tapenade_repo/nonRegressions/set01/$case_id"
    case_out="$out/$case_id"
    mkdir -p "$case_out/parser" "$case_out/forward" "$case_out/reverse"

    # Compile the exact unmodified source and stored references, preserving
    # non-zero statuses as evidence rather than silently treating them as
    # support.
    for source in "$upstream_dir/program.f" "$upstream_dir/program_b.f" \
        "$upstream_dir/program_d.f"; do
        base=$(basename "$source" .f)
        set +e
        "$fc" "${compile_flags[@]}" -c "$source" \
            -o "$case_out/upstream-$base.o" \
            >"$case_out/upstream-$base.stdout" \
            2>"$case_out/upstream-$base.stderr"
        status=$?
        set -e
        printf '%s %s\n' "$base" "$status" >"$case_out/upstream-$base.status"
    done

    tapenade="$tapenade_repo/bin/tapenade"
    "$tapenade" -p -O "$case_out/parser" -o "$case_id" \
        "$upstream_dir/program.f" >"$case_out/parser.stdout" \
        2>"$case_out/parser.stderr"
    "$tapenade" -d -root "${procedure[$case_id]}" -O "$case_out/forward" \
        -o "$case_id" "$upstream_dir/program.f" \
        >"$case_out/forward.stdout" 2>"$case_out/forward.stderr"
    "$tapenade" -b -root "${procedure[$case_id]}" -O "$case_out/reverse" \
        -o "$case_id" "$upstream_dir/program.f" \
        >"$case_out/reverse.stdout" 2>"$case_out/reverse.stderr"

    for generated in "$case_out/parser/${case_id}_p.f" \
        "$case_out/forward/${case_id}_d.f" "$case_out/reverse/${case_id}_b.f"; do
        test -s "$generated"
        base=$(basename "$generated" .f)
        set +e
        "$fc" "${compile_flags[@]}" -c "$generated" \
            -o "$case_out/$base.o" >"$case_out/$base.stdout" \
            2>"$case_out/$base.stderr"
        status=$?
        set -e
        printf '%s %s\n' "$base" "$status" >"$case_out/$base.status"
    done
    grep -Fq "${tapenade_expected_reverse[$case_id]}" \
        "$case_out/${case_id}_b.stderr"

    # FortAD must reject the exact upstream source with a stable diagnostic in
    # both modes. No generated file is accepted after this point.
    for mode in forward reverse; do
        output="$case_out/fortad_${mode}.f90"
        set +e
        if test "$mode" = forward; then
            (cd "$fortad_repo" && fo exec --no-build fortad --mode forward \
                --indep "${indep[$case_id]}" --proc "${procedure[$case_id]}" \
                --name "${case_id}_jvp" --module "${case_id}_jvp_ad" \
                --output "$output" "$upstream_dir/program.f") \
                >"$case_out/fortad_${mode}.stdout" \
                2>"$case_out/fortad_${mode}.stderr"
        else
            (cd "$fortad_repo" && fo exec --no-build fortad --mode reverse \
                --indep "${indep[$case_id]}" --dep x \
                --proc "${procedure[$case_id]}" --name "${case_id}_vjp" \
                --module "${case_id}_vjp_ad" --output "$output" \
                "$upstream_dir/program.f") \
                >"$case_out/fortad_${mode}.stdout" \
                2>"$case_out/fortad_${mode}.stderr"
        fi
        status=$?
        set -e
        test "$status" -ne 0
        grep -Fqx "${fortad_expected[$case_id]}" \
            <(grep -F 'fortad:' "$case_out/fortad_${mode}.stderr" | tail -1)
        test ! -e "$output"
        printf '%s %s\n' "$mode" "$status" >"$case_out/fortad_${mode}.status"
    done
done

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'suite: Tapenade nonRegressions set01 tranche K (lh003, lh005, lh006)\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fo: %s\n' "$(fo version)"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'fortad_setup_seconds: %s\n' "$setup_seconds"
    printf 'independent_oracle_compile_runtime_seconds: %s\n' "$oracle_seconds"
    printf 'oracle: finite differences against independent hand tangent for '
    printf 'lh003 safe fixed-trip model; branch hand/FD checks for lh005; '
    printf 'fixed-trace hand/FD checks for lh006\n'
    printf 'tapenade_result: fresh parser, tangent, and reverse outputs generated '
    printf 'from exact source; generated files compile statuses are recorded below\n'
    printf 'fortad_result: exact source refusal diagnostics are checked in both '
    printf 'forward and reverse modes; no transformation/runtime claim\n'
    for case_id in lh003 lh005 lh006; do
        printf '%s_upstream_compile_statuses:\n' "$case_id"
        for source in "$out/$case_id"/upstream-*.status; do cat "$source"; done
        printf '%s_tapenade_generated_compile_statuses:\n' "$case_id"
        for source in "$out/$case_id"/"${case_id}"_*.status; do cat "$source"; done
        printf '%s_fortad_refusal_statuses:\n' "$case_id"
        cat "$out/$case_id"/fortad_*.status
        printf '%s_fortad_diagnostic:\n' "$case_id"
        grep -F 'fortad:' "$out/$case_id"/fortad_forward.stderr | tail -1
        printf '%s_source_sha256:\n' "$case_id"
        sha256sum "$tapenade_repo/nonRegressions/set01/$case_id"/program*.f
    done
    printf 'harness_sha256:\n'
    (cd "$root" && sha256sum harness/bench_tapenade_set01_tranche_k.f90 \
        cases/tapenade-set01/tranche-k-manifest.toml \
        cases/tapenade-set01/tranche-k.md \
        scripts/bench_tapenade_set01_tranche_k.sh)
    printf 'oracle_output:\n'
    cat "$out/oracle/run.txt"
} >"$result"

cat "$result"
