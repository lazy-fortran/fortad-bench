program tapenade_set01_v526_harness
    use tapenade_set01_v526_case, only: v526_sing3
    use v526_port_forward_mod, only: v526_port_forward
    use v526_port_reverse_mod, only: v526_port_reverse
    implicit none

    double precision, parameter :: tolerance = 2.0d-12
    double precision :: dxp(1), dyp_initial(1), dyp(1), dxp_d(1), dyp_initial_d(1), dyp_d(1)
    double precision :: dyp_b(1), dxp_b(1), dyp_initial_b(1)

    dxp(1) = 1.25d0
    dyp_initial(1) = -0.75d0
    dxp_d(1) = -0.3d0
    dyp_initial_d(1) = 0.4d0
    dyp_d(1) = 0.4d0
    dyp_b(1) = 0.7d0

    call v526_sing3(dxp, dyp_initial, dyp, 1)
    call assert_close('active primal', dyp(1), 1.25d0 * 1.25d0)

    call v526_port_forward(dxp, dxp_d, dyp_initial, dyp_initial_d, dyp, dyp_d, 1)
    call assert_close('active forward primal', dyp(1), 1.25d0 * 1.25d0)
    call assert_close('active forward tangent', dyp_d(1), 2.0d0 * 1.25d0 * (-0.3d0))

    dxp_b(1) = 0.0d0
    dyp(1) = 0.0d0
    call v526_port_reverse(dxp, dyp_initial, dyp, 1, dyp_b, dxp_b, dyp_initial_b)
    call assert_close('active reverse adjoint', dxp_b(1), dyp_b(1) * 2.0d0 * 1.25d0)
    call assert_close('active adjoint identity', dyp_b(1) * dyp_d(1), dxp_b(1) * dxp_d(1))

    call v526_sing3(dxp, dyp_initial, dyp, 0)
    call assert_close('inactive primal', dyp(1), -0.75d0)

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

end program tapenade_set01_v526_harness
