#!/usr/bin/env bash
set -euo pipefail

case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$case_dir/../../.." && pwd)
result="$case_dir/result.txt"
fortad_repo=$(cd "${FORTAD_REPO:-$root/../fortad}" && pwd)
tapenade_repo=$(cd "${TAPENADE_REPO:-$root/upstream/tapenade}" && pwd)
required_fortad_commit=8137837b6c474708c20ea86ad02b086aa15322fd
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
source_rel=nonRegressions/set01/ala01
source_dir="$tapenade_repo/$source_rel"
fortad="$fortad_repo/build/fo/bin/fortad"
tapenade="$tapenade_repo/bin/tapenade"
out=$(mktemp -d /var/tmp/fortad-bench-tapenade-set01-ala01.XXXXXX)

command -v "$fc" >/dev/null
command -v java >/dev/null
command -v python3 >/dev/null
command -v fo >/dev/null
test "$(git -C "$fortad_repo" rev-parse HEAD)" = "$required_fortad_commit"
test "$(git -C "$fortad_repo" branch --show-current)" = main
test -z "$(git -C "$fortad_repo" status --porcelain --untracked-files=no)"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"
test -x "$fortad" && test -x "$tapenade"
for source in Options program.f program_d.f program_d.msg program_b.f program_b.msg; do
    test -e "$source_dir/$source"
done

strict=(-std=f2018 -ffixed-form -ffixed-line-length-none -pedantic-errors
    -Wall -Wextra -Wimplicit-interface -fsyntax-only -fno-lto)
legacy=(-std=legacy -ffixed-form -ffixed-line-length-none -Wall -Wextra
    -Wimplicit-interface -fsyntax-only -fno-lto)

run_status() {
    local label=$1
    shift
    local status=0
    "$@" >"$out/$label.stdout" 2>"$out/$label.stderr" || status=$?
    printf '%s\n' "$status" >"$out/$label.status"
}

status() { cat "$out/$1.status"; }

mkdir -p "$out/fresh/parser" "$out/fresh/forward" "$out/fresh/reverse" "$out/fortad"

# Exact upstream source and stored reference gates, in both strict and legacy
# fixed-form modes. The reverse artifact's strict failure is intentional.
for file in program.f program_d.f program_b.f; do
    run_status "exact-strict-${file%.f}" "$fc" "${strict[@]}" "$source_dir/$file"
    run_status "exact-legacy-${file%.f}" "$fc" "${legacy[@]}" "$source_dir/$file"
done
test "$(status exact-strict-program)" -eq 0
test "$(status exact-strict-program_d)" -eq 0
test "$(status exact-strict-program_b)" -ne 0
grep -Fq 'Nonstandard type declaration REAL*8' "$out/exact-strict-program_b.stderr"
for label in exact-legacy-program exact-legacy-program_d exact-legacy-program_b; do
    test "$(status "$label")" -eq 0
done

# Fresh pinned Tapenade generation using the case's recorded Options mode and
# explicit -p/-d/-b and -root options.
for mode in parser forward reverse; do
    case "$mode" in
        parser) flag=-p; suffix=p ;;
        forward) flag=-d; suffix=d ;;
        reverse) flag=-b; suffix=b ;;
    esac
    run_status "tapenade-$mode" bash -c \
        "cd '$out/fresh/$mode' && '$tapenade' '$flag' -context -root root -O . -o ala01 '$source_dir/program.f'"
    test "$(status "tapenade-$mode")" -eq 0
    test -e "$out/fresh/$mode/ala01_${suffix}.msg"
    test -s "$out/fresh/$mode/ala01_${suffix}.f"
    run_status "fresh-$mode-strict" "$fc" "${strict[@]}" \
        "$out/fresh/$mode/ala01_${suffix}.f"
    run_status "fresh-$mode-legacy" "$fc" "${legacy[@]}" \
        "$out/fresh/$mode/ala01_${suffix}.f"
done
test "$(status fresh-parser-strict)" -eq 0
test "$(status fresh-parser-legacy)" -eq 0
test "$(status fresh-forward-strict)" -eq 0
test "$(status fresh-forward-legacy)" -eq 0
test "$(status fresh-reverse-strict)" -ne 0
grep -Fq 'Nonstandard type declaration REAL*8' "$out/fresh-reverse-strict.stderr"
test "$(status fresh-reverse-legacy)" -eq 0
diff -I '^C  Tapenade ' "$source_dir/program_d.f" \
    "$out/fresh/forward/ala01_d.f" >/dev/null
diff -I '^C  Tapenade ' "$source_dir/program_b.f" \
    "$out/fresh/reverse/ala01_b.f" >/dev/null

# Exact FortAD parser, forward, and reverse CLI probes. All three hit the
# same source boundary and must not leave derivative output behind.
run_status fortad-check bash -c \
    "cd '$fortad_repo' && fo exec --no-build fortad check --proc root --output '$out/fortad/check.f90' '$source_dir/program.f'"
