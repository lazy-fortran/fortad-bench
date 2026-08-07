#!/usr/bin/env bash
# Validate Tapenade set01 bd01, bd02, and bd03 end to end.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_tranche_l_bd_ht_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
required_fortad_commit=477bd5a80aabe2d0556c3f4c29015e6593b92082
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
compile_flags=(-std=f2018 -O3 -ffree-line-length-none -fno-lto)
case_ids=(bd01 bd02 bd03)

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

python3 - "$case_dir/tranche-l-bd-ht-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
if manifest["runner"] != "scripts/bench_tapenade_set01_tranche_l_bd_ht.sh":
    raise SystemExit("set01 tranche L manifest names a different runner")
if manifest["upstream_revision"] != \
        "e59864cab441d4175df75383b3ff58c3dcd26df9":
    raise SystemExit("set01 tranche L revision differs from runner")
expected = {
    "bd01": ("set01_bd01(x_initial,y_initial,z_initial,w_final,x_final,y_final,z_final)",
             ["x_initial", "y_initial", "z_initial"], "w_final"),
    "bd02": ("set01_bd02(b,a)", ["b"], "a"),
    "bd03": ("set01_bd03(b,a)", ["b"], "a"),
}
for case in manifest["case"]:
    if case["id"] not in expected:
        raise SystemExit(f"unexpected tranche L case {case['id']}")
    entry, independent, dependent = expected[case["id"]]
    if case["ported_entry_point"] != entry:
        raise SystemExit(f"{case['id']} manifest entry point differs from runner")
    if case["independent"] != independent or case["dependent"] != dependent:
        raise SystemExit(f"{case['id']} derivative contract differs from runner")
if {case["id"] for case in manifest["case"]} != set(expected):
    raise SystemExit("set01 tranche L manifest case set differs from runner")
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-tranche-l-bd-ht.XXXXXX")
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/mod" "$out/tapenade"
cp "$tapenade_repo/nonRegressions/DIFFSIZES.f" "$out/DIFFSIZES.inc"

setup_start=$(date +%s.%N)
(cd "$fortad_repo" && fo build) >"$out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" 'BEGIN {printf "%.6f", b-a}')

if test ! -s "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    test -x "$tapenade_repo/gradlew" || {
        printf 'Tapenade checkout has no jar or gradlew\n' >&2
        exit 1
    }
    (cd "$tapenade_repo" && ./gradlew --no-daemon jar) \
        >"$out/tapenade-build.log" 2>&1 < /dev/null
fi

upstream_start=$(date +%s.%N)
for case_id in "${case_ids[@]}"; do
    upstream_dir="$tapenade_repo/nonRegressions/set01/$case_id"
    for source in "$upstream_dir"/program*.f; do
        base=$(basename "$source")
        "$fc" -std=f2018 -pedantic-errors -ffixed-line-length-none \
            -I"$out" -c "$source" \
            -o "$out/upstream-${case_id}-${base}.o"
    done
done
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" 'BEGIN {printf "%.6f", b-a}')

export PATH="$tapenade_repo/bin:$PATH"
declare -A roots=( [bd01]=titi [bd02]=toto [bd03]=g )
tapenade_parser_start=$(date +%s.%N)
for case_id in "${case_ids[@]}"; do
    upstream_source="$tapenade_repo/nonRegressions/set01/$case_id/program.f"
    mkdir -p "$out/tapenade/$case_id/parser" \
        "$out/tapenade/$case_id/forward" "$out/tapenade/$case_id/reverse"
    "$tapenade_repo/bin/tapenade" -p \
        -O "$out/tapenade/$case_id/parser" -o "$case_id" "$upstream_source" \
        >"$out/tapenade/$case_id/parser.log" \
        2>"$out/tapenade/$case_id/parser.err"
    "$tapenade_repo/bin/tapenade" -d -root "${roots[$case_id]}" \
        -O "$out/tapenade/$case_id/forward" -o "$case_id" "$upstream_source" \
        >"$out/tapenade/$case_id/forward.log" \
        2>"$out/tapenade/$case_id/forward.err"
    "$tapenade_repo/bin/tapenade" -b -root "${roots[$case_id]}" \
        -O "$out/tapenade/$case_id/reverse" -o "$case_id" "$upstream_source" \
        >"$out/tapenade/$case_id/reverse.log" \
        2>"$out/tapenade/$case_id/reverse.err"
done
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_parser_start" -v b="$tapenade_stop" 'BEGIN {printf "%.6f", b-a}')

