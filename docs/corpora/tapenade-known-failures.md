# Tapenade bounded source shard

This report covers the 37 `fortran-known-failures` rows and the 22
Fortran rows under `large-examples` in the pinned Tapenade checkout.
It is a source-viability classification, not a FortAD support claim:
no row below has a derivative numerical oracle.

Pinned revision: `e59864cab441d4175df75383b3ff58c3dcd26df9`

## Probe contract

The primary `program.f90` (or fixed-form `program.f`) is checked with
`gfortran -fsyntax-only -std=f2018` and, if needed, `-std=legacy`, with
the case directory as the include path. `missing-dependency` requires a
compiler fatal diagnostic for an include/module; it is not inferred from
the static queue. `runnable` means the source syntax check passed and the
Tapenade `-p` parser probe emitted `program_p`; it does not mean the
program links, executes, or differentiates correctly.

Tapenade setup for this run (from the pinned checkout):

```text
./gradlew --no-daemon illang
./gradlew --no-daemon buildVersion
./gradlew --no-daemon assemble
./gradlew --no-daemon frontf
```

## Summary

| status | rows |
|---|---:|
| `runnable` | 35 |
| `parser-failure` | 1 |
| `missing-dependency` | 9 |
| `invalid-source` | 14 |
| **total** | **59** |

## Evidence

