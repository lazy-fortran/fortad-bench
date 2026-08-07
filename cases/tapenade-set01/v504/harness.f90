program tapenade_set01_v504_harness
    use v504_port_forward_mod, only: v504_port_forward
    use v504_port_reverse_mod, only: v504_port_reverse
    implicit none

    interface
        subroutine set01_v504(r, s, top)
            real, intent(in) :: r(2), s(2)
            real, intent(out) :: top
        end subroutine set01_v504
    end interface

    real, parameter :: tolerance = 2.0e-5
    real :: r(2), s(2), rd(2), sd(2)
    real :: top, top_d, top_b, rb(2), sb(2)
    real :: expected_top, expected_top_d, expected_r_b(2)

    r = [3.0, 2.0]
    s = [0.0, 0.0]
    rd = [-0.25, 0.5]
    sd = [1.5, -2.0]
    expected_top = 4.0 * r(1) * r(2)
    expected_top_d = 4.0 * (rd(1) * r(2) + r(1) * rd(2))
    top_b = 1.75
    expected_r_b = [4.0 * r(2) * top_b, 4.0 * r(1) * top_b]

    call set01_v504(r, s, top)
    call assert_close('primal', top, expected_top)

    top = 0.0
    top_d = 0.0
    call v504_port_forward(r, rd, s, sd, top, top_d)
    call assert_close('forward primal', top, expected_top)
    call assert_close('forward tangent', top_d, expected_top_d)

    rb = 0.0
    sb = 0.0
    call v504_port_reverse(r, s, top, top_b, rb, sb)
    call assert_close('reverse r(1) adjoint', rb(1), expected_r_b(1))
    call assert_close('reverse r(2) adjoint', rb(2), expected_r_b(2))
    call assert_close('reverse s(1) adjoint', sb(1), 0.0)
    call assert_close('reverse s(2) adjoint', sb(2), 0.0)
    call assert_close('adjoint identity', top_b * top_d, sum(rb * rd + sb * sd))

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

end program tapenade_set01_v504_harness
