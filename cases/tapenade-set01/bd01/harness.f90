program tapenade_set01_bd01_harness
    use tapenade_set01_bd01_case, only: set01_bd01
    use tapenade_set01_bd01_hand, only: hand_value, hand_forward, hand_reverse
    use bd01_forward_mod, only: bd01_forward
    use bd01_reverse_mod, only: bd01_reverse
    implicit none

    real, parameter :: tolerance = 5.0e-6
    real :: a, b, c, a_out_hand
    real :: a_d, b_d, c_d, a_d_hand
    real :: a_b, b_b, c_b, b_b_hand, c_b_hand
    real :: lhs, rhs

    a = 0.3
    b = 1.25
    c = -0.75
    a_d = 0.07
    b_d = -0.02
    c_d = 0.11
    a_b = 0.6

    call hand_value(a, b, c, a_out_hand)
    call set01_bd01(a, b, c)
    call assert_close('primal', a, a_out_hand)

    call hand_forward(a, b, c, a_d, b_d, c_d, a_out_hand, a_d_hand)
    call bd01_forward(a, a_d, b, b_d, c, c_d)
    call assert_close('forward primal', a, a_out_hand)
    call assert_close('forward tangent', a_d, a_d_hand)

    call hand_reverse(a, b, c, a_b, b_b_hand, c_b_hand, a_out_hand)
    call bd01_reverse(a, b, c, a_b, b_b, c_b)
    call assert_close('reverse primal', a, a_out_hand)
    call assert_close('reverse b adjoint', b_b, b_b_hand)
    call assert_close('reverse c adjoint', c_b, c_b_hand)

    lhs = a_b * a_d_hand
    rhs = b_b * b_d + c_b * c_d
    call assert_close('adjoint identity', lhs, rhs)
    print '(a)', 'harness_status: pass'

contains

    subroutine assert_close(label, got, want)
        character(*), intent(in) :: label
        real, intent(in) :: got, want
        if (abs(got - want) > tolerance) then
            print '(a,2(es16.7,1x))', 'FAIL '//label//' got/want=', got, want
            error stop 1
        end if
    end subroutine assert_close

end program tapenade_set01_bd01_harness
