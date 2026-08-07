module tapenade_v420_hand
    use, intrinsic :: iso_fortran_env, only: real64
    implicit none
    private
    public :: v420_hand_jvp, v420_hand_vjp
contains
    subroutine v420_hand_jvp(u, u_d, v, v_d)
        real(real64), intent(in) :: u, u_d
        real(real64), intent(out) :: v, v_d
        v = 50.0_real64*u
        v_d = 50.0_real64*u_d
    end subroutine v420_hand_jvp

    subroutine v420_hand_vjp(u, v_b, u_b)
        real(real64), intent(in) :: u, v_b
        real(real64), intent(out) :: u_b
        u_b = 50.0_real64*v_b
    end subroutine v420_hand_vjp
end module tapenade_v420_hand
