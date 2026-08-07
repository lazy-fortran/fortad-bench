"""Contract and independent-oracle checks for the set01 lh025 tranche."""

import math
import tomllib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class Lh025EvidenceTests(unittest.TestCase):
    def test_manifest_and_report_record_all_gates(self):
        manifest_path = ROOT / "cases/tapenade-set01/tranche-lh025-manifest.toml"
        with manifest_path.open("rb") as stream:
            manifest = tomllib.load(stream)
        case = manifest["case"][0]
        self.assertEqual(case["id"], "lh025")
        self.assertEqual(case["classification"], "runnable-ported-with-exact-source-fortad-refusal")
        self.assertEqual(manifest["upstream_revision"], "e59864cab441d4175df75383b3ff58c3dcd26df9")
        self.assertEqual(manifest["required_fortad_revision"], "db0050259520b618e2a0aeba203c85a7613943b5")

        report = (ROOT / "results/tapenade_set01_lh025_validation.txt").read_text()
        for marker in (
            "oracle_status: pass",
            "tapenade_oracle: fresh parser, tangent, and reverse",
            "upstream_exact_source_compile_statuses:",
            "fortad_exact_result: expected-refusal",
            "fortad_port_result: pass-transform-compile-runtime",
            "program_dv.f=0",
        ):
            self.assertIn(marker, report)

    def test_matrix_formula_is_independent_and_has_adjoint_identity(self):
        # This is a separate scalar oracle, not a check of generated files.
        m, k = 4, 3
        a = [[0.2 * (i + 1) - 0.1 * (j + 1) for j in range(k)] for i in range(m)]
        x = [0.7, -0.2, 1.1]
        da = [[0.03 * math.sin(i + 2 * j + 1) for j in range(k)] for i in range(m)]
        dx = [-0.04, 0.01, 0.02]
        lam, dlam = 1.4, -0.13
        seed = [0.5, -0.3, 0.2]

        z = [sum(a[i][j] * x[j] for j in range(k)) for i in range(m)]
        dz = [sum(da[i][j] * x[j] + a[i][j] * dx[j] for j in range(k)) for i in range(m)]
        y = [sum(a[i][j] * z[i] for i in range(m)) + lam * lam * x[j] for j in range(k)]
        dy = [
            sum(da[i][j] * z[i] + a[i][j] * dz[i] for i in range(m))
            + 2.0 * lam * dlam * x[j]
            + lam * lam * dx[j]
            for j in range(k)
        ]
        abar = [[z[i] * seed[j] + sum(a[i][q] * seed[q] for q in range(k)) * x[j]
                 for j in range(k)] for i in range(m)]
        xbar = [sum(a[i][j] * sum(a[i][q] * seed[q] for q in range(k)) for i in range(m))
                + lam * lam * seed[j] for j in range(k)]
        lbar = 2.0 * lam * sum(x[j] * seed[j] for j in range(k))
        lhs = sum(seed[j] * dy[j] for j in range(k))
        rhs = sum(abar[i][j] * da[i][j] for i in range(m) for j in range(k))
        rhs += sum(xbar[j] * dx[j] for j in range(k)) + lbar * dlam
        self.assertEqual(len(y), k)
        self.assertTrue(all(math.isfinite(value) for value in y + dy))
        self.assertAlmostEqual(lhs, rhs, places=13)


if __name__ == "__main__":
    unittest.main()
