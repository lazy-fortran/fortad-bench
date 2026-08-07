from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_v054_contract_records_fresh_generation_and_independent_oracle():
    report = (ROOT / "results/tapenade_set05_v054_validation.txt").read_text()
    assert "entry_point: f_vector(x)" in report
    assert "tapenade_generation: parser=0 tangent=0 reverse=0" in report
    assert "fortad_generated_strict_compile: jvp=0 vjp=0" in report
    assert "oracle_status: pass" in report


def test_v054_manifest_keeps_elemental_boundary_explicit():
    notes = (ROOT / "cases/tapenade-set05/tranche-v054.md").read_text()
    assert "elemental companion" in notes
    assert "strict purity contract" in notes
