! Independent hand JVP for the bounded lh051 terminating path.
module tapenade_set01_lh051_hand
    implicit none
contains
    subroutine hand_jvp(x, y, z, n, o, xd, yd, zd)
        integer, intent(in) :: n, o
        real, intent(inout) :: x(:), y(:), z(:)
        real, intent(inout) :: xd(:), yd(:), zd(:)
        real :: a, ad
        integer :: i, j, k

        a = 0.5*x(20)
        ad = 0.5*xd(20)
        do i = 5 + o, n, 2
            zd(i) = zd(i-1) - 2.0*zd(i) + zd(i+1)
            z(i) = z(i-1) - 2.0*z(i) + z(i+1)
            xd(i) = 3.0*xd(i) - y(i+1)*yd(i-1) - y(i-1)*yd(i+1)
            x(i) = 3.0*x(i) - y(i+1)*y(i-1)
        end do

        ad = xd(10) + ad
        a = x(10) + a
        j = 0
        do k = 1, 34
            j = j + 3
            xd(j) = ad*y(j-1) + a*yd(j-1)
            x(j) = a*y(j-1)
            yd(j+1) = zd(j)*z(3) + z(j)*zd(3) + xd(j+1)
            y(j+1) = z(j)*z(3) + x(j+1)
        end do
        a = 2.0*a + 3.0
        ad = 2.0*ad
    end subroutine hand_jvp
end module tapenade_set01_lh051_hand
