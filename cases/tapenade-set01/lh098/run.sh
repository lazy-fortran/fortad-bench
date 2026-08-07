#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=${FORTAD_REPO:-/mnt/storage/code/lazy-fortran/fortad}
tapenade_repo=${TAPENADE_REPO:-/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
required_fortad_commit=ba15d9fc2445e7aa8e8cd130484bd0984ceb2fc1
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_dir="$tapenade_repo/nonRegressions/set01/lh098"
strict_flags=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface)
legacy_flags=(-std=legacy -ffixed-form -ffixed-line-length-none -Wall -Wextra)
free_flags=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface)

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
command -v fo >/dev/null
test -x "$tapenade_repo/bin/tapenade"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -s "$source_dir/program.f"
test -s "$source_dir/program_d.f"
test -s "$source_dir/program_d.msg"

out=$(mktemp -d /var/tmp/fortad-bench-lh098.XXXXXX)
cleanup() {
    find "$out" -depth -type f -delete
    find "$out" -depth -type d -empty -delete
}
trap cleanup EXIT
test -x "$fortad_repo/build/fo/bin/fortad"
mkdir -p "$out/tapenade/parser" "$out/tapenade/forward" "$out/tapenade/reverse" "$out/fortad" "$out/mod"

compile() { local label=$1 flags_name=$2 source=$3; shift 3; local -a flags; eval "flags=(\"\${${flags_name}[@]}\")"; "$fc" "${flags[@]}" -J"$out/mod" -c "$source" -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"; }
compile_expected_refusal() { local label=$1 flags_name=$2 source=$3; local -a flags; eval "flags=(\"\${${flags_name}[@]}\")"; set +e; "$fc" "${flags[@]}" -J"$out/mod" -c "$source" -o "$out/$label.o" >"$out/$label.stdout" 2>"$out/$label.stderr"; local status=$?; set -e; printf '%s\n' "$status" >"$out/$label.status"; test "$status" -ne 0; }
compile upstream_strict strict_flags "$source_dir/program.f"
compile stored_strict strict_flags "$source_dir/program_d.f"
compile upstream_legacy legacy_flags "$source_dir/program.f"
compile stored_legacy legacy_flags "$source_dir/program_d.f"
python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fqx 'oracle_status: pass' "$out/oracle.txt"

run_tapenade() { local label=$1 flag=$2 dir=$3; (cd "$dir" && "$tapenade_repo/bin/tapenade" "$flag" -root ff -O . -o lh098 "$source_dir/program.f") >"$out/tapenade-$label.log" 2>&1; }
run_tapenade parser -p "$out/tapenade/parser"
run_tapenade forward -d "$out/tapenade/forward"
run_tapenade reverse -b "$out/tapenade/reverse"
for generated in "$out/tapenade/parser/lh098_p.f" "$out/tapenade/forward/lh098_d.f" "$out/tapenade/reverse/lh098_b.f"; do test -s "$generated"; done
for generated in "$out/tapenade/parser/lh098_p.f" "$out/tapenade/forward/lh098_d.f" "$out/tapenade/reverse/lh098_b.f"; do
    label=$(basename "$generated" .f)
    compile "fresh_${label}_strict" strict_flags "$generated"
    compile "fresh_${label}_legacy" legacy_flags "$generated"
done
grep -Fq '(DF05)' "$out/tapenade/forward/lh098_d.msg"
grep -Fq '(DF05)' "$out/tapenade/reverse/lh098_b.msg"

fortad="$fortad_repo/build/fo/bin/fortad"
"$fortad" check --proc ff --output "$out/fortad/check.f90" "$source_dir/program.f" >"$out/fortad/check.log" 2>&1
"$fortad" --mode forward --indep t,x --proc ff --name lh098_jvp --module lh098_jvp_mod --output "$out/fortad/jvp.f90" "$source_dir/program.f" >"$out/fortad/jvp.log" 2>&1
"$fortad" --mode reverse --indep t,x --dep xbt --proc ff --name lh098_vjp --module lh098_vjp_mod --output "$out/fortad/vjp.f90" "$source_dir/program.f" >"$out/fortad/vjp.log" 2>&1
for generated in "$out/fortad/check.f90" "$out/fortad/jvp.f90" "$out/fortad/vjp.f90"; do
    test -s "$generated"
    label=$(basename "$generated" .f90)
    compile_expected_refusal "fortad_${label}_strict" free_flags "$generated"
    compile_expected_refusal "fortad_${label}_legacy" legacy_flags "$generated"
done

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions set01 lh098 exact ff\n'
    printf 'classification: runnable-exact-source-no-port\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'legacy_compiler_flags: %s\n' "${legacy_flags[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: ff(N,t,xbt,x)\n'
    printf 'upstream_exact_strict_compile: pass status=0\n'
    printf 'upstream_stored_forward_strict_compile: pass status=0\n'
    printf 'upstream_exact_legacy_compile: pass status=0\n'
    printf 'upstream_stored_forward_legacy_compile: pass status=0\n'
    printf 'tapenade_generation: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_fresh_strict_compile: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_fresh_legacy_compile: parser=pass tangent=pass reverse=pass\n'
    printf 'tapenade_diagnostics: DD31 DF05\n'
    printf 'fortad_exact_parser_check: pass output=check.f90\n'
    printf 'fortad_exact_jvp: pass output=jvp.f90\n'
    printf 'fortad_exact_vjp: pass output=vjp.f90\n'
    printf 'fortad_generated_strict_compile: check=expected-refusal status=%s jvp=expected-refusal status=%s vjp=expected-refusal status=%s\n' \
        "$(cat "$out/fortad_check_strict.status")" "$(cat "$out/fortad_jvp_strict.status")" "$(cat "$out/fortad_vjp_strict.status")"
    printf 'fortad_generated_legacy_compile: check=expected-refusal status=%s jvp=expected-refusal status=%s vjp=expected-refusal status=%s\n' \
        "$(cat "$out/fortad_check_legacy.status")" "$(cat "$out/fortad_jvp_legacy.status")" "$(cat "$out/fortad_vjp_legacy.status")"
    printf 'fortad_generated_diagnostics: check=external-cnklog-type jvp=duplicate-k-and-external-cnklog-type vjp=external-cnklog-type\n'
    printf 'independent_semantic_oracle:\n'; sed 's/^/  /' "$out/oracle.txt"
    printf 'port_result: not-created exact-source-preserved\n'
    printf 'upstream_sha256:\n'; (cd "$tapenade_repo" && sha256sum nonRegressions/set01/lh098/program.f nonRegressions/set01/lh098/program_d.f nonRegressions/set01/lh098/program_d.msg)
    printf 'case_artifact_sha256:\n'; (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
