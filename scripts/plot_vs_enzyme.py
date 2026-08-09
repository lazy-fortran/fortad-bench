#!/usr/bin/env python3
"""Plot fortad against Enzyme for every benchmarked operator.

One panel per suite. Each operator contributes a reverse bar and a forward
bar, drawn as fortad's time divided by Enzyme's, so 1.0 is parity and lower
is faster. The 20% and 30% lines are the targets the port was held to.
"""
import csv, collections
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

SUITES = [("enzyme_suite", "Enzyme's own suite"),
          ("fortnum_suite", "fortnum operators"),
          ("fortfem_suite", "fortfem operators")]
MODES = [("reverse", "fortad", "enzyme"), ("forward", "fortad-jvp", "enzyme-jvp")]

def load(name):
    d = collections.defaultdict(dict)
    for r in csv.DictReader(open(f"results/{name}.csv")):
        rate = r.get("ns_per_input_median") or r.get("ns_per_input")
        d[r.get("operator") or r["workload"]][r["engine"]] = float(rate)
    return d

fig, axes = plt.subplots(3, 1, figsize=(11, 13))
for ax, (name, title) in zip(axes, SUITES):
    d = load(name)
    ops = sorted(d)
    x = np.arange(len(ops))
    for k, (mode, a, b) in enumerate(MODES):
        vals = [d[o][a] / d[o][b] if a in d[o] and b in d[o] else np.nan for o in ops]
        bars = ax.bar(x + (k - 0.5) * 0.38, vals, 0.38,
                      label=mode, color=["#2b6cb0", "#dd6b20"][k])
        for rect, v in zip(bars, vals):
            if not np.isnan(v):
                ax.text(rect.get_x() + rect.get_width() / 2, v + 0.02,
                        f"{v:.2f}", ha="center", va="bottom", fontsize=7)
    ax.axhline(1.0, color="black", lw=1)
    ax.axhline(1.2, color="green", ls="--", lw=1, label="20% target")
    ax.axhline(1.3, color="red", ls=":", lw=1, label="30% target")
    ax.set_xticks(x)
    ax.set_xticklabels(ops, rotation=30, ha="right", fontsize=8)
    ax.set_ylabel("fortad / Enzyme")
    ax.set_title(title)
    ax.set_ylim(0, 1.45)
    ax.legend(fontsize=8, ncol=4)
fig.suptitle("fortad against Enzyme - lower is faster, 1.0 is parity", fontsize=13)
fig.tight_layout()
fig.savefig("results/fortad_vs_enzyme.png", dpi=150)
print("wrote results/fortad_vs_enzyme.png")

# Second figure: the absolute timings behind those ratios, on a log axis so
# operators three orders of magnitude apart stay readable on one page.
fig2, ax = plt.subplots(figsize=(12, 7))
labels, fa, en = [], [], []
for name, title in SUITES:
    d = load(name)
    for o in sorted(d):
        for mode, a, b in MODES:
            if a in d[o] and b in d[o]:
                labels.append(f"{o} ({mode[:3]})")
                fa.append(d[o][a]); en.append(d[o][b])
x = np.arange(len(labels))
ax.bar(x - 0.2, en, 0.4, label="Enzyme", color="#718096")
ax.bar(x + 0.2, fa, 0.4, label="fortad", color="#2b6cb0")
ax.set_yscale("log")
ax.set_ylabel("ns per input (log scale)")
ax.set_xticks(x)
ax.set_xticklabels(labels, rotation=75, ha="right", fontsize=7)
ax.set_title("Absolute cost per input, fortad against Enzyme (39 measurements)")
ax.legend()
fig2.tight_layout()
fig2.savefig("results/fortad_vs_enzyme_absolute.png", dpi=150)
print("wrote results/fortad_vs_enzyme_absolute.png")


def load_size_sweep():
    path = Path("results/enzyme_suite_sweep.csv")
    if not path.is_file():
        return {}
    data = collections.defaultdict(lambda: collections.defaultdict(dict))
    for row in csv.DictReader(path.open(encoding="utf-8")):
        rate = row.get("ns_per_input_median")
        if not rate:
            raise ValueError("size sweep must contain median normalized timings")
        data[row["workload"]][int(row["problem_size"])][row["engine"]] = float(rate)
    return data


sweep = load_size_sweep()
if sweep:
    fig3, axes3 = plt.subplots(len(sweep), 1, figsize=(10, 2.6 * len(sweep)), squeeze=False)
    for ax, workload in zip(axes3[:, 0], sorted(sweep)):
        sizes = sorted(sweep[workload])
        for engine, color in (("fortad", "#2b6cb0"), ("enzyme", "#718096"),
                              ("tapenade", "#dd6b20"), ("fortad-grad", "#805ad5")):
            values = [sweep[workload][size].get(engine, np.nan) for size in sizes]
            ax.plot(sizes, values, marker="o", label=engine, color=color)
        ax.set_xscale("log")
        ax.set_yscale("log")
        ax.set_ylabel("median ns/input")
        ax.set_title(workload)
        ax.grid(True, which="both", alpha=0.2)
        ax.legend(fontsize=8, ncol=4)
    axes3[-1, 0].set_xlabel("problem size N")
    fig3.suptitle("Enzyme suite size sweep (median wall-clock samples)")
    fig3.tight_layout()
    fig3.savefig("results/fortad_vs_enzyme_size_sweep.png", dpi=150)
    print("wrote results/fortad_vs_enzyme_size_sweep.png")
