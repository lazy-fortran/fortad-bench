! SPDX-License-Identifier: MIT
!
! Bounded standard-conforming specialization of the fixed-form lh060 case.
! The upstream routine calls two opaque external procedures and carries TN in
! COMMON.  This port exposes TN and fixes the callback contracts below so the
! control flow is reproducible; it is not an exact-source support claim.
module tapenade_set01_lh060_case
    implicit none
contains
    subroutine set01_lh060(neq, y, savf, tn, c3, c4, y_out, savf_out, tn_out)
        integer, intent(in) :: neq
        real, intent(in) :: y, savf, tn
        real, intent(in) :: c3, c4
        real, intent(out) :: y_out, savf_out, tn_out
        real :: y_state, savf_state, tn_state

        y_state = y
        savf_state = savf
        tn_state = tn

        ! FX3(neq, tn, y, savf): bounded callback contract.
        savf_state = savf_state + c3*tn_state + 0.5*y_state + 2.0
        tn_state = tn_state + 0.1*c3*y_state

        ! FX4(neq, tn, y, savf, FX3): bounded callback contract.  The
        ! callback handle is part of the upstream signature, but this fixed
        ! specialization does not invoke it recursively.
        y_state = y_state + c4*savf_state + tn_state + 0.25*c3
        tn_state = tn_state + 0.05*c4*savf_state

        ! The upstream INVERT calls FX3 for a second time.
        savf_state = savf_state + c3*tn_state + 0.5*y_state + 2.0
        tn_state = tn_state + 0.1*c3*y_state

        y_out = y_state
        savf_out = savf_state
        tn_out = tn_state
    end subroutine set01_lh060
end module tapenade_set01_lh060_case
