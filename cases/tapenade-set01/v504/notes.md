# Tapenade `todoF90/REFERENCES/v504`: procedure-interface boundary

`v504` contains modules `M`, `M1_I`, and `M2_I`, followed by the external
functions `compute`, `ftest`, and `top`.  The exact `ftest` interface imports
`compute` from `M1_I` and also declares `compute` as a dummy; its `top`
interface repeats the same collision.  Strict F2018 gfortran therefore
refuses both `program.f90` and the stored forward reference
`program_d.f90`.  The stored `program_d.msg` records Tapenade's type-mismatch
and assumed-intent diagnostics; no stored reverse reference is present.

Fresh generation from the pinned Tapenade checkout succeeds in parser,
tangent, and reverse modes with root `top`.  The generated `v504_p.f90`,
`v504_d.f90`, and `v504_b.f90` sources are retained only in the disposable
probe.  Strict compilation refuses all three: the parser retains the
ambiguous interface, while tangent and reverse additionally expose generated
interface/module closure failures.

FortAD's exact parser, forward, and reverse requests all refuse before
writing output at `interface` line 62.  This exact refusal is preserved.  A
bounded port is included because the returned observable is reconstructable:
`compute` forms `2*r`, returns the product of its two components, and `ftest`
and `top` forward that scalar.  `port.f90` exposes that returned function value
as the output of standard subroutine `set01_v504`; it deliberately excludes
the source's `global` accumulator and caller-visible mutation of `s`.

The port uses the algebraically identical expression
`(2.0*r(1))*(2.0*r(2))`.  This is necessary for the pinned FortAD reverse
generator, which does not reconstruct the local temporary array `y` in its
reverse output.  The port's domain is finite `r` and `s` with finite
intermediate products.  The harness checks the primal, generated forward and
reverse products, zero `s` derivative, and the adjoint identity.  The
independent Python oracle checks central differences and the JVP/VJP identity
without reading or executing the Fortran source or invoking either tool.

Run the complete pinned probe from this worker worktree with:

```sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v504/run.sh
FORTAD_REPO=/home/ert/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  python3 cases/tapenade-set01/v504/test_contract.py
```

All generated sources, compiler modules, logs, and FortAD outputs remain in
disposable `/var/tmp` directories.  Only this case directory is committed.
