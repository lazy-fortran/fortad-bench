! SPDX-License-Identifier: MIT
!
! Independent bounded oracle for the set01/lh011 refusal record.  This is
! deliberately not a repaired port of the upstream routine: it models only
! the defined computed-GOTO paths for selectors at most ten, before the
! unresolved TOTO/TUTU calls.
module tapenade_set01_lh011_oracle
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine bounded_model(selector, a)
        integer, intent(in) :: selector
        real(dp), intent(inout) :: a(100)

        ! A computed GOTO with selector 2 takes label 200.  Selector 1, and
        ! an out-of-range selector, continue at label 100 in the source.
        if (selector == 2) then
            a(3) = 10.0_dp
        else
            a(2) = 10.0_dp
        end if
        a(4) = 10.0_dp
    end subroutine bounded_model

    subroutine objective(selector, a, weight, value)
        integer, intent(in) :: selector
        real(dp), intent(in) :: a(100), weight(100)
        real(dp), intent(out) :: value
        real(dp) :: output(100)

        output = a
        call bounded_model(selector, output)
        value = dot_product(weight, output)
    end subroutine objective

    subroutine hand_jvp(selector, direction, weight, value)
        integer, intent(in) :: selector
        real(dp), intent(in) :: direction(100), weight(100)
        real(dp), intent(out) :: value
        real(dp) :: gradient(100)

        gradient = weight
        if (selector == 2) then
            gradient(3) = 0.0_dp
        else
            gradient(2) = 0.0_dp
        end if
        gradient(4) = 0.0_dp
        value = dot_product(gradient, direction)
    end subroutine hand_jvp

    subroutine hand_vjp(selector, seed, weight, gradient)
        integer, intent(in) :: selector
        real(dp), intent(in) :: seed, weight(100)
        real(dp), intent(out) :: gradient(100)

        gradient = seed*weight
        if (selector == 2) then
            gradient(3) = 0.0_dp
        else
            gradient(2) = 0.0_dp
        end if
        gradient(4) = 0.0_dp
    end subroutine hand_vjp
end module tapenade_set01_lh011_oracle
