"""Independent metadata checks for the set04 lh110 validation artifact."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    result = (ROOT / "results/tapenade_set04_lh110_validation.txt").read_text()
    manifest = (ROOT / "cases/tapenade-set04/tranche-a-lh110-manifest.toml").read_text()
    notes = (ROOT / "cases/tapenade-set04/tranche-a-lh110.md").read_text()

    required_result = (
        "tapenade_commit: e59864cab441d4175df75383b3ff58c3dcd26df9",
        "oracle_status: pass",
        "upstream-program.status 0",
        "upstream-program_d.status 0",
        "tapenade_oracle:",
        "independent_oracle:",
    )
    for marker in required_result:
        assert marker in result, marker
    for marker in (
        'case = "lh110"',
        'status = "runnable-ported"',
        'independents = ["x"]',
        'dependents = ["y"]',
        'program.f90',
    ):
        assert marker in manifest, marker
    assert "TARGET" in notes and "POINTER" in notes
    print("set04 lh110 metadata oracle: pass")


if __name__ == "__main__":
    main()
