#!/usr/bin/env bash
# Record the strict-source refusal for Tapenade set01 lh052.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case_dir="$root/cases/tapenade-set01"
result="$root/results/tapenade_set01_lh052_refusal_validation.txt"
tapenade_repo=${TAPENADE_REPO:-"$root/upstream/tapenade"}
required_tapenade_commit=e59864cab441d4175df75383b3ff58c3dcd26df9
fc=${FC:-gfortran}
strict_flags=(-std=f2018 -pedantic-errors -ffixed-line-length-none)

command -v "$fc" >/dev/null
test -d "$tapenade_repo/.git" || test -f "$tapenade_repo/.git"
test "$(git -C "$tapenade_repo" rev-parse HEAD)" = "$required_tapenade_commit"
test -z "$(git -C "$tapenade_repo" status --porcelain --untracked-files=no)"

python3 - "$case_dir/tranche-m-lh052-manifest.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    manifest = tomllib.load(stream)
case = manifest["case"][0]
assert manifest["runner"] == "scripts/bench_tapenade_set01_lh052.sh"
assert manifest["upstream_revision"] == "e59864cab441d4175df75383b3ff58c3dcd26df9"
assert case["upstream_source"] == "nonRegressions/set01/lh052/program.f"
assert case["expected_diagnostic"] == "PROCEDURE attribute conflicts with COMMON attribute"
PY

mkdir -p "$root/build" "$root/results"
out=$(mktemp -d "$root/build/tapenade-set01-lh052.XXXXXX")
mkdir -p "$out/parser" "$out/forward" "$out/reverse"
source="$tapenade_repo/nonRegressions/set01/lh052/program.f"

strict_compile() {
    local input=$1 label=$2
    set +e
    "$fc" "${strict_flags[@]}" -c "$input" -o "$out/$label.o" \
        >"$out/$label.log" 2>&1
    local status=$?
    set -e
    test "$status" -ne 0
    grep -Fq "PROCEDURE attribute conflicts with COMMON attribute" \
        "$out/$label.log"
}

strict_compile "$source" upstream-primal

if test ! -x "$tapenade_repo/bin/tapenade" || \
        test ! -f "$tapenade_repo/build/libs/tapenade-3.16.jar"; then
    (cd "$tapenade_repo" && ./gradlew buildAll) >"$out/tapenade-build.log" 2>&1
fi

"$tapenade_repo/bin/tapenade" -p -O "$out/parser" -o lh052 "$source" \
    >"$out/parser.stdout" 2>"$out/parser.stderr"
"$tapenade_repo/bin/tapenade" -d -root f -O "$out/forward" -o lh052 "$source" \
    >"$out/forward.stdout" 2>"$out/forward.stderr"
"$tapenade_repo/bin/tapenade" -b -root f -O "$out/reverse" -o lh052 "$source" \
    >"$out/reverse.stdout" 2>"$out/reverse.stderr"

strict_compile "$out/parser/lh052_p.f" tapenade-parser
strict_compile "$out/forward/lh052_d.f" tapenade-forward
strict_compile "$out/reverse/lh052_b.f" tapenade-reverse

{
    printf 'case: Tapenade nonRegressions set01 lh052 strict-source refusal\n'
    printf 'recorded_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'compiler: %s\n' "$("$fc" --version | head -1)"
    printf 'strict_compiler_flags: %s\n' "${strict_flags[*]}"
    printf 'tapenade_commit: %s\n' "$required_tapenade_commit"
    printf 'upstream_primal_strict_compile: expected-refusal\n'
    printf 'tapenade_parser_generation: pass\n'
    printf 'tapenade_forward_generation: pass\n'
    printf 'tapenade_reverse_generation: pass\n'
    printf 'tapenade_parser_strict_compile: expected-refusal\n'
    printf 'tapenade_forward_strict_compile: expected-refusal\n'
    printf 'tapenade_reverse_strict_compile: expected-refusal\n'
    printf 'independent_oracle: gfortran independently rejects the scalar COMMON aj subscript in exact and fresh-generated sources\n'
    printf 'fortad_result: not-run-invalid-upstream-source\n'
    printf 'runtime_result: not-run-no-conforming-primal\n'
    printf 'refusal_reason: no semantics-preserving FortAD port exists without repairing the upstream source\n'
    printf 'source_sha256:\n'
    (cd "$root" && sha256sum cases/tapenade-set01/tranche-m-lh052.md \
        cases/tapenade-set01/tranche-m-lh052-manifest.toml \
        scripts/bench_tapenade_set01_lh052.sh)
    printf 'refusal_oracle_status: pass\n'
} >"$result"
cat "$result"
