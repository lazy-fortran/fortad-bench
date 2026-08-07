# Tapenade `nonRegressions/set01/lh095`

`lh095` is the fixed-form `testliveness(a,b,c,d)` regression, with helper
function `SUB1(a,b)`. Its useful numerical behavior is deterministic: `b` is
formed from `log(a)`, `SUB1` cubes that value and returns twice the cube, and
the caller updates `d` and final `a` from those values.

At the pinned Tapenade revision, the stored primal, parser, forward, and
reverse files pass the strict fixed-form compiler gate. Stored
`program_dv.f` does not: it includes `DIFFSIZES.inc`, which is missing from
the case directory. The pinned upstream contains no unambiguous authoritative
definition for this case, so the include is not fabricated or copied from an
unrelated example.

Fresh pinned Tapenade parser (`-p`), forward (`-d`), and reverse (`-b`)
generation all succeed, and each generated fixed-form file passes the strict
syntax gate. FortAD source-first `check` and forward transformation succeed;
source-first reverse refuses the exact source with `assignment to undeclared
'sub1'`. The direct Tapenade-compatible parser and forward forms succeed, and
the compatible reverse form has the same expected refusal.

`oracle.py` is independent of repository hashes and generated files. It checks
three meaningful numerical inputs against an explicit model using central
finite differences and a reverse dot-product identity.

