# Tapenade set02/lh192 simple tranche

This exact source is a checkpoint/replay regression with a large nested loop.
The first output `y` reads two array elements, the loop scales a large active
region, and the final `x` uses an untouched array element.

Tapenade generates and strictly compiles all three modes.  FortAD's forward
output is syntactically compilable but uses `i` and `j` without assigning them
in the transformed loop.  Reverse mode deliberately refuses the same active
read/write loop because it lacks per-iteration storage.  Both observations
are retained as expected-refusal evidence; no repaired port is claimed.

The independent oracle reduces the exact scalar dataflow to four values and
checks its directional derivative without relying on either AD engine.