tapenade_compile_start=$(date +%s.%N)
for case_id in "${case_ids[@]}"; do
    for mode in parser forward reverse; do
        for generated in "$out/tapenade/$case_id/$mode"/*.f; do
            test -s "$generated"
            "$fc" -std=f2018 -pedantic-errors -ffixed-line-length-none -c \
                "$generated" -o "$out/tapenade-$(basename "$generated").o"
        done
    done
done
tapenade_compile_stop=$(date +%s.%N)
tapenade_compile_seconds=$(awk -v a="$tapenade_compile_start" \
    -v b="$tapenade_compile_stop" 'BEGIN {printf "%.6f", b-a}')

fortad_forward_start=$(date +%s.%N)
for spec in \
    'bd01 x_initial,y_initial,z_initial set01_bd01 w_final' \
    'bd02 b set01_bd02 a' \
    'bd03 b set01_bd03 a'; do
    set -- $spec
    case_id=$1
    independent=$2
    procedure=$3
    dependent=$4
    (cd "$fortad_repo" && fo exec --no-build fortad jvp "$independent" \
        --proc "$procedure" --name "${case_id}_jvp" \
        --module "${case_id}_forward_ad" --output "$out/${case_id}_forward.f90" \
        "$case_dir/${case_id}.f90") >"$out/${case_id}-forward.stdout" \
        2>"$out/${case_id}-forward.stderr"
done
fortad_forward_stop=$(date +%s.%N)
fortad_forward_seconds=$(awk -v a="$fortad_forward_start" \
    -v b="$fortad_forward_stop" 'BEGIN {printf "%.6f", b-a}')

fortad_reverse_start=$(date +%s.%N)
for spec in \
    'bd01 x_initial,y_initial,z_initial set01_bd01 w_final' \
    'bd02 b set01_bd02 a' \
    'bd03 b set01_bd03 a'; do
    set -- $spec
    case_id=$1
    independent=$2
    procedure=$3
    dependent=$4
    (cd "$fortad_repo" && fo exec --no-build fortad vjp "$independent" \
        --dep "$dependent" --proc "$procedure" --name "${case_id}_vjp" \
        --module "${case_id}_reverse_ad" --output "$out/${case_id}_reverse.f90" \
        "$case_dir/${case_id}.f90") >"$out/${case_id}-reverse.stdout" \
        2>"$out/${case_id}-reverse.stderr"
done
fortad_reverse_stop=$(date +%s.%N)
fortad_reverse_seconds=$(awk -v a="$fortad_reverse_start" \
    -v b="$fortad_reverse_stop" 'BEGIN {printf "%.6f", b-a}')

compile_start=$(date +%s.%N)
for case_id in "${case_ids[@]}"; do
    for source in "$case_dir/$case_id.f90" \
        "$case_dir/hand_derivatives_$case_id.f90" \
        "$out/${case_id}_forward.f90" "$out/${case_id}_reverse.f90"; do
        base=$(basename "$source" .f90)
        "$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c "$source" \
            -o "$out/${base}.o"
    done
done
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
    "$root/harness/bench_tapenade_set01_tranche_l_bd_ht.f90" \
    -o "$out/harness.o"
"$fc" "${compile_flags[@]}" -o "$out/bench" \
    "$out/bd01.o" "$out/hand_derivatives_bd01.o" "$out/bd01_forward.o" \
    "$out/bd01_reverse.o" "$out/bd02.o" "$out/hand_derivatives_bd02.o" \
    "$out/bd02_forward.o" "$out/bd02_reverse.o" "$out/bd03.o" \
    "$out/hand_derivatives_bd03.o" "$out/bd03_forward.o" \
    "$out/bd03_reverse.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" \
    2>"$out/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/run.txt"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 bd01 bd02 bd03\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'fortad_setup_seconds: %s\n' "$setup_seconds"
    printf 'upstream_strict_compile_seconds: %s\n' "$upstream_seconds"
    printf 'tapenade_parser_forward_reverse_seconds: %s\n' "$tapenade_seconds"
    printf 'tapenade_generated_compile_seconds: %s\n' "$tapenade_compile_seconds"
    printf 'fortad_forward_seconds: %s\n' "$fortad_forward_seconds"
    printf 'fortad_reverse_seconds: %s\n' "$fortad_reverse_seconds"
    printf 'fortad_generated_compile_and_link_seconds: %s\n' "$compile_seconds"
    for case_id in "${case_ids[@]}"; do
        printf '%s_tapenade_parser_source_bytes: %s\n' "$case_id" \
            "$(wc -c <"$out/tapenade/$case_id/parser/${case_id}_p.f")"
        printf '%s_tapenade_forward_source_bytes: %s\n' "$case_id" \
            "$(wc -c <"$out/tapenade/$case_id/forward/${case_id}_d.f")"
        printf '%s_tapenade_reverse_source_bytes: %s\n' "$case_id" \
            "$(wc -c <"$out/tapenade/$case_id/reverse/${case_id}_b.f")"
        printf '%s_fortad_forward_source_bytes: %s\n' "$case_id" \
            "$(wc -c <"$out/${case_id}_forward.f90")"
        printf '%s_fortad_reverse_source_bytes: %s\n' "$case_id" \
            "$(wc -c <"$out/${case_id}_reverse.f90")"
    done
    cat "$out/runtime-metrics.txt"
    printf 'upstream_compiler_oracle: all unmodified program and stored '
    printf '%s\n' 'reference sources compile with strict fixed-form flags'
    printf 'tapenade_oracle: fresh parser, tangent, and adjoint outputs for all '
    printf '%s\n' 'three cases compile with -std=f2018 -pedantic-errors'
    printf 'oracle: independent hand JVP/VJP, four-step central differences, '
    printf '%s\n' 'and JVP/VJP adjoint identities for every promoted case'
    printf 'runtime_method: Fortran system_clock over 200000 repetitions; '
    printf '%s\n' '/usr/bin/time %e and %M wrap the executable'
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum \
        cases/tapenade-set01/bd01.f90 cases/tapenade-set01/bd02.f90 \
        cases/tapenade-set01/bd03.f90 \
        cases/tapenade-set01/hand_derivatives_bd01.f90 \
        cases/tapenade-set01/hand_derivatives_bd02.f90 \
        cases/tapenade-set01/hand_derivatives_bd03.f90 \
        cases/tapenade-set01/tranche-l-bd-ht-manifest.toml \
        cases/tapenade-set01/tranche-l-bd-ht.md \
        harness/bench_tapenade_set01_tranche_l_bd_ht.f90 \
        scripts/bench_tapenade_set01_tranche_l_bd_ht.sh)
    printf 'generated_source_sha256:\n'
    sha256sum "$out"/*_forward.f90 "$out"/*_reverse.f90 | sed "s#$out/##"
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"

cat "$result"
