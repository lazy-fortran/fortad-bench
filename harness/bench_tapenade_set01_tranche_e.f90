program bench_tapenade_set01_tranche_e
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    use lh001_forward_ad, only: lh001_jvp
    use lh001_reverse_ad, only: lh001_vjp
    use tapenade_set01_lh001_hand, only: lh001_hand_jvp, lh001_hand_vjp
    implicit none

    interface
        subroutine set01_lh001(i1, i2, i3, o1, o2, o3)
            import dp
            real(dp), intent(inout) :: i1, i2
            real(dp), intent(in) :: i3
            real(dp), intent(out) :: o1, o2, o3
        end subroutine set01_lh001
    end interface

    logical :: passed

    passed = .true.
    call check_case(passed)
    call benchmark_derivatives()
    if (.not. passed) error stop "Tapenade set01 tranche E oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_case(ok)
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-3_dp, 1.0e-4_dp, &
            1.0e-5_dp, 1.0e-6_dp]
        real(dp), parameter :: i1_initial = 4.0_dp, i2_initial = 1.0_dp
        real(dp), parameter :: i3_initial = 2.0_dp
        real(dp), parameter :: i1_direction = 0.2_dp, i2_direction = -0.1_dp
        real(dp), parameter :: i3_direction = 0.3_dp
        real(dp), parameter :: o1_b = 0.73_dp
        real(dp) :: i1, i2, i3, i1_d, i2_d, i3_d
        real(dp) :: o1, o1_d, o2, o3, o3_d
        real(dp) :: hand_o1, hand_o1_d, hand_o2, hand_o3, hand_o3_d
        real(dp) :: hand_i1, hand_i1_d, hand_i2, hand_i2_d, hand_i3, hand_i3_d
        real(dp) :: reverse_o1, reverse_o2, reverse_o3
        real(dp) :: i1_b, i2_b, i3_b
        real(dp) :: hand_i1_b, hand_i2_b, hand_i3_b
        real(dp) :: plus_o1, minus_o1, plus_o2, minus_o2
        real(dp) :: plus_o3, minus_o3, errors(4)
        real(dp) :: plus_i1, plus_i2, minus_i1, minus_i2
        integer :: index

        i1 = i1_initial
        i2 = i2_initial
        i3 = i3_initial
        i1_d = i1_direction
        i2_d = i2_direction
        i3_d = i3_direction
        call lh001_jvp(i1, i1_d, i2, i2_d, i3, i3_d, o1, o1_d, o2, o3, &
            o3_d)
        hand_i1 = i1_initial
        hand_i2 = i2_initial
        hand_i3 = i3_initial
        hand_i1_d = i1_direction
        hand_i2_d = i2_direction
        hand_i3_d = i3_direction
        call lh001_hand_jvp(hand_i1, hand_i1_d, hand_i2, hand_i2_d, hand_i3, &
            hand_i3_d, hand_o1, hand_o1_d, hand_o2, hand_o3, hand_o3_d)
        call check_close("JVP o1 primal", o1, hand_o1, ok)
        call check_close("JVP o1 tangent", o1_d, hand_o1_d, ok)
        call check_close("JVP o2", o2, hand_o2, ok)
        call check_close("JVP o3 primal", o3, hand_o3, ok)
        call check_close("JVP o3 tangent", o3_d, hand_o3_d, ok)
        call check_close("JVP final i1", i1, 99.0_dp, ok)
        call check_close("JVP final i2", i2, 5.0_dp, ok)
        call check_close("JVP final i1 tangent", i1_d, 0.0_dp, ok)
        call check_close("JVP final i2 tangent", i2_d, 0.0_dp, ok)

        i1 = i1_initial
        i2 = i2_initial
        i3 = i3_initial
        call lh001_vjp(i1, i2, i3, reverse_o1, reverse_o2, reverse_o3, &
            o1_b, i1_b, i2_b, i3_b)
        call lh001_hand_vjp(i1_initial, i2_initial, i3_initial, hand_o1, &
            hand_o2, hand_o3, o1_b, hand_i1_b, hand_i2_b, hand_i3_b)
        call check_close("VJP o1 primal", reverse_o1, hand_o1, ok)
        call check_close("VJP i1", i1_b, hand_i1_b, ok)
        call check_close("VJP i2", i2_b, hand_i2_b, ok)
        call check_close("VJP i3", i3_b, hand_i3_b, ok)
        call check_close("VJP adjoint identity", o1_b*o1_d, &
            i1_b*i1_direction + i2_b*i2_direction + i3_b*i3_direction, ok)

        do index = 1, size(h)
            plus_i1 = i1_initial + h(index)*i1_direction
            plus_i2 = i2_initial + h(index)*i2_direction
            minus_i1 = i1_initial - h(index)*i1_direction
            minus_i2 = i2_initial - h(index)*i2_direction
            call set01_lh001(plus_i1, plus_i2, i3_initial + &
                h(index)*i3_direction, plus_o1, plus_o2, plus_o3)
            call set01_lh001(minus_i1, minus_i2, i3_initial - &
                h(index)*i3_direction, minus_o1, minus_o2, minus_o3)
            errors(index) = abs((plus_o1 - minus_o1)/(2.0_dp*h(index)) - &
                o1_d)
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
        print '(a,4(es12.4,1x))', "fd_errors_o1: ", errors
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
        real(dp) :: i1, i2, i3, i1_d, i2_d, i3_d
        real(dp) :: o1, o1_d, o2, o3, o3_d
        real(dp) :: o1_v, o2_v, o3_v, i1_b, i2_b, i3_b
        real(dp) :: sink, elapsed

        sink = 0.0_dp
        call system_clock(clock_start, clock_rate)
        do index = 1, repetitions
            i1 = 4.0_dp + real(mod(index, 97), dp)*1.0e-5_dp
            i2 = 1.0_dp - real(mod(index, 83), dp)*1.0e-5_dp
            i3 = 2.0_dp
            i1_d = 0.2_dp
            i2_d = -0.1_dp
            i3_d = 0.3_dp
            call lh001_jvp(i1, i1_d, i2, i2_d, i3, i3_d, o1, o1_d, o2, &
                o3, o3_d)
            i1 = 4.0_dp + real(mod(index, 97), dp)*1.0e-5_dp
            i2 = 1.0_dp - real(mod(index, 83), dp)*1.0e-5_dp
            i3 = 2.0_dp
            call lh001_vjp(i1, i2, i3, o1_v, o2_v, o3_v, 0.73_dp, i1_b, &
                i2_b, i3_b)
            sink = sink + 1.0e-15_dp*(o1_d + o1_v + o2 + o3 + o3_d + &
                o2_v + o3_v + i1_b + i2_b + i3_b)
        end do
        call system_clock(clock_stop)
        elapsed = real(clock_stop - clock_start, dp)/real(clock_rate, dp)
        print '(a,i0)', "derivative_calls: ", 2*repetitions
        print '(a,es16.8)', "derivative_runtime_seconds: ", elapsed
        print '(a,es16.8)', "ns_per_derivative_call: ", &
            elapsed*1.0e9_dp/real(2*repetitions, dp)
        print '(a,es16.8)', "runtime_sink: ", sink
    end subroutine benchmark_derivatives

end program bench_tapenade_set01_tranche_e
