module tapenade_set01_lh076_hand
    implicit none
    private
    public :: lh076_hand_jvp, lh076_hand_vjp

contains

    subroutine lh076_hand_jvp(pin4, pin4d, emipint, emipintd)
        real(8), intent(in) :: pin4, pin4d
        complex(8), intent(out) :: emipint, emipintd

        emipint = cmplx(cos(pin4), -sin(pin4), 8)
        emipintd = cmplx(-sin(pin4) * pin4d, -cos(pin4) * pin4d, 8)
    end subroutine lh076_hand_jvp

    subroutine lh076_hand_vjp(emipintb, pin4b)
        complex(8), intent(in) :: emipintb
        real(8), intent(out) :: pin4b

        pin4b = -sin(0.7d0) * real(emipintb) - &
            cos(0.7d0) * aimag(emipintb)
    end subroutine lh076_hand_vjp

end module tapenade_set01_lh076_hand
