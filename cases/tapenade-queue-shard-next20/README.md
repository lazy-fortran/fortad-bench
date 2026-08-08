# Tapenade Fortran queue shard: next20

Next20 closes exactly the next four pure-Fortran queue rows after next19, in
committed order: `set01/lh114`, `set01/lh115`, `set01/lh117`, and
`set01/lh118`. Exact pinned sources and references are hashed against the
Tapenade checkout. Each row has fresh pinned Tapenade parser, forward, and
reverse probes, FortAD probes, and an independent behavioral/refusal oracle.

| row | classification | evidence boundary |
|---|---|---|
| `set01/lh114` | `unsupported-fortad-dependent-inference` | parser/forward succeed; reverse has no selected dependent |
| `set01/lh115` | `unsupported-fortad-procedure-call-actual` | a legacy callee may write array-element actuals; FortAD requires plain variables |
| `set01/lh117` | `unsupported-fortad-global-mutable-state` | `COMMON` storage crosses the differentiated call boundary; implicit values are undefined |
| `set01/lh118` | `unsupported-fortad-active-io` | active `READ` and an unresolved external `TOTO` cross the differentiated procedure |

These are evidence boundaries, not claims that FortAD should imitate Tapenade's
handling of uninitialized storage, global mutable state, active I/O, or
unresolved external calls. The independent oracles check the defined local
semantics or the explicit refusal pattern without repairing the exact source.

The shard was run with Tapenade commit
`e59864cab441d4175df75383b3ff58c3dcd26df9` and FortAD executable revision
`a6930141b6967aeca3f7bb5cc8208d71716adc27`.

Rebuild the evidence from fresh probe JSON files with:

```bash
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh114 --entry-point bugDeadLoop --result /var/tmp/fortad-bench-next20/lh114.raw.json --result-dir /var/tmp/fortad-bench-next20/lh114
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh115 --entry-point bugResetAdj --result /var/tmp/fortad-bench-next20/lh115.raw.json --result-dir /var/tmp/fortad-bench-next20/lh115
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh117 --entry-point defuse --result /var/tmp/fortad-bench-next20/lh117.raw.json --result-dir /var/tmp/fortad-bench-next20/lh117
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh118 --entry-point s1 --result /var/tmp/fortad-bench-next20/lh118.raw.json --result-dir /var/tmp/fortad-bench-next20/lh118
python3 cases/tapenade-queue-shard-next20/record.py --raw /var/tmp/fortad-bench-next20/lh114.raw.json --raw /var/tmp/fortad-bench-next20/lh115.raw.json --raw /var/tmp/fortad-bench-next20/lh117.raw.json --raw /var/tmp/fortad-bench-next20/lh118.raw.json
python3 cases/tapenade-queue-shard-next20/test_contract.py
```
