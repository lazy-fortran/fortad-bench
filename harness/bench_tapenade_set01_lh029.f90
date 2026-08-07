program bench_tapenade_set01_lh029
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use lh029_forward_ad, only: lh029_jvp_generated => lh029_jvp
    use lh029_xx_reverse_ad, only: lh029_xx_vjp_generated => lh029_xx_vjp
    use lh029_z_out_reverse_ad, only: lh029_z_out_vjp_generated => lh029_z_out_vjp
    use tapenade_set01_lh029_case, only: set01_lh029
    use tapenade_set01_lh029_hand, only: reference_lh029, lh029_jvp_hand, &
        lh029_vjp_hand
    implicit none

    integer, parameter :: n = 7
    real(dp) :: t0(n), t_d0(n), t_bar(n), t_bar_hand(n), t_bar_gen(n)
    real(dp) :: z0, z_d0, z_bar, z_bar_hand, z_bar_gen
    real(dp) :: xx, xx_ref, xx_d, xx_d_hand, xx_bar
    real(dp) :: z_out, z_out_ref, z_out_d, z_out_d_hand, z_out_bar
    real(dp) :: xx_gen, z_out_gen, h, objective_plus, objective_minus
    real(dp) :: fd, expected, actual
    real(dp) :: t_plus(n), t_minus(n), z_plus, z_minus
    integer :: i
    logical :: ok

    ok = .true.
    do i = 1, n
        t0(i) = 0.25_dp + 0.07_dp*i
        t_d0(i) = (-1.0_dp)**i*0.03_dp + 0.004_dp*i
    end do
    z0 = 2.75_dp
    z_d0 = -0.12_dp
    xx_bar = 0.8_dp
    z_out_bar = -1.3_dp

    call set01_lh029(t0, z0, xx, z_out)
    call reference_lh029(t0, z0, xx_ref, z_out_ref)
    call check_close("primal xx", xx, xx_ref, 2.0e-13_dp, ok)
    call check_close("primal z_out", z_out, z_out_ref, 2.0e-13_dp, ok)

    call lh029_jvp_hand(t0, t_d0, z0, z_d0, xx_ref, xx_d_hand, &
        z_out_ref, z_out_d_hand)
    call lh029_jvp_generated(t0, t_d0, z0, z_d0, xx_gen, xx_d, &
        z_out_gen, z_out_d)
    call check_close("JVP primal xx", xx_gen, xx_ref, 2.0e-13_dp, ok)
    call check_close("JVP primal z_out", z_out_gen, z_out_ref, 2.0e-13_dp, ok)
    call check_close("JVP xx", xx_d, xx_d_hand, 2.0e-13_dp, ok)
    call check_close("JVP z_out", z_out_d, z_out_d_hand, 2.0e-13_dp, ok)

    call lh029_vjp_hand(t0, z0, xx_bar, z_out_bar, t_bar_hand, z_bar_hand)
    call lh029_xx_vjp_generated(t0, z0, xx, z_out, xx_bar, t_bar_gen, z_bar_gen)
    call check_array("VJP xx t", t_bar_gen, t_bar_hand, 2.0e-13_dp, ok)
    call check_close("VJP xx z", z_bar_gen, 0.0_dp, 2.0e-13_dp, ok)

    call lh029_z_out_vjp_generated(t0, z0, xx, z_out, z_out_bar, t_bar, z_bar)
    call check_array("VJP z_out t", t_bar, 0.0_dp*t_bar_hand, 2.0e-13_dp, ok)
    call check_close("VJP z_out z", z_bar, z_bar_hand, 2.0e-13_dp, ok)

    actual = dot_product(t_bar_hand, t_d0) + z_bar_hand*z_d0
    expected = xx_bar*xx_d_hand + z_out_bar*z_out_d_hand
    call check_close("adjoint identity", actual, expected, 2.0e-12_dp, ok)

    do i = 1, n
        h = 1.0e-6_dp
        t_plus = t0
        t_minus = t0
        t_plus(i) = t_plus(i) + h
        t_minus(i) = t_minus(i) - h
        call reference_lh029(t_plus, z0, xx, z_out)
        objective_plus = xx_bar*xx + z_out_bar*z_out
        call reference_lh029(t_minus, z0, xx, z_out)
        objective_minus = xx_bar*xx + z_out_bar*z_out
        fd = (objective_plus - objective_minus)/(2.0_dp*h)
        expected = t_bar_hand(i)
        call check_close("finite difference t", fd, expected, 2.0e-8_dp, ok)
    end do

    h = 1.0e-6_dp
    z_plus = z0 + h
    z_minus = z0 - h
    call reference_lh029(t0, z_plus, xx, z_out)
    objective_plus = xx_bar*xx + z_out_bar*z_out
    call reference_lh029(t0, z_minus, xx, z_out)
    objective_minus = xx_bar*xx + z_out_bar*z_out
    fd = (objective_plus - objective_minus)/(2.0_dp*h)
    call check_close("finite difference z", fd, z_bar_hand, 2.0e-8_dp, ok)

    if (.not. ok) error stop "Tapenade set01 lh029 oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_close(label, actual, expected, tolerance, ok)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected, tolerance
        logical, intent(inout) :: ok

        if (abs(actual - expected) > tolerance*max(1.0_dp, abs(expected))) then
            print '(a,2(1x,es16.8))', "FAIL "//trim(label), actual, expected
            ok = .false.
        end if
    end subroutine check_close

    subroutine check_array(label, actual, expected, tolerance, ok)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual(:), expected(:), tolerance
        logical, intent(inout) :: ok

        call check_close(label, maxval(abs(actual - expected)), 0.0_dp, &
            tolerance, ok)
    end subroutine check_array

end program bench_tapenade_set01_lh029
