import importlib.util
from pathlib import Path


ROOT = Path(__file__).parents[1]
spec = importlib.util.spec_from_file_location(
    "lh136_oracle", ROOT / "cases/tapenade-set01-lh136-simple/oracle.py"
)
oracle = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(oracle)


def test_lighthouse_oracle_is_finite_at_pinned_point():
    value = oracle.primal((3.7, 0.7, 0.5, 0.5))
    assert all(abs(component) < 100.0 for component in value)


def test_lighthouse_oracle_changes_under_active_perturbation():
    x = (3.7, 0.7, 0.5, 0.5)
    base = oracle.primal(x)
    perturbed = oracle.primal((3.700001, 0.7, 0.5, 0.5))
    assert max(abs(a - b) for a, b in zip(base, perturbed)) > 1.0e-8
