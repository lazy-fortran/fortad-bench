module callback_context_refusal_kernel
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: set_linear, set_quadratic, clear_callback, evaluate_callback

    type :: scale_context_t
        real(dp) :: scale = 1.0_dp
    end type scale_context_t

    type :: quadratic_context_t
        real(dp) :: a = 0.0_dp
        real(dp) :: b = 0.0_dp
    end type quadratic_context_t

    abstract interface
        pure function callback_interface(x, context) result(y)
            import :: dp
            real(dp), intent(in) :: x
            class(*), intent(in) :: context
            real(dp) :: y
        end function callback_interface
    end interface

    procedure(callback_interface), pointer :: selected_callback => null()
    class(*), allocatable :: selected_context

contains

    subroutine set_linear(scale)
        real(dp), intent(in) :: scale

        if (allocated(selected_context)) deallocate(selected_context)
        allocate(scale_context_t :: selected_context)
        select type (selected_context)
        type is (scale_context_t)
            selected_context%scale = scale
        end select
        selected_callback => linear_callback
    end subroutine set_linear

    subroutine set_quadratic(a, b)
        real(dp), intent(in) :: a, b

        if (allocated(selected_context)) deallocate(selected_context)
        allocate(quadratic_context_t :: selected_context)
        select type (selected_context)
        type is (quadratic_context_t)
            selected_context%a = a
            selected_context%b = b
        end select
        selected_callback => quadratic_callback
    end subroutine set_quadratic

    subroutine clear_callback()
        nullify(selected_callback)
        if (allocated(selected_context)) deallocate(selected_context)
    end subroutine clear_callback

    function evaluate_callback(x) result(y)
        real(dp), intent(in) :: x
        real(dp) :: y

        if (.not. associated(selected_callback)) then
            y = -99.0_dp
            return
        end if
        y = selected_callback(x, selected_context)
    end function evaluate_callback

    pure function linear_callback(x, context) result(y)
        real(dp), intent(in) :: x
        class(*), intent(in) :: context
        real(dp) :: y

        select type (context)
        type is (scale_context_t)
            y = context%scale*x
        class default
            error stop "wrong linear callback context"
        end select
    end function linear_callback

    pure function quadratic_callback(x, context) result(y)
        real(dp), intent(in) :: x
        class(*), intent(in) :: context
        real(dp) :: y

        select type (context)
        type is (quadratic_context_t)
            y = context%a*x*x + context%b*x
        class default
            error stop "wrong quadratic callback context"
        end select
    end function quadratic_callback

end module callback_context_refusal_kernel
