! SPDX-License-Identifier: MIT
!
! Independent derivative oracle for the bounded lh009 interpretation.
module tapenade_set01_lh009_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine lh009_primal(a_in, b_in, s, a_out, b_out)
        real(dp), intent(in) :: a_in(0:1000), b_in(0:1000)
        integer, intent(in) :: s
        real(dp), intent(out) :: a_out(0:1000), b_out(0:1000)
        integer :: i

        a_out = a_in
        b_out = b_in
        do i = s, 1000 - s
            b_out(i) = a_out(i - s)*a_out(i + s)
            a_out(i) = 2.0_dp*a_out(i) + 0.5_dp
        end do
    end subroutine lh009_primal

    subroutine lh009_hand_jvp(a_in, a_d, b_in, b_d, s, a_out, a_out_d, &
            b_out, b_out_d)
        real(dp), intent(in) :: a_in(0:1000), a_d(0:1000)
        real(dp), intent(in) :: b_in(0:1000), b_d(0:1000)
        integer, intent(in) :: s
        real(dp), intent(out) :: a_out(0:1000), a_out_d(0:1000)
        real(dp), intent(out) :: b_out(0:1000), b_out_d(0:1000)
        integer :: i

        a_out = a_in
        a_out_d = a_d
        b_out = b_in
        b_out_d = b_d
        do i = s, 1000 - s
            b_out_d(i) = a_out(i - s)*a_out_d(i + s) + &
                a_out_d(i - s)*a_out(i + s)
            b_out(i) = a_out(i - s)*a_out(i + s)
            a_out_d(i) = 2.0_dp*a_out_d(i)
            a_out(i) = 2.0_dp*a_out(i) + 0.5_dp
        end do
    end subroutine lh009_hand_jvp

    subroutine lh009_hand_vjp(a_in, b_in, s, a_out, b_out, a_bar_out, &
            b_bar_out, a_bar_in, b_bar_in)
        real(dp), intent(in) :: a_in(0:1000), b_in(0:1000)
        integer, intent(in) :: s
        real(dp), intent(in) :: a_out(0:1000), b_out(0:1000)
        real(dp), intent(in) :: a_bar_out(0:1000), b_bar_out(0:1000)
        real(dp), intent(out) :: a_bar_in(0:1000), b_bar_in(0:1000)
        real(dp) :: a_old_minus, a_old_plus
        integer :: i

        ! Each updated A element is transformed exactly once, so its input
        ! value is recovered from the final state without a large tape.
        a_bar_in = a_bar_out
        b_bar_in = b_bar_out
        do i = 1000 - s, s, -1
            a_bar_in(i) = 2.0_dp*a_bar_in(i)
            ! For positive S, I-S has already been updated at this point in
            ! the forward sweep, while I+S has not.  Recover the latter from
            ! the final state when it lies in the updated range.  S=0 is the
            ! aliasing case: both reads see A(I) before its update.
            a_old_minus = a_out(i - s)
            a_old_plus = a_out(i + s)
            if (i + s >= s .and. i + s <= 1000 - s) then
                a_old_plus = (a_old_plus - 0.5_dp)/2.0_dp
            end if
            if (s == 0) then
                a_old_minus = (a_old_minus - 0.5_dp)/2.0_dp
            end if
            a_bar_in(i - s) = a_bar_in(i - s) + &
                b_bar_in(i)*a_old_plus
            a_bar_in(i + s) = a_bar_in(i + s) + &
                b_bar_in(i)*a_old_minus
            b_bar_in(i) = 0.0_dp
        end do
    end subroutine lh009_hand_vjp
end module tapenade_set01_lh009_hand
