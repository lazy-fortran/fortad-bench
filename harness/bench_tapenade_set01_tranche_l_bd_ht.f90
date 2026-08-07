program bench_tapenade_set01_tranche_l_bd_ht
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    use bd01_forward_ad, only: bd01_jvp
    use bd01_reverse_ad, only: bd01_vjp
    use tapenade_set01_bd01_hand, only: bd01_hand_jvp, bd01_hand_vjp
    use bd02_forward_ad, only: bd02_jvp
    use bd02_reverse_ad, only: bd02_vjp
    use tapenade_set01_bd02_hand, only: bd02_hand_jvp, bd02_hand_vjp
    use bd03_forward_ad, only: bd03_jvp
    use bd03_reverse_ad, only: bd03_vjp
    use tapenade_set01_bd03_hand, only: bd03_hand_jvp, bd03_hand_vjp
    implicit none

    interface
        subroutine set01_bd01(x, y, z, w, xf, yf, zf)
            import dp
            real(dp), intent(in) :: x, y, z
            real(dp), intent(out) :: w, xf, yf, zf
        end subroutine set01_bd01

        subroutine set01_bd02(b, a)
            import dp
            real(dp), intent(in) :: b
            real(dp), intent(out) :: a
        end subroutine set01_bd02

        subroutine set01_bd03(b, a)
            import dp
            real(dp), intent(in) :: b
            real(dp), intent(out) :: a
        end subroutine set01_bd03
    end interface

    logical :: passed

    passed = .true.
    call check_bd01(passed)
    call check_bd02(passed)
    call check_bd03(passed)
    call benchmark_derivatives()
    if (.not. passed) error stop "Tapenade set01 tranche L oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_bd01(ok)
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-3_dp, 1.0e-4_dp, &
            1.0e-5_dp, 1.0e-6_dp]
        real(dp), parameter :: x = 1.2_dp, y = -0.7_dp, z = 0.4_dp
        real(dp), parameter :: xd = 0.2_dp, yd = -0.1_dp, zd = 0.3_dp
        real(dp), parameter :: wb = 0.65_dp
        real(dp) :: w, wd, xf, xfd, yf, yfd, zf, zfd
        real(dp) :: hw, hwd, hxf, hxfd, hyf, hyfd, hzf, hzfd
        real(dp) :: reverse_w, xb, yb, zb, hxb, hyb, hzb
        real(dp) :: plus_w, minus_w, errors(size(h)), lhs, rhs
        integer :: i

        call bd01_jvp(x, xd, y, yd, z, zd, w, wd, xf, xfd, yf, yfd, zf, zfd)
        call bd01_hand_jvp(x, xd, y, yd, z, zd, hw, hwd, hxf, hxfd, &
            hyf, hyfd, hzf, hzfd)
        call bd01_vjp(x, y, z, reverse_w, xf, yf, zf, wb, xb, yb, zb)
        call bd01_hand_vjp(x, y, z, wb, reverse_w, hxb, hyb, hzb)
        call check_close("bd01 primal w", w, hw, ok)
        call check_close("bd01 primal x", xf, hxf, ok)
        call check_close("bd01 primal y", yf, hyf, ok)
        call check_close("bd01 primal z", zf, hzf, ok)
        call check_close("bd01 JVP w", wd, hwd, ok)
        call check_close("bd01 JVP x", xfd, hxfd, ok)
        call check_close("bd01 JVP y", yfd, hyfd, ok)
        call check_close("bd01 JVP z", zfd, hzfd, ok)
        call check_close("bd01 VJP primal", reverse_w, hw, ok)
        call check_close("bd01 VJP x", xb, hxb, ok)
        call check_close("bd01 VJP y", yb, hyb, ok)
        call check_close("bd01 VJP z", zb, hzb, ok)
        do i = 1, size(h)
            call set01_bd01(x + h(i)*xd, y + h(i)*yd, z + h(i)*zd, &
                plus_w, xf, yf, zf)
            call set01_bd01(x - h(i)*xd, y - h(i)*yd, z - h(i)*zd, &
                minus_w, xf, yf, zf)
            errors(i) = abs((plus_w - minus_w)/(2.0_dp*h(i)) - wd)
        end do
        call check_fd("bd01", errors, ok)
        lhs = wb*wd
        rhs = xb*xd + yb*yd + zb*zd
        call check_close("bd01 adjoint identity", lhs, rhs, ok)
    end subroutine check_bd01

    subroutine check_bd02(ok)
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-3_dp, 1.0e-4_dp, &
            1.0e-5_dp, 1.0e-6_dp]
        real(dp), parameter :: b = -0.8_dp, b_direction = 0.3_dp, ab = 0.65_dp
        real(dp) :: bd
        real(dp) :: a, ad, hand_a, hand_ad, reverse_a, bb, hand_bb
        real(dp) :: plus_a, minus_a, errors(size(h)), lhs, rhs
        integer :: i

        bd = b_direction
        call bd02_jvp(b, bd, a, ad)
        call bd02_hand_jvp(b, b_direction, hand_a, hand_ad)
        call bd02_vjp(b, reverse_a, ab, bb)
        call bd02_hand_vjp(b, hand_bb, hand_a, ab)
        call check_close("bd02 primal", a, hand_a, ok)
        call check_close("bd02 JVP", ad, hand_ad, ok)
        call check_close("bd02 reverse primal", reverse_a, hand_a, ok)
        call check_close("bd02 VJP", bb, hand_bb, ok)
        do i = 1, size(h)
            call set01_bd02(b + h(i)*bd, plus_a)
            call set01_bd02(b - h(i)*bd, minus_a)
            errors(i) = abs((plus_a - minus_a)/(2.0_dp*h(i)) - ad)
        end do
        call check_fd("bd02", errors, ok)
        lhs = ab*ad
        rhs = bb*bd
        call check_close("bd02 adjoint identity", lhs, rhs, ok)
    end subroutine check_bd02

    subroutine check_bd03(ok)
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-3_dp, 1.0e-4_dp, &
            1.0e-5_dp, 1.0e-6_dp]
        real(dp), parameter :: b = 1.4_dp, b_direction = -0.25_dp, ab = -0.8_dp
        real(dp) :: bd
        real(dp) :: a, ad, hand_a, hand_ad, reverse_a, bb, hand_bb
        real(dp) :: plus_a, minus_a, errors(size(h)), lhs, rhs
        integer :: i

        bd = b_direction
        call bd03_jvp(b, bd, a, ad)
        call bd03_hand_jvp(b, b_direction, hand_a, hand_ad)
        call bd03_vjp(b, reverse_a, ab, bb)
        call bd03_hand_vjp(b, hand_bb, hand_a, ab)
        call check_close("bd03 primal", a, hand_a, ok)
        call check_close("bd03 JVP", ad, hand_ad, ok)
        call check_close("bd03 reverse primal", reverse_a, hand_a, ok)
        call check_close("bd03 VJP", bb, hand_bb, ok)
        do i = 1, size(h)
            call set01_bd03(b + h(i)*bd, plus_a)
            call set01_bd03(b - h(i)*bd, minus_a)
            errors(i) = abs((plus_a - minus_a)/(2.0_dp*h(i)) - ad)
        end do
        call check_fd("bd03", errors, ok)
        lhs = ab*ad
        rhs = bb*bd
        call check_close("bd03 adjoint identity", lhs, rhs, ok)
    end subroutine check_bd03

    subroutine check_fd(name, errors, ok)
        character(len=*), intent(in) :: name
        real(dp), intent(in) :: errors(:)
        logical, intent(inout) :: ok

        if (.not. all(ieee_is_finite(errors))) then
            print '(a)', "FAIL: "//name//" finite-difference produced non-finite"
            ok = .false.
            return
        end if
        if (any(errors > 3.0e-7_dp)) then
            print '(a,4(es12.4,1x))', "FAIL: "//name//" FD errors ", errors
            ok = .false.
            return
        end if
        print '(a,4(es12.4,1x))', "fd_errors_"//name//": ", errors
    end subroutine check_fd

    subroutine check_close(name, got, expected, ok)
        character(len=*), intent(in) :: name
        real(dp), intent(in) :: got, expected
        logical, intent(inout) :: ok
        real(dp) :: tolerance

        tolerance = 2.0e-11_dp*max(1.0_dp, abs(expected))
        if (.not. ieee_is_finite(got)) then
            print '(a,es20.10)', "FAIL: "//name//" non-finite value ", got
            ok = .false.
        else if (abs(got - expected) > tolerance) then
            print '(a,2(es20.10,1x))', "FAIL: "//name//" got/expected ", &
                got, expected
            ok = .false.
        end if
    end subroutine check_close

    subroutine benchmark_derivatives()
        integer, parameter :: repetitions = 200000
        integer(int64) :: clock_start, clock_stop, clock_rate
        integer :: i
        real(dp) :: x, y, z, w, wd, xf, xfd, yf, yfd, zf, zfd
        real(dp) :: wb, xb, yb, zb, b, b_d, a, ad, bb, sink, elapsed

        sink = 0.0_dp
        call system_clock(clock_start, clock_rate)
        do i = 1, repetitions
            x = 1.1_dp + real(mod(i, 97), dp)*1.0e-5_dp
            y = -0.8_dp + real(mod(i, 89), dp)*1.0e-5_dp
            z = 0.4_dp + real(mod(i, 83), dp)*1.0e-5_dp
            call bd01_jvp(x, 0.2_dp, y, -0.1_dp, z, 0.3_dp, w, wd, xf, &
                xfd, yf, yfd, zf, zfd)
            call bd01_vjp(x, y, z, w, xf, yf, zf, 0.65_dp, xb, yb, zb)
            b = -0.8_dp + real(mod(i, 79), dp)*1.0e-5_dp
            b_d = 0.3_dp
            call bd02_jvp(b, b_d, a, ad)
            call bd02_vjp(b, a, 0.65_dp, bb)
            b_d = -0.25_dp
            call bd03_jvp(b, b_d, a, ad)
            call bd03_vjp(b, a, -0.8_dp, bb)
            sink = sink + 1.0e-15_dp*(wd + xfd + yfd + xb + yb + zb + &
                ad + bb)
        end do
        call system_clock(clock_stop)
        elapsed = real(clock_stop - clock_start, dp)/real(clock_rate, dp)
        print '(a,i0)', "derivative_calls: ", 8*repetitions
        print '(a,es16.8)', "derivative_runtime_seconds: ", elapsed
        print '(a,es16.8)', "ns_per_derivative_call: ", &
            elapsed*1.0e9_dp/real(8*repetitions, dp)
        print '(a,es16.8)', "runtime_sink: ", sink
    end subroutine benchmark_derivatives

end program bench_tapenade_set01_tranche_l_bd_ht
