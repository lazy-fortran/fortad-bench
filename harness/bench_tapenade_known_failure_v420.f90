program bench_tapenade_known_failure_v420
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    use tapenade_v420_case, only: v420
    use v420_forward_ad, only: v420_jvp
    use v420_reverse_ad, only: v420_vjp
    use tapenade_v420_hand, only: v420_hand_jvp, v420_hand_vjp
    implicit none

    logical :: passed

    passed = .true.
    call check_case(passed)
    call benchmark_derivatives()
    if (.not. passed) error stop "Tapenade known-failure v420 oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_case(ok)
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-3_dp, 1.0e-4_dp, &
            1.0e-5_dp, 1.0e-6_dp]
        real(dp), parameter :: u_initial = 1.25_dp, u_direction = -0.3_dp
        real(dp), parameter :: v_b = 0.73_dp
        real(dp) :: u, u_d, v, v_d, hand_v, hand_v_d
        real(dp) :: v_reverse, u_b, hand_u_b
        real(dp) :: plus_v, minus_v, errors(4)
        integer :: index

        u = u_initial
        u_d = u_direction
        call v420_jvp(u, u_d, v, v_d)
        call v420_hand_jvp(u_initial, u_direction, hand_v, hand_v_d)
        call check_close("JVP v primal", v, hand_v, ok)
        call check_close("JVP v tangent", v_d, hand_v_d, ok)

        u = u_initial
        call v420_vjp(u, v_reverse, v_b, u_b)
        call v420_hand_vjp(u_initial, v_b, hand_u_b)
        call check_close("VJP v primal", v_reverse, hand_v, ok)
        call check_close("VJP u", u_b, hand_u_b, ok)
        call check_close("VJP adjoint identity", v_b*v_d, &
            u_b*u_direction, ok)

        do index = 1, size(h)
            call v420(u_initial + h(index)*u_direction, plus_v)
            call v420(u_initial - h(index)*u_direction, minus_v)
            errors(index) = abs((plus_v - minus_v)/(2.0_dp*h(index)) - v_d)
        end do
        call check_fd(errors, ok)
    end subroutine check_case

    subroutine check_fd(errors, ok)
        real(dp), intent(in) :: errors(:)
        logical, intent(inout) :: ok

        if (.not. all(ieee_is_finite(errors))) then
            print '(a)', "FAIL: FD errors non-finite"
            ok = .false.
            return
        end if
        if (any(errors > 3.0e-8_dp)) then
            print '(a,4(es12.4,1x))', "FAIL: FD errors ", errors
            ok = .false.
            return
        end if
        print '(a,4(es12.4,1x))', "fd_errors_v: ", errors
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

    subroutine benchmark_derivatives()
        integer, parameter :: repetitions = 1000000
        integer(int64) :: clock_start, clock_stop, clock_rate
        integer :: index
        real(dp) :: u, u_d, v, v_d, v_reverse, u_b, sink, elapsed

        sink = 0.0_dp
        call system_clock(clock_start, clock_rate)
        do index = 1, repetitions
            u = 1.25_dp + real(mod(index, 97), dp)*1.0e-5_dp
            u_d = -0.3_dp
            call v420_jvp(u, u_d, v, v_d)
            u = 1.25_dp + real(mod(index, 97), dp)*1.0e-5_dp
            call v420_vjp(u, v_reverse, 0.73_dp, u_b)
            sink = sink + 1.0e-15_dp*(v + v_d + v_reverse + u_b)
        end do
        call system_clock(clock_stop)
        elapsed = real(clock_stop - clock_start, dp)/real(clock_rate, dp)
        print '(a,i0)', "derivative_calls: ", 2*repetitions
        print '(a,es16.8)', "derivative_runtime_seconds: ", elapsed
        print '(a,es16.8)', "ns_per_derivative_call: ", &
            elapsed*1.0e9_dp/real(2*repetitions, dp)
        print '(a,es16.8)', "runtime_sink: ", sink
    end subroutine benchmark_derivatives

end program bench_tapenade_known_failure_v420
