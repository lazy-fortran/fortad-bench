# Enzyme suite size sweep

This is the committed controlled run of the common FortAD/Enzyme/Tapenade
harness. It is a measurement record, not a claim that one engine wins the
whole suite: the requested matrix has explicit gaps.

## Reproduction

Run the documented sweep with:

```text
scripts/run_enzyme_suite_sweep.sh --affinity 0
```

The executable is built once and then invoked once per workload and problem
size. Each invocation uses the same FortAD, Enzyme, and Tapenade objects,
seven timed trials, automatic repetitions, CPU 0 affinity, and the
`system_clock_wall` clock. Every invocation first checks its derivative against
the other engines and an independent central-difference step sweep. The CSV
stores median, minimum, and maximum wall time plus normalized nanoseconds per
input element.

The documented size list is `100,1000,10000,100000,1000000`. The result for run
`20260809T043506Z-608942` was produced on an AMD Ryzen 9 5950X with flang,
clang, opt, and llvm-link 22.1.8, Docker 29.7.1, and the pinned Tapenade image
in the provenance sidecar. The sweep used benchmark commit
`b6b727966179c0383a65681dd3d34fbe29ecf3ab` and FortAD commit
`86749dcea540061e4ad4b048663f02462c34f610`.

The durable artifacts are:

- [timing CSV](../results/enzyme_suite_sweep.csv): 95 measured rows;
- [gap CSV](../results/enzyme_suite_sweep_gaps.csv): 18 explicit gaps;
- [provenance JSON](../results/enzyme_suite_sweep.20260809T043506Z-608942.json):
  host, tool versions, flags, affinity, repetitions, peak RSS, and artifact
  sizes.

## Median runtime

Values below are `ns_per_input_median`; the complete CSV also contains
`fortad-grad` and primal rows, as well as trial minima and maxima.

| Workload | N | FortAD | Enzyme | Tapenade |
|---|---:|---:|---:|---:|
| euler | 100 | 2.001020 | 3.661934 | 0.977264 |
| euler | 1,000 | 2.124956 | 3.915341 | 0.882736 |
| euler | 10,000 | 2.131393 | 3.952461 | 0.891392 |
| euler | 100,000 | 2.175689 | 3.979254 | 0.938112 |
| euler | 1,000,000 | 2.273130 | 4.097569 | 1.097302 |
| rk4 | 100 | 2.342433 | 19.702370 | 9.093316 |
| rk4 | 1,000 | 2.161116 | 19.972180 | 9.019865 |
| rk4 | 10,000 | 2.147160 | 19.965590 | 9.027965 |
| rk4 | 100,000 | 2.203915 | 20.045630 | 9.091164 |
| rk4 | 1,000,000 | 2.282678 | 19.976880 | 9.193580 |
| ba | 100 | 5.133900 | 8.236512 | 19.038930 |
| ba | 1,000 | 5.069726 | 8.160107 | 18.877720 |
| ba | 10,000 | 5.099306 | 8.178119 | 19.098120 |
| ba | 100,000 | 5.131072 | 8.205535 | 19.036850 |
| ba | 1,000,000 | 5.470862 | 8.559983 | 19.959880 |
| bruss | 100 | 9.594317 | 12.236260 | 14.415070 |
| bruss | 1,000 | 9.583324 | 12.051140 | 14.348420 |
| bruss | 10,000 | 9.618941 | 12.066770 | 14.392910 |
| bruss | 100,000 | 9.683082 | 12.138320 | 14.535910 |

The `bruss` row at `N=1,000,000` is not a timing: the benchmark process
segfaulted with exit status 139, so all three engine entries are gaps.

## Measurement gaps

FortAD's generated `lstm` reverse and gradient-only sources fail flang semantic
rank checking at `fad_s15` and `fad_s18` (scalar-versus-array assignments).
Therefore `lstm` has no comparable FortAD/Enzyme/Tapenade rows at any of the
five sizes; the gap CSV records all 15 engine/size entries. The Enzyme and
Tapenade `lstm` rows are explicitly marked “not measured” rather than being
silently omitted.

The committed result consequently has complete three-engine measurements for
`euler` and `rk4` at all five sizes, `ba` at all five sizes, and `bruss` through
`N=100,000`. It does not support a whole-suite performance victory claim.

Independent protocol checks are in
[`scripts/test_enzyme_suite_sweep.py`](../scripts/test_enzyme_suite_sweep.py):
they test size/workload parsing, median statistics, normalized-time arithmetic,
complete matrix coverage, and explicit gap coverage without relying on the
committed measurement values.
