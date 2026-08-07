import importlib.util
from pathlib import Path


SPEC = importlib.util.spec_from_file_location(
    "shard3_oracle", Path(__file__).with_name("oracle.py")
)
assert SPEC and SPEC.loader
oracle = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(oracle)


def test_v137_hand_matches_finite_difference():
    x, y, dx, dy = 0.7, -1.3, 0.4, -0.2
    hand = oracle.jvp_v137(x, y, dx, dy)
    eps = 1.0e-5
    finite = (
        oracle.primal_v137(x + eps * dx, y + eps * dy)
        - oracle.primal_v137(x - eps * dx, y - eps * dy)
    ) / (2.0 * eps)
    assert abs(hand - finite) < 1.0e-8


def test_v137_adjoint_identity():
    x, y, dx, dy, seed = 0.7, -1.3, 0.4, -0.2, -0.6
    jvp = oracle.jvp_v137(x, y, dx, dy)
    gx, gy = oracle.vjp_v137(x, y, seed)
    assert abs(seed * jvp - (gx * dx + gy * dy)) < 1.0e-12


def test_v125_hand_matches_finite_difference():
    values = (0.7, -1.3, 2.1, -0.8)
    direction = (0.4, -0.2, 0.3, -0.5)
    hand = oracle.jvp_v125(*values, *direction)
    eps = 1.0e-5
    finite = (
        oracle.primal_v125(*(a + eps * da for a, da in zip(values, direction)))
        - oracle.primal_v125(*(a - eps * da for a, da in zip(values, direction)))
    ) / (2.0 * eps)
    assert abs(hand - finite) < 1.0e-8


def test_v125_adjoint_identity():
    values = (0.7, -1.3, 2.1, -0.8)
    direction = (0.4, -0.2, 0.3, -0.5)
    seed = -0.6
    jvp = oracle.jvp_v125(*values, *direction)
    gradient = oracle.vjp_v125(*values, seed)
    assert abs(seed * jvp - sum(a * b for a, b in zip(gradient, direction))) < 1.0e-12


if __name__ == "__main__":
    for check in (
        test_v137_hand_matches_finite_difference,
        test_v137_adjoint_identity,
        test_v125_hand_matches_finite_difference,
        test_v125_adjoint_identity,
    ):
        check()
    print("oracle_status: pass")
