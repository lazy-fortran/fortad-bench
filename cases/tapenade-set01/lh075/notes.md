# Tapenade `nonRegressions/set01/lh075`

`lh075` is a fixed-form queue candidate whose exact source is not
standard-conforming.  The only procedure is `phi(PHIS,s1)`, but line 2 calls
`PHI(N1)` and `PHI(N2)` as one-argument functions.  Fortran resolves the name
case-insensitively to the two-argument subroutine itself, so strict gfortran
rejects both `program.f` and the stored parser output `program_p.f` with
`Unexpected use of subroutine name 'phi'`.

The upstream directory contains those two source files and four stored message
references.  It does not contain stored tangent or reverse source files.  At
the pinned Tapenade revision, fresh parser generation creates `lh075_p.f`, but
fresh tangent and reverse generation creates only `lh075_d.msg` and
`lh075_b.msg`; neither `lh075_d.f` nor `lh075_b.f` exists.  The fresh parser
source has the same strict compiler refusal.  The messages retain Tapenade's
`TC32`, `TC35`, `DF06`, and uninitialized-variable diagnostics.

FortAD is probed at the queue entry point with `s1` independent and `PHIS`
dependent.  Both exact forward and reverse modes stop at line 3 with
`fortad: unsupported statement at line 3` and produce no generated source.

This is classified as `expected-refusal-invalid-upstream`.  There is no
bounded port, hand derivative, or runtime harness: changing `PHI` into a
function or supplying missing declarations would invent semantics rather than
preserve the corpus candidate.  The case-local contract test instead checks the
manifest, the fixed source boundary, and SHA-256 checksums for every exact
upstream source/reference file.

Run the complete probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh075/run.sh
```

The reproducible record is [`result.txt`](result.txt).
