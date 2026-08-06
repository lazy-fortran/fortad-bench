program bench_interfaces
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use optional_keyword_kernel, only: evaluate_optional
    use optional_keyword_hand, only: evaluate_optional_hand_jvp
    use optional_keyword_ad, only: evaluate_optional_jvp
    use generic_dispatch_models, only: evaluate_generic
    use generic_dispatch_hand, only: evaluate_generic_hand_jvp
    use complex_real_jacobian_kernel, only: evaluate_complex
    use complex_real_jacobian_hand, only: evaluate_complex_hand_jvp
    implicit none

    real(dp), parameter :: eps = 1.0e-6_dp
    real(dp) :: x, x_d, y, y_d, y_hand, y_hand_d, fd
    real(dp) :: x_plus, x_minus
    real(dp) :: zr, zi, zr_d, zi_d
    complex(dp) :: c, c_hand, c_fd
    complex(dp) :: c_plus, c_minus
    integer :: i, clock_rate, clock_start, clock_stop
    real(dp) :: elapsed, checksum

    x = 1.25_dp
    x_d = -0.7_dp
    call evaluate_optional_jvp(x=x, x_d=x_d, coefficient=4.0_dp, y=y, y_d=y_d)
    call evaluate_optional_hand_jvp(x=x, x_d=x_d, coefficient=4.0_dp, &
        y=y_hand, y_d=y_hand_d)
    x_plus = evaluate_optional(x + eps*x_d, 4.0_dp)
    x_minus = evaluate_optional(x - eps*x_d, 4.0_dp)
    fd = (x_plus - x_minus)/(2.0_dp*eps)
    call require_close("optional present primal", y, 5.0_dp*x, 1.0e-12_dp)
    call require_close("optional present JVP", y_d, 5.0_dp*x_d, 1.0e-12_dp)
    call require_close("optional present hand JVP", y_hand_d, y_d, 1.0e-12_dp)
    call require_close("optional present finite difference", fd, y_d, 1.0e-8_dp)

    call evaluate_optional_jvp(x=x, x_d=x_d, y=y, y_d=y_d)
    call evaluate_optional_hand_jvp(x=x, x_d=x_d, y=y_hand, y_d=y_hand_d)
    x_plus = evaluate_optional(x + eps*x_d)
    x_minus = evaluate_optional(x - eps*x_d)
    fd = (x_plus - x_minus)/(2.0_dp*eps)
    call require_close("optional absent primal", y, x, 1.0e-12_dp)
    call require_close("optional absent JVP", y_d, x_d, 1.0e-12_dp)
    call require_close("optional absent hand JVP", y_hand_d, y_d, 1.0e-12_dp)
    call require_close("optional absent finite difference", fd, y_d, 1.0e-8_dp)

    y = evaluate_generic(x)
    call evaluate_generic_hand_jvp(x, x_d, y_hand, y_hand_d)
    x_plus = evaluate_generic(x + eps*x_d)
    x_minus = evaluate_generic(x - eps*x_d)
    fd = (x_plus - x_minus)/(2.0_dp*eps)
    call require_close("generic primal", y, 5.75_dp*x + 1.5_dp, 1.0e-12_dp)
    call require_close("generic hand JVP", y_hand_d, 5.75_dp*x_d, 1.0e-12_dp)
    call require_close("generic finite difference", fd, y_hand_d, 1.0e-8_dp)

    zr = 0.8_dp
    zi = -1.1_dp
    zr_d = -0.35_dp
    zi_d = 0.6_dp
    call evaluate_complex_hand_jvp(zr, zi, zr_d, zi_d, c, c_hand)
    c_plus = evaluate_complex(zr + eps*zr_d, zi + eps*zi_d)
    c_minus = evaluate_complex(zr - eps*zr_d, zi - eps*zi_d)
    c_fd = (c_plus - c_minus)/(2.0_dp*eps)
    call require_complex_close("complex finite difference", c_hand, c_fd, 1.0e-8_dp)

    call system_clock(count_rate=clock_rate)
    call system_clock(clock_start)
    checksum = 0.0_dp
    do i = 1, 10000000
        c = evaluate_complex(zr + real(i, dp)*1.0e-9_dp, zi)
        checksum = checksum + real(c) + aimag(c)
    end do
    call system_clock(clock_stop)
    elapsed = real(clock_stop - clock_start, dp)/real(clock_rate, dp)
    if (abs(checksum) < 1.0_dp) error stop "unexpected checksum"

    print '(A)', "PASS: optional, generic, and complex hand oracles"
    print '(A,ES24.16)', "optional_value_present=", evaluate_optional(x, 4.0_dp)
    print '(A,ES24.16)', "optional_value_absent=", evaluate_optional(x)
    print '(A,ES24.16)', "generic_value=", evaluate_generic(x)
    print '(A,2ES24.16)', "complex_directional_jvp=", real(c_hand), aimag(c_hand)
    print '(A,ES24.16)', "complex_checksum=", checksum
    print '(A,F12.6)', "complex_ten_million_call_seconds=", elapsed

contains

    subroutine require_close(label, got, expected, tol)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: got, expected, tol
        if (abs(got - expected) > tol) then
            print '(A,2ES24.16)', "FAIL: "//trim(label)//" got/expected=", got, expected
            error stop 1
        end if
    end subroutine require_close

    subroutine require_complex_close(label, got, expected, tol)
        character(len=*), intent(in) :: label
        complex(dp), intent(in) :: got, expected
        real(dp), intent(in) :: tol
        if (abs(got - expected) > tol) then
            print '(A,4ES24.16)', "FAIL: "//trim(label)//" got/expected=", &
                real(got), aimag(got), real(expected), aimag(expected)
            error stop 1
        end if
    end subroutine require_complex_close

end program bench_interfaces
