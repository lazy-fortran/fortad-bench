program bench_tapenade_set12_modern_tranche_a
    use iso_fortran_env, only: real64
    implicit none

    call check_cmplxstep01_pure_subexpression()
    call check_f03typf01_children()
    call check_f03fptr01_dispatch()
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

    subroutine check_cmplxstep01_pure_subexpression()
        real(real64) :: a, b, ad, bd, value, tangent, reverse_a, reverse_b
        real(real64) :: seed
        a = 1.7_real64
        b = 2.4_real64
        ad = -0.3_real64
        bd = 0.6_real64
        value = b * b + 2.0_real64 * a * a
        tangent = 4.0_real64 * a * ad + 2.0_real64 * b * bd
        seed = 0.8_real64
        reverse_a = seed * 4.0_real64 * a
        reverse_b = seed * 2.0_real64 * b
        call assert_real('cmplxstep01 primal pure subexpression', value, 11.54_real64, 1.0e-13_real64)
        call assert_real('cmplxstep01 hand JVP', tangent, 0.84_real64, 1.0e-13_real64)
        call assert_real('cmplxstep01 hand VJP a', reverse_a, 5.44_real64, 1.0e-13_real64)
        call assert_real('cmplxstep01 hand VJP b', reverse_b, 3.84_real64, 1.0e-13_real64)
        call assert_real('cmplxstep01 adjoint identity', seed * tangent, reverse_a * ad + reverse_b * bd, 1.0e-13_real64)
    end subroutine check_cmplxstep01_pure_subexpression

    subroutine check_f03typf01_children()
        real(real64) :: x, xd, y1, y2, yd1, yd2, y1b, y2b, yb
        x = 1.7_real64
        xd = -0.4_real64
        y1 = 2.0_real64 * x
        y2 = x * x + 3.0_real64 * x
        yd1 = 2.0_real64 * xd
        yd2 = (2.0_real64 * x + 3.0_real64) * xd
        yb = 0.8_real64
        y1b = yb * 2.0_real64
        y2b = yb * (2.0_real64 * x + 3.0_real64)
        call assert_real('f03typf01 child 1 primal', y1, 3.4_real64, 1.0e-13_real64)
        call assert_real('f03typf01 child 2 primal', y2, 7.99_real64, 1.0e-13_real64)
        call assert_real('f03typf01 child 1 JVP', yd1, -0.8_real64, 1.0e-13_real64)
        call assert_real('f03typf01 child 2 JVP', yd2, -2.56_real64, 1.0e-13_real64)
        call assert_real('f03typf01 child 1 adjoint identity', yb * yd1, y1b * xd, 1.0e-13_real64)
        call assert_real('f03typf01 child 2 adjoint identity', yb * yd2, y2b * xd, 1.0e-13_real64)
    end subroutine check_f03typf01_children

    subroutine check_f03fptr01_dispatch()
        real(real64) :: x, xd, y1, y2, yd1, yd2, yb
        x = 1.7_real64
        xd = 0.25_real64
        y1 = x
        y2 = 2.0_real64 * x
        yd1 = xd
        yd2 = 2.0_real64 * xd
        yb = -0.6_real64
        call assert_real('f03fptr01 procedure 1 primal', y1, 1.7_real64, 1.0e-13_real64)
        call assert_real('f03fptr01 procedure 2 primal', y2, 3.4_real64, 1.0e-13_real64)
        call assert_real('f03fptr01 procedure 1 JVP', yd1, 0.25_real64, 1.0e-13_real64)
        call assert_real('f03fptr01 procedure 2 JVP', yd2, 0.5_real64, 1.0e-13_real64)
        call assert_real('f03fptr01 procedure 1 adjoint', yb, -0.6_real64, 1.0e-13_real64)
        call assert_real('f03fptr01 procedure 2 adjoint', yb * 2.0_real64, -1.2_real64, 1.0e-13_real64)
    end subroutine check_f03fptr01_dispatch

end program bench_tapenade_set12_modern_tranche_a
