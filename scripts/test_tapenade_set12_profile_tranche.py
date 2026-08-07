from pathlib import Path
import importlib.util


ROOT = Path(__file__).parents[1]
spec = importlib.util.spec_from_file_location(
    "profile_tranche_oracle",
    ROOT / "cases/tapenade-set12-profile-tranche/oracle.py",
)
oracle = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(oracle)


def test_independent_oracle():
    oracle.check()


def test_result_records_both_gates():
    result = (ROOT / "results/tapenade_set12_profile_tranche_validation.txt").read_text()
    assert "fortad_profile01: forward-reverse-generated-strict-compile-runtime-pass" in result
    assert "fortad_jlb012: forward-reverse-generated-but-strict-compile-refusal" in result
