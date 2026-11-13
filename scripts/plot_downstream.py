#!/usr/bin/env python3
"""Summarize independent downstream samples and plot both matching contracts."""

from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path
import statistics


PAIRS = (("enzyme", "fortad-vjp", "primal and gradient"),
         ("tapenade", "fortad-grad", "gradient only"))


def summarize(root: Path) -> list[dict]:
    metadata = json.loads((root / "metadata.json").read_text())
    if metadata.get("mode") != "measurement" or metadata.get("status") not in (
            "complete", "complete-with-gaps"):
        raise ValueError("plot requires a finished measurement, not a smoke run")
    expected = int(metadata["protocol"]["samples"])
    if expected < 7:
        raise ValueError("at least seven independent samples are required")
    inputs = metadata["source_sha256"]
    arities = {(row["suite"], row["operator"]): int(row["arity"])
               for row in metadata["inventory"]}
    batch = int(metadata["protocol"]["batch"])
    minimum = float(metadata["protocol"]["min_seconds"])
    if (batch < 1 or not math.isfinite(minimum) or minimum < .05 or not inputs
            or set(inputs) != {"/".join(key) for key in arities}
            or any(arity < 1 for arity in arities.values())):
        raise ValueError("invalid measurement protocol")
    values = {}
    with (root / "trials.csv").open(newline="") as stream:
        for row in csv.DictReader(stream):
            key = (row["suite"], row["operator"], row["engine"])
            identity = "/".join(key[:2])
            if identity not in inputs or key[2] not in ("fortad-vjp", "fortad-grad", "enzyme", "tapenade"):
                raise ValueError("unknown measurement identity")
            sample = int(row["sample"])
            seconds, repetitions = float(row["seconds"]), int(row["repetitions"])
            arity = int(row["arity"])
            if (int(row["batch"]) != batch or arity != arities.get(key[:2])
                    or repetitions < 1 or not math.isfinite(seconds) or seconds < minimum):
                raise ValueError("incomplete timed sample")
            value = 1e9*seconds/(batch*arity*repetitions)
            if not math.isclose(float(row["ns_per_input"]), value, rel_tol=1e-12):
                raise ValueError("inconsistent timing normalization")
            if sample < 0 or sample >= expected or not math.isfinite(value) or value <= 0:
                raise ValueError("invalid timed sample")
            if sample in values.setdefault(key, {}):
                raise ValueError("duplicate timed sample")
            values[key][sample] = value
    result = []
    for identity in sorted(inputs):
        suite, operator = identity.split("/")
        for reference, fortad, contract in PAIRS:
            a = values.get((suite, operator, fortad), {})
            b = values.get((suite, operator, reference), {})
            row = dict(suite=suite, operator=operator, reference=reference, contract=contract,
                       samples=min(len(a), len(b)), status="incomplete",
                       fortad_ns="", reference_ns="", ratio="", ratio_min="", ratio_max="")
            if set(a) == set(b) == set(range(expected)):
                ratios = [a[i]/b[i] for i in range(expected)]
                row.update(status="measured", fortad_ns=statistics.median(a.values()),
                           reference_ns=statistics.median(b.values()),
                           ratio=statistics.median(ratios), ratio_min=min(ratios), ratio_max=max(ratios))
            result.append(row)
    return result


def plot(root: Path) -> None:
    rows = summarize(root)
    with (root / "comparison.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    for suite in sorted({row["suite"] for row in rows}):
        selected = [row for row in rows if row["suite"] == suite]
        operators = sorted({row["operator"] for row in selected})
        fig, ax = plt.subplots(figsize=(10, max(4, 0.31*len(operators)+1.7)))
        for ref, color, marker, shift in (("enzyme", "#0072B2", "o", -.13),
                                          ("tapenade", "#D55E00", "s", .13)):
            for row in selected:
                if row["reference"] != ref:
                    continue
                y = operators.index(row["operator"]) + shift
                if row["status"] == "measured":
                    ax.hlines(y, row["ratio_min"], row["ratio_max"], color=color, lw=1)
                    ax.plot(row["ratio"], y, marker, color=color, ms=4)
                else:
                    ax.text(1.01, y, f"{ref}: unavailable", transform=ax.get_yaxis_transform(),
                            va="center", fontsize=6.5, color=color)
            label = "Enzyme: primal + gradient" if ref == "enzyme" else "Tapenade: gradient only"
            ax.plot([], [], marker, color=color, label=label, ms=4)
        ax.axvline(1, color="black", lw=.8)
        ax.set_xscale("log")
        ax.set_yticks(range(len(operators)), operators, fontsize=8)
        ax.invert_yaxis()
        ax.set_xlabel("FortAD time / reference time (dimensionless; below 1 is faster)")
        ax.set_title(f"{suite}: reverse derivative cost per input\n"
                     "Median paired process ratio; bars show observed sample range", fontsize=11)
        ax.grid(axis="x", which="both", alpha=.2)
        ax.legend(loc="lower center", bbox_to_anchor=(.5, 1.08), ncol=2, fontsize=8)
        fig.tight_layout()
        for suffix in ("png", "svg"):
            fig.savefig(root / f"comparison-{suite}.{suffix}", dpi=180, bbox_inches="tight")
        plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", type=Path)
    args = parser.parse_args()
    plot(args.run.resolve())


if __name__ == "__main__":
    main()
