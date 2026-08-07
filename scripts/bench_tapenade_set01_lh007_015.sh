#!/usr/bin/env bash
# Validate exact Tapenade set01 lh012/lh013/lh014 generated-compile boundaries.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh007_015_refusal_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=477bd5a80aabe2d0556c3f4c29015e6593b92082
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
compile_flags=(-std=f2018 -pedantic-errors -ffixed-line-length-none)

command -v fo >/dev/null
command -v "$fc" >/dev/null
command -v python3 >/dev/null
command -v java >/dev/null
test -d "$fortad_repo/.git" || test -f "$fortad_repo/.git"
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
git -C "$fortad_repo" cat-file -e "$required_fortad_commit^{commit}"
git -C "$fortad_repo" merge-base --is-ancestor "$required_fortad_commit" HEAD
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$tapenade_repo/bin/tapenade"

python3 - "$case_dir/tranche-l-lh007-015-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
if manifest["runner"] != "scripts/bench_tapenade_set01_lh007_015.sh":
    raise SystemExit("set01 lh007-015 manifest names a different runner")
if manifest["upstream_revision"] != \
        "e59864cab441d4175df75383b3ff58c3dcd26df9":
    raise SystemExit("set01 tranche L revision differs from runner")
cases = {case["id"]: case for case in manifest["case"]}
if set(cases) != {"lh012", "lh013", "lh014"}:
    raise SystemExit("set01 tranche L case set changed")
for case_id in cases:
    if cases[case_id]["classification"] not in {
        "unsupported-exact-source-generated-reverse-compile",
        "unsupported-exact-source-generated-compile",
    }:
        raise SystemExit(f"{case_id} must remain an exact-source refusal")
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-lh007-015.XXXXXX")

setup_start=$(date +%s.%N)
(cd "$fortad_repo" && fo build) >"$out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

oracle_start=$(date +%s.%N)
"$fc" -std=f2018 -pedantic-errors -Wall -Wextra \
    -ffree-line-length-none -fno-lto \
    -c "$root/harness/bench_tapenade_set01_lh007_015.f90" \
    -o "$out/oracle.o"
"$fc" -std=f2018 -pedantic-errors -Wall -Wextra -ffree-line-length-none \
    -fno-lto -o "$out/oracle" "$out/oracle.o"
"$out/oracle" >"$out/oracle.txt"
grep -Fqx 'oracle_status: pass' "$out/oracle.txt"
oracle_stop=$(date +%s.%N)
oracle_seconds=$(awk -v a="$oracle_start" -v b="$oracle_stop" \
    'BEGIN {printf "%.6f", b-a}')

declare -A indep=(
    [lh012]='B,C'
    [lh013]='x,y'
    [lh014]='p,q,Y'
)
declare -A dep=(
    [lh012]='A'
    [lh013]='x'
    [lh014]='X'
)
declare -A forward_compile_expected=(
    [lh012]=0
    [lh013]=0
    [lh014]=1
)
declare -A reverse_compile_expected=(
    [lh012]=1
    [lh013]=1
    [lh014]=1
)
declare -A expected_diagnostic=(
    [lh012]='no IMPLICIT type'
    [lh013]='Duplicate symbol'
    [lh014]='no IMPLICIT type'
)

