module tapenade_set01_v416_case
    implicit none
    private
    public :: set01_v416

contains

    ! Bounded standard-conforming port of the v416 recurrence.  The execution
    ! domain is nm_ha >= 2 and Tm_ha /= 0.0; the latter keeps every source
    ! division defined and the former keeps nm_ha-1 a valid index.
    subroutine set01_v416(x, y, nm_ha, Tm_ha)
        real, intent(in) :: x, Tm_ha
        real, intent(out) :: y
        integer, intent(in) :: nm_ha
        real :: MC_ha(nm_ha, nm_ha)
        integer :: kp, j_ha

        MC_ha = 0.0
        do kp = 1, 2
            MC_ha(1, 2) = 1 / 5 / 2.
            do j_ha = 1, nm_ha - 1
                MC_ha(j_ha, j_ha) = 1.0
                MC_ha(j_ha, j_ha + 1) = 1.0 / 2.0 / Tm_ha
                MC_ha(j_ha + 1, j_ha) = -1.0 / 2.0 / Tm_ha
            end do
            MC_ha(nm_ha, nm_ha) = 1.0 + 1.0 / Tm_ha
            MC_ha(nm_ha, nm_ha - 1) = -1.0 / Tm_ha
        end do

        y = x * x * MC_ha(1, 1)
    end subroutine set01_v416

end module tapenade_set01_v416_case
