program bench_tapenade_set12_profile_tranche
    use set12_profile01_jvp_mod, only: foo_jvp
    use set12_profile01_vjp_mod, only: foo_vjp
    implicit none
    real :: a, a_d, b, b_d, c, c_d, eps, c_plus, c_minus
    real :: a_b, b_b, c_b

    a = 1.7
    b = 2.4
    a_d = -0.3
    b_d = 0.6
    c = 0.0
    c_d = 0.0
    call foo_jvp(a, a_d, b, b_d, c, c_d)
    call assert_close('jvp a', a_d, 2.0 * 1.7 * (-0.3))
    call assert_close('jvp c', c_d, 2.0 * 0.6)

    eps = 1.0e-2
    c_plus = 2.0 * (b + eps * b_d)
    c_minus = 2.0 * (b - eps * b_d)
    call assert_close('finite difference c', (c_plus - c_minus) / (2.0 * eps), c_d)

    c_b = -0.4
    a_b = -99.0
    b_b = -99.0
    c = 0.0
    call foo_vjp(a, b, c, c_b, a_b, b_b)
    call assert_close('vjp a', a_b, 0.0)
    call assert_close('vjp b', b_b, 2.0 * c_b)
    call assert_close('adjoint identity', 0.8 * a_d + c_b * c_d, &
                      (0.8 * 2.0 * 1.7) * (-0.3) + (2.0 * c_b) * 0.6)
    write (*, '(a)') 'oracle_status: pass'

contains

    subroutine assert_close(label, actual, expected)
        character(*), intent(in) :: label
        real, intent(in) :: actual, expected
        if (abs(actual - expected) > 2.0e-5 * (1.0 + abs(expected))) then
            error stop 'oracle failure: ' // label
        end if
    end subroutine assert_close

end program bench_tapenade_set12_profile_tranche
