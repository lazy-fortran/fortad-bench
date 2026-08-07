module tapenade_set01_lh076
    implicit none
    private
    public :: set01_lh076

contains

    subroutine set01_lh076(pin4, emipint)
        real(8), intent(in) :: pin4
        complex(8), intent(out) :: emipint

        emipint = cmplx(cos(pin4), -sin(pin4), 8)
    end subroutine set01_lh076

end module tapenade_set01_lh076
