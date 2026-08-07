# Tapenade `nonRegressions/set07/v485`: module-only/no-entry boundary

The v485 source contains one free-form module, `FoX_dom_types`.  Its only
declaration is the private `NodeList` type with a null-initialized character
pointer component.  There is no program, subroutine, or function, and the
upstream directory has no `Options` file or stored tangent/reverse reference.

The exact source and stored `program_p.f90` both compile with strict Fortran
2018 flags.  With no `-root` or `-head`, pinned Tapenade parser mode emits a
strictly compilable `v485_p.f90`; tangent and reverse mode emit only
`v485_d.msg` and `v485_b.msg`, reporting that there is no root unit to
differentiate and no top procedure.

FortAD is invoked without `--proc` against the exact source.  Its parser,
forward, and reverse requests all refuse with `no function or subroutine found
in source` and write no output.  Naming the module as a procedure is not a
valid substitute: FortAD reports that `FoX_dom_types` is not a procedure.

The independent oracle checks the module, type privacy, pointer shape, and
null initialization directly from the source.  It invokes no compiler,
Tapenade, or FortAD.  No synthetic root, derivative port, or derivative
runtime claim is included.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v485/run.sh
python3 cases/tapenade-set01/v485/test_contract.py
```

Generated files and compiler modules remain disposable under `/var/tmp`.
