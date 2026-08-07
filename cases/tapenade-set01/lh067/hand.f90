module tapenade_set01_lh067_hand
    implicit none
contains

    subroutine hand_value(z, read7)
        implicit none
        real, intent(in) :: z
        real, intent(out) :: read7
        integer :: ncmax

        ncmax = 10
        ncmax = z + ncmax
        read7 = ncmax * z
    end subroutine hand_value

    subroutine hand_jvp(z, zd, read7, read7d)
        implicit none
        real, intent(in) :: z, zd
        real, intent(out) :: read7, read7d
        integer :: ncmax

        ncmax = 10
        ncmax = z + ncmax
        read7 = ncmax * z
        ! The probe stays in the open interval 1 < z < 2, where INT(z+10)
        ! is 11 and has zero derivative.
        read7d = ncmax * zd
    end subroutine hand_jvp

end module tapenade_set01_lh067_hand
