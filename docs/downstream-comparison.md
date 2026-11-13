# Downstream reverse-product comparison

`scripts/downstream_tapenade.py` measures reverse derivatives of the existing
17 FortNum and 42 FortFEM scalar-output operators. It builds each operator and
engine separately so that an unsupported case leaves an explicit gap while
other cases can run. A result applies to these extracted operators and batch
sizes; it does not establish whole-library performance.

The comparison has two contracts:

| Recorded engine | Returned values | Compare with |
|---|---|---|
| `fortad-grad` | Gradient only | `tapenade` |
| `tapenade` | Gradient only | `fortad-grad` |
| `fortad-vjp` | Primal value and gradient | `enzyme` |
| `enzyme` | Primal value and gradient | `fortad-vjp` |

The scalar output seed is one. Each call includes resetting that seed and
zeroing the gradient buffer. Tapenade runs in reverse mode with
`-b -head NAME(y)/(z)`; FortAD's gradient-only route uses `--no-primal`.
Enzyme differentiates the existing C-bound Fortran form of the same operator.
Fortran sources and drivers use the selected Flang compiler and flags;
Enzyme's LLVM derivative object is compiled with matching Clang and the C
flags. Enzyme also needs matching LLVM tools and plug-in versions. The original
source files remain unchanged. Enzyme's generated LLVM representation also
passes through `opt -O3`, independently of the selected Fortran flags. The
default comparison uses `-O3` throughout.

## Run

Use Python 3.11 or newer; plotting additionally requires Matplotlib. Install
FortAD, Tapenade, and a compatible LLVM/Enzyme toolchain separately. The Enzyme
route requires Flang's LLVM output to be readable by the selected LLVM tools
and plug-in; their LLVM versions must match.
Tapenade's `ADFirstAidKit` supplies its stack runtime. Set `FORTAD_COMMIT` and
`ENZYME_COMMIT` to the exact source commits used to build the executables, and
`TAPENADE_ARCHIVE_SHA256` to the hash of the installed distribution archive.
These identities are required for a measurement.

```console
python3 scripts/downstream_tapenade.py \
  --fortad-bin /path/to/fortad \
  --tapenade-bin /path/to/tapenade/bin/tapenade \
  --runtime-dir /path/to/tapenade/ADFirstAidKit \
  --compiler /path/to/llvm/bin/flang --flags=-O3 \
  --cc /path/to/llvm/bin/clang --clang /path/to/llvm/bin/clang \
  --opt /path/to/llvm/bin/opt --llvm-link /path/to/llvm/bin/llvm-link \
  --enzyme-plugin /path/to/LLVMEnzyme.so \
  --fortad-revision "$FORTAD_COMMIT" --enzyme-revision "$ENZYME_COMMIT" \
  --tapenade-revision "$TAPENADE_ARCHIVE_SHA256" \
  --output /path/to/new-run-directory
```

Use `--suite fortnum`, `--workload det2`, or repeated `--engine` arguments to
select a subset. The default batch has 20,000 operator evaluations. The
default seven independent process samples shuffle the engine and workload
order. Each process warms up, then doubles its repetition count until a timed
wall-clock interval reaches at least 50 ms. Every final timed sample is kept.
The result reports nanoseconds per input scalar, including all repetitions.
Run the measurements in a fixed resource allocation and retain the scheduler's
job record, including CPUs, memory and any exclusivity setting. The metadata
records effective CPU affinity and available Slurm allocation variables.

`--smoke` permits shorter runs for checking the protocol. Smoke results are
marked separately and the plotting script refuses them as measurements.

## Correctness checks and limits

Before timing, each route checks every gradient coordinate in two batches of
three evaluations against central differences of the original primal. For
input coordinate `i`, numbered from one, the checked values are
`offset + 0.3*sin(0.31*i + 0.13*phase)`, with phases zero and one; the offset is
0.4 for FortNum and 0.6 for FortFEM. The timing batch uses phase zero.
Each coordinate's difference step is `10**(-j)*max(1,abs(z(i)))` for
`j = 4, 5, 6`. The best absolute error must be at most `1e-5` times the larger
of one and the largest absolute entry in that checked gradient. A returned
primal must agree with the original within `1e-8*max(1,abs(original))`.
Non-finite values and failed checks prevent timing.
These are sampled numerical checks, not proofs for every possible input.

The full timing-batch gradients must also agree across all available routes.
The reference is the first available route in the requested engine order;
the default order is `fortad-grad`, `tapenade`, `fortad-vjp`, `enzyme`.
FortNum keeps the existing componentwise tolerance of `1e-12` times the larger
of one and the reference component's magnitude. FortFEM keeps the existing
scale, the larger of one and the largest absolute reference-gradient entry,
and `1e-8` tolerance, with `1e-6` for the decic and
hendecic Bezier edge-area operators. A disagreement blocks timing of that
operator and retains the gradient vectors and diagnostic. Agreement between
engines supports the independent checks; it is not an independent oracle.

## Results

The new output directory contains:

- `metadata.json`: exact source identities and hashes, tools, flags, hardware,
  selected cases, contracts, available allocation variables and protocol.
- `trials.csv`: every successful process sample, repetitions, elapsed seconds,
  nanoseconds per input, checksums and finite-difference error.
- `gaps.csv`: build, correctness or runtime failures, with diagnostic paths.
- `build/`: generated sources, objects, full gradients and command logs.

The runner exits with status one when gaps exist and retains successful rows.
Do not treat missing rows as fast results. To write the summary tables and
labelled plots, run:

```console
python3 scripts/plot_downstream.py /path/to/new-run-directory
```

The plotter uses paired process samples for the two matching contracts,
reports medians and observed ranges, and lists missing comparisons explicitly.
It does not combine a gradient-only cost with a primal-and-gradient cost.
This document defines the experiment and makes no new performance claim.
