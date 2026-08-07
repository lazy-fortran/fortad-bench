module tapenade_set01_lh019_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use tapenade_set01_lh019_case, only: real8_diff
    implicit none
    private

    public :: lh019_hand_jvp, lh019_hand_vjp

contains

    subroutine lh019_hand_jvp(x, x_d, y, y_d, n, output, output_d)
        type(real8_diff), intent(in) :: x, x_d, y, y_d
        integer, intent(in) :: n
        real(dp), intent(out) :: output, output_d

        output = x%v
        output_d = x_d%v
        if (n >= 5) then
            output = x%v*y%v
            output_d = x_d%v*y%v + x%v*y_d%v
        end if
    end subroutine lh019_hand_jvp

    subroutine lh019_hand_vjp(x, y, n, output, output_b, x_b, y_b)
        type(real8_diff), intent(in) :: x, y
        integer, intent(in) :: n
        real(dp), intent(out) :: output
        real(dp), intent(in) :: output_b
        type(real8_diff), intent(out) :: x_b, y_b

        x_b%v = 0.0_dp
        x_b%tag = 0
        y_b%v = 0.0_dp
        y_b%tag = 0
        output = x%v
        if (n >= 5) then
            output = x%v*y%v
            x_b%v = output_b*y%v
            y_b%v = output_b*x%v
        else
            x_b%v = output_b
        end if
    end subroutine lh019_hand_vjp

end module tapenade_set01_lh019_hand
