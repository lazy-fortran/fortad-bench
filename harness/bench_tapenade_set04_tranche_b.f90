program bench_tapenade_set04_tranche_b
    use iso_fortran_env, only: real64
    use set04_lh128_jvp_mod, only: set04_lh128_jvp
    use set04_lh151_jvp_mod, only: set04_lh151_jvp
    use set04_lh152_jvp_mod, only: set04_lh152_jvp
    use set04_lh152_vjp_mod, only: set04_lh152_vjp
    implicit none

    interface
        subroutine test(w)
            use iso_fortran_env, only: real64
            real(real64) :: w(0:5)
        end subroutine test
        subroutine MUL(A, B, C)
            complex :: A, C
            real :: B
        end subroutine MUL
        subroutine SATVAP(temp2, eval)
            real :: temp2, eval
        end subroutine SATVAP
    end interface

    call check_lh128()
    call check_lh151()
    call check_lh152()
    write (*, '(a)') 'oracle_status: pass'

contains

    subroutine fail(label)
        character(*), intent(in) :: label
        write (*, '(a)') 'oracle_status: fail: ' // trim(label)
        error stop 1
    end subroutine fail

    subroutine assert_real(label, actual, expected, tolerance)
        character(*), intent(in) :: label
        real(real64), intent(in) :: actual, expected, tolerance
        if (abs(actual - expected) > tolerance * (1.0_real64 + abs(expected))) then
            call fail(label)
        end if
    end subroutine assert_real

    subroutine assert_complex(label, actual, expected, tolerance)
        character(*), intent(in) :: label
        complex, intent(in) :: actual, expected
        real(real64), intent(in) :: tolerance
        if (real(abs(actual - expected), real64) > tolerance * &
                (1.0_real64 + real(abs(expected), real64))) then
            call fail(label)
        end if
    end subroutine assert_complex

    subroutine check_lh128()
        real(real64) :: w(0:5), direction(0:5), actual(0:5)
        real(real64) :: plus(0:5), minus(0:5), finite_difference
        real(real64) :: h, expected

        w = 0.0_real64
        w(1) = 1.7_real64
        direction = 0.0_real64
        direction(1) = 0.4_real64
        h = 1.0e-2_real64
        plus = w + h * direction
        minus = w - h * direction
        call test(plus)
        call test(minus)
        finite_difference = (plus(0) - minus(0)) / (2.0_real64 * h)

        actual = w
        call test(actual)
        expected = w(1) ** 2
        call assert_real('lh128 primal', actual(0), expected, 1.0e-12_real64)

        actual = w
        direction = direction
        call set04_lh128_jvp(actual, direction)
        call assert_real('lh128 central-difference JVP', direction(0), &
            finite_difference, 1.0e-10_real64)
        write (*, '(a)') 'lh128_numerical_oracle: pass'
    end subroutine check_lh128

    subroutine check_lh151()
        complex :: a, direction_a, c, direction_c, c_plus, c_minus
        complex :: finite_difference, expected, expected_direction, d
        real :: b, direction_b
        real(real64) :: h

        a = cmplx(0.7, -0.2)
        direction_a = cmplx(0.2, -0.4)
        b = 1.3
        direction_b = 0.5
        h = 1.0e-2_real64
        d = cmplx(1.0, 10.0)
        call MUL(a, b, c)
        expected = a + b * d
        call assert_complex('lh151 primal', c, expected, 1.0e-6_real64)

        call MUL(a + real(h) * direction_a, b + real(h) * direction_b, c_plus)
        call MUL(a - real(h) * direction_a, b - real(h) * direction_b, c_minus)
        finite_difference = (c_plus - c_minus) / real(2.0_real64 * h)
        expected_direction = direction_a + direction_b * d

        direction_c = cmplx(0.0, 0.0)
        call set04_lh151_jvp(a, direction_a, b, direction_b, c, direction_c)
        call assert_complex('lh151 hand JVP', direction_c, expected_direction, &
            1.0e-6_real64)
        call assert_complex('lh151 central-difference JVP', direction_c, &
            finite_difference, 1.0e-5_real64)
        write (*, '(a)') 'lh151_forward_numerical_oracle: pass'
    end subroutine check_lh151

    subroutine check_lh152()
        real :: points(2), x, direction, eval, eval_plus, eval_minus
        real :: eval_direction, reverse_gradient
        real(real64) :: h, finite_difference
        integer :: i

        points = [230.0, 300.0]
        direction = 0.7
        h = 1.0e-1_real64
        do i = 1, 2
            x = points(i)
            call SATVAP(x + real(h) * direction, eval_plus)
            call SATVAP(x - real(h) * direction, eval_minus)
            finite_difference = real((eval_plus - eval_minus) / real(2.0_real64 * h), real64)

            call set04_lh152_jvp(x, direction, eval, eval_direction)
            call assert_real('lh152 central-difference JVP', real(eval_direction, real64), &
                finite_difference, 3.0e-4_real64)

            call set04_lh152_vjp(x, eval, 1.0, reverse_gradient)
            call assert_real('lh152 reverse scalar adjoint', real(reverse_gradient, real64), &
                finite_difference / real(direction, real64), 3.0e-4_real64)
        end do
        write (*, '(a)') 'lh152_numerical_oracle: pass'
    end subroutine check_lh152

end program bench_tapenade_set04_tranche_b
