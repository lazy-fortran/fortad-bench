module tapenade_set03_ht13_hand
    implicit none
contains
    subroutine ht13_hand_jvp(x, x_d, y, y_d)
        real, intent(in) :: x, x_d
        real, intent(out) :: y, y_d

        y = x * x
        y_d = 2.0 * x * x_d
    end subroutine ht13_hand_jvp

    subroutine ht13_hand_vjp(x, y_b, x_b)
        real, intent(in) :: x, y_b
        real, intent(out) :: x_b

        x_b = 2.0 * x * y_b
    end subroutine ht13_hand_vjp
end module tapenade_set03_ht13_hand
