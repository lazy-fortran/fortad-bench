# Enzyme suite size sweep

This is the committed controlled run of the common FortAD/Enzyme/Tapenade
harness. It is a measurement record, not a claim that one engine wins the
whole suite.

## Reproduction

The committed record was produced with the existing harness in one complete
five-size run:

```bash
scripts/run_enzyme_suite_sweep.sh \
  --sizes 100,1000,10000,100000,1000000 --workloads all --affinity 0
```

The runner builds the executable and then invokes it once per workload and
problem size. Every invocation uses the same FortAD, Enzyme, and Tapenade objects,
seven timed trials, automatic repetitions, CPU 0 affinity, an unlimited
process stack, and the `system_clock_wall` clock. The runner raises the stack
limit before launching the benchmark and fails explicitly if the hard limit
cannot be raised. Every invocation first checks its derivative against
the other engines and an independent central-difference step sweep. The CSV
stores median, minimum, and maximum wall time plus normalized nanoseconds per
input element.

The documented size list is `100,1000,10000,100000,1000000`. The runs were
produced on an AMD Ryzen 9 5950X with flang, clang, opt, and llvm-link 22.1.8,
Docker 29.7.1, and the pinned Tapenade image in the provenance sidecars. They
used benchmark commit `f2697917ae03fe7ea488dea6bd10038308f216fb` and FortAD
commit `ae67c509875d07bde4a162679a78374a44365a9d`.

The durable artifacts are:

- [timing CSV](../results/enzyme_suite_sweep.csv): 125 measured rows;
- [gap CSV](../results/enzyme_suite_sweep_gaps.csv): no gaps;
- [provenance JSON](../results/enzyme_suite_sweep.20260809T071211Z-2277153.json):
  host, tool versions, flags, unlimited-stack launch, affinity, repetitions,
  peak RSS, and artifact sizes.

## Median runtime

Values below are `ns_per_input_median`; the complete CSV also contains
`fortad-grad` and primal rows, as well as trial minima and maxima.

| Workload | N | FortAD | Enzyme | Tapenade |
|---|---:|---:|---:|---:|
| euler | 100 | 2.218828 | 4.008926 | 1.065340 |
| euler | 1,000 | 2.069311 | 3.954784 | 0.902976 |
| euler | 10,000 | 2.052996 | 3.941023 | 0.892484 |
| euler | 100,000 | 2.174247 | 3.948021 | 0.947145 |
| euler | 1,000,000 | 2.182164 | 3.913552 | 1.049856 |
| rk4 | 100 | 2.330195 | 19.623580 | 9.090300 |
| rk4 | 1,000 | 2.095732 | 19.063320 | 8.606093 |
| rk4 | 10,000 | 2.082000 | 19.108740 | 8.662256 |
| rk4 | 100,000 | 2.118226 | 19.062710 | 8.644733 |
| rk4 | 1,000,000 | 2.226621 | 19.549180 | 8.913249 |
| lstm | 100 | 126.344500 | 142.659900 | 114.966800 |
| lstm | 1,000 | 129.443000 | 146.207900 | 116.947900 |
| lstm | 10,000 | 134.808600 | 153.867700 | 121.106800 |
| lstm | 100,000 | 183.051600 | 228.116600 | 192.065700 |
| lstm | 1,000,000 | 131.893700 | 151.555300 | 119.523800 |
| ba | 100 | 5.151585 | 8.175809 | 18.729010 |
| ba | 1,000 | 5.050594 | 8.088411 | 18.951940 |
| ba | 10,000 | 5.054421 | 8.111806 | 19.043570 |
| ba | 100,000 | 5.130783 | 8.200102 | 19.277740 |
| ba | 1,000,000 | 5.249692 | 8.314086 | 19.768140 |
| bruss | 100 | 10.201730 | 12.804030 | 16.616220 |
| bruss | 1,000 | 9.456779 | 11.876500 | 14.479180 |
| bruss | 10,000 | 9.347287 | 11.670880 | 14.194690 |
| bruss | 100,000 | 9.412833 | 11.701800 | 14.296190 |
| bruss | 1,000,000 | 11.188640 | 13.855040 | 17.316320 |

All rows in the table are measured timings from the complete three-engine
matrix.

## Measurement gaps

The former six gaps were process stack-limit crashes at `N=1,000,000`, not
derivative disagreements. The runner now raises the stack limit before every
benchmark invocation; the complete 125-row matrix passes derivative checks and
the independent central-difference protocol. This closes the measurement gap,
but it does not establish a whole-suite performance victory: Tapenade remains
faster on several workloads, so optimization work is still required.

The independent behavioral oracle is the harness's four-step directional
central-difference sweep of each unmodified primal; cross-engine agreement is
only corroboration. Independent protocol checks are in
[`scripts/test_enzyme_suite_sweep.py`](../scripts/test_enzyme_suite_sweep.py):
they test size/workload parsing, median statistics, normalized-time arithmetic,
complete matrix coverage, and explicit gap coverage without relying on the
committed measurement values.
