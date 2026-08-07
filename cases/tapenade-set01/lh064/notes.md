# Tapenade set01 `lh064`

`lh064` contains the fixed-form `cg02v1(T,n)` loop and its local `truc(a)`
helper. The original source has two unreachable `FORMAT` statements using
backslash-escaped apostrophes. Strict F2018 compilation rejects those
statements, and exact FortAD parsing stops at the same unterminated character
constant. The stored parser and tangent references compile strictly; the
stored reverse reference is rejected because Tapenade emits `INTEGER*4` for
its branch stack.

Fresh pinned Tapenade generation succeeds for parser, tangent, and reverse
with `-p`, `-d -root cg02v1`, and `-b -root cg02v1`. Its fresh parser and
tangent files compile; fresh reverse has the same `INTEGER*4` refusal. This
is generation evidence, not an exact FortAD support claim.

The case-local `port.f90` is a bounded standard-conforming witness. It removes
only the unreachable formatting statements, expresses the labeled DO
structurally, and inlines the complete `truc` body supplied by the row. It
therefore preserves the numerical `cg02v1` computation while making the
source acceptable to FortAD. FortAD forward generation compiles and passes a
compiled harness against `hand.f90`; reverse generation correctly refuses
the in-place loop update because it needs per-iteration storage. The Python
oracle independently checks the hand JVP/VJP, a central-difference sweep,
and the adjoint identity.

Run the complete pinned gate with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh064/run.sh
```

The resulting evidence record is in [`result.txt`](result.txt).
