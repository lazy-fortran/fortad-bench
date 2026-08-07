program bench_tapenade_set01_lh007_015
    use, intrinsic :: iso_fortran_env, only: real64
    implicit none

    integer, parameter :: dp = real64
    integer :: failures

    failures = 0
    call check_lh012(failures)
    call check_lh013(failures)
    call check_lh014(failures)
    if (failures /= 0) error stop 1
    print '(a)', 'oracle_status: pass'

contains

    subroutine check_lh012(failures)
        integer, intent(inout) :: failures
        integer, parameter :: n = 100
        real(dp) :: b(n), c(n), bd(n), cd(n), bp(n), cp(n), bm(n), cm(n)
        integer :: indx(n)
        real(dp) :: got, plus, minus, fd, hand
        real(dp) :: bb(n), cb(n), dot_left, dot_right, eps
        integer :: i, j

        do i = 1, n
            b(i) = 0.2_dp + 0.01_dp * real(i, dp)
            c(i) = 1.1_dp - 0.015_dp * real(i, dp)
            bd(i) = 0.003_dp * real(mod(i, 7) - 3, dp)
            cd(i) = 0.004_dp * real(mod(i, 5) - 2, dp)
            indx(i) = mod(7 * i + 11, n) + 1
        end do
        got = lh012_sum(b, c, indx)
        hand = 0.0_dp
        do j = 1, 50
            i = indx(j)
            hand = hand + bd(i) * c(i) + b(i) * cd(i)
        end do
        eps = 1.0e-6_dp
        bp = b + eps * bd
        cp = c + eps * cd
        bm = b - eps * bd
        cm = c - eps * cd
        plus = lh012_sum(bp, cp, indx)
        minus = lh012_sum(bm, cm, indx)
        fd = (plus - minus) / (2.0_dp * eps)
        call expect_close('lh012 JVP versus central difference', hand, fd, &
                          3.0e-8_dp, failures)
        bb = 0.0_dp
        cb = 0.0_dp
        do j = 1, 50
            i = indx(j)
            bb(i) = bb(i) + c(i)
            cb(i) = cb(i) + b(i)
        end do
        dot_left = hand
        dot_right = sum(bb * bd) + sum(cb * cd)
        call expect_close('lh012 JVP/VJP adjoint identity', dot_left, &
                          dot_right, 3.0e-12_dp, failures)
        call expect_close('lh012 primal is finite', got, got, 0.0_dp, failures)
    end subroutine check_lh012

    pure real(dp) function lh012_sum(b, c, indx) result(total)
        real(dp), intent(in) :: b(:), c(:)
        integer, intent(in) :: indx(:)
        integer :: j, i

        total = 0.0_dp
        do j = 1, 50
            i = indx(j)
            total = total + b(i) * c(i)
        end do
    end function lh012_sum

    subroutine check_lh013(failures)
        integer, intent(inout) :: failures
        real(dp) :: x, y, xd, yd, xp, xm, plus, minus, fd, hand
        real(dp) :: xb, yb, dot_left, dot_right, eps

        x = 0.7_dp
        y = -1.3_dp
        xd = 0.11_dp
        yd = -0.23_dp
        hand = xd + 2.0_dp * yd
        eps = 1.0e-6_dp
        xp = x + eps * xd
        xm = x - eps * xd
        plus = lh013_initialized(xp, y + eps * yd)
        minus = lh013_initialized(xm, y - eps * yd)
        fd = (plus - minus) / (2.0_dp * eps)
        call expect_close('lh013 JVP versus central difference', hand, fd, &
                          3.0e-10_dp, failures)
        xb = 1.0_dp
        yb = 2.0_dp
        dot_left = hand
        dot_right = xb * xd + yb * yd
        call expect_close('lh013 JVP/VJP adjoint identity', dot_left, &
                          dot_right, 3.0e-12_dp, failures)
    end subroutine check_lh013

    pure real(dp) function lh013_initialized(x, y) result(x_final)
        real(dp), intent(in) :: x, y

        x_final = x + 2.0_dp * y
    end function lh013_initialized

    subroutine check_lh014(failures)
        integer, intent(inout) :: failures
        integer, parameter :: n = 100
        real(dp) :: y(n), yd(n), yp(n), ym(n), p, q, pd, qd
        real(dp) :: plus, minus, fd, hand, pb, qb, yb(n)
        real(dp) :: dot_left, dot_right, eps
        integer :: i

        do i = 1, n
            y(i) = 0.5_dp + 0.02_dp * real(i, dp)
            yd(i) = 0.003_dp * real(mod(i, 9) - 4, dp)
        end do
        p = 1.2_dp
        q = -0.4_dp
        pd = 0.07_dp
        qd = -0.05_dp
        hand = 2.0_dp * (p + q) * sum(yd) + 2.0_dp * (pd + qd) * sum(y)
        eps = 1.0e-6_dp
        yp = y + eps * yd
        ym = y - eps * yd
        plus = lh014_sum(yp, p + eps * pd, q + eps * qd)
        minus = lh014_sum(ym, p - eps * pd, q - eps * qd)
        fd = (plus - minus) / (2.0_dp * eps)
        call expect_close('lh014 JVP versus central difference', hand, fd, &
                          1.0e-6_dp, failures)
        yb = 2.0_dp * (p + q)
        pb = 2.0_dp * sum(y)
        qb = pb
        dot_left = hand
        dot_right = sum(yb * yd) + pb * pd + qb * qd
        call expect_close('lh014 JVP/VJP adjoint identity', dot_left, &
                          dot_right, 3.0e-12_dp, failures)
    end subroutine check_lh014

    pure real(dp) function lh014_sum(y, p, q) result(total)
        real(dp), intent(in) :: y(:), p, q

        total = 2.0_dp * (p + q) * sum(y)
    end function lh014_sum

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

end program bench_tapenade_set01_lh007_015
