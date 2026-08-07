program bench_tapenade_set01_tranche_k
    use, intrinsic :: iso_fortran_env, only: real64
    implicit none

    integer, parameter :: dp = real64
    integer :: failures

    failures = 0
    call check_lh003(failures)
    call check_lh005(failures)
    call check_lh006(failures)
    if (failures /= 0) error stop 1
    print '(a)', 'oracle_status: pass'

contains

    subroutine check_lh003(failures)
        integer, intent(inout) :: failures
        integer, parameter :: n = 5, nbuf = 2 * n + 22
        real(dp) :: x(nbuf), y(nbuf), z(nbuf)
        real(dp) :: xt(nbuf), yt(nbuf), zt(nbuf)
        real(dp) :: xp(nbuf), xm(nbuf), yp(nbuf), ym(nbuf)
        real(dp) :: zp(nbuf), zm(nbuf)
        real(dp) :: xd(nbuf), yd(nbuf), zd(nbuf)
        real(dp) :: xdt(nbuf), ydt(nbuf), zdt(nbuf)
        real(dp) :: a, ad, ap, am, eps
        integer :: i

        do i = 1, nbuf
            x(i) = 0.1_dp * real(i, dp)
            y(i) = -0.2_dp + 0.03_dp * real(i, dp)
            z(i) = 0.4_dp - 0.02_dp * real(i, dp)
            xd(i) = 0.01_dp * real(mod(i, 5) - 2, dp)
            yd(i) = 0.02_dp * real(mod(i, 7) - 3, dp)
            zd(i) = 0.015_dp * real(mod(i, 4) - 1, dp)
        end do
        call lh003_primal(n, x, y, z, a)
        xt = x
        yt = y
        zt = z
        xdt = xd
        ydt = yd
        zdt = zd
        call lh003_tangent(n, xt, xdt, yt, ydt, zt, zdt, ad)
        eps = 1.0e-6_dp
        xp = x + eps * xd
        xm = x - eps * xd
        yp = y + eps * yd
        ym = y - eps * yd
        zp = z + eps * zd
        zm = z - eps * zd
        call lh003_primal(n, xp, yp, zp, ap)
        call lh003_primal(n, xm, ym, zm, am)
        call expect_close('lh003 tangent versus central difference', ad, &
                          (ap - am) / (2.0_dp * eps), 2.0e-7_dp, failures)
    end subroutine check_lh003

    subroutine lh003_primal(n, x, y, z, a)
        integer, intent(in) :: n
        real(dp), intent(inout) :: x(:), y(:), z(:)
        real(dp), intent(out) :: a
        integer :: i, j

        a = 0.5_dp * x(20)
        i = 1
        do while (i < n + 5)
            i = i + 5
            z(i) = z(i - 1) + z(i + 1)
            x(i) = 3.0_dp * x(i) - y(i + 1) * y(i - 1)
        end do
        a = x(10) + a
        j = 0
        do i = 1, n + 10
            j = j + 2
            x(j) = a * y(j - 1)
            y(j + 1) = z(j) * z(3) + x(j + 1)
        end do
        a = real(j, dp) * a
    end subroutine lh003_primal

    subroutine lh003_tangent(n, x, xd, y, yd, z, zd, ad)
        integer, intent(in) :: n
        real(dp), intent(inout) :: x(:), xd(:), y(:), yd(:), z(:), zd(:)
        real(dp), intent(out) :: ad
        real(dp) :: a
        integer :: i, j

        ad = 0.5_dp * xd(20)
        a = 0.5_dp * x(20)
        i = 1
        do while (i < n + 5)
            i = i + 5
            zd(i) = zd(i - 1) + zd(i + 1)
            z(i) = z(i - 1) + z(i + 1)
            xd(i) = 3.0_dp * xd(i) - y(i + 1) * yd(i - 1) - &
                    y(i - 1) * yd(i + 1)
            x(i) = 3.0_dp * x(i) - y(i + 1) * y(i - 1)
        end do
        ad = xd(10) + ad
        a = x(10) + a
        j = 0
        do i = 1, n + 10
            j = j + 2
            xd(j) = y(j - 1) * ad + a * yd(j - 1)
            x(j) = a * y(j - 1)
            yd(j + 1) = z(3) * zd(j) + z(j) * zd(3) + xd(j + 1)
            y(j + 1) = z(j) * z(3) + x(j + 1)
        end do
        ad = real(j, dp) * ad
    end subroutine lh003_tangent

    subroutine check_lh005(failures)
        integer, intent(inout) :: failures
        real(dp) :: y, z, eps, plus, minus, fd

        eps = 1.0e-6_dp
        y = 2.0_dp
        z = 1.0_dp
        call lh005_x1(y + eps, z, plus)
        call lh005_x1(y - eps, z, minus)
        fd = (plus - minus) / (2.0_dp * eps)
        call expect_close('lh005 y derivative in y>z branch', fd, 0.0_dp, &
                          1.0e-8_dp, failures)
        call lh005_x1(y, z + eps, plus)
        call lh005_x1(y, z - eps, minus)
        fd = (plus - minus) / (2.0_dp * eps)
        call expect_close('lh005 x(1) derivative in y>z branch', fd, 1.0_dp, &
                          1.0e-8_dp, failures)

        y = -3.0_dp
        z = -2.0_dp
        call lh005_x1(y + eps, z, plus)
        call lh005_x1(y - eps, z, minus)
        fd = (plus - minus) / (2.0_dp * eps)
        call expect_close('lh005 x(1) derivative in z<=0 branch', fd, 1.0_dp, &
                          1.0e-8_dp, failures)
        call lh005_x1(y, z + eps, plus)
        call lh005_x1(y, z - eps, minus)
        fd = (plus - minus) / (2.0_dp * eps)
        call expect_close('lh005 z derivative in z<=0 branch', fd, 0.0_dp, &
                          1.0e-8_dp, failures)
    end subroutine check_lh005

    subroutine lh005_x1(y, z, x1)
        real(dp), intent(in) :: y, z
        real(dp), intent(out) :: x1

        if (y > z) then
            x1 = z
        else if (z <= 0.0_dp) then
            x1 = y
        else
            x1 = 0.0_dp
        end if
    end subroutine lh005_x1

    subroutine check_lh006(failures)
        integer, intent(inout) :: failures
        real(dp) :: a, b, eps, plus, minus, fd

        a = 6.5_dp
        b = 1.0_dp
        eps = 1.0e-6_dp
        call lh006_x1(a, b + eps, plus)
        call lh006_x1(a, b - eps, minus)
        fd = (plus - minus) / (2.0_dp * eps)
        call expect_close('lh006 x(1) derivative with respect to b', fd, 7.0_dp, &
                          1.0e-7_dp, failures)
        call lh006_x1(a + eps, b, plus)
        call lh006_x1(a - eps, b, minus)
        fd = (plus - minus) / (2.0_dp * eps)
        call expect_close('lh006 x(1) derivative with respect to a', fd, 0.0_dp, &
                          1.0e-8_dp, failures)
    end subroutine check_lh006

    subroutine lh006_x1(a, b, x1)
        real(dp), intent(in) :: a, b
        real(dp), intent(out) :: x1
        integer :: irang

        x1 = 0.0_dp
        do irang = 1, 100
            if (x1 >= a) return
            x1 = 2.0_dp * x1 + b
        end do
    end subroutine lh006_x1

    subroutine expect_close(label, got, want, tolerance, failures)
        character(*), intent(in) :: label
        real(dp), intent(in) :: got, want, tolerance
        integer, intent(inout) :: failures
        real(dp) :: error

        error = abs(got - want)
        if (error > tolerance) then
            print '(a,1x,es12.4,1x,a,1x,es12.4)', trim(label), got, &
                  'expected', want
            failures = failures + 1
        end if
    end subroutine expect_close

end program bench_tapenade_set01_tranche_k
