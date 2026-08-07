# Tapenade set01 `lh041`

`lh041` is a fixed-form regression with two subroutines, three COMMON blocks
for loop bounds and data, in-place updates of `x(5,3,2)`, nested loops, and
two calls to `sub`. The stored references are `program_d.f`, `program_b.f`,
`program_dv.f`, and `program_p.f`; the corresponding message files are kept
in the pinned upstream checkout. The stored multidirectional source includes
`DIFFSIZES.inc`, but that include is not present in the `lh041` directory, so
its strict compile failure is recorded rather than repaired.

Fresh pinned Tapenade parser, tangent, and reverse generation succeeds for the
real root `adj10`; all three fresh fixed-form outputs compile strictly. The
exact primal and stored parser/tangent/reverse references also compile
strictly, while only the stored multidirectional reference is refused for the
missing include.

The pinned FortAD revision refuses both exact probes while parsing the first
labeled `DO WHILE` construct at line 18. This is an exact-source boundary, not
a claim that the COMMON-backed program is supported. The bounded port keeps
the fixed bounds, nested loop arithmetic, in-place array updates, and the two
passes, but makes state explicit and replaces labeled/while loops with
standard counted loops. Its forward transform compiles and passes a compiled
central-difference harness. Reverse mode refuses because the in-place `x`
update needs per-iteration storage; that refusal is recorded explicitly.

The independent Python oracle is a separate dual-number transcription. It
checks a hand JVP against central differences and checks the JVP/VJP pairing
through an adjoint identity. It does not import or inspect generated Fortran.

Run from the repository root:

```sh
FORTAD_REPO=/path/to/fortad-at-db005 \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh041/run.sh
```

The reproducible case-local record is [`result.txt`](result.txt).
