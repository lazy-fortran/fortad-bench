import csv
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class V060PromotionTests(unittest.TestCase):
    def test_result_records_all_independent_gates(self):
        report = (ROOT / 'cases/tapenade-set05/v060_result.txt').read_text()
        for marker in ('tapenade_generation: parser=0 tangent=0 reverse=0',
                       'fortad_transformation: forward=0 reverse=0',
                       'harness_status: pass', 'oracle_status: pass',
                       'upstream_sha256:', 'fresh_tapenade_sha256:'):
            self.assertIn(marker, report)

    def test_ledger_closes_only_the_selected_row(self):
        with (ROOT / 'docs/corpora/tapenade-status.csv').open(newline='') as stream:
            rows = {row['path']: row for row in csv.DictReader(stream)}
        row = rows['nonRegressions/set05/v060']
        self.assertEqual(row['status'], 'runnable-ported')
        self.assertEqual(row['entry_point'], 'M::func(t,u)')
        self.assertEqual(row['fortad_result'], 'pass-transform-compile-runtime')
        self.assertIn('pass-fresh-parser', row['tapenade_result'])

    def test_manifest_pins_the_source_and_modes(self):
        manifest = (ROOT / 'cases/tapenade-set05/v060_manifest.toml').read_text()
        self.assertIn("upstream_entry_point = 'M::func(t,u)'", manifest)
        self.assertIn("upstream_revision = 'e59864cab441d4175df75383b3ff58c3dcd26df9'", manifest)
        self.assertIn("modes = ['parser', 'forward', 'reverse']", manifest)


if __name__ == '__main__':
    unittest.main()
