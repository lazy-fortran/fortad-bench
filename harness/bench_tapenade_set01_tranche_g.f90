program bench_tapenade_set01_tranche_g
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    use lh002_forward_ad, only: lh002_jvp
    use lh002_reverse_ad, only: lh002_vjp
    use tapenade_set01_lh002_hand, only: lh002_hand_jvp, lh002_hand_vjp
    implicit none

    interface
        subroutine set01_lh002(x_initial, z_initial, b_initial, x_final, &
            y_final, z_final, a_final)
            import dp
            real(dp), intent(in) :: x_initial, z_initial, b_initial
            real(dp), intent(out) :: x_final, y_final, z_final, a_final
        end subroutine set01_lh002
    end interface

    logical :: passed

    passed = .true.
    call check_case(1.2_dp, 0.4_dp, -0.8_dp, passed)
    call check_case(-1.2_dp, 0.4_dp, -0.8_dp, passed)
    call benchmark_derivatives()
    if (.not. passed) error stop "Tapenade set01 tranche G oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_case(x_initial, z_initial, b_initial, ok)
        real(dp), intent(in) :: x_initial, z_initial, b_initial
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-3_dp, 1.0e-4_dp, &
            1.0e-5_dp, 1.0e-6_dp]
        real(dp), parameter :: x_direction = 0.2_dp, z_direction = -0.1_dp
        real(dp), parameter :: b_direction = 0.3_dp, x_final_b = 0.73_dp
        real(dp) :: x_d, z_d, b_d
        real(dp) :: x_final, x_final_d, y_final, y_final_d
        real(dp) :: z_final, z_final_d, a_final, a_final_d
        real(dp) :: hand_x_final, hand_x_final_d, hand_y_final
        real(dp) :: hand_y_final_d, hand_z_final, hand_z_final_d
        real(dp) :: hand_a_final, hand_a_final_d
        real(dp) :: reverse_x_final, reverse_y_final, reverse_z_final
        real(dp) :: reverse_a_final, x_initial_b, z_initial_b, b_initial_b
        real(dp) :: hand_reverse_x, hand_reverse_y, hand_reverse_z
        real(dp) :: hand_reverse_a, hand_x_initial_b, hand_z_initial_b
        real(dp) :: hand_b_initial_b
        real(dp) :: plus_x, minus_x, plus_z, minus_z, plus_b, minus_b
        real(dp) :: plus_x_final, minus_x_final, errors(4)
        integer :: index

        x_d = x_direction
        z_d = z_direction
        b_d = b_direction
        call lh002_jvp(x_initial, x_d, z_initial, z_d, b_initial, b_d, &
            x_final, x_final_d, y_final, y_final_d, z_final, z_final_d, &
            a_final, a_final_d)
        call lh002_hand_jvp(x_initial, x_direction, z_initial, z_direction, &
            b_initial, b_direction, hand_x_final, hand_x_final_d, &
            hand_y_final, hand_y_final_d, hand_z_final, hand_z_final_d, &
            hand_a_final, hand_a_final_d)
        call check_close("JVP x final", x_final, hand_x_final, ok)
        call check_close("JVP x tangent", x_final_d, hand_x_final_d, ok)
        call check_close("JVP y final", y_final, hand_y_final, ok)
        call check_close("JVP y tangent", y_final_d, hand_y_final_d, ok)
        call check_close("JVP z final", z_final, hand_z_final, ok)
        call check_close("JVP z tangent", z_final_d, hand_z_final_d, ok)
        call check_close("JVP a final", a_final, hand_a_final, ok)
        call check_close("JVP a tangent", a_final_d, hand_a_final_d, ok)

        call lh002_vjp(x_initial, z_initial, b_initial, reverse_x_final, &
            reverse_y_final, reverse_z_final, reverse_a_final, x_final_b, &
            x_initial_b, z_initial_b, b_initial_b)
        call lh002_hand_vjp(x_initial, z_initial, b_initial, x_final_b, &
            0.0_dp, 0.0_dp, 0.0_dp, hand_reverse_x, hand_reverse_y, &
            hand_reverse_z, hand_reverse_a, hand_x_initial_b, &
            hand_z_initial_b, hand_b_initial_b)
        call check_close("VJP x final", reverse_x_final, hand_reverse_x, ok)
        call check_close("VJP x initial", x_initial_b, hand_x_initial_b, ok)
        call check_close("VJP z initial", z_initial_b, hand_z_initial_b, ok)
        call check_close("VJP b initial", b_initial_b, hand_b_initial_b, ok)
        call check_close("VJP adjoint identity", x_final_b*x_final_d, &
            x_initial_b*x_direction + z_initial_b*z_direction + &
            b_initial_b*b_direction, ok)

        do index = 1, size(h)
            plus_x = x_initial + h(index)*x_direction
            minus_x = x_initial - h(index)*x_direction
            plus_z = z_initial + h(index)*z_direction
            minus_z = z_initial - h(index)*z_direction
            plus_b = b_initial + h(index)*b_direction
            minus_b = b_initial - h(index)*b_direction
            call set01_lh002(plus_x, plus_z, plus_b, plus_x_final, &
                hand_y_final, hand_z_final, hand_a_final)
            call set01_lh002(minus_x, minus_z, minus_b, minus_x_final, &
                hand_y_final, hand_z_final, hand_a_final)
            errors(index) = abs((plus_x_final - minus_x_final) / &
                (2.0_dp*h(index)) - x_final_d)
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
        if (any(errors > 3.0e-5_dp)) then
            print '(a,4(es12.4,1x))', "FAIL: FD errors ", errors
            ok = .false.
            return
        end if
        if (maxval(errors) > 1.0e-9_dp .and. &
            minval(errors) >= 0.2_dp*maxval(errors)) then
            print '(a,4(es12.4,1x))', "FAIL: FD convergence ", errors
            ok = .false.
            return
        end if
        print '(a,4(es12.4,1x))', "fd_errors_x_final: ", errors
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
        real(dp), parameter :: x_final_b = 0.73_dp
        integer(int64) :: clock_start, clock_stop, clock_rate
        integer :: index
        real(dp) :: x, z, b, x_d, z_d, b_d
        real(dp) :: x_f, x_f_d, y_f, y_f_d, z_f, z_f_d, a_f, a_f_d
        real(dp) :: x_v, y_v, z_v, a_v, x_b, z_b, b_b, sink, elapsed

        sink = 0.0_dp
        call system_clock(clock_start, clock_rate)
        do index = 1, repetitions
            x = 1.2_dp + real(mod(index, 97), dp)*1.0e-5_dp
            z = 0.4_dp - real(mod(index, 83), dp)*1.0e-5_dp
            b = -0.8_dp
            x_d = 0.2_dp
            z_d = -0.1_dp
            b_d = 0.3_dp
            call lh002_jvp(x, x_d, z, z_d, b, b_d, x_f, x_f_d, y_f, &
                y_f_d, z_f, z_f_d, a_f, a_f_d)
            x = 1.2_dp + real(mod(index, 97), dp)*1.0e-5_dp
            z = 0.4_dp - real(mod(index, 83), dp)*1.0e-5_dp
            b = -0.8_dp
            call lh002_vjp(x, z, b, x_v, y_v, z_v, a_v, x_final_b, x_b, &
                z_b, b_b)
            sink = sink + 1.0e-15_dp*(x_f + x_f_d + y_f + y_f_d + z_f + &
                z_f_d + a_f + a_f_d + x_v + y_v + z_v + a_v + x_b + z_b + b_b)
        end do
        call system_clock(clock_stop)
        elapsed = real(clock_stop - clock_start, dp)/real(clock_rate, dp)
        print '(a,i0)', "derivative_calls: ", 2*repetitions
        print '(a,es16.8)', "derivative_runtime_seconds: ", elapsed
        print '(a,es16.8)', "ns_per_derivative_call: ", &
            elapsed*1.0e9_dp/real(2*repetitions, dp)
        print '(a,es16.8)', "runtime_sink: ", sink
    end subroutine benchmark_derivatives

end program bench_tapenade_set01_tranche_g
