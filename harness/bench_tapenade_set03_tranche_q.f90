program bench_tapenade_set03_tranche_q
    use tapenade_set03_ht13_hand
    use ht13_jvp_mod
    use ht13_vjp_mod
    implicit none

    real :: x, x_d, y, y_d, x_b, y_b
    real :: hand_y, hand_y_d, hand_x_b, finite_difference
    real, parameter :: toler = 5.0e-5
    real, parameter :: steps(3) = [1.0e-2, 1.0e-3, 1.0e-4]
    integer :: i

    x = 1.7
    x_d = -0.35
    y = 0.0
    y_d = 0.0
    call ht13_jvp(x, x_d, y, y_d)
    call ht13_hand_jvp(1.7, -0.35, hand_y, hand_y_d)
    call assert_close("ht13 JVP primal", y, hand_y, toler)
    call assert_close("ht13 JVP tangent", y_d, hand_y_d, toler)

    y_b = 0.63
    y = 0.0
    x_b = 0.0
    call ht13_vjp(1.7, y, y_b, x_b)
    call ht13_hand_vjp(1.7, y_b, hand_x_b)
    call assert_close("ht13 VJP primal", y, hand_y, toler)
    call assert_close("ht13 VJP adjoint", x_b, hand_x_b, toler)

    do i = 1, size(steps)
        finite_difference = (square(1.7 + steps(i)) - square(1.7 - steps(i))) &
            / (2.0 * steps(i))
        call assert_close("ht13 central difference", finite_difference, 3.4, &
            2.0e-3)
    end do

    call assert_close("ht13 adjoint identity", y_b * hand_y_d, &
        hand_x_b * (-0.35), toler)
    print "(A)", "oracle_status: pass"

contains

    real function square(value)
        real, intent(in) :: value
        square = value * value
    end function square

    subroutine assert_close(label, actual, expected, tolerance)
        character(len=*), intent(in) :: label
        real, intent(in) :: actual, expected, tolerance
        if (abs(actual - expected) > tolerance) then
            error stop label // ": mismatch"
        end if
    end subroutine assert_close
end program bench_tapenade_set03_tranche_q
