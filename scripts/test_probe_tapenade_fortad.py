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
import os

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
log = os.environ.get("FAKE_CALL_LOG")
if log:
    with open(log, "a", encoding="utf-8") as stream:
        stream.write("called\\n")
print("fake tool completed")
"""


class ProbeWorkflowTest(unittest.TestCase):
    def test_queue_shards_partition_rows_independently_of_priority_rank(self):
        rows = [
            {"path": f"case/{index}", "queue_rank": 10 if index < 3 else 50}
            for index in range(11)
        ]
        shards = [
            PROBE._select_queue_rows(rows, index, 4)
            for index in range(4)
        ]
        flattened = [row["path"] for shard in shards for row in shard]
        self.assertCountEqual(flattened, [row["path"] for row in rows])
        self.assertEqual(len(flattened), len(set(flattened)))
        self.assertEqual(
            [row["path"] for row in PROBE._select_queue_rows(rows, 0, 4)],
            ["case/0", "case/4", "case/8"],
        )

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
            self.assertEqual(record["entry_point_candidates"], ["one", "two"])
            self.assertEqual(record["probes"], {})

    def test_file_path_case_with_no_hint_is_retained_as_ambiguous(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            upstream = root / "upstream" / "tapenade"
            source = upstream / "openmp" / "examples" / "standalone.f90"
            source.parent.mkdir(parents=True)
            source.write_text("subroutine work(x)\nend\n")
            static = root / "tapenade-static.jsonl"
            static.write_text(json.dumps({
                "path": "openmp/examples/standalone.f90",
                "entry_point_hints": [],
            }) + "\n")
            with patch.object(PROBE, "UPSTREAM", upstream), patch.object(PROBE, "STATIC", static):
                specs = PROBE.specs_from_case("openmp/examples/standalone.f90", all_entries=True)
                record = PROBE.probe_spec(specs[0], root / "results", None, None)
            self.assertEqual(len(specs), 1)
            self.assertEqual(specs[0].case_path, "openmp/examples")
            self.assertEqual(specs[0].source, "openmp/examples/standalone.f90")
            self.assertEqual(record["status"], "ambiguous-entry-point")
            self.assertEqual(record["entry_point_candidates"], [])
            self.assertEqual(record["probes"], {})

    def test_all_entry_discovery_expands_canonical_source_procedures(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            upstream, static, _tool = self._fixture(
                root,
                [
                    {"kind": "subroutine", "name": "one", "source": "nonRegressions/set01/fixture/program.f"},
                    {"kind": "subroutine", "name": "one_b", "source": "nonRegressions/set01/fixture/program.f"},
                    {"kind": "subroutine", "name": "two", "source": "nonRegressions/set01/fixture/program.f"},
                    {"kind": "program", "name": "driver", "source": "nonRegressions/set01/fixture/program.f"},
                ],
            )
            with patch.object(PROBE, "UPSTREAM", upstream), patch.object(PROBE, "STATIC", static):
                specs = PROBE.specs_from_case("nonRegressions/set01/fixture", all_entries=True)
            self.assertEqual([spec.entry_point for spec in specs], ["one", "two"])

    def test_all_entry_discovery_keeps_no_hint_case_as_explicit_refusal(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            upstream, static, _tool = self._fixture(root, [])
            with patch.object(PROBE, "UPSTREAM", upstream), patch.object(PROBE, "STATIC", static):
                specs = PROBE.specs_from_case("nonRegressions/set01/fixture", all_entries=True)
            self.assertEqual(len(specs), 1)
            self.assertIsNone(specs[0].entry_point)

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

    def test_source_selection_prefers_a_primal_over_derivative_named_sources(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            upstream = root / "upstream" / "tapenade"
            case = upstream / "nonRegressions" / "set01" / "fixture"
            case.mkdir(parents=True)
            (case / "work_d.f90").write_text("subroutine work_d(x)\nend\n")
            (case / "work.f90").write_text("subroutine work(x)\nend\n")
            static = root / "tapenade-static.jsonl"
            static.write_text(
                json.dumps({
                    "path": "nonRegressions/set01/fixture",
                    "entry_point_hints": [{
                        "kind": "subroutine",
                        "name": "work",
                        "source": "nonRegressions/set01/fixture/work.f90",
                    }],
                }) + "\n"
            )
            with patch.object(PROBE, "UPSTREAM", upstream), patch.object(PROBE, "STATIC", static):
                spec = PROBE.spec_from_case("nonRegressions/set01/fixture")
            self.assertEqual(spec.source, "nonRegressions/set01/fixture/work.f90")
            self.assertEqual(spec.source_candidates, (
                "nonRegressions/set01/fixture/work.f90",
                "nonRegressions/set01/fixture/work_d.f90",
            ))

    def test_pure_fortran_shards_resume_and_merge_without_queue_rank_skew(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            upstream = root / "upstream" / "tapenade"
            static = root / "tapenade-static.jsonl"
            queue = root / "queue.jsonl"
            tool = root / "fake-tool.py"
            tool.write_text(FAKE_TOOL)
            tool.chmod(tool.stat().st_mode | stat.S_IXUSR)
            rows = []
            static_rows = []
            for name, language in (("case-c", "fortran"), ("case-a", "fortran"), ("case-b", "c|fortran"), ("case-d", "fortran")):
                case = upstream / "nonRegressions" / "set01" / name
                case.mkdir(parents=True)
                source = f"nonRegressions/set01/{name}/work.f90"
                (case / "work.f90").write_text("subroutine work(x)\nend\n")
                rows.append({
                    "component": "fixture",
                    "path": f"nonRegressions/set01/{name}",
                    "language": language,
                    "queue_category": "runnable-procedure-candidate",
                    "queue_rank": 50,
                })
                static_rows.append({
                    "path": f"nonRegressions/set01/{name}",
                    "entry_point_hints": [{"kind": "subroutine", "name": "work", "source": source}],
                })
            queue.write_text("".join(json.dumps(row) + "\n" for row in rows))
            static.write_text("".join(json.dumps(row) + "\n" for row in static_rows))
            log = root / "calls.log"
            with patch.object(PROBE, "UPSTREAM", upstream), patch.object(PROBE, "STATIC", static), patch.dict("os.environ", {"FAKE_CALL_LOG": str(log)}):
                first_dir = root / "shards"
                self.assertEqual(PROBE.main([
                    "--queue", "--pure-fortran", "--queue-file", str(queue),
                    "--shard-count", "2", "--shard-index", "0", "--jobs", "2",
                    "--tapenade", str(tool), "--fortad", str(tool),
                    "--result-dir", str(first_dir),
                ]), 0)
                shard0 = first_dir / "results.shard-0000-of-0002.jsonl"
                self.assertTrue(shard0.is_file())
                calls_after_first = len(log.read_text().splitlines())
                self.assertEqual(calls_after_first, 12)

                self.assertEqual(PROBE.main([
                    "--queue", "--pure-fortran", "--queue-file", str(queue),
                    "--shard-count", "2", "--shard-index", "0", "--jobs", "2",
                    "--resume", "--tapenade", str(tool), "--fortad", str(tool),
                    "--result-dir", str(first_dir),
                ]), 0)
                self.assertEqual(len(log.read_text().splitlines()), calls_after_first)

                second_dir = root / "second"
                self.assertEqual(PROBE.main([
                    "--queue", "--pure-fortran", "--queue-file", str(queue),
                    "--shard-count", "2", "--shard-index", "1", "--jobs", "1",
                    "--tapenade", str(tool), "--fortad", str(tool),
                    "--result-dir", str(second_dir),
                ]), 0)
                shard1 = second_dir / "results.shard-0001-of-0002.jsonl"
                self.assertTrue(shard1.is_file())

                merge_dir = root / "merged"
                self.assertEqual(PROBE.main([
                    "--queue", "--pure-fortran", "--queue-file", str(queue),
                    "--merge-input", str(shard0), "--merge-input", str(shard1),
                    "--tapenade", str(tool), "--fortad", str(tool),
                    "--result-dir", str(merge_dir),
                ]), 0)

            def keys(path: Path) -> list[str]:
                return [json.loads(line)["candidate_key"] for line in path.read_text().splitlines()]

            pure_keys = sorted(
                f"fixture:nonRegressions/set01/{name}"
                for name in ("case-c", "case-a", "case-d")
            )
            expected0 = pure_keys[0::2]
            expected1 = pure_keys[1::2]
            self.assertEqual(keys(shard0), expected0)
            self.assertEqual(keys(shard1), expected1)
            self.assertEqual(keys(merge_dir / "results.jsonl"), pure_keys)


if __name__ == "__main__":
    unittest.main()
