#!/usr/bin/env bash
# Validate Tapenade todoF90/REFERENCES/v420 and record end-to-end evidence.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-known-failures/v420"
result="$root/results/tapenade_known_failure_v420_validation.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
required_fortad_commit=61f5a71
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

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-v420.XXXXXX")

setup_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo build
) >"$out/fortad-setup.log" 2>&1 < /dev/null
setup_stop=$(date +%s.%N)
setup_seconds=$(awk -v a="$setup_start" -v b="$setup_stop" \
    'BEGIN {printf "%.6f", b-a}')

upstream_source="$tapenade_repo/todoF90/REFERENCES/v420/program.f90"
upstream_start=$(date +%s.%N)
"$fc" -std=f2018 -pedantic-errors -ffree-line-length-none -c \
    "$upstream_source" -o "$out/upstream-v420.o"
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" \
    'BEGIN {printf "%.6f", b-a}')

export PATH="$tapenade_repo/bin:$PATH"
mkdir -p "$out/tapenade/probe" "$out/tapenade/forward" "$out/tapenade/reverse"
tapenade_probe_start=$(date +%s.%N)
(
    cd "$out"
    "$tapenade_repo/bin/tapenade" -p -O "$out/tapenade/probe" \
        -o program "$upstream_source"
) >"$out/tapenade-probe.stdout" 2>"$out/tapenade-probe.stderr"
tapenade_probe_stop=$(date +%s.%N)
tapenade_probe_seconds=$(awk -v a="$tapenade_probe_start" \
    -v b="$tapenade_probe_stop" 'BEGIN {printf "%.6f", b-a}')
test -s "$out/tapenade/probe/program_p.f90"

tapenade_forward_start=$(date +%s.%N)
(
    cd "$out"
    "$tapenade_repo/bin/tapenade" -d -root g -O "$out/tapenade/forward" \
        -o g_d "$upstream_source"
) >"$out/tapenade-forward.stdout" 2>"$out/tapenade-forward.stderr"
tapenade_forward_stop=$(date +%s.%N)
tapenade_forward_seconds=$(awk -v a="$tapenade_forward_start" \
    -v b="$tapenade_forward_stop" 'BEGIN {printf "%.6f", b-a}')
test -s "$out/tapenade/forward/g_d_d.f90"
"$fc" -std=f2018 -pedantic-errors -c "$out/tapenade/forward/g_d_d.f90" \
    -o "$out/tapenade-forward.o"

tapenade_reverse_start=$(date +%s.%N)
(
    cd "$out"
    "$tapenade_repo/bin/tapenade" -b -root g -O "$out/tapenade/reverse" \
        -o g_b "$upstream_source"
) >"$out/tapenade-reverse.stdout" 2>"$out/tapenade-reverse.stderr"
tapenade_reverse_stop=$(date +%s.%N)
tapenade_reverse_seconds=$(awk -v a="$tapenade_reverse_start" \
    -v b="$tapenade_reverse_stop" 'BEGIN {printf "%.6f", b-a}')
test -s "$out/tapenade/reverse/g_b_b.f90"
"$fc" -std=f2018 -pedantic-errors -c "$out/tapenade/reverse/g_b_b.f90" \
    -o "$out/tapenade-reverse.o"

forward_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode forward --indep u \
        --proc v420 --name v420_jvp --module v420_forward_ad \
        --output "$out/v420_forward.f90" "$case_dir/v420.f90"
) >"$out/forward.stdout" 2>"$out/forward.stderr"
forward_stop=$(date +%s.%N)
forward_seconds=$(awk -v a="$forward_start" -v b="$forward_stop" \
    'BEGIN {printf "%.6f", b-a}')

reverse_start=$(date +%s.%N)
(
    cd "$fortad_repo"
    fo exec --no-build fortad --mode reverse --indep u --dep v \
        --proc v420 --name v420_vjp --module v420_reverse_ad \
        --output "$out/v420_reverse.f90" "$case_dir/v420.f90"
) >"$out/reverse.stdout" 2>"$out/reverse.stderr"
reverse_stop=$(date +%s.%N)
reverse_seconds=$(awk -v a="$reverse_start" -v b="$reverse_stop" \
    'BEGIN {printf "%.6f", b-a}')

