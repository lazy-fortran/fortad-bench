# Set02 `lh150`

`lh150` is Tapenade's checkpointing regression for repeated `foo`/`gee`
calls. The exact upstream routine leaves `yy` and `zz` undefined and returns
no explicit result, so it is not a valid numerical benchmark interface.

This case keeps the first `foo`/`gee` path and uses a bounded modern port with
an explicit input `x` and final result `y`. The exact pinned upstream source,
its checked-in derivative, and fresh parser/tangent/reverse generation are
still compiled by the runner. FortAD JVP/VJP output is checked against an
independent closed-form derivative, central differences, and the adjoint
identity.
