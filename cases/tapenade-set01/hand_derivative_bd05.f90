module tapenade_set01_bd05_hand
    implicit none
contains
    subroutine bd05_primal(a_in, b_in, c_in, a_out, c_out)
        real, intent(in) :: a_in(10), b_in, c_in
        real, intent(out) :: a_out(10), c_out
        integer :: i

        a_out = a_in
        c_out = c_in
        do i = 1, 10
            a_out(i) = b_in
            c_out = c_out * a_out(i)
        end do
        do i = 1, 10
            c_out = c_out * a_out(i)
        end do
    end subroutine bd05_primal

    subroutine bd05_hand_jvp(a_in, a_d, b_in, b_d, c_in, c_d, a_out, &
            a_out_d, c_out, c_out_d)
        real, intent(in) :: a_in(10), a_d(10), b_in, b_d, c_in, c_d
        real, intent(out) :: a_out(10), a_out_d(10), c_out, c_out_d
        integer :: i

        a_out = a_in
        a_out_d = a_d
        c_out = c_in
        c_out_d = c_d
        do i = 1, 10
            a_out(i) = b_in
            a_out_d(i) = b_d
            c_out_d = c_out_d * a_out(i) + c_out * a_out_d(i)
            c_out = c_out * a_out(i)
        end do
        do i = 1, 10
            c_out_d = c_out_d * a_out(i) + c_out * a_out_d(i)
            c_out = c_out * a_out(i)
        end do
    end subroutine bd05_hand_jvp

    subroutine bd05_hand_vjp(a_in, b_in, c_in, a_out, c_out, c_bar, &
            a_bar, b_bar, c_in_bar)
        real, intent(in) :: a_in(10), b_in, c_in, a_out(10), c_out, c_bar
        real, intent(out) :: a_bar(10), b_bar, c_in_bar
        real :: c_bar_work, tape_c(0:20), tape_a(1:10)
        integer :: i

        tape_a = a_out
        tape_c(0) = c_in
        do i = 1, 10
            tape_c(i) = tape_c(i-1) * tape_a(i)
        end do
        do i = 1, 10
            tape_c(10+i) = tape_c(10+i-1) * tape_a(i)
        end do

        a_bar = 0.0
        b_bar = 0.0
        c_bar_work = c_bar
        do i = 10, 1, -1
            a_bar(i) = a_bar(i) + c_bar_work * tape_c(10+i-1)
            c_bar_work = c_bar_work * tape_a(i)
        end do
        do i = 10, 1, -1
            b_bar = b_bar + a_bar(i)
            c_bar_work = c_bar_work * b_in
        end do
        a_bar = 0.0
        c_in_bar = c_bar_work
    end subroutine bd05_hand_vjp
end module tapenade_set01_bd05_hand
