# Tapenade Fortran queue follow-up shard

This shard closes four rows from the committed 1,277-row queue. Selection is
deterministic: pure-Fortran rank-50 procedure candidates, compiler-clean and
free-form with no unresolved include or `USE` hint, are scored by modern
language constructs in their exact primary source and then ordered by queue
order. The selected roots are static declarations; no active or dependent
arguments were supplied.

The rows deliberately exercise modern-language boundaries: pointer-owned
recursive trees, allocatable and pointer-containing derived arguments, active
unformatted I/O, and recursive derived-type pointer traversal. Tapenade and
FortAD were run against the pinned revisions in `manifest.toml`. `result.json`
retains exact source/reference SHA-256 hashes, engine commands, bounded
diagnostics, generated-source syntax checks, revision pins, and independent
primal/derivative/refusal oracle results.

The committed handoff before closure is identified by the `selection_*` hashes;
the regenerated queue and batch hashes are recorded as `current_*` in the
manifest and result. Rebuild the canonical evidence with:

```bash
python3 cases/tapenade-queue-shard-followup/record.py \
  --raw /var/tmp/fortad-bench-followup-vmp06/raw.json \
  --raw /var/tmp/fortad-bench-followup-lh159/raw.json \
  --raw /var/tmp/fortad-bench-followup-vmp07/raw.json \
  --raw /var/tmp/fortad-bench-followup-v193/raw.json
python3 cases/tapenade-queue-shard-followup/test_contract.py
```
