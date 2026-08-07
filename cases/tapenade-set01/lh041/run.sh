#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case_dir="$root/cases/tapenade-set01/lh041"
result="$case_dir/result.txt"
fortad_source=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_source=$(cd "$fortad_source" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=db0050259520b618e2a0aeba203c85a7613943b5
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_dir="$tapenade_repo/nonRegressions/set01/lh041"

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
command -v fo >/dev/null
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
for source in program.f program_d.f program_b.f program_dv.f program_p.f \
              program_d.msg program_b.msg program_dv.msg program_p.msg; do
    test -e "$source_dir/$source"
done

out=$(mktemp -d /var/tmp/tapenade-set01-lh041.XXXXXX)
clean_fortad_repo=
cleanup() {
    rm -rf "$out"
    test -z "$clean_fortad_repo" || rm -rf "$clean_fortad_repo"
}
trap cleanup EXIT
if test "$(git -C "$fortad_source" rev-parse HEAD)" != "$required_fortad_commit"; then
    clean_fortad_repo=$(mktemp -d "$(dirname "$fortad_source")/fortad-lh041-clean.XXXXXX")
    rmdir "$clean_fortad_repo"
    git clone --shared --quiet "$fortad_source" "$clean_fortad_repo"
    git -C "$clean_fortad_repo" checkout --detach --quiet "$required_fortad_commit"
    fortad_repo="$clean_fortad_repo"
else
    fortad_repo="$fortad_source"
fi
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"

mkdir -p "$out/mod" "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse" "$out/fortad"
strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface)
strict_free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -O2 -fno-lto -Wall -Wextra -Wimplicit-interface)
compile_capture() {
    local source=$1 object=$2 label=$3 form=$4 include_dir=${5:-}
    local -a flags
    if test "$form" = fixed; then flags=("${strict_fixed[@]}"); else flags=("${strict_free[@]}" "-J$out/mod" "-I$out/mod"); fi
    test -z "$include_dir" || flags+=("-I$include_dir")
    set +e
    "$fc" "${flags[@]}" -c "$source" -o "$object" >"$out/$label.stdout" 2>"$out/$label.stderr"
    local status=$?
    set -e
    printf '%s\n' "$status" >"$out/$label.status"
}

if test ! -x "$fortad_repo/build/fo/bin/fortad"; then
    (cd "$fortad_repo" && fo build) >"$out/fortad-build.log" 2>&1
