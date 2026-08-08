# Tapenade Fortran queue shard: next21

Next21 closes exactly the next four untriaged pure-Fortran queue rows after
next20, in committed order: `set01/lh119`, `set01/lh120`, `set01/lh121`, and
`set01/lh122`. Exact pinned sources and references are hashed against the
Tapenade checkout. Each row has fresh pinned Tapenade parser, forward, and
reverse probes, FortAD probes, and an independent behavioral/refusal oracle.

| row | classification | evidence boundary |
|---|---|---|
| `set01/lh119` | `unsupported-fortad-active-io` | active `READ` overwrites a differentiated array, with an unresolved external call |
| `set01/lh120` | `unsupported-fortad-legacy-goto` | fixed-form labeled `GOTO` control flow is refused before transformation |
| `set01/lh121` | `unsupported-fortad-do-while` | nested labeled `DO WHILE` control flow is refused by the parser |
| `set01/lh122` | `unsupported-fortad-legacy-labeled-do` | hierarchical legacy labeled `DO` control flow is refused by the parser |

These are evidence boundaries, not claims that FortAD should imitate
Tapenade's handling. The independent oracles model deterministic bounded
state or loop behavior and record the exact refusal boundary without claiming
derivative support for active I/O, invalid array accesses, or legacy control
flow.

The shard was run with Tapenade commit
`e59864cab441d4175df75383b3ff58c3dcd26df9` and FortAD executable revision
`bfe204d2905fd3159ca218895b9cc76dfff8b2a3`.

Rebuild the evidence from fresh probe JSON files with:

```bash
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh119 --entry-point s1 --result /var/tmp/fortad-bench-next21/lh119.raw.json --result-dir /var/tmp/fortad-bench-next21/lh119
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh120 --entry-point sub --result /var/tmp/fortad-bench-next21/lh120.raw.json --result-dir /var/tmp/fortad-bench-next21/lh120
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh121 --entry-point nestedcounters --result /var/tmp/fortad-bench-next21/lh121.raw.json --result-dir /var/tmp/fortad-bench-next21/lh121
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh122 --entry-point bigfunction --result /var/tmp/fortad-bench-next21/lh122.raw.json --result-dir /var/tmp/fortad-bench-next21/lh122
python3 cases/tapenade-queue-shard-next21/record.py --raw /var/tmp/fortad-bench-next21/lh119.raw.json --raw /var/tmp/fortad-bench-next21/lh120.raw.json --raw /var/tmp/fortad-bench-next21/lh121.raw.json --raw /var/tmp/fortad-bench-next21/lh122.raw.json
python3 cases/tapenade-queue-shard-next21/test_contract.py
```
