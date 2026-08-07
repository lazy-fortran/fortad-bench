# First-aid validity interval

Tapenade's `ADFirstAidKit/validityTest.f` updates a global interval in which a
directional perturbation keeps its sign. It has no external dependencies. The
source uses fixed form, `BLOCK DATA`, `COMMON`, and the legacy `REAL*8` and
`REAL*4` spellings.

The focused runner compiles and executes the unmodified source, checks lower,
upper, inactive, and zero-direction state transitions, and freshly runs the
Tapenade parser, tangent, and adjoint transforms. All three Tapenade outputs
compile in legacy mode. FortAD stops at the exact `COMMON` statement with
`unsupported statement at line 21`; this is an expected refusal, not support.

Run it after fetching the pinned Tapenade checkout:

```sh
FORTAD_REPO=../fortad TAPENADE_REPO=upstream/tapenade \
  scripts/bench_tapenade_first_aid_validity.sh
```

The measurement record is
[`results/tapenade_first_aid_validity_refusal_validation.txt`](../../results/tapenade_first_aid_validity_refusal_validation.txt).
