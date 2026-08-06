program check_dynamic_callback_primal
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use dynamic_callback_kernel, only: evaluate_dynamic, &
        select_linear_callback, select_quadratic_callback
    implicit none

    real(dp), parameter :: tolerance = 1.0e-13_dp

    call select_linear_callback()
    call check_close(evaluate_dynamic(1.25_dp), 2.375_dp)
    call select_quadratic_callback()
    call check_close(evaluate_dynamic(1.25_dp), -0.875_dp)
    print '(a)', "PASS: procedure-pointer primal dispatches to both callbacks"

contains

    subroutine check_close(actual, expected)
        real(dp), intent(in) :: actual, expected

        if (abs(actual - expected) > tolerance) error stop 1
    end subroutine check_close
end program check_dynamic_callback_primal
