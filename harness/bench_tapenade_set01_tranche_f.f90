program bench_tapenade_set01_tranche_f
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    use lh049_forward_ad, only: lh049_jvp
    use lh049_reverse_ad, only: lh049_vjp
    use tapenade_set01_lh049_hand, only: lh049_hand_jvp, lh049_hand_vjp
    implicit none

    interface
        subroutine set01_lh049(x, y, z)
            import dp
            real(dp), intent(in) :: x
            real(dp), intent(inout) :: y
            real(dp), intent(out) :: z
        end subroutine set01_lh049
    end interface

    logical :: passed

    passed = .true.
    call check_case(passed)
    call benchmark_derivatives()
    if (.not. passed) error stop "Tapenade set01 tranche F oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_case(ok)
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-3_dp, 1.0e-4_dp, &
            1.0e-5_dp, 1.0e-6_dp]
        real(dp), parameter :: x_initial = 1.5_dp, y_initial = 0.75_dp
        real(dp), parameter :: x_direction = 0.2_dp, y_direction = -0.1_dp
        real(dp), parameter :: z_b = 0.73_dp
        real(dp) :: x, y, x_d, y_d, z, z_d
        real(dp) :: hand_x, hand_y, hand_x_d, hand_y_d, hand_z, hand_z_d
        real(dp) :: reverse_z, x_b, y_b, hand_reverse_z, hand_x_b, hand_y_b
        real(dp) :: plus_x, minus_x, plus_y, minus_y
        real(dp) :: plus_z, minus_z, errors(4)
        integer :: index

        x = x_initial
        y = y_initial
        x_d = x_direction
        y_d = y_direction
        call lh049_jvp(x, x_d, y, y_d, z, z_d)
        hand_x = x_initial
        hand_y = y_initial
        hand_x_d = x_direction
        hand_y_d = y_direction
        call lh049_hand_jvp(hand_x, hand_x_d, hand_y, hand_y_d, hand_z, &
            hand_z_d)
        call check_close("JVP z primal", z, hand_z, ok)
        call check_close("JVP z tangent", z_d, hand_z_d, ok)
        call check_close("JVP final y", y, 2.0_dp*x_initial, ok)
        call check_close("JVP final y tangent", y_d, 2.0_dp*x_direction, ok)

        x = x_initial
        y = y_initial
        call lh049_vjp(x, y, reverse_z, z_b, x_b, y_b)
        call lh049_hand_vjp(x_initial, y_initial, hand_reverse_z, z_b, &
            hand_x_b, hand_y_b)
        call check_close("VJP z primal", reverse_z, hand_reverse_z, ok)
        call check_close("VJP x", x_b, hand_x_b, ok)
        call check_close("VJP y", y_b, hand_y_b, ok)
        call check_close("VJP adjoint identity", z_b*z_d, &
            x_b*x_direction + y_b*y_direction, ok)

        do index = 1, size(h)
            plus_x = x_initial + h(index)*x_direction
            minus_x = x_initial - h(index)*x_direction
            plus_y = y_initial + h(index)*y_direction
            minus_y = y_initial - h(index)*y_direction
            call set01_lh049(plus_x, plus_y, plus_z)
            call set01_lh049(minus_x, minus_y, minus_z)
            errors(index) = abs((plus_z - minus_z)/(2.0_dp*h(index)) - z_d)
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
        print '(a,4(es12.4,1x))', "fd_errors_z: ", errors
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
        real(dp), parameter :: z_b = 0.73_dp
        integer(int64) :: clock_start, clock_stop, clock_rate
        integer :: index
        real(dp) :: x, y, x_d, y_d, z, z_d
        real(dp) :: z_v, x_b, y_b, sink, elapsed

        sink = 0.0_dp
        call system_clock(clock_start, clock_rate)
        do index = 1, repetitions
            x = 1.5_dp + real(mod(index, 97), dp)*1.0e-5_dp
            y = 0.75_dp - real(mod(index, 83), dp)*1.0e-5_dp
            x_d = 0.2_dp
            y_d = -0.1_dp
            call lh049_jvp(x, x_d, y, y_d, z, z_d)
            x = 1.5_dp + real(mod(index, 97), dp)*1.0e-5_dp
            y = 0.75_dp - real(mod(index, 83), dp)*1.0e-5_dp
            call lh049_vjp(x, y, z_v, z_b, x_b, y_b)
            sink = sink + 1.0e-15_dp*(z + z_d + z_v + x_b + y_b + y)
        end do
        call system_clock(clock_stop)
        elapsed = real(clock_stop - clock_start, dp)/real(clock_rate, dp)
        print '(a,i0)', "derivative_calls: ", 2*repetitions
        print '(a,es16.8)', "derivative_runtime_seconds: ", elapsed
        print '(a,es16.8)', "ns_per_derivative_call: ", &
            elapsed*1.0e9_dp/real(2*repetitions, dp)
        print '(a,es16.8)', "runtime_sink: ", sink
    end subroutine benchmark_derivatives

end program bench_tapenade_set01_tranche_f
