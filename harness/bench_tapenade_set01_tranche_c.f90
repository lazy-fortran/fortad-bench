program bench_tapenade_set01_tranche_c
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    use lh058_forward_ad, only: lh058_jvp
    use lh058_reverse_ad, only: lh058_vjp
    use tapenade_set01_lh058_hand, only: lh058_hand_jvp, lh058_hand_vjp
    implicit none

    logical :: passed

    interface
        subroutine set01_lh058(t, u, n, e)
            import dp
            real(dp), intent(in) :: t(:), u(:)
            integer, intent(in) :: n
            real(dp), intent(out) :: e
        end subroutine set01_lh058
    end interface

    passed = .true.
    call check_case(passed)
    call benchmark_derivatives()
    if (.not. passed) error stop "Tapenade set01 tranche C oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_case(ok)
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-3_dp, 1.0e-4_dp, &
            1.0e-5_dp, 1.0e-6_dp]
        real(dp), parameter :: t(4) = [1.2_dp, -0.4_dp, 2.1_dp, 0.7_dp]
        real(dp), parameter :: u(4) = [0.3_dp, 0.8_dp, -0.9_dp, 1.4_dp]
        real(dp), parameter :: t_d(4) = [0.2_dp, -0.15_dp, 0.11_dp, 0.07_dp]
        real(dp), parameter :: u_d(4) = [-0.1_dp, 0.04_dp, 0.08_dp, -0.12_dp]
        real(dp), parameter :: e_b = 0.73_dp
        real(dp) :: e, e_d, hand_e, hand_e_d
        real(dp) :: reverse_e, hand_reverse_e
        real(dp) :: t_b(4), u_b(4), hand_t_b(4), hand_u_b(4)
        real(dp) :: plus_e, minus_e
        real(dp) :: errors(4)
        integer :: i

        call lh058_jvp(t, t_d, u, u_d, 4, e, e_d)
        call lh058_hand_jvp(t, t_d, u, u_d, 4, hand_e, hand_e_d)
        call check_close("JVP primal", e, hand_e, ok)
        call check_close("JVP tangent", e_d, hand_e_d, ok)

        call lh058_vjp(t, u, 4, reverse_e, e_b, t_b, u_b)
        call lh058_hand_vjp(t, u, 4, hand_reverse_e, e_b, hand_t_b, &
            hand_u_b)
        call check_close("VJP primal", reverse_e, hand_reverse_e, ok)
        do i = 1, 4
            call check_close("VJP t_b", t_b(i), hand_t_b(i), ok)
            call check_close("VJP u_b", u_b(i), hand_u_b(i), ok)
        end do
        call check_close("adjoint identity", e_b*e_d, &
            dot_product(t_b, t_d) + dot_product(u_b, u_d), ok)

        do i = 1, size(h)
            call set01_lh058(t + h(i)*t_d, u + h(i)*u_d, 4, plus_e)
            call set01_lh058(t - h(i)*t_d, u - h(i)*u_d, 4, minus_e)
            errors(i) = abs((plus_e - minus_e)/(2.0_dp*h(i)) - e_d)
        end do
        call check_fd(errors, ok)
    end subroutine check_case

    subroutine check_fd(errors, ok)
        real(dp), intent(in) :: errors(:)
        logical, intent(inout) :: ok

        if (.not. all(ieee_is_finite(errors))) then
            print '(a)', "FAIL: FD errors are non-finite"
            ok = .false.
            return
        end if
        if (any(errors > 1.0e-8_dp)) then
            print '(a,4(es12.4,1x))', "FAIL: FD errors ", errors
            ok = .false.
            return
        end if
        if (errors(2) >= 0.2_dp*errors(1) .or. &
            minval(errors) >= 0.01_dp*errors(1)) then
            print '(a,4(es12.4,1x))', "FAIL: FD convergence ", errors
            ok = .false.
            return
        end if
        print '(a,4(es12.4,1x))', "fd_errors: ", errors
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
        real(dp) :: t(4), u(4), t_d(4), u_d(4), e, e_d
        real(dp) :: e_b, t_b(4), u_b(4), sink, elapsed

        sink = 0.0_dp
        call system_clock(clock_start, clock_rate)
        do i = 1, repetitions
            t = [1.1_dp, -0.3_dp, 2.0_dp, 0.6_dp] + &
                real(mod(i, 97), dp)*1.0e-5_dp
            u = [0.2_dp, 0.9_dp, -0.8_dp, 1.2_dp] + &
                real(mod(i, 89), dp)*1.0e-5_dp
            t_d = [0.2_dp, -0.15_dp, 0.11_dp, 0.07_dp]
            u_d = [-0.1_dp, 0.04_dp, 0.08_dp, -0.12_dp]
            call lh058_jvp(t, t_d, u, u_d, 4, e, e_d)
            e_b = 0.73_dp
            call lh058_vjp(t, u, 4, e, e_b, t_b, u_b)
            sink = sink + 1.0e-15_dp*(e_d + sum(t_b) + sum(u_b))
        end do
        call system_clock(clock_stop)
        elapsed = real(clock_stop - clock_start, dp)/real(clock_rate, dp)
        print '(a,i0)', "derivative_calls: ", 2*repetitions
        print '(a,es16.8)', "derivative_runtime_seconds: ", elapsed
        print '(a,es16.8)', "ns_per_derivative_call: ", &
            elapsed*1.0e9_dp/real(2*repetitions, dp)
        print '(a,es16.8)', "runtime_sink: ", sink
    end subroutine benchmark_derivatives

end program bench_tapenade_set01_tranche_c
