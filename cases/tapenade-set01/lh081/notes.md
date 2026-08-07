# Tapenade set01/lh081

`lh081` is a small fixed-form external-procedure call-graph regression. The
exact upstream source defines `test2`, which calls `test`; `test` calls the
external `pjac` procedure and passes the external `jac` procedure. `f`, `jac`,
and `pjac` have no implementations in this corpus directory, so this case
deliberately does not fabricate them or turn the call graph into a numerical
port.

At the pinned Tapenade revision
`e59864cab441d4175df75383b3ff58c3dcd26df9`, the stored primal, parser,
forward, and reverse files pass the strict fixed-form syntax gate. The stored
multidirectional reference is the expected exception: it includes the absent
`DIFFSIZES.inc`. Fresh parser, forward, and reverse probes rooted at the
actual `test2` procedure generate the corresponding artifacts, and each fresh
artifact passes the same strict gate.

At FortAD revision `7adc75030db3fa4422339d82d2725ae29ee13dac`, exact forward
and reverse requests for the actual `test2` procedure both refuse before
creating an output file. Their diagnostic is that inlining `test` would need
a statement form it does not have. This is recorded as an external-procedure
boundary, not papered over with a synthetic root, external implementation, or
bounded port.

`oracle.py` independently checks the source call graph and the semantic
propagation represented by the fresh tangent and adjoint wrappers. The
three-test contract additionally checks the oracle, fresh Tapenade strict
compilation, and exact FortAD refusal behavior.
