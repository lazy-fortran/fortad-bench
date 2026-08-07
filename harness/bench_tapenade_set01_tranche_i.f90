program bench_tapenade_set01_tranche_i
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    use tapenade_set01_lh019_case, only: real8_diff, set01_lh019
    use lh019_forward_ad, only: lh019_jvp
    use lh019_reverse_ad, only: lh019_vjp
    use tapenade_set01_lh019_hand, only: lh019_hand_jvp, lh019_hand_vjp
    implicit none

    logical :: passed

    passed = .true.
    call check_case(2.25_dp, -0.75_dp, 6, passed)
    call check_case(-1.5_dp, 0.8_dp, 3, passed)
    call benchmark_derivatives()
    if (.not. passed) error stop "Tapenade set01 tranche H oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_case(x_value, y_value, n, ok)
        real(dp), intent(in) :: x_value, y_value
        integer, intent(in) :: n
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-3_dp, 1.0e-4_dp, &
            1.0e-5_dp, 1.0e-6_dp]
        real(dp), parameter :: x_direction = 0.35_dp, y_direction = -0.2_dp
        real(dp), parameter :: output_b = 1.3_dp
        type(real8_diff) :: x, x_d, y, y_d, x_b, y_b, x_b_hand, y_b_hand
        type(real8_diff) :: plus_x, minus_x, plus_y, minus_y
        real(dp) :: output, output_d, hand_output, hand_output_d
        real(dp) :: reverse_output, hand_reverse_output
        real(dp) :: reverse_x, reverse_y, hand_x, hand_y
        real(dp) :: plus_value, minus_value, errors(4)
        integer :: index

        x%v = x_value
        x%tag = 7
        y%v = y_value
        y%tag = 11
        x_d%v = x_direction
        x_d%tag = 0
        y_d%v = y_direction
        y_d%tag = 0
        call lh019_jvp(x, x_d, y, y_d, n, output, output_d)
        call lh019_hand_jvp(x, x_d, y, y_d, n, hand_output, hand_output_d)
        call check_close("JVP output", output, hand_output, ok)
        call check_close("JVP tangent", output_d, hand_output_d, ok)

        call lh019_vjp(x, y, n, reverse_output, output_b, x_b, y_b)
        call lh019_hand_vjp(x, y, n, hand_reverse_output, output_b, &
            x_b_hand, y_b_hand)
        hand_x = x_b_hand%v
        hand_y = y_b_hand%v
        reverse_x = x_b%v
        reverse_y = y_b%v
        call check_close("VJP output", reverse_output, hand_reverse_output, ok)
        call check_close("VJP x component", reverse_x, hand_x, ok)
        call check_close("VJP y component", reverse_y, hand_y, ok)
        call check_close("VJP adjoint identity", output_b*output_d, &
            reverse_x*x_direction + reverse_y*y_direction, ok)

        do index = 1, size(h)
            plus_x = x
            minus_x = x
            plus_y = y
            minus_y = y
            plus_x%v = x%v + h(index)*x_direction
            minus_x%v = x%v - h(index)*x_direction
            plus_y%v = y%v + h(index)*y_direction
            minus_y%v = y%v - h(index)*y_direction
            call set01_lh019(plus_x, plus_y, n, plus_value)
            call set01_lh019(minus_x, minus_y, n, minus_value)
            errors(index) = abs((plus_value - minus_value)/(2.0_dp*h(index)) &
                - output_d)
        end do
        if (.not. all(ieee_is_finite(errors)) .or. &
            any(errors > 3.0e-7_dp)) then
            print '(a,4(es12.4,1x))', "FAIL: FD errors ", errors
            ok = .false.
        else
            print '(a,i0,a,4(es12.4,1x))', "fd_errors_n=", n, ": ", errors
        end if
    end subroutine check_case

    subroutine check_close(name, got, expected, ok)
        character(len=*), intent(in) :: name
        real(dp), intent(in) :: got, expected
        logical, intent(inout) :: ok
        real(dp) :: tolerance

        tolerance = 2.0e-11_dp*max(1.0_dp, abs(expected))
        if (.not. ieee_is_finite(got) .or. abs(got - expected) > tolerance) then
            print '(a,2(es20.10,1x))', "FAIL: "//name//" got/expected ", &
                got, expected
            ok = .false.
        end if
    end subroutine check_close

    subroutine benchmark_derivatives()
        integer, parameter :: repetitions = 500000
        integer(int64) :: clock_start, clock_stop, clock_rate
        integer :: index
        type(real8_diff) :: x, x_d, y, y_d, x_b, y_b
        real(dp) :: output, output_d, output_v, sink, elapsed

        sink = 0.0_dp
        call system_clock(clock_start, clock_rate)
        do index = 1, repetitions
            x%v = 2.25_dp + real(mod(index, 97), dp)*1.0e-5_dp
            x%tag = 7
            y%v = -0.75_dp
            y%tag = 11
            x_d%v = 0.35_dp
            x_d%tag = 0
            y_d%v = -0.2_dp
            y_d%tag = 0
            call lh019_jvp(x, x_d, y, y_d, 6, output, output_d)
            call lh019_vjp(x, y, 6, output_v, 1.3_dp, x_b, y_b)
            sink = sink + 1.0e-15_dp*(output + output_d + output_v + &
                x_b%v + y_b%v)
        end do
        call system_clock(clock_stop)
        elapsed = real(clock_stop - clock_start, dp)/real(clock_rate, dp)
        print '(a,i0)', "derivative_calls: ", 2*repetitions
        print '(a,es16.8)', "derivative_runtime_seconds: ", elapsed
        print '(a,es16.8)', "ns_per_derivative_call: ", &
            elapsed*1.0e9_dp/real(2*repetitions, dp)
        print '(a,es16.8)', "runtime_sink: ", sink
    end subroutine benchmark_derivatives

end program bench_tapenade_set01_tranche_i