| component | path | source | form | status | compiler evidence | Tapenade evidence | FortAD |
|---|---|---|---|---|---|---|---|
| large-examples | `examples/big01/B04` | `examples/big01/B04/program.f` | fixed | `invalid-source` | gfortran rejected both strict and legacy syntax checks | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/lh062` | `examples/big01/lh062/program.f` | fixed | `missing-dependency` | gfortran reported a missing include or module | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/lh205` | `examples/big01/lh205/program.f90` | free | `missing-dependency` | gfortran reported a missing include or module | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/v059` | `examples/big01/v059/program.f90` | free | `runnable` | gfortran legacy syntax check passed; strict mode rejected | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/v068` | `examples/big01/v068/program.f` | fixed | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/v108` | `examples/big01/v108/program.f` | fixed | `invalid-source` | gfortran rejected both strict and legacy syntax checks | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/v234` | `examples/big01/v234/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/v235` | `examples/big01/v235/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/v512` | `examples/big01/v512/program.f90` | free | `parser-failure` | gfortran legacy syntax check passed; strict mode rejected | Uncaught exception | not-run; no derivative oracle |
| large-examples | `examples/big01/v520` | `examples/big01/v520/program.f90` | free | `missing-dependency` | gfortran reported a missing include or module | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/vmp01` | `examples/big01/vmp01/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/vmp02` | `examples/big01/vmp02/program.f90` | free | `invalid-source` | gfortran rejected both strict and legacy syntax checks | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/vmp03` | `examples/big01/vmp03/program.f90` | free | `invalid-source` | gfortran rejected both strict and legacy syntax checks | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/vmp04` | `examples/big01/vmp04/program.f90` | free | `missing-dependency` | gfortran reported a missing include or module | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/vmp05` | `examples/big01/vmp05/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/vmp09` | `examples/big01/vmp09/program.f90` | free | `invalid-source` | gfortran rejected both strict and legacy syntax checks | Uncaught exception | not-run; no derivative oracle |
| large-examples | `examples/big01/vmp10` | `examples/big01/vmp10/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/vmp12` | `examples/big01/vmp12/program.f90` | free | `missing-dependency` | gfortran reported a missing include or module | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/vmp14` | `examples/big01/vmp14/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/vmp15` | `examples/big01/vmp15/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/vmp16` | `examples/big01/vmp16/program.f90` | free | `runnable` | gfortran legacy syntax check passed; strict mode rejected | program_p output generated (parser probe only) | not-run; no derivative oracle |
| large-examples | `examples/big01/vmp18` | `examples/big01/vmp18/program.f90` | free | `runnable` | gfortran legacy syntax check passed; strict mode rejected | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/bd01` | `todoF90/REFERENCES/bd01/program.f90` | free | `missing-dependency` | gfortran reported a missing include or module | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/bd11` | `todoF90/REFERENCES/bd11/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v01` | `todoF90/REFERENCES/v01/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v02` | `todoF90/REFERENCES/v02/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v05` | `todoF90/REFERENCES/v05/program.f90` | free | `invalid-source` | gfortran rejected both strict and legacy syntax checks | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v07` | `todoF90/REFERENCES/v07/program.f90` | free | `invalid-source` | gfortran rejected both strict and legacy syntax checks | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v100` | `todoF90/REFERENCES/v100/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v101` | `todoF90/REFERENCES/v101/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v144` | `todoF90/REFERENCES/v144/program.f90` | free | `invalid-source` | gfortran rejected both strict and legacy syntax checks | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v270` | `todoF90/REFERENCES/v270/program.f90` | free | `runnable` | gfortran legacy syntax check passed; strict mode rejected | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v322` | `todoF90/REFERENCES/v322/program.f90` | free | `runnable` | gfortran legacy syntax check passed; strict mode rejected | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v377` | `todoF90/REFERENCES/v377/program.f90` | free | `missing-dependency` | gfortran reported a missing include or module | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v385` | `todoF90/REFERENCES/v385/program.f90` | free | `missing-dependency` | gfortran reported a missing include or module | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v402` | `todoF90/REFERENCES/v402/program.f90` | free | `invalid-source` | gfortran rejected both strict and legacy syntax checks | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v412` | `todoF90/REFERENCES/v412/program.f90` | free | `invalid-source` | gfortran rejected both strict and legacy syntax checks | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v413` | `todoF90/REFERENCES/v413/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v414` | `todoF90/REFERENCES/v414/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v415` | `todoF90/REFERENCES/v415/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v416` | `todoF90/REFERENCES/v416/program.f90` | free | `runnable` | gfortran legacy syntax check passed; strict mode rejected | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v417` | `todoF90/REFERENCES/v417/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v418` | `todoF90/REFERENCES/v418/program.f90` | free | `missing-dependency` | gfortran reported a missing include or module | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v419` | `todoF90/REFERENCES/v419/program.f90` | free | `invalid-source` | gfortran rejected both strict and legacy syntax checks | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v420` | `todoF90/REFERENCES/v420/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v421` | `todoF90/REFERENCES/v421/program.f90` | free | `runnable` | gfortran legacy syntax check passed; strict mode rejected | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v422` | `todoF90/REFERENCES/v422/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v425` | `todoF90/REFERENCES/v425/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v426` | `todoF90/REFERENCES/v426/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v427` | `todoF90/REFERENCES/v427/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v469` | `todoF90/REFERENCES/v469/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v500` | `todoF90/REFERENCES/v500/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v503` | `todoF90/REFERENCES/v503/program.f90` | free | `invalid-source` | gfortran rejected both strict and legacy syntax checks | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v504` | `todoF90/REFERENCES/v504/program.f90` | free | `invalid-source` | gfortran rejected both strict and legacy syntax checks | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v505` | `todoF90/REFERENCES/v505/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v508` | `todoF90/REFERENCES/v508/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v519` | `todoF90/REFERENCES/v519/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v526` | `todoF90/REFERENCES/v526/program.f90` | free | `invalid-source` | gfortran rejected both strict and legacy syntax checks | program_p output generated (parser probe only) | not-run; no derivative oracle |
| fortran-known-failures | `todoF90/REFERENCES/v547` | `todoF90/REFERENCES/v547/program.f90` | free | `runnable` | gfortran strict syntax check passed | program_p output generated (parser probe only) | not-run; no derivative oracle |

The other `runnable` rows are the next candidates for explicit entry-point
selection, generated-code compilation, and independent finite-difference
and adjoint-oracle cases. The separate `v420` case has already cleared
those gates. This report remains source-viability evidence and must not
be read as a support result for the other rows.
