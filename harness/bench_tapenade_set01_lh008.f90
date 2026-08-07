program bench_tapenade_set01_lh008
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use lh008_forward_ad, only: lh008_jvp
    use lh008_reverse_ad, only: lh008_vjp
    use tapenade_set01_lh008_hand, only: lh008_hand_jvp, lh008_hand_vjp
    implicit none

    real(dp), parameter :: y_initial = 0.73_dp, y_direction = -0.21_dp
    real(dp), parameter :: objective_b = 0.67_dp
    real(dp), parameter :: h(4) = [1.0e-3_dp, 1.0e-4_dp, 1.0e-5_dp, 1.0e-6_dp]
    real(dp) :: y, y_d, x, x_d, z, z_d, objective, objective_d
    real(dp) :: hand_x, hand_x_d, hand_z, hand_z_d
    real(dp) :: hand_objective, hand_objective_d, hand_y_b
    real(dp) :: reverse_y, reverse_x, reverse_z, reverse_objective, reverse_y_b
    real(dp) :: plus_y, minus_y, plus_x, minus_x, plus_z, minus_z
    real(dp) :: plus_objective, minus_objective, fd_errors(4)
    integer :: index
    logical :: passed

    passed = .true.
    y = y_initial
    y_d = y_direction
    call lh008_jvp(y, y_d, x, x_d, z, z_d, objective, objective_d)
    call lh008_hand_jvp(y_initial, y_direction, hand_x, hand_x_d, hand_z, &
        hand_z_d, hand_objective, hand_objective_d)
    call check_close("JVP x", x, hand_x, passed)
    call check_close("JVP x tangent", x_d, hand_x_d, passed)
    call check_close("JVP z", z, hand_z, passed)
    call check_close("JVP z tangent", z_d, hand_z_d, passed)
    call check_close("JVP objective", objective, hand_objective, passed)
    call check_close("JVP objective tangent", objective_d, hand_objective_d, passed)
    call check_close("JVP final y", y, 0.0_dp, passed)
    call check_close("JVP final y tangent", y_d, 0.0_dp, passed)

    reverse_y = y_initial
    call lh008_vjp(reverse_y, reverse_x, reverse_z, reverse_objective, &
        objective_b, reverse_y_b)
    call lh008_hand_vjp(y_initial, objective_b, hand_y_b)
    call check_close("VJP objective", reverse_objective, hand_objective, passed)
    call check_close("VJP y", reverse_y_b, hand_y_b, passed)
    call check_close("adjoint identity", objective_b * objective_d, &
        reverse_y_b * y_direction, passed)

    do index = 1, size(h)
        plus_y = y_initial + h(index) * y_direction
        minus_y = y_initial - h(index) * y_direction
        call set01_lh008(plus_y, plus_x, plus_z, plus_objective)
        call set01_lh008(minus_y, minus_x, minus_z, minus_objective)
        fd_errors(index) = abs((plus_objective - minus_objective) / &
            (2.0_dp * h(index)) - objective_d)
    end do
    if (.not. all(ieee_is_finite(fd_errors)) .or. maxval(fd_errors) > 2.0e-8_dp) then
        print '(a,4(es12.4,1x))', "FAIL: FD errors ", fd_errors
        passed = .false.
    else
        print '(a,4(es12.4,1x))', "fd_errors_objective: ", fd_errors
    end if

    if (.not. passed) error stop "Tapenade set01 lh008 oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_close(name, got, expected, ok)
        character(len=*), intent(in) :: name
        real(dp), intent(in) :: got, expected
        logical, intent(inout) :: ok
        real(dp) :: tolerance

        tolerance = 2.0e-12_dp * max(1.0_dp, abs(expected))
        if (.not. ieee_is_finite(got) .or. abs(got - expected) > tolerance) then
            print '(a,2(es20.10,1x))', "FAIL: "//name//" got/expected ", &
                got, expected
            ok = .false.
        end if
    end subroutine check_close

end program bench_tapenade_set01_lh008
