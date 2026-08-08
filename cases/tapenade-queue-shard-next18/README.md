# Tapenade Fortran queue shard: next18

Next18 closes exactly the next four pure-Fortran queue rows after next17, in
committed order: `set01/lh099`, `set01/lh101`, `set01/lh106`, and
`set01/lh108`. The exact source and stored reference products are hashed
against the pinned Tapenade checkout. Each case has fresh Tapenade parser,
forward, and reverse probes, FortAD probes, and an independent behavioral or
refusal-boundary oracle.

| row | classification | boundary |
|---|---|---|
| `set01/lh099` | `unsupported-fortad-do-while` | fixed-index `DO WHILE` control flow |
| `set01/lh101` | `unsupported-invalid-upstream-fortran` | non-`SEQUENCE` derived type in `COMMON` and incompatible implicit function interface |
| `set01/lh106` | `unsupported-fortad-dependent-inference` | reverse has multiple outputs and no selected dependent |
| `set01/lh108` | `unsupported-fortad-global-mutable-state` | `COMMON` storage plus undefined local index/value |

These are explicit evidence boundaries. `lh101` is an invalid-upstream
closure because independent strict and legacy compilation reject the exact
source. The other rows are FortAD product boundaries; they do not claim that
FortAD should differentiate legacy `COMMON`, undefined storage, or an
automatically chosen reverse dependent.

The shard was run with Tapenade commit
`e59864cab441d4175df75383b3ff58c3dcd26df9` and FortAD executable revision
`fc285f0ed2ff9692c1827f66e3ffb5e4d06b3ee4`.

Rebuild the evidence from fresh probe JSON files with:

```bash
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh099 --entry-point expandintest --result /var/tmp/fortad-bench-next18-lh099.raw.json --result-dir /var/tmp/fortad-bench-next18-lh099
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh101 --entry-point top --result /var/tmp/fortad-bench-next18-lh101.raw.json --result-dir /var/tmp/fortad-bench-next18-lh101
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh106 --entry-point top --result /var/tmp/fortad-bench-next18-lh106.raw.json --result-dir /var/tmp/fortad-bench-next18-lh106
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh108 --entry-point adj3 --result /var/tmp/fortad-bench-next18-lh108.raw.json --result-dir /var/tmp/fortad-bench-next18-lh108
python3 cases/tapenade-queue-shard-next18/record.py --raw /var/tmp/fortad-bench-next18-lh099.raw.json --raw /var/tmp/fortad-bench-next18-lh101.raw.json --raw /var/tmp/fortad-bench-next18-lh106.raw.json --raw /var/tmp/fortad-bench-next18-lh108.raw.json
python3 cases/tapenade-queue-shard-next18/test_contract.py
```
