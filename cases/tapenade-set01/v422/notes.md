# Tapenade `todoF90/REFERENCES/v422`: undefined function result boundary

`v422` contains a small free-form module candidate.  `m1.f4(t)` updates its
dummy argument with `t = t * t * u`, where `u` is a public module variable, but
never assigns the declared function result `f4`.  The exact primal and the
stored `program_Rd.f90` reference therefore compile strictly only with the
compiler warning that the function return value is not set.  The stored
reference also contains the historical `F4_RD` tangent.

Fresh generation from the pinned Tapenade checkout succeeds in parser,
tangent, and reverse modes and each generated file strictly compiles.  Those
files preserve the same undefined function-result semantics.  The `Options`
file records Tapenade's `-association byaddress` setting, which is passed
explicitly by the runner.

FortAD's exact parser request succeeds in writing a malformed procedure with
`result()` and a blank declaration.  Forward mode with the only declared
independent, `t`, writes a malformed subroutine with a blank dependent
argument.  Reverse mode with `t` as both the in-place dependent and
independent writes duplicate `t_b` arguments.  Strict compilation rejects all
three generated files.

The independent oracle does not execute generated code or compare against a
stored derivative.  It hand-checks the only defined observable, the mutation
`t -> t**2*u`, using a central-difference JVP and an adjoint identity, and
independently verifies that the exact source assigns `t` but not `f4`.  No
bounded port is supplied because assigning the missing function result would
change the historical candidate.

Run the complete probe with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v422/run.sh
python3 cases/tapenade-set01/v422/test_contract.py
```

The compiler, fresh-generation, exact FortAD boundary, oracle, and checksum
record is in [`result.txt`](result.txt).
