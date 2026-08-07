! SPDX-License-Identifier: MIT
!
! Bounded standard-conforming port of the fixed-form lh045 procedure.  The
! two COMMON values are explicit state here: w4 is the c1 value read before
! S3 overwrites it, and v2 is the c2 value read by S2 and S3.
subroutine set01_lh045(x, y, w4, v2, x_out, z, w4_out)
    implicit none
    real(kind=8), intent(in) :: x, y, w4, v2
    real(kind=8), intent(out) :: x_out, z, w4_out
    real(kind=8) :: t, v1, p

    v1 = v2*x + 7.0d0 - 8.0d0*14.0d0
    t = y - 10.0d0
    x_out = x
    if (x > y) then
        x_out = t
    end if
    p = v1 + 6.0d0
    z = 2.0d0*p + w4
    w4_out = v1*v2
end subroutine set01_lh045
