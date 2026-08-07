#!/usr/bin/env bash
set -euo pipefail
case_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "$(cd "$case_dir/../../.." && pwd)/scripts/bench_tapenade_set02_tranche_b.sh" v128
