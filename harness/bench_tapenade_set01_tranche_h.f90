program bench_tapenade_set01_tranche_h_refusal
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    use tapenade_set01_lh004_hand, only: lh004_hand_jvp, lh004_hand_vjp
    implicit none

    interface
        subroutine set01_lh004(y_initial, z_initial, x1_final, x2_final)
            import dp
            real(dp), intent(in) :: y_initial, z_initial
            real(dp), intent(out) :: x1_final, x2_final
        end subroutine set01_lh004
    end interface

    logical :: passed

    passed = .true.
    call check_case(2.3_dp, 0.7_dp, passed)
    call check_case(2.3_dp, -0.7_dp, passed)
    call benchmark_primal()
    if (.not. passed) error stop "Tapenade set01 tranche H oracle failed"
    print '(a)', "refusal_oracle_status: pass"

contains

    subroutine check_case(y_initial, z_initial, ok)
        real(dp), intent(in) :: y_initial, z_initial
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-3_dp, 1.0e-4_dp, &
            1.0e-5_dp, 1.0e-6_dp]
        real(dp), parameter :: y_direction = 0.13_dp, z_direction = -0.11_dp
        real(dp), parameter :: x1_final_b = 0.73_dp, x2_final_b = -0.21_dp
        real(dp) :: y_d, z_d, x1, x1_d, x2, x2_d
        real(dp) :: hand_x1, hand_x1_d, hand_x2, hand_x2_d
        real(dp) :: reverse_x1, reverse_x2, y_b, z_b
        real(dp) :: plus_x1, minus_x1, plus_x2, minus_x2
        real(dp) :: errors_x1(4), errors_x2(4)
        integer :: index

        y_d = y_direction
        z_d = z_direction
        call set01_lh004(y_initial, z_initial, x1, x2)
        call lh004_hand_jvp(y_initial, y_d, z_initial, z_d, hand_x1, &
            hand_x1_d, hand_x2, hand_x2_d)
        call check_close("primal x1", x1, hand_x1, ok)
        call check_close("primal x2", x2, hand_x2, ok)

        call lh004_hand_jvp(y_initial, y_direction, z_initial, z_direction, &
            hand_x1, hand_x1_d, hand_x2, hand_x2_d)
        call check_close("hand x1 tangent", hand_x1_d, &
            real(4, dp)*sign(1.0_dp, z_initial)*z_direction, ok)
        call check_close("hand x2 tangent", hand_x2_d, &
            real(4, dp)*y_direction, ok)

        call lh004_hand_vjp(y_initial, z_initial, x1_final_b, x2_final_b, &
            reverse_x1, reverse_x2, y_b, z_b)
        call check_close("hand VJP x1", reverse_x1, hand_x1, ok)
        call check_close("hand VJP x2", reverse_x2, hand_x2, ok)
        call check_close("hand adjoint identity", x1_final_b*hand_x1_d + &
            x2_final_b*hand_x2_d, y_b*y_direction + z_b*z_direction, ok)

        do index = 1, size(h)
            call set01_lh004(y_initial + h(index)*y_direction, &
                z_initial + h(index)*z_direction, plus_x1, plus_x2)
            call set01_lh004(y_initial - h(index)*y_direction, &
                z_initial - h(index)*z_direction, minus_x1, minus_x2)
            errors_x1(index) = abs((plus_x1 - minus_x1)/(2.0_dp*h(index)) - &
                hand_x1_d)
            errors_x2(index) = abs((plus_x2 - minus_x2)/(2.0_dp*h(index)) - &
                hand_x2_d)
        end do
        call check_fd("x1", errors_x1, ok)
        call check_fd("x2", errors_x2, ok)
    end subroutine check_case

    subroutine check_fd(name, errors, ok)
        character(len=*), intent(in) :: name
        real(dp), intent(in) :: errors(:)
        logical, intent(inout) :: ok

        if (.not. all(ieee_is_finite(errors))) then
            print '(a)', "FAIL: "//name//" FD errors non-finite"
            ok = .false.
        else if (any(errors > 3.0e-5_dp)) then
            print '(a,4(es12.4,1x))', "FAIL: "//name//" FD errors ", errors
            ok = .false.
        else
            print '(a,4(es12.4,1x))', "fd_errors_"//name//": ", errors
        end if
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

    subroutine benchmark_primal()
        integer, parameter :: repetitions = 1000000
        integer(int64) :: clock_start, clock_stop, clock_rate
        integer :: index
        real(dp) :: y, z, x1, x2, sink, elapsed

        sink = 0.0_dp
        call system_clock(clock_start, clock_rate)
        do index = 1, repetitions
            y = 2.3_dp + real(mod(index, 97), dp)*1.0e-5_dp
            z = 0.7_dp - real(mod(index, 83), dp)*1.0e-5_dp
            call set01_lh004(y, z, x1, x2)
            sink = sink + 1.0e-15_dp*(x1 + x2)
        end do
        call system_clock(clock_stop)
        elapsed = real(clock_stop - clock_start, dp)/real(clock_rate, dp)
        print '(a,i0)', "primal_calls: ", repetitions
        print '(a,es16.8)', "primal_runtime_seconds: ", elapsed
        print '(a,es16.8)', "ns_per_primal_call: ", &
            elapsed*1.0e9_dp/real(repetitions, dp)
        print '(a,es16.8)', "primal_runtime_sink: ", sink
    end subroutine benchmark_primal

end program bench_tapenade_set01_tranche_h_refusal
