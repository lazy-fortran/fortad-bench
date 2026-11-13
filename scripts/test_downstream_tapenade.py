#!/usr/bin/env python3
"""Behavioral checks for the downstream reverse-product experiment."""

from __future__ import annotations

from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

import downstream_tapenade as experiment


class ResultContractTest(unittest.TestCase):
    def test_only_complete_finite_trials_count(self):
        record = experiment.parse_result("RESULT 0.06 32 7.1 2e-9 1.0\n", 0.05)
        self.assertEqual(record["repetitions"], 32)
        for text in ("RESULT 0.04 32 7.1 0 1", "RESULT 0.06 0 7.1 0 1",
                     "RESULT 0.06 32 nan 0 1", "RESULT 0.06 32 7.1 1e-3 1",
                     "RESULT 0.06 32 7.1 0", "RESULT 0.06 32 7.1 0 1\nRESULT 1 1 1 0 1"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                experiment.parse_result(text, 0.05)

    def test_inventory_tracks_the_existing_comparison_scope(self):
        root = Path(__file__).resolve().parent.parent
        cases = experiment.inventory(root, ["fortnum", "fortfem"])
        self.assertEqual(len(cases), 59)
        self.assertEqual(sum(suite == "fortnum" for suite, _, _ in cases), 17)
        self.assertNotIn("cartesian_to_toroidal", {name for _, name, _ in cases})
        self.assertEqual(dict((name, arity) for _, name, arity in cases)["det2"], 4)

    def test_fortnum_comparison_keeps_componentwise_accuracy(self):
        gradients = {"fortad-grad": [1e12, 1.0], "tapenade": [1e12, 2.0]}
        error, tolerance = experiment.compare_gradients("fortnum", "det2", gradients)
        self.assertGreater(error, tolerance)
        self.assertEqual(error, 1.0)

    def test_successful_launcher_does_not_leave_its_child_running(self):
        with tempfile.TemporaryDirectory() as raw:
            work = Path(raw)
            command = [sys.executable, "-c", "import subprocess,sys,pathlib; "
                       "p=subprocess.Popen([sys.executable,'-c','import time; time.sleep(60)'], "
                       "stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); "
                       "pathlib.Path('child.pid').write_text(str(p.pid))"]
            experiment.run(command, work, work / "run.log", 5)
            pid = int((work / "child.pid").read_text())
            for _ in range(100):
                proc = subprocess.run(["ps", "-o", "state=", "-p", str(pid)], capture_output=True, text=True)
                if not proc.stdout.strip() or proc.stdout.strip().startswith("Z"):
                    break
                time.sleep(0.01)
            else:
                self.fail(f"launcher child {pid} remains running")


@unittest.skipUnless(shutil.which("gfortran"), "native oracle check requires gfortran")
class NativeOracleTest(unittest.TestCase):
    def compile(self, work: Path, coefficient: int, engine: str = "fortad-grad",
                wrong_primal: bool = False) -> Path:
        (work / "measure.f90").write_text(experiment.driver("square", 1, "fortnum", engine))
        (work / "square.f90").write_text("""subroutine square(n, z, y)
  use, intrinsic :: iso_fortran_env, only: dp => real64
  integer, intent(in) :: n
  real(dp), intent(in) :: z(n)
  real(dp), intent(out) :: y
  y = sum(z*z)
end subroutine
""")
        if engine == "enzyme":
            routine = f"""subroutine square_vjp_enzyme(n, z, g, y, seed) bind(C)
  use, intrinsic :: iso_c_binding
  integer(c_int), value :: n
  real(c_double) :: z(n), g(n), y, seed
  y = {"0.0_c_double" if wrong_primal else "sum(z*z)"}
  g = {coefficient}*z*seed
end subroutine
"""
        else:
            routine = f"""subroutine square_grad(n, z, seed, g)
  use, intrinsic :: iso_fortran_env, only: dp => real64
  integer, intent(in) :: n
  real(dp), intent(in) :: z(n), seed
  real(dp), intent(out) :: g(n)
  g = {coefficient}*z*seed
end subroutine
"""
        (work / "derivative.f90").write_text(routine)
        command = ["gfortran", "-O2", "-fcheck=all", "measure.f90", "square.f90", "derivative.f90", "-o", "measure"]
        subprocess.run(command, cwd=work, check=True, capture_output=True, text=True)
        return work / "measure"

    def test_native_driver_measures_valid_derivative_and_saves_full_gradient(self):
        with tempfile.TemporaryDirectory() as raw:
            work = Path(raw)
            executable = self.compile(work, 2)
            proc = subprocess.run([str(executable), "31", "0.001"], cwd=work,
                                  capture_output=True, text=True, timeout=10)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            values = experiment.parse_result(proc.stdout, 0.001)
            self.assertGreaterEqual(values["seconds"], 0.001)
            self.assertEqual((work / "gradient.bin").stat().st_size, 31*8)

    def test_native_oracle_rejects_planted_wrong_derivative_before_timing(self):
        with tempfile.TemporaryDirectory() as raw:
            work = Path(raw)
            executable = self.compile(work, 3)
            proc = subprocess.run([str(executable), "31", "0.001"], cwd=work,
                                  capture_output=True, text=True, timeout=10)
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn("FD_FAILURE", proc.stdout)
            self.assertNotIn("RESULT ", proc.stdout)
            self.assertFalse((work / "gradient.bin").exists())

    def test_c_binding_passes_batch_size_by_value(self):
        with tempfile.TemporaryDirectory() as raw:
            work = Path(raw)
            executable = self.compile(work, 2, "enzyme")
            proc = subprocess.run([str(executable), "31", "0.001", "check"], cwd=work,
                                  capture_output=True, text=True, timeout=10)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            self.assertEqual((work / "gradient.bin").stat().st_size, 31*8)

    def test_correct_gradient_does_not_hide_a_wrong_returned_primal(self):
        with tempfile.TemporaryDirectory() as raw:
            work = Path(raw)
            executable = self.compile(work, 2, "enzyme", wrong_primal=True)
            proc = subprocess.run([str(executable), "31", "0.001", "check"], cwd=work,
                                  capture_output=True, text=True, timeout=10)
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn("primal mismatch", proc.stderr)
            self.assertFalse((work / "gradient.bin").exists())


if __name__ == "__main__":
    unittest.main()
