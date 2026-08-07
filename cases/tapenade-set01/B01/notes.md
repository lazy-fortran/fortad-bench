# Tapenade set01 B01: exact B01 GRADFB

This case records the exact pinned source procedure GRADFB(x,y,z,b,c,d,vol6)
from upstream/tapenade/nonRegressions/set01/B01/program.f. The upstream file
is not copied, extracted, repaired, or replaced. The full translation unit and
its original include context are used by every engine probe.

Explicit Tapenade-style choices:

    -p
    -d -root gradfb
    -b -root gradfb

The exact source and stored program_d.f/program_b.f references compile with
the legacy fixed-form gate and refuse the strict F2018 gate because the pinned
upstream uses REAL*8. Fresh pinned Tapenade parser, forward, and reverse
generation succeeds; each fresh artifact has the same strict-refusal and
legacy-pass compiler boundary.

Exact FortAD probes:

    fortad check --proc gradfb --output check.f90 program.f
    fortad jvp x,y,z --proc gradfb --name b01_jvp --module b01_jvp_mod --output jvp.f90 program.f
    fortad vjp x,y,z --dep vol6 --proc gradfb --name b01_vjp --module b01_vjp_mod --output vjp.f90 program.f

All three exact probes refuse at line 116, the legacy labeled DO 5, with
could not locate the end of this do construct; no derivative or re-emitted
file is produced. This is an exact-source parser limitation, not a claim that
the isolated mathematical body is unsupported.

oracle.py independently evaluates six times the tetrahedral determinant,
checks the source cofactor outputs against central differences, and checks the
corresponding VJP adjoint identity. It does not invoke Tapenade or FortAD and
does not create a support port.

The runner writes complete command statuses and hashes to result.txt.
