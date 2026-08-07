import importlib.util
from pathlib import Path


ROOT = Path(__file__).parents[1]
spec = importlib.util.spec_from_file_location(
    "lh192_oracle", ROOT / "cases/tapenade-set02-lh192-simple/oracle.py"
)
oracle = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(oracle)


def test_checkpoint_dataflow_oracle():
    assert oracle.primal(1.7, 2.0, -0.25, 0.8) == (-0.68, -0.5, 4.25)


def test_checkpoint_dataflow_directional_derivative():
    point = (1.7, 2.0, -0.25, 0.8)
    direction = (0.3, -0.4, 0.2, -0.1)
    eps = 1.0e-7
    base = oracle.primal(*point)
    shifted = oracle.primal(*(p + eps * d for p, d in zip(point, direction)))
    finite = tuple((a - b) / eps for a, b in zip(shifted, base))
    hand = oracle.jvp(*point, *direction)
    assert max(abs(a - b) for a, b in zip(finite, hand)) < 5.0e-5
