# Tapenade set01 `lh021`

`lh021` is an exact-source boundary case at the pinned Tapenade commit.  The
primal uses the obsolescent but compilable fixed-form `COMMON /c1/` statement,
then calls external `S2` and `S3` without providing their definitions in this
corpus row.  The stored tangent reference has the same unresolved interfaces;
the stored reverse reference additionally uses nonstandard `INTEGER*4`.

The runner compiles the exact primal and stored references under strict
Fortran 2018 flags, regenerates parser/tangent/reverse files with the pinned
Tapenade checkout, and strictly compiles every fresh output.  It then probes
both FortAD forward and reverse modes on the exact source.  Tapenade parser and
tangent output compile; the stored and fresh reverse sources reproducibly fail
on `INTEGER*4`; FortAD refuses both modes at `COMMON /c1/` line 5.

There is no bounded standard-conforming port or numerical runtime oracle.  A
port would have to invent the missing `S2` in-place update and `S3` result and
derivative, so it would no longer be an independent check of this corpus case.
The independent oracle is therefore the compiler/refusal identity, not a
numerical derivative comparison.

Run from the repository root with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh021/run.sh
```

The reproducible record is
[`result.txt`](result.txt).

The case runner uses `fo exec --no-build` for the FortAD refusal probe.  In the
current shared checkout, a direct `fo build` gate was also attempted and failed
before compilation at the pre-existing `run_all_products` implicit-interface
diagnostic; that unrelated worktree state is not changed or folded into this
case commit.
