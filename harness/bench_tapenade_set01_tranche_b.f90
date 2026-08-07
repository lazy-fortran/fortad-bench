program bench_tapenade_set01_tranche_b
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    use lh057_forward_a_out_ad, only: lh057_forward_a_out
    use lh057_reverse_a_out_ad, only: lh057_reverse_a_out
    use lh057_reverse_c_out_ad, only: lh057_reverse_c_out
    use tapenade_set01_lh057_hand, only: lh057_hand_jvp, &
        lh057_hand_vjp_a, lh057_hand_vjp_c
    implicit none

    interface
        subroutine set01_lh057_split(a, b, c, a_out, c_out)
            import dp
            real(dp), intent(in) :: a, b, c
            real(dp), intent(out) :: a_out, c_out
        end subroutine set01_lh057_split
    end interface

    logical :: passed

    passed = .true.
    call check_case(passed)
    call benchmark_derivatives()
    if (.not. passed) error stop "Tapenade set01 tranche B oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_case(ok)
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-3_dp, 1.0e-4_dp, &
            1.0e-5_dp, 1.0e-6_dp]
        real(dp), parameter :: a = 1.3_dp, b = 0.7_dp, c = 1.1_dp
        real(dp), parameter :: a_d = 0.2_dp, b_d = -0.15_dp, c_d = 0.11_dp
        real(dp), parameter :: a_out_b = -0.63_dp, c_out_b = 0.81_dp
        real(dp) :: a_out, a_out_d, c_out, c_out_d
        real(dp) :: hand_a_out, hand_a_out_d, hand_c_out, hand_c_out_d
        real(dp) :: a_b, b_b, c_b, hand_a_b, hand_b_b, hand_c_b
        real(dp) :: plus_a, minus_a, plus_c, minus_c
        real(dp) :: errors_a(size(h)), errors_c(size(h))
        integer :: i

        call lh057_forward_a_out(a, a_d, b, b_d, c, c_d, a_out, &
            a_out_d, c_out, c_out_d)
        call lh057_hand_jvp(a, a_d, b, b_d, c, c_d, hand_a_out, &
            hand_a_out_d, hand_c_out, hand_c_out_d)
        call check_close("JVP a_out", a_out, hand_a_out, ok)
        call check_close("JVP c_out", c_out, hand_c_out, ok)
        call check_close("JVP a_out_d", a_out_d, hand_a_out_d, ok)
        call check_close("JVP c_out_d", c_out_d, hand_c_out_d, ok)

        call lh057_reverse_a_out(a, b, c, a_out, c_out, a_out_b, a_b, &
            b_b, c_b)
        call lh057_hand_vjp_a(a, b, c, a_out_b, hand_a_b, hand_b_b, &
            hand_c_b)
        call check_close("VJP a_out primal", a_out, hand_a_out, ok)
        call check_close("VJP a_out a_b", a_b, hand_a_b, ok)
        call check_close("VJP a_out b_b", b_b, hand_b_b, ok)
        call check_close("VJP a_out c_b", c_b, hand_c_b, ok)
        call check_close("VJP a_out adjoint identity", a_out_b*a_out_d, &
            a_b*a_d + b_b*b_d + c_b*c_d, ok)

        call lh057_reverse_c_out(a, b, c, a_out, c_out, c_out_b, a_b, &
            b_b, c_b)
        call lh057_hand_vjp_c(a, b, c, c_out_b, hand_a_b, hand_b_b, &
            hand_c_b)
        call check_close("VJP c_out primal", c_out, hand_c_out, ok)
        call check_close("VJP c_out a_b", a_b, hand_a_b, ok)
        call check_close("VJP c_out b_b", b_b, hand_b_b, ok)
        call check_close("VJP c_out c_b", c_b, hand_c_b, ok)
        call check_close("VJP c_out adjoint identity", c_out_b*c_out_d, &
            a_b*a_d + b_b*b_d + c_b*c_d, ok)

        do i = 1, size(h)
            call set01_lh057_split(a + h(i)*a_d, b + h(i)*b_d, &
                c + h(i)*c_d, plus_a, plus_c)
            call set01_lh057_split(a - h(i)*a_d, b - h(i)*b_d, &
                c - h(i)*c_d, minus_a, minus_c)
            errors_a(i) = abs((plus_a - minus_a)/(2.0_dp*h(i)) - a_out_d)
            errors_c(i) = abs((plus_c - minus_c)/(2.0_dp*h(i)) - c_out_d)
        end do
        call check_fd("a_out", errors_a, ok)
        call check_fd("c_out", errors_c, ok)
    end subroutine check_case

    subroutine check_fd(name, errors, ok)
        character(len=*), intent(in) :: name
        real(dp), intent(in) :: errors(:)
        logical, intent(inout) :: ok
        integer :: i

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
        if (errors(2) >= 0.2_dp*errors(1) .or. &
            minval(errors) >= 0.01_dp*errors(1)) then
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

        tolerance = 1.0e-11_dp*max(1.0_dp, abs(expected))
        if (.not. ieee_is_finite(got)) then
            print '(a,es20.10)', "FAIL: "//name//" non-finite ", got
            ok = .false.
            return
        end if
        if (abs(got - expected) > tolerance) then
            print '(a,2(es20.10,1x))', "FAIL: "//name//" got/expected ", &
                got, expected
            ok = .false.
        end if
    end subroutine check_close

    subroutine benchmark_derivatives()
        integer, parameter :: repetitions = 1000000
        integer(int64) :: clock_start, clock_stop, clock_rate
        integer :: i
        real(dp) :: a, b, c, a_d, b_d, c_d, a_out, a_out_d, c_out, c_out_d
        real(dp) :: a_b, b_b, c_b, sink, elapsed

        sink = 0.0_dp
        call system_clock(clock_start, clock_rate)
        do i = 1, repetitions
            a = 1.2_dp + real(mod(i, 97), dp)*1.0e-5_dp
            b = 0.6_dp + real(mod(i, 89), dp)*1.0e-5_dp
            c = 1.1_dp + real(mod(i, 83), dp)*1.0e-5_dp
            a_d = 0.2_dp
            b_d = -0.15_dp
            c_d = 0.11_dp
            call lh057_forward_a_out(a, a_d, b, b_d, c, c_d, a_out, &
                a_out_d, c_out, c_out_d)
            call lh057_reverse_a_out(a, b, c, a_out, c_out, -0.63_dp, a_b, &
                b_b, c_b)
            call lh057_reverse_c_out(a, b, c, a_out, c_out, 0.81_dp, a_b, &
                b_b, c_b)
            sink = sink + 1.0e-15_dp*(a_out_d + c_out_d + a_b + b_b + c_b)
        end do
        call system_clock(clock_stop)
        elapsed = real(clock_stop - clock_start, dp)/real(clock_rate, dp)
        print '(a,i0)', "derivative_calls: ", 3*repetitions
        print '(a,es16.8)', "derivative_runtime_seconds: ", elapsed
        print '(a,es16.8)', "ns_per_derivative_call: ", &
            elapsed*1.0e9_dp/real(3*repetitions, dp)
        print '(a,es16.8)', "runtime_sink: ", sink
    end subroutine benchmark_derivatives

end program bench_tapenade_set01_tranche_b
