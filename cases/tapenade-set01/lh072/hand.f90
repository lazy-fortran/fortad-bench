! Independent formulas for the bounded lh072 callback specialization.
module tapenade_set01_lh072_hand
    implicit none
contains
    subroutine hand_value(a_in, b_in, a_out, b_out, a_sum)
        real, intent(in) :: a_in(10), b_in(10)
        real, intent(out) :: a_out(10), b_out(10)
        real, intent(out) :: a_sum
        integer :: i

        do i = 1, 10
            a_out(i) = b_in(i) * a_in(i)
            b_out(i) = b_in(i)
        end do
        a_sum = sum(a_out)
        b_out(4) = b_in(4) * b_in(4)
        b_out(10) = b_in(10) * b_in(10)
    end subroutine hand_value

    subroutine hand_jvp(a_in, b_in, a_in_d, b_in_d, a_out, b_out, a_sum, &
                        a_out_d, b_out_d, a_sum_d)
        real, intent(in) :: a_in(10), b_in(10)
        real, intent(in) :: a_in_d(10), b_in_d(10)
        real, intent(out) :: a_out(10), b_out(10)
        real, intent(out) :: a_out_d(10), b_out_d(10)
        real, intent(out) :: a_sum, a_sum_d
        integer :: i

        do i = 1, 10
            a_out(i) = b_in(i) * a_in(i)
            a_out_d(i) = b_in_d(i) * a_in(i) + b_in(i) * a_in_d(i)
            b_out(i) = b_in(i)
            b_out_d(i) = b_in_d(i)
        end do
        a_sum = sum(a_out)
        a_sum_d = sum(a_out_d)
        b_out(4) = b_in(4) * b_in(4)
        b_out_d(4) = 2.0 * b_in(4) * b_in_d(4)
        b_out(10) = b_in(10) * b_in(10)
        b_out_d(10) = 2.0 * b_in(10) * b_in_d(10)
    end subroutine hand_jvp

    subroutine hand_reverse_a(a_in, b_in, a_sum_b, a_in_b, b_in_b)
        real, intent(in) :: a_in(10), b_in(10), a_sum_b
        real, intent(out) :: a_in_b(10), b_in_b(10)
        integer :: i

        do i = 1, 10
            a_in_b(i) = a_sum_b * b_in(i)
            b_in_b(i) = a_sum_b * a_in(i)
        end do
    end subroutine hand_reverse_a
end module tapenade_set01_lh072_hand
