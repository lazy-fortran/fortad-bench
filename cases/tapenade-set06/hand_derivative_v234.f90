module tapenade_set06_v234_hand
    implicit none
    private
    public :: primal_v234, v234_jvp, v234_vjp

contains

    subroutine primal_v234(t, f)
        real, intent(in) :: t
        real, intent(out) :: f

        f = t*t
    end subroutine primal_v234

    subroutine v234_jvp(t, td, f, fd)
        real, intent(in) :: t, td
        real, intent(out) :: f, fd

        f = t*t
        fd = 2.0* t*td
    end subroutine v234_jvp

    subroutine v234_vjp(t, fb, tb)
        real, intent(in) :: t, fb
        real, intent(out) :: tb

        tb = 2.0*t*fb
    end subroutine v234_vjp

end module tapenade_set06_v234_hand
