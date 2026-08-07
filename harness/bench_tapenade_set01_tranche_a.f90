program bench_tapenade_set01_tranche_a
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use set01_lh088_ad, only: set01_lh088_jvp
    use set01_lh088_reverse_ad, only: set01_lh088_vjp
    use tapenade_set01_lh088_hand, only: lh088_hand_jvp, lh088_hand_vjp
    implicit none

    interface
        subroutine set01_lh088(a, b, c, d, total)
            import dp
            real(dp), intent(in) :: a, b, c, d
            real(dp), intent(out) :: total
        end subroutine set01_lh088
    end interface

    logical :: passed
    passed = .true.
    call check_lh088(passed)
    if (.not. passed) error stop "Tapenade set01 tranche A oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_lh088(ok)
        logical, intent(inout) :: ok
        real(dp), parameter :: h(4) = [1.0e-3_dp, 1.0e-4_dp, &
            1.0e-5_dp, 1.0e-6_dp]
        real(dp), parameter :: a = 2.0_dp, a_d = -0.35_dp
        real(dp), parameter :: b = 4.0_dp, b_d = -0.25_dp
        real(dp), parameter :: c = 1.7_dp, c_d = 0.45_dp
        real(dp), parameter :: d = 1.3_dp, d_d = -0.2_dp
        real(dp), parameter :: total_b = -0.7_dp
        real(dp) :: total, total_d
        real(dp) :: hand_total, hand_total_d, reverse_total
        real(dp) :: a_b, b_b, c_b, d_b, hand_a_b, hand_b_b
        real(dp) :: hand_c_b, hand_d_b, plus_total, minus_total
        real(dp) :: errors(size(h)), lhs, rhs
        integer :: i

        call set01_lh088_jvp(a, a_d, b, b_d, c, c_d, d, d_d, total, total_d)
        call lh088_hand_jvp(a, a_d, b, b_d, c, c_d, d, d_d, hand_total, hand_total_d)
        call set01_lh088_vjp(a, b, c, d, reverse_total, total_b, a_b, b_b, c_b, d_b)
        call lh088_hand_vjp(a, b, c, d, total_b, hand_total, hand_a_b, &
            hand_b_b, hand_c_b, hand_d_b)

        call check_close("lh088 total", total, hand_total, ok)
        call check_close("lh088 JVP", total_d, hand_total_d, ok)
        call check_close("lh088 VJP a", a_b, hand_a_b, ok)
        call check_close("lh088 VJP b", b_b, hand_b_b, ok)
        call check_close("lh088 VJP c", c_b, hand_c_b, ok)
        call check_close("lh088 VJP d", d_b, hand_d_b, ok)
        call check_close("lh088 reverse primal", reverse_total, hand_total, ok)

        do i = 1, size(h)
            call set01_lh088(a + h(i)*a_d, b + h(i)*b_d, c + h(i)*c_d, &
                d + h(i)*d_d, plus_total)
            call set01_lh088(a - h(i)*a_d, b - h(i)*b_d, c - h(i)*c_d, &
                d - h(i)*d_d, minus_total)
            errors(i) = abs((plus_total - minus_total)/(2.0_dp*h(i)) - total_d)
        end do
        if (.not. all(ieee_is_finite(errors)) .or. any(errors > 2.0e-7_dp)) then
            print '(a,4(es12.4,1x))', "FAIL: lh088 FD errors ", errors
            ok = .false.
        else
            print '(a,4(es12.4,1x))', "fd_errors_lh088: ", errors
        end if
        lhs = total_b*total_d
        rhs = a_b*a_d + b_b*b_d + c_b*c_d + d_b*d_d
        call check_close("lh088 adjoint identity", lhs, rhs, ok)
    end subroutine check_lh088

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

end program bench_tapenade_set01_tranche_a
