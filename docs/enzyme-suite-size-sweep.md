# Enzyme suite size sweep

This is the committed controlled run of the common FortAD/Enzyme/Tapenade
harness. It is a measurement record, not a claim that one engine wins the
whole suite: the requested matrix has explicit gaps.

## Reproduction

The committed record was produced with the existing harness in two successful
shards, because the two `N=1,000,000` runtime failures do not produce a CSV
header and the current all-sizes merge step cannot parse those files:

```bash
scripts/run_enzyme_suite_sweep.sh \
  --sizes 100,1000,10000,100000 --affinity 0
scripts/run_enzyme_suite_sweep.sh \
  --sizes 1000000 --workloads euler,rk4,ba --affinity 0
```

The two outputs were combined by workload/size/engine with duplicate-key and
coverage validation; the aggregate provenance records both source run IDs.

Each shard builds the executable and then invokes it once per workload and
problem size. Every invocation uses the same FortAD, Enzyme, and Tapenade objects,
seven timed trials, automatic repetitions, CPU 0 affinity, and the
`system_clock_wall` clock. Every invocation first checks its derivative against
the other engines and an independent central-difference step sweep. The CSV
stores median, minimum, and maximum wall time plus normalized nanoseconds per
input element.

The documented size list is `100,1000,10000,100000,1000000`. The runs were
produced on an AMD Ryzen 9 5950X with flang, clang, opt, and llvm-link 22.1.8,
Docker 29.7.1, and the pinned Tapenade image in the provenance sidecars. They
used benchmark commit `e3db0e700fbd72901c628da892ac3129c2861166` and FortAD
commit `b8c4a78a6763200ed6e84ec96fbac74116b67943`, whose ancestry includes the
`089130f` LSTM reverse-temporary rank fix.

The durable artifacts are:

- [timing CSV](../results/enzyme_suite_sweep.csv): 115 measured rows;
- [gap CSV](../results/enzyme_suite_sweep_gaps.csv): six explicit gaps;
- [four-size provenance JSON](../results/enzyme_suite_sweep.20260809T050610Z-1030078.json)
  and [million-size provenance JSON](../results/enzyme_suite_sweep.20260809T050546Z-1028234.json):
  host, tool versions, flags, affinity, repetitions, peak RSS, and artifact
  sizes for each source run;
- [aggregate provenance JSON](../results/enzyme_suite_sweep.20260809T050610Z-1030078-aggregate.json):
  source runs, full five-size coverage, and the six runtime gaps.

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
| ba | 100 | 5.151585 | 8.175809 | 18.729010 |
| ba | 1,000 | 5.050594 | 8.088411 | 18.951940 |
| ba | 10,000 | 5.054421 | 8.111806 | 19.043570 |
| ba | 100,000 | 5.130783 | 8.200102 | 19.277740 |
| ba | 1,000,000 | 5.249692 | 8.314086 | 19.768140 |
| bruss | 100 | 10.201730 | 12.804030 | 16.616220 |
| bruss | 1,000 | 9.456779 | 11.876500 | 14.479180 |
| bruss | 10,000 | 9.347287 | 11.670880 | 14.194690 |
| bruss | 100,000 | 9.412833 | 11.701800 | 14.296190 |

The `lstm` and `bruss` rows at `N=1,000,000` are not timings: the benchmark
process terminated with signal 11/exit status 139, so all six three-engine
entries are explicit gaps.

## Measurement gaps

The historical LSTM gap was FortAD's generated reverse and gradient-only
sources failing flang semantic rank checking at `fad_s15` and `fad_s18`
(scalar-versus-array assignments). After FortAD `089130f`, all three engines
have comparable LSTM measurements at 100, 1,000, 10,000, and 100,000: 12 of
the historical 15 LSTM engine/size gaps are closed. At 1,000,000 the generated
LSTM benchmark still terminates with signal 11; a one-trial, one-repetition
probe reproduced that failure before timing (about 18 MiB peak RSS), so the
remaining three LSTM entries are recorded as runtime gaps rather than as
missing measurements.

The three historical `bruss` 1,000,000 gaps remain runtime gaps with exit
status 139. The Enzyme and Tapenade rows for both failed workload/size points
are explicitly marked “not measured” rather than silently omitted.

The committed result consequently has complete three-engine measurements for
`euler`, `rk4`, and `ba` at all five sizes, and for `lstm` and `bruss` through
`N=100,000`: 115 rows plus six explicit gaps. It does not support a whole-suite
performance victory claim.

The independent behavioral oracle is the harness's four-step directional
central-difference sweep of each unmodified primal; cross-engine agreement is
only corroboration. Independent protocol checks are in
[`scripts/test_enzyme_suite_sweep.py`](../scripts/test_enzyme_suite_sweep.py):
they test size/workload parsing, median statistics, normalized-time arithmetic,
complete matrix coverage, and explicit gap coverage without relying on the
committed measurement values.
