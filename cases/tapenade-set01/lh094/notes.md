# Tapenade `nonRegressions/set01/lh094`

`lh094` is the fixed-form `test(a,b)` external-summary candidate. The exact
source computes `s=a*a`, passes `s` through external `DISACTIVATE`, and then
updates `b=a+b+s`. The upstream row does not provide an implementation of
`DISACTIVATE`; `MyGeneralLib` only supplies Tapenade summary metadata.

Pinned fresh Tapenade parser, forward, and reverse generation succeeds with
that exact summary supplied by `-ext`, and the generated files compile under
strict fixed-form syntax checks. The exact and stored tangent sources pass
both strict and legacy gates.

At FortAD `ba15d9fc2445e7aa8e8cd130484bd0984ceb2fc1`, `check` re-emits the
exact source successfully. Exact forward and reverse refuse because there is
no derivative rule for `DISACTIVATE`; neither writes an output file. This is
the recorded behavior, not a support claim.

`oracle.py` is independent of Tapenade and FortAD. It treats the summary's
read/write declaration as a bounded identity witness and checks the induced
`b=a+b+a*a` JVP and VJP identities. This is summary-level evidence only; no
external implementation or repaired port is added.

Run from the repository root with `cases/tapenade-set01/lh094/run.sh`. The
complete gate record is in [`result.txt`](result.txt).
