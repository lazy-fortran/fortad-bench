! Bounded standard-conforming specialization of the fixed-form lh072 case.
!
! The upstream callback is defined locally as EXTF, but FortAD cannot inline
! the generic EXTERNAL dummy passed through TOTO/TUTU.  This port specializes
! that callback chain to the known EXTF body.  No missing external routine is
! invented; the two callback applications and their in-place update order are
! unchanged.
module tapenade_set01_lh072_case
    implicit none
contains
    subroutine set01_lh072(a_in, b_in, a_out, b_out, a_sum)
        real, intent(in) :: a_in(10), b_in(10)
        real, intent(out) :: a_out(10), b_out(10)
        real, intent(out) :: a_sum
        integer :: i
        real :: callback_value
        real :: b_state(10)

        do i = 1, 10
            a_out(i) = b_in(i) * a_in(i)
        end do
        a_sum = 0.0
        do i = 1, 10
            a_sum = a_sum + a_out(i)
        end do
        ! TOTO -> TUTU -> EXTF, specialized to the locally defined callback.
        ! The scalar temporary makes the callback's in/out contract explicit.
        do i = 1, 10
            b_state(i) = b_in(i)
        end do
        callback_value = b_state(4)
        call extf_lh072(callback_value)
        b_state(4) = callback_value
        callback_value = b_state(10)
        call extf_lh072(callback_value)
        b_state(10) = callback_value
        do i = 1, 10
            b_out(i) = b_state(i)
        end do
    end subroutine set01_lh072

    subroutine extf_lh072(r)
        real, intent(inout) :: r

        r = r * r
    end subroutine extf_lh072
end module tapenade_set01_lh072_case
