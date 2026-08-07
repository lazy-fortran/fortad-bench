# Tapenade `ADFirstAidKit/testMemSizef.f`

This fixed-form program checks the storage occupied by intrinsic Fortran types.
It is a runnable Tapenade runtime test, but it has no procedure arguments and no
active input or output. It therefore has no JVP or VJP contract.

The focused runner compiles the unmodified program with its pinned C helper and
checks its output against an independent Fortran `storage_size` program. It also
round-trips the source through Tapenade's parser. Tapenade then reports `AD06`
for both tangent and adjoint mode and emits no derivative source. FortAD reports
that the named program is not a differentiable procedure and likewise emits no
derivative source. These are expected refusals, not missing numerical tests.

Run:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_firstaid_memsize.sh
```

The timed result is in
[`results/tapenade_firstaid_memsize_refusal_validation.txt`](../../../results/tapenade_firstaid_memsize_refusal_validation.txt).
The upstream files remain in the gitignored pinned checkout and are not copied
into this repository.
