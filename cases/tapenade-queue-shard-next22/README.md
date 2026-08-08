# Tapenade Fortran queue shard: next22

Next22 closes exactly the next four untriaged pure-Fortran queue rows after
next21, in committed order: `set01/lh123`, `set01/lh124`, `set01/lh125`, and
`set01/lh126`. Exact pinned sources and references are hashed against the
Tapenade checkout. Each row has fresh pinned Tapenade parser, forward, and
reverse probes, FortAD probes, and an independent behavioral/refusal oracle.

| row | classification | evidence boundary |
|---|---|---|
| `set01/lh123` | `unsupported-fortad-reverse-loop-control` | forward differentiation passes; reverse refuses a branch inside an iteration loop |
| `set01/lh124` | `unsupported-fortad-procedure-call-actual` | the caller-to-callee mapping for the exact fixed-form call is not proven |
| `set01/lh125` | `unsupported-fortad-implicit-typing` | reverse lowering refuses the undeclared implicitly typed loop variable |
| `set01/lh126` | `unsupported-fortad-dependent-inference` | parser and forward pass; reverse requires an explicit dependent |

These are evidence boundaries, not claims that FortAD should reproduce
Tapenade's handling of implicit state, legacy interfaces, or undefined source
values. The independent oracles use explicit bounded values and control traces;
they check the defined local behavior without repairing the exact source.

The shard was run with Tapenade commit
`e59864cab441d4175df75383b3ff58c3dcd26df9` and FortAD executable revision
`92bf9ad3f4d714eee4f1e93e53413915ecf7c571`.

Rebuild the evidence from fresh probe JSON files with:

```bash
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh123 --entry-point iiloop --result /var/tmp/fortad-bench-next22/lh123.raw.json --result-dir /var/tmp/fortad-bench-next22/lh123
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh124 --entry-point ttt --result /var/tmp/fortad-bench-next22/lh124.raw.json --result-dir /var/tmp/fortad-bench-next22/lh124
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh125 --entry-point tetacrit --result /var/tmp/fortad-bench-next22/lh125.raw.json --result-dir /var/tmp/fortad-bench-next22/lh125
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh126 --entry-point test --result /var/tmp/fortad-bench-next22/lh126.raw.json --result-dir /var/tmp/fortad-bench-next22/lh126
python3 cases/tapenade-queue-shard-next22/record.py --raw /var/tmp/fortad-bench-next22/lh123.raw.json --raw /var/tmp/fortad-bench-next22/lh124.raw.json --raw /var/tmp/fortad-bench-next22/lh125.raw.json --raw /var/tmp/fortad-bench-next22/lh126.raw.json
python3 cases/tapenade-queue-shard-next22/test_contract.py
```
