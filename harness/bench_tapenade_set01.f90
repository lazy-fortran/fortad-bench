program bench_tapenade_set01
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    use set01_lh023_ad, only: set01_lh023_jvp
    use set01_lh023_reverse_ad, only: set01_lh023_vjp
    use set01_lh032_ad, only: set01_lh032_jvp
    use set01_lh032_reverse_ad, only: set01_lh032_vjp
    use set01_lh134_ad, only: set01_lh134_jvp
    use set01_lh134_reverse_ad, only: set01_lh134_vjp
    use tapenade_set01_hand_derivatives, only: lh023_hand_jvp, &
        lh023_hand_vjp, &
        lh032_hand_jvp, &
        lh032_hand_vjp, &
        lh134_hand_jvp, &
        lh134_hand_vjp
    implicit none

    interface
        subroutine set01_lh023(a, b, c)
            import dp
            real(dp), intent(in) :: a, b
            real(dp), intent(out) :: c
        end subroutine set01_lh023

        subroutine set01_lh032(x, y)
            import dp
            real(dp), intent(in) :: x
            real(dp), intent(out) :: y
        end subroutine set01_lh032

        subroutine set01_lh134(x, f)
            import dp
            real(dp), intent(in) :: x
            real(dp), intent(out) :: f
        end subroutine set01_lh134
    end interface

    logical :: passed

    passed = .true.
    call check_lh023(passed)
    call check_lh032(passed)
    call check_lh134(passed)
    call benchmark_derivatives()

    if (.not. passed) error stop "Tapenade set01 support oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_lh023(ok)
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-2_dp, 1.0e-3_dp, &
            1.0e-4_dp, 1.0e-5_dp]
        real(dp), parameter :: a = 1.3_dp, a_d = 0.4_dp
        real(dp), parameter :: b = -0.7_dp, b_d = -1.1_dp
        real(dp), parameter :: c_b = 0.6_dp
        real(dp) :: c, c_d, hand_c, hand_c_d, reverse_c
        real(dp) :: a_b, b_b, hand_a_b, hand_b_b, plus_c, minus_c
        real(dp) :: errors(size(h)), lhs, rhs
        integer :: i

        call set01_lh023_jvp(a, a_d, b, b_d, c, c_d)
        call lh023_hand_jvp(a, a_d, b, b_d, hand_c, hand_c_d)
        call set01_lh023_vjp(a, b, reverse_c, c_b, a_b, b_b)
        call lh023_hand_vjp(a, b, c_b, hand_c, hand_a_b, hand_b_b)
        call check_close("lh023 primal", c, hand_c, ok)
        call check_close("lh023 reverse primal", reverse_c, hand_c, ok)
        call check_close("lh023 JVP", c_d, hand_c_d, ok)
        call check_close("lh023 VJP a", a_b, hand_a_b, ok)
        call check_close("lh023 VJP b", b_b, hand_b_b, ok)

        do i = 1, size(h)
            call set01_lh023(a + h(i)*a_d, b + h(i)*b_d, plus_c)
            call set01_lh023(a - h(i)*a_d, b - h(i)*b_d, minus_c)
            errors(i) = abs((plus_c - minus_c)/(2.0_dp*h(i)) - c_d)
        end do
        call check_fd("lh023", errors, ok)
        lhs = c_b*c_d
        rhs = a_b*a_d + b_b*b_d
        call check_close("lh023 adjoint identity", lhs, rhs, ok)
    end subroutine check_lh023

    subroutine check_lh032(ok)
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-2_dp, 1.0e-3_dp, &
            1.0e-4_dp, 1.0e-5_dp]
        real(dp), parameter :: x = 1.25_dp, x_d = -0.4_dp, y_b = 0.7_dp
        real(dp) :: y, y_d, hand_y, hand_y_d, reverse_y
        real(dp) :: x_b, hand_x_b, plus_y, minus_y, errors(size(h))
        integer :: i

        call set01_lh032_jvp(x, x_d, y, y_d)
        call lh032_hand_jvp(x, x_d, hand_y, hand_y_d)
        call set01_lh032_vjp(x, reverse_y, y_b, x_b)
        call lh032_hand_vjp(x, y_b, hand_y, hand_x_b)
        call check_close("lh032 primal", y, hand_y, ok)
        call check_close("lh032 reverse primal", reverse_y, hand_y, ok)
        call check_close("lh032 JVP", y_d, hand_y_d, ok)
        call check_close("lh032 VJP", x_b, hand_x_b, ok)

        do i = 1, size(h)
            call set01_lh032(x + h(i)*x_d, plus_y)
            call set01_lh032(x - h(i)*x_d, minus_y)
            errors(i) = abs((plus_y - minus_y)/(2.0_dp*h(i)) - y_d)
        end do
        call check_fd("lh032", errors, ok)
        call check_close("lh032 adjoint identity", y_b*y_d, x_b*x_d, ok)
    end subroutine check_lh032

    subroutine check_lh134(ok)
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-2_dp, 1.0e-3_dp, &
            1.0e-4_dp, 1.0e-5_dp]
        real(dp), parameter :: x = -1.7_dp, x_d = 0.35_dp, f_b = -0.8_dp
        real(dp) :: f, f_d, hand_f, hand_f_d, reverse_f
        real(dp) :: x_b, hand_x_b, plus_f, minus_f, errors(size(h))
        integer :: i

        call set01_lh134_jvp(x, x_d, f, f_d)
        call lh134_hand_jvp(x, x_d, hand_f, hand_f_d)
        call set01_lh134_vjp(x, reverse_f, f_b, x_b)
        call lh134_hand_vjp(x, f_b, hand_f, hand_x_b)
        call check_close("lh134 primal", f, hand_f, ok)
        call check_close("lh134 reverse primal", reverse_f, hand_f, ok)
        call check_close("lh134 JVP", f_d, hand_f_d, ok)
        call check_close("lh134 VJP", x_b, hand_x_b, ok)

        do i = 1, size(h)
            call set01_lh134(x + h(i)*x_d, plus_f)
            call set01_lh134(x - h(i)*x_d, minus_f)
            errors(i) = abs((plus_f - minus_f)/(2.0_dp*h(i)) - f_d)
        end do
        call check_fd("lh134", errors, ok)
        do i = 2, size(errors)
            if (errors(i) >= 0.2_dp*errors(i - 1)) then
                print '(a,4(es12.4,1x))', "FAIL: lh134 FD convergence ", &
                    errors
                ok = .false.
                exit
            end if
        end do
        call check_close("lh134 adjoint identity", f_b*f_d, x_b*x_d, ok)
    end subroutine check_lh134

    subroutine check_fd(name, errors, ok)
        character(len=*), intent(in) :: name
        real(dp), intent(in) :: errors(:)
        logical, intent(inout) :: ok

        if (.not. all(ieee_is_finite(errors))) then
            print '(a)', "FAIL: "//name//" finite-difference produced non-finite"
            ok = .false.
            return
        end if
        if (any(errors > 1.0e-6_dp)) then
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

        tolerance = 1.0e-11_dp*max(1.0_dp, abs(expected))
        if (.not. ieee_is_finite(got)) then
            print '(a,es20.10)', "FAIL: "//name//" non-finite value ", got
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
        real(dp) :: a, b, c, c_d, a_b, b_b
        real(dp) :: x, y, y_d, x_b, f, f_d, sink, elapsed

        sink = 0.0_dp
        call system_clock(clock_start, clock_rate)
        do i = 1, repetitions
            a = 1.0_dp + real(mod(i, 97), dp)*1.0e-5_dp
            b = -0.4_dp + real(mod(i, 89), dp)*1.0e-5_dp
            call set01_lh023_jvp(a, 0.3_dp, b, -0.2_dp, c, c_d)
            call set01_lh023_vjp(a, b, c, 0.7_dp, a_b, b_b)
            x = 1.2_dp + real(mod(i, 83), dp)*1.0e-5_dp
            call set01_lh032_jvp(x, -0.4_dp, y, y_d)
            call set01_lh032_vjp(x, y, 0.6_dp, x_b)
            x = -1.4_dp - real(mod(i, 79), dp)*1.0e-5_dp
            call set01_lh134_jvp(x, 0.25_dp, f, f_d)
            call set01_lh134_vjp(x, f, -0.8_dp, x_b)
            sink = sink + 1.0e-15_dp*(c_d + a_b + b_b + y_d + f_d + x_b)
        end do
        call system_clock(clock_stop)
        elapsed = real(clock_stop - clock_start, dp)/real(clock_rate, dp)
        print '(a,i0)', "derivative_calls: ", 6*repetitions
        print '(a,es16.8)', "derivative_runtime_seconds: ", elapsed
        print '(a,es16.8)', "ns_per_derivative_call: ", &
            elapsed*1.0e9_dp/real(6*repetitions, dp)
        print '(a,es16.8)', "runtime_sink: ", sink
    end subroutine benchmark_derivatives

end program bench_tapenade_set01
