"""Check the matrix's generated sources with an actual FortAD executable."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
FORTAD_BIN = os.environ.get("FORTAD_BIN")


@unittest.skipUnless(FORTAD_BIN, "set FORTAD_BIN for the CLI integration check")
@unittest.skipUnless(shutil.which("gfortran"), "gfortran is required for the compiler oracle")
class CompilerMatrixCLI(unittest.TestCase):
    def test_all_three_derivative_forms_compile(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            (root / "cases/compiler_matrix").mkdir(parents=True)
            (root / "fortad/build").mkdir(parents=True)
            shutil.copy2(ROOT / "scripts/check_compilers.sh", root / "scripts")
            shutil.copy2(
                ROOT / "cases/compiler_matrix/primal_plain.f90",
                root / "cases/compiler_matrix",
            )
            shutil.copy2(FORTAD_BIN, root / "fortad/build/fortad")
            # Vendor toolchains may be absent on the host of this CLI check.
            result = subprocess.run(
                ["bash", str(root / "scripts/check_compilers.sh")],
                env={**os.environ, "FORTAD_REPO": str(root / "fortad")},
                capture_output=True,
                text=True,
                timeout=120,
            )
            output = root / "build/compilers"
            for name in ("adjoint", "tangent", "tangent_v"):
                with self.subTest(product=name):
                    source = output / f"{name}.f90"
                    self.assertTrue(source.is_file(), result.stdout + result.stderr)
                    compiled = subprocess.run(
                        ["gfortran", "-std=f2018", "-fsyntax-only", source.name],
                        cwd=output,
                        capture_output=True,
                        text=True,
                    )
                    self.assertEqual(compiled.returncode, 0, compiled.stderr)


if __name__ == "__main__":
    unittest.main()
