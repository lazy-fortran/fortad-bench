# Tapenade Fortran queue shard: next17

Next17 closes exactly the next four untriaged rows in committed queue order
after next16: `set01/B05` (`flux`), `set01/bd07` (`test`), `set01/ht01`
(`adj7`), and `set01/lh043` (`adj7`). The original source and every selected
reference are checked against the pinned Tapenade checkout. Fresh Tapenade
parser, forward, and reverse commands are recorded for each root, alongside
FortAD probes and independent Python behavioral/refusal-boundary oracles.

The rows are valid source cases or valid source procedures with known
reference/dependency signals; none is silently labeled invalid upstream:

| row | classification | observed boundary |
|---|---|---|
| `set01/B05` | `unsupported-fortad-invalid-generated-interface` | FortAD parser/forward products fail strict generated-source checks; reverse accumulation also needs per-iteration storage. |
| `set01/bd07` | `unsupported-fortad-active-io` | active `READ` statements are a deliberate derivative boundary. |
| `set01/ht01` | `unsupported-fortad-character-section` | character substring assignment is outside the current storage contract. |
| `set01/lh043` | `unsupported-fortad-legacy-labeled-do` | legacy labeled `DO`, with `COMMON` and unresolved `EXTERNAL`, is refused during parsing. |

These are product-boundary records, not claims that FortAD should imitate
Tapenade's treatment of active I/O, mutable global state, legacy control flow,
or invalid generated interfaces. The independent oracles check defined primal
state or the explicit refusal boundary and make no derivative-support claim.

The shard was run with Tapenade commit
`e59864cab441d4175df75383b3ff58c3dcd26df9` and FortAD executable revision
`2d35391974c3c21abacadc24bfb6cbd9540060cc`.

Rebuild the evidence from fresh probe JSON files with:

```bash
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/B05 --entry-point flux --result /var/tmp/fortad-bench-next17/B05.raw.json --result-dir /var/tmp/fortad-bench-next17/B05
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/bd07 --entry-point test --result /var/tmp/fortad-bench-next17/bd07.raw.json --result-dir /var/tmp/fortad-bench-next17/bd07
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/ht01 --entry-point adj7 --result /var/tmp/fortad-bench-next17/ht01.raw.json --result-dir /var/tmp/fortad-bench-next17/ht01
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh043 --entry-point adj7 --result /var/tmp/fortad-bench-next17/lh043.raw.json --result-dir /var/tmp/fortad-bench-next17/lh043
python3 cases/tapenade-queue-shard-next17/record.py --raw /var/tmp/fortad-bench-next17/B05.raw.json --raw /var/tmp/fortad-bench-next17/bd07.raw.json --raw /var/tmp/fortad-bench-next17/ht01.raw.json --raw /var/tmp/fortad-bench-next17/lh043.raw.json
python3 cases/tapenade-queue-shard-next17/test_contract.py
```
