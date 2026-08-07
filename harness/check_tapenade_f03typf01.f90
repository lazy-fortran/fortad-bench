program check_tapenade_f03typf01
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use abstract_deferred_refusal_kernel, only: affine_model_t, square_model_t, &
        evaluate_deferred
    implicit none

    real(dp), parameter :: x = 0.7_dp, eps = 1.0e-6_dp
    real(dp) :: plus, minus, fd
    type(affine_model_t) :: affine
    type(square_model_t) :: square

    affine%slope = 2.25_dp
    affine%bias = -0.5_dp
    call require_close(evaluate_deferred(affine, x), 2.25_dp*x - 0.5_dp, 1.0e-13_dp)
    plus = evaluate_deferred(affine, x + eps)
    minus = evaluate_deferred(affine, x - eps)
    fd = (plus - minus)/(2.0_dp*eps)
    call require_close(fd, 2.25_dp, 1.0e-8_dp)

    square%slope = -0.8_dp
    square%curvature = 1.6_dp
    square%bias = 0.3_dp
    call require_close(evaluate_deferred(square, x), &
        1.6_dp*x*x - 0.8_dp*x + 0.3_dp, 1.0e-13_dp)
    plus = evaluate_deferred(square, x + eps)
    minus = evaluate_deferred(square, x - eps)
    fd = (plus - minus)/(2.0_dp*eps)
    call require_close(fd, 3.2_dp*x - 0.8_dp, 1.0e-8_dp)

    print '(a)', "PASS: Tapenade f03typf01 primal and finite-difference oracle"

contains

    subroutine require_close(actual, expected, tolerance)
        real(dp), intent(in) :: actual, expected, tolerance
        if (abs(actual - expected) > tolerance) error stop 1
    end subroutine require_close

end program check_tapenade_f03typf01