run_status fortad-forward bash -c \
    "cd '$fortad_repo' && fo exec --no-build fortad --mode forward --indep x,initial --dep y --proc root --name ala01_forward --module ala01_forward_mod --output '$out/fortad/forward.f90' '$source_dir/program.f'"
run_status fortad-reverse bash -c \
    "cd '$fortad_repo' && fo exec --no-build fortad --mode reverse --indep x,initial --dep y --proc root --name ala01_reverse --module ala01_reverse_mod --output '$out/fortad/reverse.f90' '$source_dir/program.f'"
for mode in check forward reverse; do
    test "$(status "fortad-$mode")" -ne 0
    grep -Fq 'fortad: unsupported statement at line 39' \
        "$out/fortad-$mode.stdout" "$out/fortad-$mode.stderr"
    test ! -e "$out/fortad/$mode.f90"
done

python3 "$case_dir/oracle.py" >"$out/oracle.txt"
grep -Fq 'oracle_status: pass' "$out/oracle.txt"

cpu_model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
os_name=$(awk -F= '$1 == "PRETTY_NAME" {gsub(/"/, "", $2); print $2}' /etc/os-release)
{
    printf 'case: Tapenade nonRegressions/set01/ala01\n'
    printf 'classification: expected-refusal-fortad-unsupported-print-line-39\n'
    printf 'runner_result: pass\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'machine: %s\n' "$(hostname)"
    printf 'os: %s\n' "$os_name"
    printf 'kernel: %s\n' "$(uname -srvmo)"
    printf 'cpu: %s\n' "$cpu_model"
    printf 'compiler: %s\n' "$($fc --version | head -1)"
    printf 'strict_flags: %s\n' "${strict[*]}"
    printf 'legacy_flags: %s\n' "${legacy[*]}"
    printf 'fortad_commit: %s\n' "$(git -C "$fortad_repo" rev-parse HEAD)"
    printf 'tapenade_commit: %s\n' "$(git -C "$tapenade_repo" rev-parse HEAD)"
    printf 'upstream_entry_point: root(x,y,initial)\n'
    printf 'ported_entry_point: not-claimed-exact-source-only\n'
    printf 'tapenade_options: parser=-p -context -root root forward=-d -context -root root reverse=-b -context -root root\n'
    printf 'exact_strict_compile: program=%s program_d=%s program_b=%s diagnostic=REAL*8\n' \
        "$(status exact-strict-program)" "$(status exact-strict-program_d)" "$(status exact-strict-program_b)"
    printf 'exact_legacy_compile: program=%s program_d=%s program_b=%s\n' \
        "$(status exact-legacy-program)" "$(status exact-legacy-program_d)" "$(status exact-legacy-program_b)"
    printf 'tapenade_generation: parser=%s forward=%s reverse=%s\n' \
        "$(status tapenade-parser)" "$(status tapenade-forward)" "$(status tapenade-reverse)"
    printf 'tapenade_fresh_strict_compile: parser=%s forward=%s reverse=%s diagnostic=REAL*8\n' \
        "$(status fresh-parser-strict)" "$(status fresh-forward-strict)" "$(status fresh-reverse-strict)"
    printf 'tapenade_fresh_legacy_compile: parser=%s forward=%s reverse=%s\n' \
        "$(status fresh-parser-legacy)" "$(status fresh-forward-legacy)" "$(status fresh-reverse-legacy)"
    printf 'tapenade_reference_match: fresh_forward=program_d.f fresh_reverse=program_b.f after-banner-normalization\n'
    printf 'fortad_exact_behavior: check=expected-refusal forward=expected-refusal reverse=expected-refusal diagnostic=unsupported-print-line-39 no-output\n'
    printf 'independent_oracle: fixed-point-primal jvp-finite-difference vjp-dot-product\n'
    cat "$out/oracle.txt"
    printf 'dependency_blocker: FortAD parser does not yet accept exact PRINT at line 39; Tapenade reverse uses legacy REAL*8\n'
    printf 'port_result: not-claimed\n'
    printf 'upstream_sha256:\n'
    (cd "$tapenade_repo" && sha256sum "$source_rel"/Options "$source_rel"/program.f \
        "$source_rel"/program_d.f "$source_rel"/program_d.msg \
        "$source_rel"/program_b.f "$source_rel"/program_b.msg)
    printf 'fresh_tapenade_sha256:\n'
    (cd "$out/fresh" && sha256sum parser/ala01_p.f parser/ala01_p.msg \
        forward/ala01_d.f forward/ala01_d.msg \
        reverse/ala01_b.f reverse/ala01_b.msg)
    printf 'case_artifact_sha256:\n'
    (cd "$case_dir" && sha256sum manifest.toml notes.md oracle.py run.sh test_contract.py)
} >"$result"
cat "$result"
