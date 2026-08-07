! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Port of Tapenade nonRegressions/set01/lh085/program.f at e59864c.
subroutine set01_lh085(flur1, fltr1, aux1, dpex, e2, dpm, aux2, dpor, &
        r1, r2, v, v3, v6)
    implicit none
    real(8), intent(out) :: flur1, fltr1
    real(8), intent(in) :: aux1, dpex, e2, dpm, aux2, dpor
    real(8), intent(out) :: r1, r2
    real(8), intent(inout) :: v(0:100)
    real(8), intent(out) :: v3, v6

    flur1 = aux1 * ((dpex*dpex + e2)*dpm + (dpm*dpm + e2)*dpex) / &
        (dpex*dpex + dpm*dpm + 2.0d0*e2)
    fltr1 = aux2 * ((dpor*dpor/e2)*dpm*(dpm*dpm*e2)*dpor) / &
        (dpor/dpm*dpm*2.0d0/e2)
    v3 = 2.5d0
    v6 = 3.5d0
    r1 = (v(0)*v(1) + v(2)/v3) * ((v(4)*v(5))/(v6+v(7))) + &
        (v(8)*v(9) + v(10)**v(11)) * ((v(12)*v(13))**(v(14)*v(15)))
    r2 = (v(21)*v(22)/(v(23)*v(24)) + 1.3d0) * v(25)
end subroutine set01_lh085
