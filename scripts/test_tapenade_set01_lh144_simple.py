import importlib.util
from pathlib import Path


ROOT = Path(__file__).parents[1]
spec = importlib.util.spec_from_file_location(
    "lh144_oracle", ROOT / "cases/tapenade-set01-lh144-simple/oracle.py"
)
oracle = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(oracle)


def test_independent_oracle_matches_closed_form_directional_derivative():
    x, y, dx, dy = 0.7, 1.2, 0.3, -0.7
    got = oracle.jvp(x, y, dx, dy)
    eps = 1.0e-7
    base = oracle.primal(x, y)
    perturbed = oracle.primal(x + eps * dx, y + eps * dy)
    finite = tuple((a - b) / eps for a, b in zip(perturbed, base))
    assert max(abs(a - b) for a, b in zip(got, finite)) < 5.0e-4


def test_independent_oracle_adjoint_identity():
    x, y = 1.3, -0.8
    dx, dy = 0.3, -0.7
    bx, by = 0.4, -0.9
    j = oracle.jvp(x, y, dx, dy)
    g = oracle.vjp(x, y, bx, by)
    assert abs(bx * j[0] + by * j[1] - (g[0] * dx + g[1] * dy)) < 2.0e-6
