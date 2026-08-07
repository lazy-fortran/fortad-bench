program tapenade_set01_v416_harness
    use tapenade_set01_v416_case, only: set01_v416
    use v416_port_forward_mod, only: v416_port_forward
    use v416_port_reverse_mod, only: v416_port_reverse
    implicit none

    real, parameter :: tolerance = 2.0e-5
    real :: x, y, tm_ha
    real :: x_d, y_d, tm_ha_d
    real :: y_b, x_b, tm_ha_b
    real :: expected_y, expected_y_d, expected_x_b

    x = 1.25
    tm_ha = 0.75
    x_d = -0.2
    tm_ha_d = 0.4
    y_b = 0.6
    expected_y = x * x
    expected_y_d = 2.0 * x * x_d
    expected_x_b = 2.0 * x * y_b

    call set01_v416(x, y, 3, tm_ha)
    call assert_close('primal', y, expected_y)

    y = 0.0
    y_d = 0.0
    call v416_port_forward(x, x_d, y, y_d, 3, tm_ha, tm_ha_d)
    call assert_close('forward primal', y, expected_y)
    call assert_close('forward tangent', y_d, expected_y_d)

    y = 0.0
    x_b = 0.0
    tm_ha_b = 0.0
    call v416_port_reverse(x, y, 3, tm_ha, y_b, x_b, tm_ha_b)
    call assert_close('reverse x adjoint', x_b, expected_x_b)
    call assert_close('reverse tm_ha adjoint', tm_ha_b, 0.0)

    call assert_close('adjoint identity', y_b * y_d, x_b * x_d + tm_ha_b * tm_ha_d)
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

end program tapenade_set01_v416_harness