for case_id in lh012 lh013 lh014; do
    upstream_dir="$tapenade_repo/nonRegressions/set01/$case_id"
    case_out="$out/$case_id"
    mkdir -p "$case_out/parser" "$case_out/forward" "$case_out/reverse" \
        "$case_out/mod"

    # The exact primal and stored Tapenade references are all strict-compilable
    # evidence, even when FortAD's generated output reaches a refusal boundary.
    for source in "$upstream_dir/program.f" "$upstream_dir/program_d.f" \
        "$upstream_dir/program_b.f"; do
        base=$(basename "$source" .f)
        "$fc" "${compile_flags[@]}" -c "$source" \
            -o "$case_out/upstream-$base.o" \
            >"$case_out/upstream-$base.stdout" \
            2>"$case_out/upstream-$base.stderr"
        printf '%s 0\n' "$base" >"$case_out/upstream-$base.status"
    done

    tapenade="$tapenade_repo/bin/tapenade"
    "$tapenade" -p -O "$case_out/parser" -o "$case_id" \
        "$upstream_dir/program.f" >"$case_out/parser.stdout" \
        2>"$case_out/parser.stderr"
    "$tapenade" -d -root test -O "$case_out/forward" -o "$case_id" \
        "$upstream_dir/program.f" >"$case_out/forward.stdout" \
        2>"$case_out/forward.stderr"
    "$tapenade" -b -root test -O "$case_out/reverse" -o "$case_id" \
        "$upstream_dir/program.f" >"$case_out/reverse.stdout" \
        2>"$case_out/reverse.stderr"

    # Fresh parser/tangent/reverse Tapenade outputs must compile unchanged.
    for generated in "$case_out/parser/${case_id}_p.f" \
        "$case_out/forward/${case_id}_d.f" "$case_out/reverse/${case_id}_b.f"; do
        test -s "$generated"
        base=$(basename "$generated" .f)
        "$fc" "${compile_flags[@]}" -c "$generated" \
            -o "$case_out/$base.o" >"$case_out/$base.stdout" \
            2>"$case_out/$base.stderr"
        printf '%s 0\n' "$base" >"$case_out/$base.status"
    done

    for mode in forward reverse; do
        output="$case_out/fortad_${mode}.f90"
        set +e
        if test "$mode" = forward; then
            (cd "$fortad_repo" && fo exec --no-build fortad --mode forward \
                --indep "${indep[$case_id]}" --proc test \
                --name "${case_id}_jvp" --module "${case_id}_jvp_ad" \
                --output "$output" "$upstream_dir/program.f") \
                >"$case_out/fortad_${mode}.stdout" \
                2>"$case_out/fortad_${mode}.stderr"
        else
            (cd "$fortad_repo" && fo exec --no-build fortad --mode reverse \
                --indep "${indep[$case_id]}" --dep "${dep[$case_id]}" \
                --proc test --name "${case_id}_vjp" \
                --module "${case_id}_vjp_ad" --output "$output" \
                "$upstream_dir/program.f") \
                >"$case_out/fortad_${mode}.stdout" \
                2>"$case_out/fortad_${mode}.stderr"
        fi
        transform_status=$?
        set -e
        test "$transform_status" -eq 0
        test -s "$output"
        set +e
        "$fc" -std=f2018 -pedantic-errors -ffree-line-length-none -fno-lto \
            -J"$case_out/mod" -I"$case_out/mod" -c "$output" \
            -o "$case_out/fortad_${mode}.o" \
            >"$case_out/fortad_${mode}_compile.stdout" \
            2>"$case_out/fortad_${mode}_compile.stderr"
        compile_status=$?
        set -e
        expected_status=0
        if test "$mode" = forward; then
            expected_status=${forward_compile_expected[$case_id]}
        else
            expected_status=${reverse_compile_expected[$case_id]}
        fi
        test "$compile_status" -eq "$expected_status"
        if test "$compile_status" -ne 0; then
            grep -Fqi "${expected_diagnostic[$case_id]}" \
                "$case_out/fortad_${mode}_compile.stderr"
        fi
        printf '%s %s\n' "$mode" "$compile_status" \
            >"$case_out/fortad_${mode}.status"
    done
done

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'suite: Tapenade nonRegressions set01 lh007-015 tranche (lh012, lh013, lh014)\n'
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
    printf 'oracle: safe indexed-product, initialization-safe scalar, and '
    printf '%s\n' 'output-sum observations; hand JVP/VJP, central differences, adjoint identity'
    printf 'tapenade_result: fresh parser, tangent, and reverse outputs generated '
    printf '%s\n' 'from exact source; all generated files compile under strict flags'
    printf 'fortad_result: exact-source transform commands succeed; generated '
    printf '%s\n' 'compile statuses and refusal diagnostics are checked below'
    for case_id in lh012 lh013 lh014; do
        upstream_dir="$tapenade_repo/nonRegressions/set01/$case_id"
        printf '%s_upstream_compile_statuses:\n' "$case_id"
        for source in "$out/$case_id"/upstream-*.status; do cat "$source"; done
        printf '%s_tapenade_generated_compile_statuses:\n' "$case_id"
        for source in "$out/$case_id"/"${case_id}"_*.status; do cat "$source"; done
        printf '%s_fortad_generated_compile_statuses:\n' "$case_id"
        cat "$out/$case_id"/fortad_*.status
        printf '%s_fortad_diagnostics:\n' "$case_id"
        for source in "$out/$case_id"/fortad_*_compile.stderr; do
            printf '%s:\n' "$(basename "$source")"
            grep -E 'Error:|error:' "$source" | head -3 || true
        done
        printf '%s_source_sha256:\n' "$case_id"
        sha256sum "$upstream_dir"/program*.f
    done
    printf 'harness_sha256:\n'
    (cd "$root" && sha256sum harness/bench_tapenade_set01_lh007_015.f90 \
        cases/tapenade-set01/tranche-l-lh007-015-manifest.toml \
        cases/tapenade-set01/tranche-l-lh007-015.md \
        scripts/bench_tapenade_set01_lh007_015.sh)
    printf 'oracle_output:\n'
    cat "$out/oracle.txt"
} >"$result"

cat "$result"
