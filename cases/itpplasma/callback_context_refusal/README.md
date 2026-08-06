# Callback and `class(*)` context boundary

This primal combines the callback features that tend to be hidden in
production interfaces: procedure-pointer reassignment, `associated` and null
callback paths, and an opaque `class(*)` context whose dynamic type is selected
inside each callback. The linear and quadratic targets have independent
closed-form values, so the harness validates both targets and central finite
differences before checking the null result.

FortAD is expected to refuse `selected_callback(x, selected_context)`. Runtime
procedure-pointer identity and an opaque context are not currently derivative
rules; accepting the call would risk differentiating the wrong target. This is
the P8.6/B5/B13 boundary. The existing `SELECT TYPE` callback case documents
the supported explicit-dispatch replacement.
At the pinned FortAD revision the refusal diagnostic is `fortad: empty
expression`; the harness captures stderr during the check and verifies that no
derivative file is produced.

Run the primal and refusal check with:

```sh
FORTAD_REPO=../fortad scripts/bench_itpplasma_oo_boundaries.sh
```
