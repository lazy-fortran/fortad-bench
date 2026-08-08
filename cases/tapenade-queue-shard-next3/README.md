# Tapenade Fortran modern-feature queue shard: next3

This shard closes four disjoint pure-Fortran, compiler-clean queue rows:
`set04/lh109` (`top`, score 60), `set12/mvo32` (`caller`, 54), `set12/mvo31`
(`calc`, 48), and `set04/lh121` (`foo`, 37). The exact source roots were
selected after checking the committed queue and source declarations. The
fixed modern-feature weights are the queue-shard weights: `abstract=20`,
`polymorphic=18`, `select type=18`, `class(`=16, `allocatable=14`,
`pointer=14`, `associate=12`, `do concurrent/coarray/codimension=12`,
`contiguous=10`, `derived/type ::=10`, `type(`/`procedure`/`recursive=8`,
`elemental/pure/final=7`, `generic=6`, `interface/bind(c)/iso_c_binding=5`,
`optional=4`, and `dimension=3`.

The current compiler-clean queue contains no actual `ASSOCIATE` statement, so
this shard covers the adjacent modern boundaries: a procedure-pointer
callback, a polymorphic type-bound procedure, a local derived component
allocation through a generic interface, and local allocatable TARGET/pointer
alias lifetime. None uses module-level mutable state. Tapenade passes all
three modes for all four roots. The mvo32 and mvo31 generated products are
strict-compile-clean; Tapenade's lh109 and lh121 reverse products contain its
nonstandard `INTEGER*4` spelling and are recorded as generated-source strict
compile refusals. FortAD records precise refusals for the unsupported
boundaries; the mvo31 parser is accepted while its detached parser product
lacks the defining module and its forward and reverse modes refuse the active
polymorphic receiver.

Each exact source/reference is strict-compiled and hash-recorded. Each result
also contains a separate Python oracle that models the primal behavior and
asserts the storage or dispatch boundary independently of Tapenade and FortAD.

Rebuild and check the canonical result with:

```bash
python3 cases/tapenade-queue-shard-next3/record.py \
  --raw /var/tmp/fortad-bench-next3-lh109-foo.RWIcwv/raw.json \
  --raw /var/tmp/fortad-bench-next3-mvo32-caller.vHDpWq/raw.json \
  --raw /var/tmp/fortad-bench-next3-mvo31-calc.Cx3w3h/raw.json \
  --raw /var/tmp/fortad-bench-next3-lh121-foo.RWIcwv/raw.json
python3 cases/tapenade-queue-shard-next3/test_contract.py
```
