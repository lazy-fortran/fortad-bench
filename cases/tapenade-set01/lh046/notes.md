# Tapenade `nonRegressions/set01/lh046`

`lh046` is a fixed-form parser/regression case whose entry point is
`test(T1,T2,n,x)`. It passes assumed-size arrays with lower bounds into `F1`,
then performs an indexed `READ` from unit 88 before calling `F1` again. The
exact primal and the stored tangent and reverse references use nonstandard
`REAL*16` declarations. The primal and tangent also contain a malformed
comma-prefixed `READ` list (`READ(88,*), ...`), so none of the exact source set
is a strict F2018 program under the repository compiler oracle.

Fresh pinned Tapenade parser, tangent, and reverse generation succeeds from
the real `test` root. Strict compilation of each fresh output fails, however;
stored derivatives are not used as fresh-generation evidence. FortAD is run
on the exact primal in both forward and reverse modes and refuses at the
indexed `READ` statement on line 8. This is recorded as an invalid-upstream
closure rather than repaired source support. No bounded numerical port is
claimed because changing the nonstandard kind or I/O semantics would invent
the test's behavior.

Run the complete evidence probe with:

```sh
FORTAD_REPO=/path/to/fortad-at-db005 \
TAPENADE_REPO=upstream/tapenade \
  cases/tapenade-set01/lh046/run.sh
```

The runner records exact and fresh compiler diagnostics, generation options,
toolchain revisions, source hashes, generated-output hashes, and the
independent compiler-oracle result in `result.txt`.
