#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=ba15d9fc2445e7aa8e8cd130484bd0984ceb2fc1
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
fixed_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -cpp)
free_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -cpp)
legacy_fixed_flags=(-std=legacy -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -cpp)
legacy_free_flags=(-std=legacy -ffree-form -ffree-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -cpp)

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
command -v fo >/dev/null
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -x "$tapenade_repo/bin/tapenade"

source_dir="$tapenade_repo/nonRegressions/set01/lh102"
for source in program.f program_b.f program_d.f; do test -f "$source_dir/$source"; done
out=$(mktemp -d /var/tmp/fortad-bench-lh102.XXXXXX)
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/mod" "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse" "$out/fortad"

compile_status() {
    local label=$1 form=$2 standard=$3 source=$4
    local -a flags
    if test "$form" = fixed && test "$standard" = strict; then flags=("${fixed_flags[@]}" -fsyntax-only)
    elif test "$form" = fixed; then flags=("${legacy_fixed_flags[@]}" -fsyntax-only)
    elif test "$standard" = strict; then flags=("${free_flags[@]}" -fsyntax-only)
    else flags=("${legacy_free_flags[@]}" -fsyntax-only)
    fi
    "$fc" "${flags[@]}" -I"$source_dir" -J"$out/mod" "$source" >"$out/$label.stdout" 2>"$out/$label.stderr"
}

for source in program.f program_b.f program_d.f; do
    compile_status "strict-$source" fixed strict "$source_dir/$source"
    compile_status "legacy-$source" fixed legacy "$source_dir/$source"
done

oracle_output=$(python3 "$case_dir/oracle.py" "$source_dir")
grep -Fqx "oracle_status: pass" <<<"$oracle_output"

run_tapenade() {
    local mode=$1 directory=$2
    (cd "$directory" && "$tapenade_repo/bin/tapenade" "$mode" -root testprotect -O . -o lh102 "$source_dir/program.f") >"$out/tapenade/$(basename "$directory").stdout" 2>"$out/tapenade/$(basename "$directory").stderr"
}
run_tapenade -p "$out/tapenade/parser"
run_tapenade -d "$out/tapenade/forward"
run_tapenade -b "$out/tapenade/reverse"
for mode in parser forward reverse; do
    suffix=p
    test "$mode" = forward && suffix=d
    test "$mode" = reverse && suffix=b
    generated="$out/tapenade/$mode/lh102_$suffix.f"
    compile_status "tap-$mode-strict" fixed strict "$generated"
    compile_status "tap-$mode-legacy" fixed legacy "$generated"
done

fortad_run() { (cd "$fortad_repo" && fo exec --no-build fortad "$@"); }
fortad_run check --proc testprotect --output "$out/fortad/check.f90" "$source_dir/program.f" >"$out/fortad/check.log" 2>&1
fortad_run --mode forward --indep xx,vv1,vv2,vv3 --proc testprotect --name lh102_jvp --module lh102_jvp_mod --output "$out/fortad/jvp.f90" "$source_dir/program.f" >"$out/fortad/jvp.log" 2>&1
fortad_run --mode reverse --indep xx,vv1,vv2,vv3 --dep yy --proc testprotect --name lh102_vjp --module lh102_vjp_mod --output "$out/fortad/vjp.f90" "$source_dir/program.f" >"$out/fortad/vjp.log" 2>&1
for generated in check jvp vjp; do
    compile_status "fortad-$generated-strict" free strict "$out/fortad/$generated.f90"
    compile_status "fortad-$generated-legacy" free legacy "$out/fortad/$generated.f90"
done

cpu_model=$(lscpu | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
tap_hashes=$(cd "$out" && sha256sum tapenade/parser/lh102_p.f tapenade/forward/lh102_d.f tapenade/reverse/lh102_b.f)
{
    printf 'case: Tapenade nonRegressions set01 lh102
'
    printf 'classification: transformable-upstream-fortad-output-gap
'
    printf 'recorded_utc: %s
' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s
' "$(hostname)"
    printf 'os: %s
' "$os_name"
    printf 'kernel: %s
' "$(uname -srvmo)"
    printf 'cpu: %s
' "$cpu_model"
    printf 'compiler: %s
' "$($fc --version | head -1)"
    printf 'strict_fixed_flags: %s
' "${fixed_flags[*]}"
    printf 'legacy_fixed_flags: %s
' "${legacy_fixed_flags[*]}"
    printf 'fortad_commit: %s
' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s
' "$required_tapenade_commit"
    printf 'upstream_entry_point: testprotect(xx,yy,zz,vv1,vv2,vv3)
'
    printf 'upstream_strict_compile: program.f=0 program_b.f=0 program_d.f=0
'
    printf 'upstream_legacy_compile: program.f=0 program_b.f=0 program_d.f=0
'
    printf 'tapenade_generation: parser=0 forward=0 reverse=0
'
    printf 'tapenade_strict_compile: parser=0 forward=0 reverse=0
'
    printf 'tapenade_legacy_compile: parser=0 forward=0 reverse=0
'
    printf 'fortad_check: status=0 output=check.f90
'
    printf 'fortad_jvp: status=0 output=jvp.f90 observed-incomplete-zz-only-emission
'
    printf 'fortad_vjp: status=0 dep=yy output=vjp.f90 observed-zero-adjoint-emission
'
    printf 'fortad_strict_compile: check=0 jvp=0 vjp=0
'
    printf 'fortad_legacy_compile: check=0 jvp=0 vjp=0
'
    printf 'oracle_behavioral_cases: 3
'
    printf '%s
' "$oracle_output"
    printf 'upstream_sha256:
'
    (cd "$source_dir" && sha256sum program.f program_b.f program_d.f program_b.msg program_d.msg)
    printf 'fresh_tapenade_sha256:
%s
' "$tap_hashes"
    printf 'fortad_observation: generated JVP/VJP compile but do not preserve complete exact-source computation; no repaired port claimed
'
    printf 'case_artifact_sha256:
'
    (cd "$root" && sha256sum cases/tapenade-set01/lh102/manifest.toml cases/tapenade-set01/lh102/notes.md cases/tapenade-set01/lh102/oracle.py cases/tapenade-set01/lh102/run.sh cases/tapenade-set01/lh102/test_contract.py)
} >"$result"
cat "$result"
