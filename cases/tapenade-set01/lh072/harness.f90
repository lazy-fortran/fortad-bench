program tapenade_set01_lh072_harness
    use tapenade_set01_lh072_case, only: set01_lh072
    use tapenade_set01_lh072_hand, only: hand_jvp, hand_reverse_a, hand_value
    use lh072_forward_mod, only: lh072_forward
    use lh072_reverse_a_sum_mod, only: lh072_reverse_a_sum
    implicit none

    real, parameter :: tolerance = 4.0e-5
    real :: a_in(10), b_in(10), a_out(10), b_out(10), a_sum
    real :: a_out_h(10), b_out_h(10)
    real :: a_sum_h
    real :: a_in_d(10), b_in_d(10), a_out_d(10), b_out_d(10)
    real :: a_out_d_h(10), b_out_d_h(10)
    real :: a_sum_d, a_sum_d_h
    real :: a_out_r(10), b_out_r(10), a_sum_r
    real :: a_in_b(10), b_in_b(10)
    real :: a_in_b_h(10), b_in_b_h(10), a_out_b(10)
    real :: lhs, rhs
    integer :: i

    do i = 1, 10
        a_in(i) = 0.17 * real(i) - 0.4
        b_in(i) = -0.11 * real(i) + 1.4
        a_in_d(i) = 0.013 * real(i) - 0.03
        b_in_d(i) = -0.009 * real(i) + 0.04
        a_out_b(i) = 0.07 * real(i) - 0.2
    end do

    call hand_value(a_in, b_in, a_out_h, b_out_h, a_sum_h)
    call set01_lh072(a_in, b_in, a_out, b_out, a_sum)
    call assert_array('primal a_out', a_out, a_out_h)
    call assert_array('primal b_out', b_out, b_out_h)
    call assert_scalar('primal a_sum', a_sum, a_sum_h)

    call hand_jvp(a_in, b_in, a_in_d, b_in_d, a_out_h, b_out_h, a_sum_h, &
                  a_out_d_h, b_out_d_h, a_sum_d_h)
    call lh072_forward(a_in, a_in_d, b_in, b_in_d, a_out, a_out_d, &
                       b_out, b_out_d, a_sum, a_sum_d)
    call assert_array('forward a_out', a_out, a_out_h)
    call assert_array('forward b_out', b_out, b_out_h)
    call assert_array('forward a_out_d', a_out_d, a_out_d_h)
    call assert_array('forward b_out_d', b_out_d, b_out_d_h)
    call assert_scalar('forward a_sum', a_sum, a_sum_h)
    call assert_scalar('forward a_sum_d', a_sum_d, a_sum_d_h)

    call hand_reverse_a(a_in, b_in, 0.6, a_in_b_h, b_in_b_h)
    call lh072_reverse_a_sum(a_in, b_in, a_out_r, b_out_r, a_sum_r, 0.6, &
                             a_in_b, b_in_b)
    call assert_array('reverse a_out', a_out_r, a_out_h)
    call assert_array('reverse b_out', b_out_r, b_out_h)
    call assert_scalar('reverse a_sum', a_sum_r, a_sum_h)
    call assert_array('reverse a_in_b', a_in_b, a_in_b_h)
    call assert_array('reverse b_in_b', b_in_b, b_in_b_h)

    lhs = 0.6 * a_sum_d
    rhs = sum(a_in_b * a_in_d) + sum(b_in_b * b_in_d)
    call assert_scalar('adjoint identity', lhs, rhs)

    print '(a)', 'harness_status: pass'
    print '(a,es24.16)', 'forward_a_out_4: ', a_out(4)
    print '(a,es24.16)', 'forward_b_out_4: ', b_out(4)
    print '(a,es24.16)', 'forward_b_out_10: ', b_out(10)
    print '(a,es24.16)', 'forward_a_sum: ', a_sum
    print '(a,es24.16)', 'reverse_a_in_b_4: ', a_in_b(4)
    print '(a,es24.16)', 'reverse_b_in_b_4: ', b_in_b(4)

contains
    subroutine assert_array(label, got, want)
        character(*), intent(in) :: label
        real, intent(in) :: got(10), want(10)

        if (maxval(abs(got - want)) > tolerance) then
            print '(a,es16.7)', 'FAIL '//label//' max_error=', &
                maxval(abs(got - want))
            error stop 1
        end if
    end subroutine assert_array

    subroutine assert_scalar(label, got, want)
        character(*), intent(in) :: label
        real, intent(in) :: got, want

        if (abs(got - want) > tolerance) then
            print '(a,2(es16.7,1x))', 'FAIL '//label//' got/want=', got, want
            error stop 1
        end if
    end subroutine assert_scalar
end program tapenade_set01_lh072_harness
