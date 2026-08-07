program bench_tapenade_set01_tranche_d
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    use lh068_forward_ad, only: lh068_jvp
    use lh068_reverse_c3_ad, only: lh068_vjp_c3
    use lh068_reverse_c7_ad, only: lh068_vjp_c7
    use tapenade_set01_lh068_hand, only: lh068_hand_jvp, lh068_hand_vjp
    implicit none

    interface
        subroutine set01_lh068_split(a, b, c, c3, c7)
            import dp
            real(dp), intent(in) :: a(:), b(:), c(:)
            real(dp), intent(out) :: c3, c7
        end subroutine set01_lh068_split
    end interface

    logical :: passed

    passed = .true.
    call check_case(passed)
    call benchmark_derivatives()
    if (.not. passed) error stop "Tapenade set01 tranche D oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_case(ok)
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-3_dp, 1.0e-4_dp, &
            1.0e-5_dp, 1.0e-6_dp]
        real(dp), parameter :: a(10) = [1.5_dp, -0.4_dp, 0.7_dp, &
            -1.2_dp, 0.75_dp, 0.2_dp, -0.8_dp, 1.1_dp, 0.3_dp, -0.6_dp]
        real(dp), parameter :: b(15) = [0.1_dp, -0.2_dp, 0.3_dp, 0.4_dp, &
            -0.5_dp, 0.6_dp, -0.7_dp, 0.25_dp, 0.9_dp, -1.1_dp, 0.8_dp, &
            0.4_dp, -0.3_dp, 0.2_dp, -0.1_dp]
        real(dp), parameter :: c(10) = [-0.2_dp, 0.3_dp, -0.4_dp, 0.5_dp, &
            -0.6_dp, 0.7_dp, 0.8_dp, -0.9_dp, 1.0_dp, -1.1_dp]
        real(dp), parameter :: a_d(10) = [0.2_dp, -0.1_dp, 0.05_dp, &
            0.12_dp, -0.08_dp, 0.07_dp, -0.04_dp, 0.09_dp, -0.03_dp, &
            0.06_dp]
        real(dp), parameter :: b_d(15) = [-0.03_dp, 0.04_dp, -0.05_dp, &
            0.06_dp, -0.07_dp, 0.08_dp, -0.09_dp, 0.10_dp, -0.11_dp, &
            0.12_dp, -0.13_dp, 0.14_dp, -0.15_dp, 0.16_dp, -0.17_dp]
        real(dp), parameter :: c_d(10) = [0.11_dp, -0.12_dp, 0.13_dp, &
            -0.14_dp, 0.15_dp, -0.16_dp, 0.17_dp, -0.18_dp, 0.19_dp, &
            -0.20_dp]
        real(dp), parameter :: c3_b = 0.73_dp, c7_b = -0.41_dp
        real(dp) :: c3, c3_d, c7, c7_d
        real(dp) :: hand_c3, hand_c3_d, hand_c7, hand_c7_d
        real(dp) :: reverse_c3, reverse_c7, unused_c3, unused_c7
        real(dp) :: a_b(10), b_b(15), c_b(10)
        real(dp) :: hand_a_b(10), hand_b_b(15), hand_c_b(10)
        real(dp) :: plus_c3, minus_c3, plus_c7, minus_c7
        real(dp) :: errors_c3(4), errors_c7(4)
        integer :: i

        call lh068_jvp(a, a_d, b, b_d, c, c_d, c3, c3_d, c7, c7_d)
        call lh068_hand_jvp(a, a_d, b, b_d, c, c_d, hand_c3, &
            hand_c3_d, hand_c7, hand_c7_d)
        call check_close("JVP c3 primal", c3, hand_c3, ok)
        call check_close("JVP c3 tangent", c3_d, hand_c3_d, ok)
        call check_close("JVP c7 primal", c7, hand_c7, ok)
        call check_close("JVP c7 tangent", c7_d, hand_c7_d, ok)

        call lh068_vjp_c3(a, b, c, reverse_c3, unused_c7, c3_b, a_b, &
            b_b, c_b)
        call lh068_hand_vjp(a, b, c, c3_b, 0.0_dp, hand_a_b, hand_b_b, &
            hand_c_b)
        call check_close("VJP c3 primal", reverse_c3, hand_c3, ok)
        call check_vector("VJP c3 a", a_b, hand_a_b, ok)
        call check_vector("VJP c3 b", b_b, hand_b_b, ok)
        call check_vector("VJP c3 c", c_b, hand_c_b, ok)
        call check_close("VJP c3 adjoint identity", c3_b*c3_d, &
            dot_product(a_b, a_d) + dot_product(b_b, b_d) + &
            dot_product(c_b, c_d), ok)

        call lh068_vjp_c7(a, b, c, unused_c3, reverse_c7, c7_b, a_b, &
            b_b, c_b)
        call lh068_hand_vjp(a, b, c, 0.0_dp, c7_b, hand_a_b, hand_b_b, &
            hand_c_b)
        call check_close("VJP c7 primal", reverse_c7, hand_c7, ok)
        call check_vector("VJP c7 a", a_b, hand_a_b, ok)
        call check_vector("VJP c7 b", b_b, hand_b_b, ok)
        call check_vector("VJP c7 c", c_b, hand_c_b, ok)
        call check_close("VJP c7 adjoint identity", c7_b*c7_d, &
            dot_product(a_b, a_d) + dot_product(b_b, b_d) + &
            dot_product(c_b, c_d), ok)

        do i = 1, size(h)
            call set01_lh068_split(a + h(i)*a_d, b + h(i)*b_d, &
                c + h(i)*c_d, plus_c3, plus_c7)
            call set01_lh068_split(a - h(i)*a_d, b - h(i)*b_d, &
                c - h(i)*c_d, minus_c3, minus_c7)
            errors_c3(i) = abs((plus_c3 - minus_c3)/(2.0_dp*h(i)) - c3_d)
            errors_c7(i) = abs((plus_c7 - minus_c7)/(2.0_dp*h(i)) - c7_d)
        end do
        call check_fd("c3", errors_c3, ok)
        call check_fd("c7", errors_c7, ok)
    end subroutine check_case

    subroutine check_fd(name, errors, ok)
        character(len=*), intent(in) :: name
        real(dp), intent(in) :: errors(:)
        logical, intent(inout) :: ok

        if (.not. all(ieee_is_finite(errors))) then
            print '(a)', "FAIL: "//name//" non-finite FD errors"
            ok = .false.
            return
        end if
        if (any(errors > 1.0e-8_dp)) then
            print '(a,4(es12.4,1x))', "FAIL: "//name//" FD errors ", errors
            ok = .false.
            return
        end if
        ! A branch with a locally affine output can reach roundoff at every
        ! step (the inactive c7 branch is exactly zero). Require the absolute
        ! error bound and only demand visible convergence when truncation error
        ! is larger than roundoff.
        if (maxval(errors) > 1.0e-13_dp .and. &
            minval(errors) >= 0.5_dp*maxval(errors)) then
            print '(a,4(es12.4,1x))', "FAIL: "//name//" FD convergence ", &
                errors
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
            print '(a,es20.10)', "FAIL: "//name//" non-finite ", got
            ok = .false.
        else if (abs(got - expected) > tolerance) then
            print '(a,2(es20.10,1x))', "FAIL: "//name//" got/expected ", &
                got, expected
            ok = .false.
        end if
    end subroutine check_close

    subroutine check_vector(name, got, expected, ok)
        character(len=*), intent(in) :: name
        real(dp), intent(in) :: got(:), expected(:)
        logical, intent(inout) :: ok
        real(dp) :: tolerance
        integer :: i

        do i = 1, size(got)
            tolerance = 2.0e-11_dp*max(1.0_dp, abs(expected(i)))
            if (.not. ieee_is_finite(got(i)) .or. &
                abs(got(i) - expected(i)) > tolerance) then
                print '(a,i0,2(es20.10,1x))', "FAIL: "//name//" index ", &
                    i, got(i), expected(i)
                ok = .false.
            end if
        end do
    end subroutine check_vector

    subroutine benchmark_derivatives()
        integer, parameter :: repetitions = 1000000
        integer(int64) :: clock_start, clock_stop, clock_rate
        integer :: i
        real(dp) :: a(10), b(15), c(10), a_d(10), b_d(15), c_d(10)
        real(dp) :: c3, c3_d, c7, c7_d, reverse_c3, reverse_c7
        real(dp) :: unused_c3, unused_c7, a_b(10), b_b(15), c_b(10)
        real(dp) :: sink, elapsed

        a = [1.5_dp, -0.4_dp, 0.7_dp, -1.2_dp, 0.75_dp, 0.2_dp, -0.8_dp, &
            1.1_dp, 0.3_dp, -0.6_dp]
        b = [0.1_dp, -0.2_dp, 0.3_dp, 0.4_dp, -0.5_dp, 0.6_dp, -0.7_dp, &
            0.25_dp, 0.9_dp, -1.1_dp, 0.8_dp, 0.4_dp, -0.3_dp, 0.2_dp, &
            -0.1_dp]
        c = [-0.2_dp, 0.3_dp, -0.4_dp, 0.5_dp, -0.6_dp, 0.7_dp, 0.8_dp, &
            -0.9_dp, 1.0_dp, -1.1_dp]
        a_d = 0.1_dp
        b_d = -0.07_dp
        c_d = 0.05_dp
        sink = 0.0_dp
        call system_clock(clock_start, clock_rate)
        do i = 1, repetitions
            a(1) = 1.5_dp + real(mod(i, 97), dp)*1.0e-5_dp
            c(3) = -0.4_dp + real(mod(i, 83), dp)*1.0e-5_dp
            b(8) = 0.25_dp
            a(5) = 0.75_dp
            c(7) = 0.8_dp
            b(12) = 0.4_dp
            call lh068_jvp(a, a_d, b, b_d, c, c_d, c3, c3_d, c7, c7_d)
            call lh068_vjp_c3(a, b, c, reverse_c3, unused_c7, 0.73_dp, &
                a_b, b_b, c_b)
            call lh068_vjp_c7(a, b, c, unused_c3, reverse_c7, -0.41_dp, &
                a_b, b_b, c_b)
            sink = sink + 1.0e-15_dp*(c3_d + c7_d + reverse_c3 + &
                reverse_c7 + sum(a_b) + sum(b_b) + sum(c_b))
        end do
        call system_clock(clock_stop)
        elapsed = real(clock_stop - clock_start, dp)/real(clock_rate, dp)
        print '(a,i0)', "derivative_calls: ", 3*repetitions
        print '(a,es16.8)', "derivative_runtime_seconds: ", elapsed
        print '(a,es16.8)', "ns_per_derivative_call: ", &
            elapsed*1.0e9_dp/real(3*repetitions, dp)
        print '(a,es16.8)', "runtime_sink: ", sink
    end subroutine benchmark_derivatives

end program bench_tapenade_set01_tranche_d
