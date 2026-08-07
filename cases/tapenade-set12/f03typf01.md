# Tapenade `f03typf01`: abstract deferred dispatch boundary

`nonRegressions/set12/f03typf01/program.f90` is a compact Fortran 2003/2008
object-oriented case. It declares an abstract `data_container`, a deferred
`calc_value` binding, two concrete extensions, and a `foo` routine that calls
the deferred binding through `class(data_container)`.

The strict probe in
[`bench_tapenade_f03typf01_oo.sh`](../../scripts/bench_tapenade_f03typf01_oo.sh)
compiles the unmodified upstream primal and stored `program_p.f90` reference.
Tapenade 3.16's parser emits `program_p.f90`, but the generated source does
not compile: the abstract type is regenerated without `ABSTRACT`, the child
types lose their `EXTENDS` relation, and the deferred procedure declaration is
invalid. This is recorded as a malformed-generated-source result, not as
support.

The FortAD port is the existing
[`abstract_deferred_refusal`](../itpplasma/abstract_deferred_refusal) fixture.
It keeps the same deferred call while using a parser-compatible module name.
Its independent harness checks both concrete children and central finite
differences. FortAD refuses the derivative with:

```text
fortad: unsupported type-bound call 'value': the concrete type is not defined in this source
```

The ledger row therefore records an `expected-refusal`. The refusal is
intentional: differentiating only the abstract declaration would silently
drop the concrete implementation selected by runtime dispatch.

Run the evidence probe after fetching and building Tapenade's pinned checkout:

```sh
TAPENADE_REPO=upstream/tapenade FORTAD_REPO=../fortad \
  scripts/bench_tapenade_f03typf01_oo.sh
```
