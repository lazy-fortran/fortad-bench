# Tapenade set02 `lh163`

This is an exact fixed-form source from the pinned Tapenade regression suite.
The routine deliberately writes `v` and `q` after producing `s`; the
independent inputs are therefore `v`, `p`, and `q`, while `s` is the selected
dependent. FortAD's source-first Tapenade compatibility inference handles this
legacy signature without a hand-written `INTENT` annotation.

The runner checks the exact upstream source, fresh Tapenade parser/forward/
reverse generation, independently compiled FortAD products, and a hand JVP/
VJP oracle with central differences and the adjoint identity.

Run it with:

```sh
cases/tapenade-set02/lh163/run.sh
python3 cases/tapenade-set02/lh163/oracle.py
```
