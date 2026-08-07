module tapenade_set01_bd01_hand
    implicit none
    private
    public :: hand_value, hand_forward, hand_reverse

contains

    subroutine hand_value(a, b, c, a_out)
        real, intent(in) :: a, b, c
        real, intent(out) :: a_out

        a_out = b * c
    end subroutine hand_value

    subroutine hand_forward(a, b, c, a_d, b_d, c_d, a_out, a_out_d)
        real, intent(in) :: a, b, c, a_d, b_d, c_d
        real, intent(out) :: a_out, a_out_d

        a_out = b * c
        a_out_d = b_d * c + b * c_d
    end subroutine hand_forward

    subroutine hand_reverse(a, b, c, a_b, b_b, c_b, a_out)
        real, intent(in) :: a, b, c, a_b
        real, intent(out) :: b_b, c_b, a_out

        a_out = b * c
        b_b = c * a_b
        c_b = b * a_b
    end subroutine hand_reverse

end module tapenade_set01_bd01_hand
