#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
fortad_repo=$(cd "${FORTAD_REPO:-$root/../fortad}" && pwd)
fc=${FC:-gfortran}
tapenade="$tapenade_repo/bin/tapenade"
fortad="$fortad_repo/build/fo/bin/fortad"
result="$root/results/tapenade_set12_profile_tranche_validation.txt"
out=$(mktemp -d /var/tmp/fortad-bench-set12-profile.XXXXXX)
trap 'rm -rf "$out"' EXIT

test -x "$tapenade" && test -x "$fortad"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "e59864cab441d4175df75383b3ff58c3dcd26df9"
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "597ea236fb5ede09c0e6fb752355f78511746608"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -s "$tapenade_repo/build/libs/tapenade-3.16.jar"

free_strict=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -Wall -Wextra -fsyntax-only)
fixed_strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -fsyntax-only)
source_jlb="$tapenade_repo/nonRegressions/set12/jlb012/program.f90"
source_profile="$tapenade_repo/nonRegressions/set12/profile01/program.f"
"$fc" "${free_strict[@]}" "$source_jlb"
"$fc" "${fixed_strict[@]}" "$source_profile"

run_tapenade() {
    local id=$1 source=$2 root_name=$3 form=$4 expected_compile=$5
    local mode flag generated
    for mode in parser forward reverse; do
        case "$mode" in parser) flag=p;; forward) flag=d;; reverse) flag=b;; esac
        mkdir -p "$out/tapenade/$id/$mode"
        (cd "$(dirname "$source")" && "$tapenade" "-$flag" -root "$root_name" \
            -O "$out/tapenade/$id/$mode" -o probe "$(basename "$source")") \
            >"$out/tapenade/$id/$mode/stdout" 2>"$out/tapenade/$id/$mode/stderr"
        generated=$(find "$out/tapenade/$id/$mode" -maxdepth 1 -type f \
            \( -name 'probe_*.f' -o -name 'probe_*.f90' \) | head -1)
        if test ! -s "$generated"; then
            test "$expected_compile" = refuse
            printf '%s %s no-generated-source-strict-refusal\n' "$id" "$mode" \
                >>"$out/tapenade-status"
            continue
        fi
        set +e
        if test "$form" = free; then "$fc" "${free_strict[@]}" "$generated" \
            >"$out/tapenade/$id/$mode/compile.stdout" \
            2>"$out/tapenade/$id/$mode/compile.stderr"
        else "$fc" "${fixed_strict[@]}" "$generated" \
            >"$out/tapenade/$id/$mode/compile.stdout" \
            2>"$out/tapenade/$id/$mode/compile.stderr"; fi
        local compile_status=$?
        set -e
        if test "$expected_compile" = pass; then
            test "$compile_status" -eq 0
            printf '%s %s generated-and-strict-compiled %s\n' "$id" "$mode" \
                "$(basename "$generated")" >>"$out/tapenade-status"
        else
            test "$compile_status" -ne 0
            grep -Fq 'GNU Extension' "$out/tapenade/$id/$mode/compile.stderr"
            printf '%s %s generated-strict-compile-refused %s\n' "$id" "$mode" \
                "$(basename "$generated")" >>"$out/tapenade-status"
        fi
    done
}

run_tapenade jlb012 "$source_jlb" mysum free refuse
run_tapenade profile01 "$source_profile" foo fixed pass

mkdir -p "$out/fortad"
"$fortad" --mode forward --proc foo --indep a,b --dep c \
    --name foo_jvp --module set12_profile01_jvp_mod \
    --output "$out/fortad/profile01_jvp.f90" "$source_profile"
"$fortad" --mode reverse --proc foo --indep a,b --dep c \
    --name foo_vjp --module set12_profile01_vjp_mod \
    --output "$out/fortad/profile01_vjp.f90" "$source_profile"
"$fc" "${free_strict[@]}" "$out/fortad/profile01_jvp.f90"
"$fc" "${free_strict[@]}" "$out/fortad/profile01_vjp.f90"
"$fc" -std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -O0 \
    -o "$out/profile-oracle" "$root/harness/bench_tapenade_set12_profile_tranche.f90" \
    "$out/fortad/profile01_jvp.f90" "$out/fortad/profile01_vjp.f90"
"$out/profile-oracle" | grep -Fqx 'oracle_status: pass'

set +e
"$fortad" --mode forward --proc mysum --indep x --dep mysum \
    --name mysum_jvp --module set12_jlb012_jvp_mod \
    --output "$out/fortad/jlb012_jvp.f90" "$source_jlb" \
    >"$out/fortad/jlb012_forward.stdout" 2>"$out/fortad/jlb012_forward.stderr"
jlb_forward_status=$?
"$fortad" --mode reverse --proc mysum --indep x --dep mysum \
    --name mysum_vjp --module set12_jlb012_vjp_mod \
    --output "$out/fortad/jlb012_vjp.f90" "$source_jlb" \
    >"$out/fortad/jlb012_reverse.stdout" 2>"$out/fortad/jlb012_reverse.stderr"
jlb_reverse_status=$?
set -e
test "$jlb_forward_status" -eq 0
test "$jlb_reverse_status" -eq 0
"$fc" "${free_strict[@]}" "$out/fortad/jlb012_jvp.f90" \
    >"$out/fortad/jlb012_jvp_compile.stdout" 2>"$out/fortad/jlb012_jvp_compile.stderr" && exit 1 || true
"$fc" "${free_strict[@]}" "$out/fortad/jlb012_vjp.f90" \
    >"$out/fortad/jlb012_vjp_compile.stdout" 2>"$out/fortad/jlb012_vjp_compile.stderr" && exit 1 || true
grep -Fq 'Error:' "$out/fortad/jlb012_jvp_compile.stderr"
grep -Fq 'Error:' "$out/fortad/jlb012_vjp_compile.stderr"

python3 "$root/cases/tapenade-set12-profile-tranche/oracle.py" | \
    grep -Fqx 'oracle_status: pass'

{
    printf 'tranche: Tapenade set12 profile\n'
    printf 'runner_result: pass\n'
    printf 'tapenade_revision: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'fortad_revision: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'exact_source_compile: jlb012=pass-free-form; profile01=pass-fixed-form\n'
    printf 'tapenade_modes: fresh-parser-forward-reverse; jlb012-generated-strict-compile-refusal; profile01-generated-strict-compile-pass\n'
    cat "$out/tapenade-status"
    printf 'fortad_profile01: forward-reverse-generated-strict-compile-runtime-pass\n'
    printf 'fortad_jlb012: forward-reverse-generated-but-strict-compile-refusal\n'
    printf 'tapenade_jlb012_compile_diagnostic: '
    grep -m1 -F 'Error:' "$out/tapenade/jlb012/parser/compile.stderr"
    printf 'fortad_jlb012_forward_compile_diagnostic: '
    grep -m1 -F 'Error:' "$out/fortad/jlb012_jvp_compile.stderr"
    printf 'fortad_jlb012_reverse_compile_diagnostic: '
    grep -m1 -F 'Error:' "$out/fortad/jlb012_vjp_compile.stderr"
    printf 'independent_oracle: hand-central-difference-sweep-adjoint-identity\n'
    printf 'oracle_status: pass\n'
    printf 'source_sha256:\n'
    sha256sum "$source_jlb" "$source_profile"
} >"$result"
cat "$result"
