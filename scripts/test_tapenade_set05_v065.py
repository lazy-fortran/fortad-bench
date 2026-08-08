import csv
import importlib.util
import math
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def load_oracle():
    path = ROOT / 'cases/tapenade-set05/v065_oracle.py'
    spec = importlib.util.spec_from_file_location('tapenade_set05_v065_oracle', path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class V065PromotionTests(unittest.TestCase):
    def test_result_records_all_independent_gates(self):
        report = (ROOT / 'cases/tapenade-set05/v065_result.txt').read_text()
        for marker in ('tapenade_generation: parser=0 tangent=0 reverse=0',
                       'fortad_transformation: forward=0 reverse=0',
                       'harness_status: pass', 'oracle_status: pass',
                       'upstream_sha256:', 'fresh_tapenade_sha256:'):
            self.assertIn(marker, report)

    def test_ledger_closes_only_the_selected_row(self):
        with (ROOT / 'docs/corpora/tapenade-status.csv').open(newline='') as stream:
            rows = {row['path']: row for row in csv.DictReader(stream)}
        row = rows['nonRegressions/set05/v065']
        self.assertEqual(row['status'], 'runnable-ported')
        self.assertEqual(row['entry_point'], 'LIB::mppsum_real2(ptab,cst,str)')
        self.assertEqual(row['fortad_result'], 'pass-forward-reverse-transform-strict-compile-runtime')
        self.assertIn('pass-fresh-parser', row['tapenade_result'])
        self.assertEqual(rows['nonRegressions/set05/v066']['status'], 'unsupported-invalid-upstream-fortran')

    def test_manifest_pins_source_modes_and_passive_boundary(self):
        manifest = (ROOT / 'cases/tapenade-set05/v065_manifest.toml').read_text()
        self.assertIn("upstream_entry_point = 'LIB::mppsum_real2(ptab,cst,str)'", manifest)
        self.assertIn("upstream_revision = 'e59864cab441d4175df75383b3ff58c3dcd26df9'", manifest)
        self.assertIn("modes = ['parser', 'forward', 'reverse']", manifest)
        self.assertIn('cst is passive', manifest)
        self.assertIn('not presented as a repaired upstream source', manifest)

    def test_independent_vector_oracle_has_fd_and_adjoint_identity(self):
        oracle = load_oracle()
        ptab = [0.3 * i - 1.0 for i in range(10)]
        direction = [(-0.2) ** i for i in range(10)]
        cst = 1.7
        epsilon = 1.0e-6
        tangent = oracle.jvp(direction, cst)
        plus = oracle.primal([x + epsilon * d for x, d in zip(ptab, direction)], cst)
        minus = oracle.primal([x - epsilon * d for x, d in zip(ptab, direction)], cst)
        finite_difference = [(a - b) / (2.0 * epsilon) for a, b in zip(plus, minus)]
        self.assertTrue(all(math.isclose(a, b, rel_tol=1.0e-9, abs_tol=1.0e-9)
                            for a, b in zip(tangent, finite_difference)))
        seed = [0.1 * i - 0.4 for i in range(1, 11)]
        cotangent = oracle.vjp(cst, seed)
        self.assertTrue(math.isclose(oracle.dot(cotangent, direction),
                                     oracle.dot(seed, tangent),
                                     rel_tol=1.0e-12, abs_tol=1.0e-12))


if __name__ == '__main__':
    unittest.main()
