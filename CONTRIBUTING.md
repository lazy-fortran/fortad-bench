# Contributing

Keep each workload's mathematical statement, source origin, licence and independent
oracle together. Update [PROVENANCE.md](PROVENANCE.md) before adapting external
source, and retain its notices in the source and `LICENSES/`.

Use the existing Python `unittest` tests under `scripts/` for script changes.
Run them with Python 3.11 or later:

```console
python3 -m unittest discover -s scripts -p 'test_*.py'
```

Run the affected compiled driver for a kernel or engine-interface change. Keep
parser acceptance, generated-code compilation and runtime derivative correctness
as separate outcomes. Analytical derivatives, finite-difference convergence and
adjoint identities are independent checks; another tool's output is supporting
evidence.

Record hardware, operating system, compiler, engine revision, flags, warm-up and
repetition count with measurements. Include losses and missing engines. Do not
commit fetched tool sources, generated derivatives, build trees or scratch output.
