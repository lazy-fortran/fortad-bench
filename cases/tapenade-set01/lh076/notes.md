# Tapenade `nonRegressions/set01/lh076`

`lh076` is the fixed-form `onegvert(pin4, emipint)` regression.  The primal
assigns

```text
emipint = cos(pin4) - i sin(pin4)
```

and the stored parser, tangent, and reverse artifacts are accompanied by a
stored multidirectional artifact that includes `DIFFSIZES.inc`.  That include
is not present in the upstream case directory.

The exact source and all four stored derivative files also use legacy
`REAL*8` and `COMPLEX*16` declarations.  With strict F2018 fixed-form flags,
the first four files refuse those declarations and `program_dv.f` refuses the
missing include.  Fresh pinned Tapenade parser, tangent, and reverse
generation succeeds, but their generated fixed-form files reproduce the
legacy-kind strict-compile refusal.  The exact FortAD forward and reverse
invocations are separately retained as named declaration diagnostics.

The bounded `port.f90` changes only the kind spelling to standard
`real(8)`/`complex(8)` and makes the intents explicit.  Its hand JVP is

```text
demipint = (-sin(pin4) - i cos(pin4)) d pin4
```

The hand VJP is used only as an independent real-coordinate oracle:
`pin4_b = -sin(pin4) real(emipint_b) - cos(pin4) aimag(emipint_b)`.  FortAD's
bounded JVP is generated, strictly compiled, and exercised by a Fortran
harness against the hand formula and central differences.  The active
complex-output reverse boundary is expected to refuse; the independent hand
VJP and adjoint identity do not claim FortAD reverse support for the exact
source.

Run the complete evidence probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh076/run.sh
```

The full gate record, source/reference checksums, and generated-artifact
checksums are in [`result.txt`](result.txt).
