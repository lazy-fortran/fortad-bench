# Tapenade `todoF90/REFERENCES/bd11`

`program.f90` is a valid free-form subroutine:

```fortran
subroutine top(i1,i2,i3)
real i1(10,10),i2(10),i3(10)
...
i2(:)=sqrt(i*abs(i*i3(:)))
i1(:,i) = i2(:) * i3(:)
```

The pinned source compiles strictly. The directory has no checked-in parser,
tangent, reverse, or multidirectional references; `Options` requests
`-nolib -ext REFERENCES/lh09/NoInlineABS`, but that historical external-library
path is absent from the pinned checkout. Fresh Tapenade still generates parser,
tangent, and reverse sources, and all three compile with the strict free-form
compiler flags recorded in `result.txt`.

FortAD's exact parser/check, forward, and reverse attempts all stop at source
line 6 with the same explicit diagnostic about unsupported array-section storage
identity. The source remains a named exact-refusal boundary; it is not
classified as invalid upstream Fortran.

The bounded port in `port.f90` changes only the two whole-array assignments to
scalar element assignments over the fixed declared shapes. It preserves the
in-place `i1`/`i2` outputs and adds `objective=i1(1,1)` as a deliberately
bounded scalar reverse observation. `oracle.py` independently checks the hand
JVP against central differences and an adjoint identity on a positive `i3`
trace. `harness.f90` compiles and runs the bounded FortAD JVP and VJP against
the hand result. None of this promotes the original array-section source to
exact FortAD support.

Run the complete case with:

```console
./cases/tapenade-set01/bd11/run.sh
python3 cases/tapenade-set01/bd11/test_contract.py
```