compile_start=$(date +%s.%N)
mkdir -p "$out/mod"
for source in "$case_dir/v420.f90" \
    "$case_dir/hand_derivatives_v420.f90" "$out/v420_forward.f90" \
    "$out/v420_reverse.f90"; do
    base=$(basename "$source" .f90)
    "$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
        "$source" -o "$out/${base}.o"
done
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -c \
    "$root/harness/bench_tapenade_known_failure_v420.f90" \
    -o "$out/harness.o"
"$fc" "${compile_flags[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" \
    "$out/v420.o" "$out/hand_derivatives_v420.o" \
    "$out/v420_forward.o" "$out/v420_reverse.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" \
    'BEGIN {printf "%.6f", b-a}')

/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' \
    -o "$out/runtime_metrics.txt" "$out/bench" >"$out/run.txt" \
    2>"$out/run.stderr"
grep -Fqx 'oracle_status: pass' "$out/run.txt"

fortad_commit=$(git -C "$fortad_repo" rev-parse HEAD)
tapenade_version=$({ "$tapenade_repo/bin/tapenade" -version || true; } \
    | head -1)
cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' \
    /etc/os-release)
{
    printf 'case: Tapenade todoF90 REFERENCES v420\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'compiler_flags: %s\n' "${compile_flags[*]}"
    printf 'fo: %s\n' "$(cd "$fortad_repo" && fo version)"
    printf 'fortad_commit: %s\n' "$fortad_commit"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'tapenade_version: %s\n' "$tapenade_version"
    printf 'fortad_setup_seconds: %s\n' "$setup_seconds"
    printf 'upstream_strict_compile_seconds: %s\n' "$upstream_seconds"
    printf 'tapenade_probe_seconds: %s\n' "$tapenade_probe_seconds"
    printf 'tapenade_forward_generation_seconds: %s\n' "$tapenade_forward_seconds"
    printf 'tapenade_reverse_generation_seconds: %s\n' "$tapenade_reverse_seconds"
    printf 'fortad_forward_transform_seconds: %s\n' "$forward_seconds"
    printf 'fortad_reverse_transform_seconds: %s\n' "$reverse_seconds"
    printf 'generated_compile_and_link_seconds: %s\n' "$compile_seconds"
    printf 'generated_forward_source_bytes: %s\n' \
        "$(wc -c <"$out/v420_forward.f90")"
    printf 'generated_reverse_source_bytes: %s\n' \
        "$(wc -c <"$out/v420_reverse.f90")"
    cat "$out/runtime_metrics.txt"
    printf 'upstream_compiler_oracle: unmodified program.f90 compiles with '
    printf '%s\n' '-std=f2018 -pedantic-errors'
    printf 'tapenade_oracle: parser output program_p.f90 and tangent/adjoint '
    printf '%s\n' 'outputs generated and compile with strict Fortran flags'
    printf 'oracle: independent hand JVP/VJP, four-step central differences, '
    printf '%s\n' 'and the JVP/VJP adjoint identity at u=1.25'
    printf 'transform_method: date +%%s.%%N around one engine invocation per '
    printf '%s\n' 'mode; setup timed separately'
    printf 'runtime_method: Fortran system_clock over 1000000 repetitions '
    printf '%s\n' 'of one JVP and one VJP; /usr/bin/time %e and %M wrap executable'
    printf 'source_sha256:\n'
    (
        cd "$root"
        sha256sum cases/tapenade-known-failures/v420/v420.f90 \
            cases/tapenade-known-failures/v420/hand_derivatives_v420.f90 \
            cases/tapenade-known-failures/v420/manifest.toml \
            cases/tapenade-known-failures/v420/README.md \
            harness/bench_tapenade_known_failure_v420.f90 \
            scripts/bench_tapenade_known_failure_v420.sh
    )
    printf 'run_output:\n'
    cat "$out/run.txt"
} >"$result"

cat "$result"
