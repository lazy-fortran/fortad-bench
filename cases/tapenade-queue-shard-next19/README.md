# Tapenade Fortran queue shard: next19

Next19 closes exactly the next four pure-Fortran queue rows after next18, in
committed order: `set01/lh110`, `set01/lh111`, `set01/lh112`, and
`set01/lh113`. Exact pinned sources and references are hashed against the
Tapenade checkout. Each row has fresh pinned Tapenade parser, forward, and
reverse probes, FortAD probes, and an independent behavioral/refusal oracle.

| row | classification | evidence boundary |
|---|---|---|
| `set01/lh110` | `unsupported-fortad-invalid-generated-interface` | legacy `REAL*8`, lost parser declarations, and no automatic active/dependent inference |
| `set01/lh111` | `unsupported-fortad-dependent-inference` | valid array recurrence; automatic reverse has no selected dependent |
| `set01/lh112` | `unsupported-fortad-invalid-generated-interface` | valid piecewise scalar source; missing `DIFFSIZES.inc` reference and broken generated declarations |
| `set01/lh113` | `unsupported-invalid-upstream-fortran` | active DO variable reassignment and undefined `ia` index |

These are evidence boundaries, not claims that FortAD should imitate Tapenade's
handling of invalid upstream programs or silently guess active and dependent
variables. `lh110` and `lh111` are valid legacy source patterns in the
appropriate compiler mode; their classifications record FortAD's current
automatic CLI/product boundaries. `lh112` has a valid primal source but its
stored multidirectional reference includes an absent `DIFFSIZES.inc`; the
generated FortAD products still fail strict syntax checks. `lh113` is not a
support candidate because the exact upstream violates the DO-variable rule.

The shard was run with Tapenade commit
`e59864cab441d4175df75383b3ff58c3dcd26df9` and FortAD executable revision
`4f7b59ec089da6d113ae715ef79d5b57140cbf98`.

Rebuild the evidence from fresh probe JSON files with:

```bash
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh110 --entry-point foo --result /var/tmp/fortad-bench-next19/lh110.raw.json --result-dir /var/tmp/fortad-bench-next19/lh110
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh111 --entry-point top --result /var/tmp/fortad-bench-next19/lh111.raw.json --result-dir /var/tmp/fortad-bench-next19/lh111
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh112 --entry-point top --result /var/tmp/fortad-bench-next19/lh112.raw.json --result-dir /var/tmp/fortad-bench-next19/lh112
python3 scripts/probe_tapenade_fortad.py --case nonRegressions/set01/lh113 --entry-point test --result /var/tmp/fortad-bench-next19/lh113.raw.json --result-dir /var/tmp/fortad-bench-next19/lh113
python3 cases/tapenade-queue-shard-next19/record.py --raw /var/tmp/fortad-bench-next19/lh110.raw.json --raw /var/tmp/fortad-bench-next19/lh111.raw.json --raw /var/tmp/fortad-bench-next19/lh112.raw.json --raw /var/tmp/fortad-bench-next19/lh113.raw.json
python3 cases/tapenade-queue-shard-next19/test_contract.py
```
