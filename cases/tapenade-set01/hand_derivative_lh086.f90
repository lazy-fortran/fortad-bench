module tapenade_set01_lh086_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: lh086_jvp, lh086_vjp, primal_lh086

contains

    subroutine primal_lh086(x, n, alpha, y)
        real(dp), intent(in) :: x, alpha
        integer, intent(in) :: n
        real(dp), intent(out) :: y
        integer :: i
        real(dp) :: f, fp

        y = x
        do i = 1, n
            f = y - alpha*cos(y)
            fp = 1.0_dp + alpha*sin(y)
            y = y - f/fp
        end do
    end subroutine primal_lh086

    subroutine lh086_jvp(x, xd, n, alpha, alphad, y, yd)
        real(dp), intent(in) :: x, xd, alpha, alphad
        integer, intent(in) :: n
        real(dp), intent(out) :: y, yd
        integer :: i
        real(dp) :: c, s, f, fp, fd, fpd

        y = x
        yd = xd
        do i = 1, n
            c = cos(y)
            s = sin(y)
            f = y - alpha*c
            fp = 1.0_dp + alpha*s
            fd = yd - alphad*c + alpha*s*yd
            fpd = alphad*s + alpha*c*yd
            yd = yd - (fd*fp - f*fpd)/(fp*fp)
            y = y - f/fp
        end do
    end subroutine lh086_jvp

    subroutine lh086_vjp(x, n, alpha, yb, xb, alphab)
        real(dp), intent(in) :: x, alpha, yb
        integer, intent(in) :: n
        real(dp), intent(out) :: xb, alphab
        integer :: i
        real(dp) :: y, c, s, f, fp, a, b, adjoint
        real(dp) :: ys(n)

        y = x
        do i = 1, n
            ys(i) = y
            f = y - alpha*cos(y)
            fp = 1.0_dp + alpha*sin(y)
            y = y - f/fp
        end do

        adjoint = yb
        alphab = 0.0_dp
        do i = n, 1, -1
            y = ys(i)
            c = cos(y)
            s = sin(y)
            f = y - alpha*c
            fp = 1.0_dp + alpha*s
            a = f*alpha*c/(fp*fp)
            b = c/fp + f*s/(fp*fp)
            alphab = alphab + adjoint*b
            adjoint = adjoint*a
        end do
        xb = adjoint
    end subroutine lh086_vjp

end module tapenade_set01_lh086_hand
