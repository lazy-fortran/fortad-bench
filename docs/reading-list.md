# Reading list

Hand-curated. Every identifier below was looked up and checked against the
actual record — arXiv IDs were confirmed by reading the PDF's first page,
DOIs by matching the publisher's title and venue.

**Fetch column:** `arXiv` means an author-posted preprint is freely available at
the link. `manual` means no validated open-access PDF was fetched; use the
linked report, repository, institutional access, or a library copy as
appropriate.

No full text is committed to this repository. See [../LEGAL.md](../LEGAL.md).

---

## Tier 1 — read before writing any transformation code

| # | Work | Identifier | Fetch |
|---|---|---|---|
| 1 | Hascoët & Pascual, *The Tapenade Automatic Differentiation Tool: Principles, Model, and Specification*, ACM TOMS 39(3), 2013 | [10.1145/2450153.2450158](https://doi.org/10.1145/2450153.2450158) | **manual** — also available as Inria research report [RR-7957](https://inria.hal.science/hal-00695839) |
| 2 | Hascoët, Naumann & Pascual, *"To Be Recorded" Analysis in Reverse-Mode Automatic Differentiation*, FGCS 21(8), 2005 | [10.1016/j.future.2004.11.009](https://doi.org/10.1016/j.future.2004.11.009) | **manual** |
| 3 | Giering & Kaminski, *Recipes for Adjoint Code Construction*, ACM TOMS 24(4), 1998 | [10.1145/293686.293695](https://doi.org/10.1145/293686.293695) | **manual** |
| 4 | Moses & Churavy, *Instead of Rewriting Foreign Code for Machine Learning, Automatically Synthesize Fast Gradients* (Enzyme), NeurIPS 2020 | [arXiv:2010.01709](https://arxiv.org/abs/2010.01709) | arXiv |
| 5 | Griewank & Walther, *Evaluating Derivatives*, 2nd ed., SIAM 2008 | [10.1137/1.9780898717761](https://doi.org/10.1137/1.9780898717761) | **manual** — book. The one durable purchase. |

## Tier 2 — the analyses and the storage problem

| # | Work | Identifier | Fetch |
|---|---|---|---|
| 6 | Utke et al., *OpenAD/F: A Modular Open-Source Tool for Automatic Differentiation of Fortran Codes*, ACM TOMS 34(4), 2008 | [10.1145/1377596.1377598](https://doi.org/10.1145/1377596.1377598) | **manual** |
| 7 | Griewank & Walther, *Algorithm 799: Revolve*, ACM TOMS 26(1), 2000 | [10.1145/347837.347846](https://doi.org/10.1145/347837.347846) | **manual** |
| 8 | Naumann, *Optimal Jacobian Accumulation is NP-complete*, Math. Prog. 112, 2008 | [10.1007/s10107-006-0042-z](https://doi.org/10.1007/s10107-006-0042-z) | **manual** |
| 9 | Naumann, *The Art of Differentiating Computer Programs*, SIAM 2012 | [10.1137/1.9781611972078](https://doi.org/10.1137/1.9781611972078) | **manual** — book |
| 10 | Christianson, *Reverse Accumulation and Attractive Fixed Points*, Optim. Methods Softw. 3, 1994 | [10.1080/10556789408805572](https://doi.org/10.1080/10556789408805572) | **manual** |
| 11 | Heimbach, Hill & Giering, *An Efficient Exact Adjoint of the Parallel MIT General Circulation Model, Generated via Automatic Differentiation*, FGCS 21(8), 2005 | [10.1016/j.future.2004.11.010](https://doi.org/10.1016/j.future.2004.11.010) | **manual** |

## Tier 3 — source-level AD that competes with IR-level AD

| # | Work | Identifier | Fetch |
|---|---|---|---|
| 12 | van Merriënboer, Moldovan & Wiltschko, *Tangent: Automatic Differentiation Using Source-Code Transformation*, NeurIPS 2018 | [arXiv:1809.09569](https://arxiv.org/abs/1809.09569) | arXiv |
| 13 | Innes, *Don't Unroll Adjoint: Differentiating SSA-Form Programs* (Zygote), 2019 | [arXiv:1810.07951](https://arxiv.org/abs/1810.07951) | arXiv |
| 14 | Vassilev et al., *Clad — Automatic Differentiation Using Clang and LLVM*, J. Phys. Conf. Ser. 608, 2015 | [10.1088/1742-6596/608/1/012055](https://doi.org/10.1088/1742-6596/608/1/012055) | open access |
| 15 | Paszke et al., *Getting to the Point: Index Sets and Parallelism-Preserving Autodiff for Pointful Array Programming*, ICFP 2021 | [10.1145/3473593](https://doi.org/10.1145/3473593), [arXiv:2104.05372](https://arxiv.org/abs/2104.05372) | arXiv |
| 16 | Hückelheim & Hascoët, *Source-to-Source Automatic Differentiation of OpenMP Parallel Loops*, ACM TOMS 48(1), 2022 | [10.1145/3472796](https://doi.org/10.1145/3472796), [arXiv:2111.01861](https://arxiv.org/abs/2111.01861) | arXiv |
| 17 | Bischof, Carle, Khademi & Mauer, *ADIFOR 2.0*, IEEE Comput. Sci. Eng. 3(3), 1996 | [10.1109/99.537089](https://doi.org/10.1109/99.537089) | **manual** |
| 18 | van Merriënboer et al., *Automatic Differentiation in ML: Where We Are and Where We Should Be Going*, NeurIPS 2018 | [arXiv:1810.11530](https://arxiv.org/abs/1810.11530) | arXiv |

## Tier 4 — Enzyme in depth, so the comparison is fair

| # | Work | Identifier | Fetch |
|---|---|---|---|
| 19 | Moses et al., *Reverse-Mode Automatic Differentiation and Optimization of GPU Kernels via Enzyme*, SC'21 | [10.1145/3458817.3476165](https://doi.org/10.1145/3458817.3476165) | **manual** |
| 20 | Moses et al., *Scalable Automatic Differentiation of Multiple Parallel Paradigms through Compiler Augmentation*, SC'22 | [10.1109/SC41404.2022.00065](https://doi.org/10.1109/SC41404.2022.00065) | **manual** |

## Tier 5 — performance references and structured rules

| # | Work | Identifier | Fetch |
|---|---|---|---|
| 21 | Hogan, *Fast Reverse-Mode Automatic Differentiation Using Expression Templates in C++* (Adept), ACM TOMS 40(4), 2014 | [10.1145/2560359](https://doi.org/10.1145/2560359) | **manual** |
| 22 | Sagebaum, Albring & Gauger, *High-Performance Derivative Computations Using CoDiPack*, ACM TOMS 45(4), 2019 | [10.1145/3356900](https://doi.org/10.1145/3356900), [arXiv:1709.07229](https://arxiv.org/abs/1709.07229) | arXiv |
| 23 | Giles, *Collected Matrix Derivative Results for Forward and Reverse Mode Algorithmic Differentiation*, in *Advances in Automatic Differentiation*, 2008 | [10.1007/978-3-540-68942-3_4](https://doi.org/10.1007/978-3-540-68942-3_4) | **manual** — also as [Oxford NA report 08/01](https://people.maths.ox.ac.uk/gilesm/files/NA-08-01.pdf) |
| 24 | Blondel et al., *Efficient and Modular Implicit Differentiation*, NeurIPS 2022 | [arXiv:2105.15183](https://arxiv.org/abs/2105.15183) | arXiv |
| 25 | Hückelheim et al., *Reverse-Mode Algorithmic Differentiation of an OpenMP-Parallel Compressible Flow Solver*, IJHPCA 33(1), 2019 | [10.1177/1094342017712060](https://doi.org/10.1177/1094342017712060) | **manual** |

## Tier 6 — sparsity, higher order, and the product side

| # | Work | Identifier | Fetch |
|---|---|---|---|
| 26 | Gebremedhin, Manne & Pothen, *What Color Is Your Jacobian? Graph Coloring for Computing Derivatives*, SIAM Review 47(4), 2005 | [10.1137/S0036144504444711](https://doi.org/10.1137/S0036144504444711) | **manual** |
| 27 | Curtis, Powell & Reid, *On the Estimation of Sparse Jacobian Matrices*, IMA J. Appl. Math. 13(1), 1974 | [10.1093/imamat/13.1.117](https://doi.org/10.1093/imamat/13.1.117) | **manual** |
| 28 | Gower & Mello, *A New Framework for the Computation of Hessians* (edge_pushing), Optim. Methods Softw. 27(2), 2012 | [10.1080/10556788.2011.580098](https://doi.org/10.1080/10556788.2011.580098), [arXiv:2007.15040](https://arxiv.org/abs/2007.15040) | arXiv |
| 29 | Walther & Griewank, *Getting Started with ADOL-C*, in *Combinatorial Scientific Computing*, 2012 | [10.1201/b11644-8](https://doi.org/10.1201/b11644-8) | **manual** |
| 30 | Smith, *Uncertainty Quantification: Theory, Implementation, and Applications*, SIAM 2013 | [10.1137/1.9781611973228](https://doi.org/10.1137/1.9781611973228) | **manual** — book |
| 31 | Nocedal & Wright, *Numerical Optimization*, 2nd ed., Springer 2006 | [10.1007/978-0-387-40065-5](https://doi.org/10.1007/978-0-387-40065-5) | **manual** — book, likely already on the shelf |
| 32 | Saltelli et al., *Global Sensitivity Analysis: The Primer*, Wiley 2008 | ISBN 978-0-470-05997-5 | **manual** — book. Bounds what fortad may claim for UQ. |

## Not papers, but read them

- **JAX** `jax/_src/interpreters/ad.py` — JVP plus transposition, the single most
  valuable architectural idea for fortad. Apache-2.0, in `upstream/jax`.
- **ChainRules.jl** `src/rulesets/` — the rule-registry design to beat. MIT.
- **PyTorch** `tools/autograd/derivatives.yaml` — a declarative derivative table
  at scale. BSD-3.
- **Tangent** `tangent/reverse_ad.py`, `grads.py`, `fence.py` — the closest
  product precedent. Apache-2.0.
- **Enzyme** `ActivityAnalysis.cpp`, `TypeAnalysis/`, `CacheUtility.cpp`,
  `InstructionDerivatives.td` — what we are competing with, and the evidence for
  how much of it exists only because LLVM IR has lost Fortran's types.

---

## What is already local

`literature/` currently holds the nine open-access preprints (items 4, 12, 13,
15, 16, 18, 22, 24, 28), fetched from arXiv. Everything marked **manual** above
is paywalled; those are the ones to pull through TU Graz access into Zotero.

## Resolution audit (2026-08-05)

The remote resolver parsed all 33 bibliography entries and recorded Crossref,
arXiv, and Unpaywall results in its ignored `literature/resolved.json`. A clean
`--fetch` run validated nine PDFs: the preprints listed above. It also found
open-access landing pages for Tapenade (item 1), Clad (item 14), and ADOL-C
(item 29), but those responses were HTML rather than PDFs and were not copied.
The other 21 entries have no accepted open-access PDF in the audit and remain
institutional/library retrieval items. No title was changed because of an
uncertain Crossref match.
