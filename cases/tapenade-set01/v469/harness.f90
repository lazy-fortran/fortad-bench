program tapenade_set01_v469_harness
    use tapenade_set01_v469_case, only: v469_head
    use v469_port_forward_mod, only: v469_port_forward
    use v469_port_reverse_mod, only: v469_port_reverse
    implicit none

    double precision, parameter :: tolerance = 2.0d-12
    double precision :: x(1), y(1), x_d(1), y_d(1)
    double precision :: y_b(1), x_b(1)
    double precision :: expected_y, expected_y_d, expected_x_b

    x(1) = 0.125d0
    x_d(1) = -0.3d0
    y_b(1) = 0.7d0
    expected_y = sin(2.0d0 * acos(-1.0d0) * x(1))
    expected_y_d = 2.0d0 * acos(-1.0d0) * cos(2.0d0 * acos(-1.0d0) * x(1)) * x_d(1)
    expected_x_b = y_b(1) * 2.0d0 * acos(-1.0d0) * cos(2.0d0 * acos(-1.0d0) * x(1))

    call v469_head(x, y)
    call assert_close('primal', y(1), expected_y)

    y = 0.0d0
    y_d = 0.0d0
    call v469_port_forward(x, x_d, y, y_d)
    call assert_close('forward primal', y(1), expected_y)
    call assert_close('forward tangent', y_d(1), expected_y_d)

    y = 0.0d0
    x_b = 0.0d0
    call v469_port_reverse(x, y, y_b, x_b)
    call assert_close('reverse x adjoint', x_b(1), expected_x_b)

    call assert_close('adjoint identity', y_b(1) * y_d(1), x_b(1) * x_d(1))
    print '(a)', 'harness_status: pass'

contains

    subroutine assert_close(label, got, want)
        character(*), intent(in) :: label
        double precision, intent(in) :: got, want

        if (abs(got - want) > tolerance) then
            print '(a,2(es24.16,1x))', 'FAIL '//label//' got/want=', got, want
            error stop 1
        end if
    end subroutine assert_close

end program tapenade_set01_v469_harness
