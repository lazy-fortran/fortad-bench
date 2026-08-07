# Tapenade `nonRegressions/set01/lh051`

The pinned fixed-form source differentiates `adj1(x,y,z,n,o)`. It has a
labeled DO from line 11 through label 200 and then a natural loop that visits
`j=3,6,...,102`. The exact source, stored tangent, stored reverse, and fresh
Tapenade parser/tangent/reverse outputs all pass the strict Fortran compiler
gate. The stored and fresh reverse outputs retain the expected implicit stack
interfaces as warnings, not errors.

FortAD refuses both exact probes at line 11 because the parser cannot locate
the end of the labeled DO construct. This is recorded as an exact-source
boundary. The bounded port uses structured loops, keeps `n` and `o` explicit,
and specializes the natural loop to its original 34-iteration terminating
path. Its forward JVP transforms, compiles, and matches an independent hand
JVP plus a central-difference sweep. Reverse generation is attempted for each
of `x`, `y`, and `z`; FortAD explicitly refuses because `z` is read and
written in the same loop and would require per-iteration storage.

Run the complete evidence probe with:

```sh
FORTAD_REPO=/var/tmp/fortad-lh035-pinned-xQjiZj \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/lh051/run.sh
```
