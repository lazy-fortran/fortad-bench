module tapenade_set01_v526_case
    implicit none
    private
    public :: v526_sing3

contains

    ! Bounded port of SING3: separate initial and final DYP state so the
    ! reverse contract has one dependent seed for the output.
    subroutine v526_sing3(dxp, dyp_initial, dyp, epaisseur_seuil)
        double precision, intent(in) :: dxp(1), dyp_initial(1)
        double precision, intent(out) :: dyp(1)
        integer, intent(in) :: epaisseur_seuil

        if (epaisseur_seuil == 1) then
            dyp = dxp * dxp
        else
            dyp = dyp_initial
        end if
    end subroutine v526_sing3

end module tapenade_set01_v526_case
