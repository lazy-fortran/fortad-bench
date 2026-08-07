! SPDX-License-Identifier: MIT
! Independent derivative oracle for Tapenade set02/lh163.
module tapenade_set02_lh163_hand
    implicit none
    private
    public :: primal, jvp, vjp

contains

    subroutine primal(v, p, q, s)
        real, intent(inout) :: v, q
        real, intent(in) :: p
        real, intent(out) :: s

        s = q*v
        v = p*p
        q = 3.0*v
    end subroutine primal

    subroutine jvp(v, vd, p, pd, q, qd, s, sd)
        real, intent(inout) :: v, vd, q, qd
        real, intent(in) :: p, pd
        real, intent(out) :: s, sd

        sd = qd*v + q*vd
        s = q*v
        vd = 2.0*(p*pd)
        v = p*p
        qd = 3.0*vd
        q = 3.0*v
    end subroutine jvp

    subroutine vjp(v, p, q, s, sb, vb, pb, qb)
        real, intent(in) :: v, p, q, s, sb
        real, intent(out) :: vb, pb, qb

        vb = sb*q
        pb = 0.0
        qb = sb*v
    end subroutine vjp

end module tapenade_set02_lh163_hand
