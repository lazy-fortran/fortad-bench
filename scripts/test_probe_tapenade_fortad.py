#!/usr/bin/env python3
"""Behavioral tests for the manifest/queue probe workflow."""

from __future__ import annotations

import importlib.util
import json
import stat
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("probe_tapenade_fortad.py")
SPEC = importlib.util.spec_from_file_location("probe_tapenade_fortad", SCRIPT)
assert SPEC and SPEC.loader
PROBE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = PROBE
SPEC.loader.exec_module(PROBE)


FAKE_TOOL = """#!/usr/bin/env python3
import pathlib
import sys

args = sys.argv[1:]
out = pathlib.Path(args[args.index("-O") + 1])
out.mkdir(parents=True, exist_ok=True)
if "-p" in args:
    suffix = "p"
elif "-d" in args:
    suffix = "d"
else:
    suffix = "b"
(out / ("probe_" + suffix + ".f90")).write_text("! independent fake tool output\\n")
print("fake tool completed")
"""


class ProbeWorkflowTest(unittest.TestCase):
    def _fixture(self, root: Path, hints: list[dict[str, str]]) -> tuple[Path, Path, Path]:
        upstream = root / "upstream" / "tapenade"
        case = upstream / "nonRegressions" / "set01" / "fixture"
        case.mkdir(parents=True)
        (case / "program.f").write_text(
            "      subroutine work(x,y)\n      y = x*x\n      end\n"
        )
        static = root / "tapenade-static.jsonl"
        static.write_text(
            json.dumps(
                {
                    "path": "nonRegressions/set01/fixture",
                    "entry_point_hints": hints,
                }
            )
            + "\n"
        )
        tool = root / "fake-tool.py"
        tool.write_text(FAKE_TOOL)
        tool.chmod(tool.stat().st_mode | stat.S_IXUSR)
        return upstream, static, tool

    def test_ambiguous_discovery_never_runs_a_transform(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            upstream, static, tool = self._fixture(
                root,
                [
                    {"kind": "subroutine", "name": "one", "source": "nonRegressions/set01/fixture/program.f"},
                    {"kind": "subroutine", "name": "two", "source": "nonRegressions/set01/fixture/program.f"},
                ],
            )
            with patch.object(PROBE, "UPSTREAM", upstream), patch.object(PROBE, "STATIC", static):
                spec = PROBE.spec_from_case("nonRegressions/set01/fixture")
                record = PROBE.probe_spec(spec, root / "results", tool, tool)
            self.assertIsNone(spec.entry_point)
            self.assertEqual(record["status"], "ambiguous-entry-point")
            self.assertEqual(record["probes"], {})

    def test_explicit_selection_runs_all_three_tools_and_records_products(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            upstream, static, tool = self._fixture(
                root,
                [
                    {"kind": "subroutine", "name": "work", "source": "nonRegressions/set01/fixture/program.f"},
                ],
            )
            with patch.object(PROBE, "UPSTREAM", upstream), patch.object(PROBE, "STATIC", static):
                spec = PROBE.spec_from_case("nonRegressions/set01/fixture")
                record = PROBE.probe_spec(spec, root / "results", tool, tool)
            self.assertEqual(record["status"], "pass")
            self.assertEqual(record["entry_point"], "work")
            self.assertEqual(set(record["probes"]), {"parser", "forward", "reverse"})
            for mode in record["probes"]:
                for engine in ("tapenade", "fortad"):
                    result = record["probes"][mode][engine]
                    self.assertEqual(result["status"], "pass")
                    self.assertTrue(result["generated"])
                    self.assertIn("-root", result["command"])
                    diagnostics = result["diagnostics"]
                    self.assertTrue(
                        (root / "results" / mode / engine / diagnostics["stdout"]).is_file()
                    )
            self.assertTrue((root / "results" / "parser" / "tapenade" / "probe_p.f90").is_file())

    def test_manifest_entry_and_explicit_arguments_are_preserved(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            upstream, _static, _tool = self._fixture(root, [])
            manifest = root / "case.toml"
            manifest.write_text(
                'upstream_source = "nonRegressions/set01/fixture/program.f"\n'
                'upstream_entry_point = "work(x y)"\n'
                'independent = ["x"]\n'
                'dependent = "y"\n'
                'modes = ["forward", "reverse"]\n'
            )
            with patch.object(PROBE, "UPSTREAM", upstream):
                spec = PROBE.spec_from_manifest(manifest)
            self.assertEqual(spec.entry_point, "work")
            self.assertEqual(spec.independent, ("x",))
            self.assertEqual(spec.dependent, "y")
            self.assertEqual(spec.modes, ("forward", "reverse"))


if __name__ == "__main__":
    unittest.main()
