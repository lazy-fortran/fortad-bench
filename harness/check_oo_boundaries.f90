program check_oo_boundaries
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use abstract_deferred_refusal_kernel, only: model_t, evaluate_deferred, &
        make_model, destroy_model
    use polymorphic_ownership_refusal_kernel, only: holder_t, replace_holder, &
        clear_holder, evaluate_owned
    use callback_context_refusal_kernel, only: set_linear, set_quadratic, &
        clear_callback, evaluate_callback
    implicit none

    real(dp), parameter :: eps = 1.0e-6_dp
    real(dp) :: x, x_plus, x_minus, fd
    class(model_t), allocatable :: deferred_model
    type(holder_t) :: holder

    x = 0.7_dp
    call make_model(1, 2.25_dp, 0.0_dp, -0.5_dp, deferred_model)
    call require_close("deferred affine", evaluate_deferred(deferred_model, x), &
        2.25_dp*x - 0.5_dp, 1.0e-13_dp)
    x_plus = evaluate_deferred(deferred_model, x + eps)
    x_minus = evaluate_deferred(deferred_model, x - eps)
    fd = (x_plus - x_minus)/(2.0_dp*eps)
    call require_close("deferred affine finite difference", fd, 2.25_dp, 1.0e-8_dp)
    call destroy_model(deferred_model)

    call make_model(2, -0.8_dp, 1.6_dp, 0.3_dp, deferred_model)
    call require_close("deferred square", evaluate_deferred(deferred_model, x), &
        1.6_dp*x*x - 0.8_dp*x + 0.3_dp, 1.0e-13_dp)
    x_plus = evaluate_deferred(deferred_model, x + eps)
    x_minus = evaluate_deferred(deferred_model, x - eps)
    fd = (x_plus - x_minus)/(2.0_dp*eps)
    call require_close("deferred square finite difference", fd, &
        3.2_dp*x - 0.8_dp, 1.0e-8_dp)
    call destroy_model(deferred_model)

    call replace_holder(holder, 1, 1.75_dp, 0.0_dp, -0.25_dp)
    call require_close("owned linear", evaluate_owned(holder, x), &
        1.75_dp*x - 0.25_dp + 1.0_dp, 1.0e-13_dp)
    x_plus = evaluate_owned(holder, x + eps)
    x_minus = evaluate_owned(holder, x - eps)
    fd = (x_plus - x_minus)/(2.0_dp*eps)
    call require_close("owned linear finite difference", fd, 1.75_dp, 1.0e-8_dp)
    call replace_holder(holder, 2, -0.4_dp, 1.2_dp, 0.1_dp)
    call require_close("owned quadratic", evaluate_owned(holder, x), &
        1.2_dp*x*x - 0.4_dp*x + 0.1_dp + 2.0_dp, 1.0e-13_dp)
    x_plus = evaluate_owned(holder, x + eps)
    x_minus = evaluate_owned(holder, x - eps)
    fd = (x_plus - x_minus)/(2.0_dp*eps)
    call require_close("owned quadratic finite difference", fd, &
        2.4_dp*x - 0.4_dp, 1.0e-8_dp)
    call clear_holder(holder)

    call set_linear(2.5_dp)
    call require_close("callback linear", evaluate_callback(x), 2.5_dp*x, 1.0e-13_dp)
    x_plus = evaluate_callback(x + eps)
    x_minus = evaluate_callback(x - eps)
    fd = (x_plus - x_minus)/(2.0_dp*eps)
    call require_close("callback linear finite difference", fd, 2.5_dp, 1.0e-8_dp)
    call set_quadratic(-1.2_dp, 0.8_dp)
    call require_close("callback quadratic", evaluate_callback(x), &
        -1.2_dp*x*x + 0.8_dp*x, 1.0e-13_dp)
    x_plus = evaluate_callback(x + eps)
    x_minus = evaluate_callback(x - eps)
    fd = (x_plus - x_minus)/(2.0_dp*eps)
    call require_close("callback quadratic finite difference", fd, &
        -2.4_dp*x + 0.8_dp, 1.0e-8_dp)
    call clear_callback()
    call require_close("callback null path", evaluate_callback(x), -99.0_dp, 1.0e-13_dp)

    print '(a)', "PASS: abstract deferred, ownership, and callback primal oracles"

contains

    subroutine require_close(label, actual, expected, tolerance)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected, tolerance

        if (abs(actual - expected) > tolerance) then
            print '(a,2es24.16)', "FAIL: "//trim(label)//" got/expected=", &
                actual, expected
            error stop 1
        end if
    end subroutine require_close

end program check_oo_boundaries
