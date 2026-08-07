#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fortad_repo=${FORTAD_REPO:-"$root/../fortad"}
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
fortad_repo=$(cd "$fortad_repo" && pwd)
tapenade_repo=$(cd "$tapenade_repo" && pwd)
fc=${FC:-gfortran}
required_fortad_commit=a1c9f25f87eaadf700ba47ee3e841a0fb41585a3
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
strict_fixed=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface)
strict_free=(-std=f2018 -ffree-form -ffree-line-length-none -pedantic-errors -Wall -Wextra -Wimplicit-interface -fno-lto)

command -v "$fc" >/dev/null
command -v python3 >/dev/null
command -v fo >/dev/null
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$tapenade"

(cd "$fortad_repo" && fo build) >/dev/null
test -x "$fortad"

requested=("$@")
if test "${#requested[@]}" -eq 0; then
    requested=(v128 v130 v103)
fi
for case_id in "${requested[@]}"; do
    case_dir="$root/cases/tapenade-set02/$case_id"
    result="$case_dir/result.txt"
    source_dir="$tapenade_repo/nonRegressions/set02/$case_id"
    out=$(mktemp -d "/var/tmp/tapenade-set02-$case_id.XXXXXX")
    trap 'find "$out" -depth -type f -delete; find "$out" -depth -type d -empty -delete' EXIT
    mkdir -p "$out/fresh" "$out/fresh-mod" "$out/fortad" "$out/fortad-mod"

    compile_capture() {
        local label=$1 source=$2 object=$3 form=$4
        shift 4
        local -a flags
        if test "$form" = fixed; then flags=("${strict_fixed[@]}"); else flags=("${strict_free[@]}"); fi
        set +e
        "$fc" "${flags[@]}" "$@" -I"$source_dir" -J"$out/fortad-mod" -c "$source" -o "$object" \
            >"$out/$label.stdout" 2>"$out/$label.stderr"
        local status=$?
        set -e
        printf '%s\n' "$status" >"$out/$label.status"
    }

    run_capture() {
        local label=$1
        shift
        set +e
        "$@" >"$out/$label.stdout" 2>"$out/$label.stderr"
        local status=$?
        set -e
        printf '%s\n' "$status" >"$out/$label.status"
    }

    compile_capture "$case_id-exact-primal" "$source_dir/program.f" "$out/$case_id-exact-primal.o" fixed
    test "$(cat "$out/$case_id-exact-primal.status")" -eq 0
    for reference in program_dv.f program_d.f program_p.f; do
        if test -f "$source_dir/$reference"; then
            base=${reference%.f}
            compile_capture "$case_id-exact-$base" "$source_dir/$reference" "$out/$case_id-exact-$base.o" fixed
            test "$(cat "$out/$case_id-exact-$base.status")" -eq 0
        fi
    done

    for mode in p d b; do
        mode_dir="$out/fresh/$mode"
        mkdir -p "$mode_dir"
        run_capture "$case_id-tapenade-generate-$mode" bash -c \
            "cd '$mode_dir' && '$tapenade' '-$mode' -root foo -O . -o '$case_id' '$source_dir/program.f'"
        test "$(cat "$out/$case_id-tapenade-generate-$mode.status")" -eq 0
        generated="$mode_dir/${case_id}_${mode}.f"
        test -s "$generated"
        compile_capture "$case_id-tapenade-compile-$mode" "$generated" "$out/$case_id-tapenade-$mode.o" fixed
        test "$(cat "$out/$case_id-tapenade-compile-$mode.status")" -eq 0
    done

    run_capture "$case_id-fortad-check" "$fortad" check --proc foo --output "$out/fortad/check.f90" "$source_dir/program.f"
    run_capture "$case_id-fortad-forward" "$fortad" --mode forward --indep x --dep y --proc foo \
        --name "${case_id}_jvp" --module "${case_id}_jvp_ad" --output "$out/fortad/forward.f90" "$source_dir/program.f"
    run_capture "$case_id-fortad-reverse" "$fortad" --mode reverse --indep x --dep y --proc foo \
        --name "${case_id}_vjp" --module "${case_id}_vjp_ad" --output "$out/fortad/reverse.f90" "$source_dir/program.f"

    if test "$case_id" = v103; then
        for mode in check forward reverse; do
            test "$(cat "$out/$case_id-fortad-$mode.status")" -ne 0
            test ! -e "$out/fortad/$mode.f90"
            grep -Fq "unsupported statement at line 32" "$out/$case_id-fortad-$mode.stderr"
        done
        python3 "$case_dir/oracle.py" >"$out/oracle.txt"
        grep -Fqx 'oracle_status: pass' "$out/oracle.txt"
    else
        for mode in check forward reverse; do
            test "$(cat "$out/$case_id-fortad-$mode.status")" -eq 0
        done
        test -s "$out/fortad/forward.f90"
        test -s "$out/fortad/reverse.f90"
        compile_capture "$case_id-fortad-forward-compile" "$out/fortad/forward.f90" "$out/$case_id-fortad-forward.o" free
        compile_capture "$case_id-fortad-reverse-compile" "$out/fortad/reverse.f90" "$out/$case_id-fortad-reverse.o" free
        test "$(cat "$out/$case_id-fortad-forward-compile.status")" -eq 0
        test "$(cat "$out/$case_id-fortad-reverse-compile.status")" -eq 0
        compile_capture "$case_id-harness-compile" "$case_dir/harness.f90" "$out/$case_id-harness.o" free
        test "$(cat "$out/$case_id-harness-compile.status")" -eq 0
        "$fc" "${strict_free[@]}" -I"$out/fortad-mod" -J"$out/fortad-mod" \
            -o "$out/$case_id-harness" "$out/$case_id-fortad-forward.o" \
            "$out/$case_id-fortad-reverse.o" "$out/$case_id-harness.o"
        "$out/$case_id-harness" >"$out/harness.txt"
        grep -Fqx 'harness_status: pass' "$out/harness.txt"
        python3 "$case_dir/oracle.py" >"$out/oracle.txt"
        grep -Fqx 'oracle_status: pass' "$out/oracle.txt"
    fi

    cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
    os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
    {
        printf 'case: Tapenade nonRegressions set02 %s\n' "$case_id"
        printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf 'machine: %s\n' "$(hostname)"
        printf 'os: %s\n' "$os_name"
        printf 'cpu: %s\n' "$cpu_model"
        printf 'compiler: %s\n' "$($fc --version | head -1)"
        printf 'strict_fixed_flags: %s\n' "${strict_fixed[*]}"
        printf 'strict_free_flags: %s\n' "${strict_free[*]}"
        printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
        printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
        printf 'entry_point: foo\n'
        printf 'tapenade_generation: parser=%s tangent=%s reverse=%s\n' \
            "$(cat "$out/$case_id-tapenade-generate-p.status")" \
            "$(cat "$out/$case_id-tapenade-generate-d.status")" \
            "$(cat "$out/$case_id-tapenade-generate-b.status")"
        printf 'tapenade_fresh_strict_compile: parser=%s tangent=%s reverse=%s\n' \
            "$(cat "$out/$case_id-tapenade-compile-p.status")" \
            "$(cat "$out/$case_id-tapenade-compile-d.status")" \
            "$(cat "$out/$case_id-tapenade-compile-b.status")"
        printf 'upstream_exact_strict_compile: primal=%s' "$(cat "$out/$case_id-exact-primal.status")"
        for reference in program_dv.f program_d.f program_p.f; do
            if test -f "$source_dir/$reference"; then
                base=${reference%.f}; printf ' %s=%s' "$base" "$(cat "$out/$case_id-exact-$base.status")"
            fi
        done
        printf '\n'
        printf 'fortad_exact_check_forward_reverse: %s %s %s\n' \
            "$(cat "$out/$case_id-fortad-check.status")" \
            "$(cat "$out/$case_id-fortad-forward.status")" \
            "$(cat "$out/$case_id-fortad-reverse.status")"
        if test "$case_id" = v103; then
            printf 'fortad_result: expected-refusal; diagnostic="unsupported statement at line 32"; no output\n'
        else
            printf 'fortad_generated_strict_compile: forward=%s reverse=%s\n' \
                "$(cat "$out/$case_id-fortad-forward-compile.status")" \
                "$(cat "$out/$case_id-fortad-reverse-compile.status")"
            printf 'fortad_harness: %s\n' "$(cat "$out/harness.txt")"
        fi
        cat "$out/oracle.txt"
        printf 'oracle: independent hand JVP/VJP, central-difference sweep, adjoint identity\n'
        printf 'upstream_sha256:\n'
        (cd "$tapenade_repo" && sha256sum "nonRegressions/set02/$case_id"/DIFFSIZES.inc \
            "nonRegressions/set02/$case_id"/program*.f "nonRegressions/set02/$case_id"/program*.msg 2>/dev/null || true)
        printf 'case_artifact_sha256:\n'
        (cd "$root" && sha256sum "cases/tapenade-set02/$case_id/manifest.toml" \
            "cases/tapenade-set02/$case_id/notes.md" "cases/tapenade-set02/$case_id/oracle.py" \
            "cases/tapenade-set02/$case_id/run.sh" "scripts/bench_tapenade_set02_tranche_b.sh" \
            "cases/tapenade-set02/$case_id/harness.f90" 2>/dev/null || true)
    } >"$result"
    cat "$result"
    trap - EXIT
    find "$out" -depth -type f -delete
    find "$out" -depth -type d -empty -delete
done
