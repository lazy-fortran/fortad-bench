# Next pure-Fortran queue shard

This record advances the automatic queue workflow with four deterministic
pure-Fortran rows selected from the committed queue and compiler batch:

- `nonRegressions/set05/v196`: recursive `FACTORIAL`
- `nonRegressions/set05/v202`: elemental `twice_real`
- `nonRegressions/set06/v220`: derived-type `addvector`
- `nonRegressions/set06/v232`: constant-result `test`

All four rows are `compiler-clean`, carry no unresolved include or `USE` hint,
and use the exact pinned Tapenade checkout. The probe supplied no active or
dependent arguments: it used only the statically discovered procedure name.
Tapenade completed all parser/forward/reverse probes. When a root had no
active input/output it recorded its diagnostic message rather than a source
derivative. FortAD has precise refusals or invalid generated-source evidence
for every row. The fourth returns zero for all modes, but its generated
interfaces fail strict syntax validation, so it is also not a support claim.

The committed batch handoff is also recorded per case as `compiler-clean`,
including its exact compiler file statuses and empty missing/extra source
lists. `oracle.py` is an independent arithmetic/behavioral oracle. It checks only
defined primal behavior (and finite-difference slopes for the affine and
constant models). It does not convert any refusal into support. `result.json`
contains the canonical probe statuses, exact source/reference SHA-256 hashes,
revision pins, diagnostics, generated-output syntax checks, and oracle
results.

The `selection_*` hashes identify the 1,281-row queue and 1,207-row batch that
fed the probe. The `current_*` hashes identify the regenerated 1,277-row queue
and 1,203-row batch after these four rows were closed. Retaining both makes the
selection provenance explicit without relabelling the evidence.

Re-run the probe with a temporary queue file containing exactly the four rows
listed in `manifest.toml`, using `--jobs 4`, then canonicalize it with:

```bash
python3 cases/tapenade-queue-shard-next/record.py \
  --raw /path/to/results.jsonl
python3 cases/tapenade-queue-shard-next/test_contract.py
```
