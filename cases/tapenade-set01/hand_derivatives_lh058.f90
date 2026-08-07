! Independent closed-form oracle for the lh058 Euclidean norm.
module tapenade_set01_lh058_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: lh058_hand_jvp, lh058_hand_vjp

contains

    subroutine lh058_hand_jvp(t, t_d, u, u_d, n, e, e_d)
        real(dp), intent(in) :: t(:), t_d(:), u(:), u_d(:)
        integer, intent(in) :: n
        real(dp), intent(out) :: e, e_d
        real(dp) :: e1, e2, e2_d
        integer :: i

        e2 = 0.0_dp
        e2_d = 0.0_dp
        do i = 1, n
            e1 = t(i) - u(i)
            e2 = e2 + e1**2
            e2_d = e2_d + 2.0_dp*e1*(t_d(i) - u_d(i))
        end do
        e = sqrt(e2)
        e_d = e2_d/(2.0_dp*e)
    end subroutine lh058_hand_jvp

    subroutine lh058_hand_vjp(t, u, n, e, e_b, t_b, u_b)
        real(dp), intent(in) :: t(:), u(:)
        integer, intent(in) :: n
        real(dp), intent(out) :: e, t_b(:), u_b(:)
        real(dp), intent(in) :: e_b
        real(dp) :: e1, e2
        integer :: i

        e2 = 0.0_dp
        do i = 1, n
            e1 = t(i) - u(i)
            e2 = e2 + e1**2
        end do
        e = sqrt(e2)
        do i = 1, n
            t_b(i) = e_b*(t(i) - u(i))/e
            u_b(i) = -t_b(i)
        end do
    end subroutine lh058_hand_vjp

end module tapenade_set01_lh058_hand