fi
fortad_bin="$fortad_repo/build/fo/bin/fortad"
test -x "$fortad_bin"
tapenade="$tapenade_repo/bin/tapenade"
if test ! -x "$tapenade"; then (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1; fi
test -x "$tapenade"

upstream_start=$(date +%s.%N)
for source in program.f program_d.f program_b.f program_dv.f program_p.f; do
    include_dir=
    test "$source" = program_dv.f && include_dir="$source_dir"
    compile_capture "$source_dir/$source" "$out/upstream_${source}.o" "upstream_${source}" fixed "$include_dir"
done
upstream_stop=$(date +%s.%N)
upstream_seconds=$(awk -v a="$upstream_start" -v b="$upstream_stop" 'BEGIN {printf "%.6f", b-a}')
test "$(cat "$out/upstream_program.f.status")" = 0
test "$(cat "$out/upstream_program_d.f.status")" = 0
test "$(cat "$out/upstream_program_b.f.status")" = 0
test "$(cat "$out/upstream_program_dv.f.status")" -ne 0
grep -Fq "Cannot open included file ‘DIFFSIZES.inc’" "$out/upstream_program_dv.f.stderr"
test "$(cat "$out/upstream_program_p.f.status")" = 0

tapenade_start=$(date +%s.%N)
(cd "$out/tapenade/parser" && "$tapenade" -p -root adj10 -o lh041 "$source_dir/program.f") >"$out/tapenade-parser.log" 2>&1
(cd "$out/tapenade/forward" && "$tapenade" -d -root adj10 -o lh041 "$source_dir/program.f") >"$out/tapenade-forward.log" 2>&1
(cd "$out/tapenade/reverse" && "$tapenade" -b -root adj10 -o lh041 "$source_dir/program.f") >"$out/tapenade-reverse.log" 2>&1
tapenade_stop=$(date +%s.%N)
tapenade_seconds=$(awk -v a="$tapenade_start" -v b="$tapenade_stop" 'BEGIN {printf "%.6f", b-a}')
for generated in "$out/tapenade/parser/lh041_p.f" "$out/tapenade/forward/lh041_d.f" "$out/tapenade/reverse/lh041_b.f"; do test -s "$generated"; done
compile_capture "$out/tapenade/parser/lh041_p.f" "$out/tapenade_parser.o" tapenade_parser fixed
compile_capture "$out/tapenade/forward/lh041_d.f" "$out/tapenade_forward.o" tapenade_forward fixed
compile_capture "$out/tapenade/reverse/lh041_b.f" "$out/tapenade_reverse.o" tapenade_reverse fixed
for label in tapenade_parser tapenade_forward tapenade_reverse; do test "$(cat "$out/$label.status")" = 0; done

exact_diagnostic='fortad: parse failed: ERROR at line 18, column 7: internal: could not locate the end of this do construct; refusing to drop the statements that follow'
set +e
"$fortad_bin" --mode forward --indep a,b,q --dep result --proc adj10 --name lh041_exact_forward --module lh041_exact_forward_mod --output "$out/exact_forward.f90" "$source_dir/program.f" >"$out/exact-forward.log" 2>&1
exact_forward_status=$?
"$fortad_bin" --mode reverse --indep a,b,q --dep result --proc adj10 --name lh041_exact_reverse --module lh041_exact_reverse_mod --output "$out/exact_reverse.f90" "$source_dir/program.f" >"$out/exact-reverse.log" 2>&1
exact_reverse_status=$?
set -e
test "$exact_forward_status" -ne 0
test "$exact_reverse_status" -ne 0
grep -Fq "$exact_diagnostic" "$out/exact-forward.log"
grep -Fq "$exact_diagnostic" "$out/exact-reverse.log"
test ! -e "$out/exact_forward.f90"
test ! -e "$out/exact_reverse.f90"

set +e
fortad_port_start=$(date +%s.%N)
"$fortad_bin" --mode forward --indep a,b,q --dep result --proc set01_lh041 --name lh041_forward --module lh041_forward_mod --output "$out/fortad/lh041_forward.f90" "$case_dir/port.f90" >"$out/fortad-forward.log" 2>&1
port_forward_status=$?
"$fortad_bin" --mode reverse --indep a,b,q --dep result --proc set01_lh041 --name lh041_reverse --module lh041_reverse_mod --output "$out/fortad/lh041_reverse.f90" "$case_dir/port.f90" >"$out/fortad-reverse.log" 2>&1
port_reverse_status=$?
set -e
fortad_port_stop=$(date +%s.%N)
fortad_port_seconds=$(awk -v a="$fortad_port_start" -v b="$fortad_port_stop" 'BEGIN {printf "%.6f", b-a}')
test "$port_forward_status" = 0
test -s "$out/fortad/lh041_forward.f90"
test "$port_reverse_status" -ne 0
port_reverse_diagnostic="fortad: reverse mode: 'x' is both read and written in the same loop; that needs per-iteration storage"
grep -Fq "$port_reverse_diagnostic" "$out/fortad-reverse.log"
test ! -e "$out/fortad/lh041_reverse.f90"

compile_start=$(date +%s.%N)
compile_capture "$case_dir/port.f90" "$out/port.o" port free
compile_capture "$out/fortad/lh041_forward.f90" "$out/fortad_forward.o" fortad_forward free
compile_capture "$root/harness/bench_tapenade_set01_lh041.f90" "$out/harness.o" harness free
for label in port fortad_forward harness; do test "$(cat "$out/$label.status")" = 0; done
"$fc" "${strict_free[@]}" -J"$out/mod" -I"$out/mod" -o "$out/bench" "$out/port.o" "$out/fortad_forward.o" "$out/harness.o"
compile_stop=$(date +%s.%N)
compile_seconds=$(awk -v a="$compile_start" -v b="$compile_stop" 'BEGIN {printf "%.6f", b-a}')
set +e
/usr/bin/time -f 'runtime_wall_seconds=%e\nruntime_peak_rss_kb=%M' -o "$out/runtime-metrics.txt" "$out/bench" >"$out/run.txt" 2>"$out/run.stderr"
run_status=$?
set -e
test "$run_status" = 0
grep -Fqx 'oracle_status: pass' "$out/run.txt"
oracle_output=$(python3 "$case_dir/oracle.py")
grep -Fqx 'oracle_status: pass' <<<"$oracle_output"

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh041\n'
    printf 'classification: runnable-ported-with-exact-source-fortad-refusal\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s\n' "${strict_fixed[*]}"
    printf 'strict_free_flags: %s\n' "${strict_free[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'required_fortad_commit: %s\n' "$required_fortad_commit"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_strict_compile_seconds: %s\n' "$upstream_seconds"
    printf 'upstream_program.f_strict_compile: pass status=%s\n' "$(cat "$out/upstream_program.f.status")"
    printf 'upstream_program_d.f_strict_compile: pass status=%s\n' "$(cat "$out/upstream_program_d.f.status")"
    printf 'upstream_program_b.f_strict_compile: pass status=%s\n' "$(cat "$out/upstream_program_b.f.status")"
    printf 'upstream_program_dv.f_strict_compile: expected-refusal status=%s missing DIFFSIZES.inc\n' "$(cat "$out/upstream_program_dv.f.status")"
    printf 'upstream_program_p.f_strict_compile: pass status=%s\n' "$(cat "$out/upstream_program_p.f.status")"
    printf 'stored_references: program_d.f program_b.f program_dv.f program_p.f and message files present\n'
    printf 'tapenade_generation_seconds: %s\n' "$tapenade_seconds"
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_parser_strict_compile: pass status=%s\n' "$(cat "$out/tapenade_parser.status")"
    printf 'tapenade_forward_strict_compile: pass status=%s\n' "$(cat "$out/tapenade_forward.status")"
    printf 'tapenade_reverse_strict_compile: pass status=%s\n' "$(cat "$out/tapenade_reverse.status")"
    printf 'fortad_exact_forward: expected-refusal status=%s\n' "$exact_forward_status"
    printf 'fortad_exact_reverse: expected-refusal status=%s\n' "$exact_reverse_status"
    printf 'fortad_exact_diagnostic: %s\n' "$exact_diagnostic"
    printf 'fortad_port_transform_seconds: %s\n' "$fortad_port_seconds"
    printf 'fortad_port_forward: pass-transform-compile-runtime status=%s\n' "$port_forward_status"
    printf 'fortad_port_reverse: expected-refusal status=%s\n' "$port_reverse_status"
    printf 'fortad_port_reverse_diagnostic: %s\n' "$port_reverse_diagnostic"
    printf 'fortad_port_compile_statuses: port=%s generated_forward=%s harness=%s\n' "$(cat "$out/port.status")" "$(cat "$out/fortad_forward.status")" "$(cat "$out/harness.status")"
    printf 'compile_link_seconds: %s\n' "$compile_seconds"
    printf 'independent_oracle: hand dual-number JVP, central-difference sweep, and adjoint identity\n'
    printf '%s\n' "$oracle_output"
    cat "$out/runtime-metrics.txt"
    printf 'compiled_harness_output:\n'
    cat "$out/run.txt"
    printf 'source_sha256:\n'
    (cd "$tapenade_repo" && sha256sum nonRegressions/set01/lh041/program.f nonRegressions/set01/lh041/program_d.f nonRegressions/set01/lh041/program_b.f nonRegressions/set01/lh041/program_dv.f nonRegressions/set01/lh041/program_p.f nonRegressions/set01/lh041/program_d.msg nonRegressions/set01/lh041/program_b.msg nonRegressions/set01/lh041/program_dv.msg nonRegressions/set01/lh041/program_p.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/lh041/manifest.toml cases/tapenade-set01/lh041/notes.md cases/tapenade-set01/lh041/port.f90 cases/tapenade-set01/lh041/oracle.py cases/tapenade-set01/lh041/run.sh cases/tapenade-set01/lh041/test_contract.py harness/bench_tapenade_set01_lh041.f90)
} >"$result"
cat "$result"
