"""Check that preserved exact-source recorders load from their case paths."""

import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class ExactRecorderImports(unittest.TestCase):
    def test_recorders_import(self):
        recorders = sorted((ROOT / "cases/tapenade-exact").glob("*/record.py"))
        self.assertTrue(recorders)
        for recorder in recorders:
            with self.subTest(case=recorder.parent.name):
                result = subprocess.run(
                    [
                        sys.executable,
                        "-c",
                        "import runpy, sys; runpy.run_path(sys.argv[1], "
                        "run_name='recorder_import_check')",
                        str(recorder),
                    ],
                    cwd=ROOT,
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
