module dynamic_callback_kernel
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: evaluate_dynamic, select_linear_callback, &
        select_quadratic_callback

    abstract interface
        pure function callback_interface(x) result(y)
            import dp
            real(dp), intent(in) :: x
            real(dp) :: y
        end function callback_interface
    end interface

    procedure(callback_interface), pointer :: selected_callback => null()

contains

    function evaluate_dynamic(x) result(y)
        real(dp), intent(in) :: x
        real(dp) :: y

        y = selected_callback(x)
    end function evaluate_dynamic

    subroutine select_linear_callback()
        selected_callback => linear_callback
    end subroutine select_linear_callback

    subroutine select_quadratic_callback()
        selected_callback => quadratic_callback
    end subroutine select_quadratic_callback

    pure function linear_callback(x) result(y)
        real(dp), intent(in) :: x
        real(dp) :: y

        y = 2.5_dp*x - 0.75_dp
    end function linear_callback

    pure function quadratic_callback(x) result(y)
        real(dp), intent(in) :: x
        real(dp) :: y

        y = -1.2_dp*x*x + 0.8_dp*x
    end function quadratic_callback
end module dynamic_callback_kernel
