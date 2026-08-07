program bench_tapenade_set01_lh026
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use lh026_forward_ad, only: lh026_jvp_generated => lh026_jvp
    use tapenade_set01_lh026_hand, only: lh026_jvp_hand, lh026_vjp_hand, &
        reference_lh026
    implicit none

    interface
        subroutine set01_lh026(a, b)
            import dp
            real(dp), intent(inout) :: a(100), b(100)
        end subroutine set01_lh026
    end interface

    logical :: ok
    real(dp) :: a0(100), b0(100), ad0(100), bd0(100)
    real(dp) :: a(100), b(100), a_ref(100), b_ref(100)
    real(dp) :: ad(100), bd(100), ah(100), bh(100), adh(100), bdh(100)
    real(dp) :: a_seed(100), b_seed(100), a_bar(100), b_bar(100)
    real(dp) :: plus_a(100), plus_b(100), minus_a(100), minus_b(100)
    real(dp) :: objective_plus, objective_minus, objective_tangent
    real(dp) :: h, fd, expected, actual
    integer :: i, step, selected(5)

    ok = .true.
    selected = [1, 4, 10, 50, 100]
    do i = 1, 100
        a0(i) = 0.25_dp + 0.001_dp*i
        b0(i) = 0.20_dp + 0.001_dp*i
        if (i == 4) b0(i) = -0.60_dp
        if (i == 10) b0(i) = -0.70_dp
        ad0(i) = 0.01_dp*sin(real(i, dp))
        bd0(i) = -0.02_dp*cos(real(i, dp))
        a_seed(i) = 0.3_dp*cos(real(i, dp))
        b_seed(i) = -0.2_dp*sin(real(i, dp))
    end do

    a = a0
    b = b0
    a_ref = a0
    b_ref = b0
    call set01_lh026(a, b)
    call reference_lh026(a_ref, b_ref)
    call check_array("lh026 primal a", a, a_ref, ok)
    call check_array("lh026 primal b", b, b_ref, ok)

    ah = a0
    bh = b0
    adh = ad0
    bdh = bd0
    call lh026_jvp_hand(ah, adh, bh, bdh)
    a = a0
    b = b0
    ad = ad0
    bd = bd0
    call lh026_jvp_generated(a, ad, b, bd)
    call check_array("lh026 JVP primal a", a, ah, ok)
    call check_array("lh026 JVP primal b", b, bh, ok)
    call check_array("lh026 JVP a", ad, adh, ok)
    call check_array("lh026 JVP b", bd, bdh, ok)

    call lh026_vjp_hand(a0, b0, a_seed, b_seed, a_bar, b_bar)
    objective_tangent = dot_product(a_seed, adh) + dot_product(b_seed, bdh)
    actual = dot_product(a_bar, ad0) + dot_product(b_bar, bd0)
    call check_close("lh026 adjoint identity", actual, objective_tangent, ok)

    do step = 2, 6
        h = 10.0_dp**(-step)
        plus_a = a0 + h*ad0
        plus_b = b0 + h*bd0
        minus_a = a0 - h*ad0
        minus_b = b0 - h*bd0
        call set01_lh026(plus_a, plus_b)
        call set01_lh026(minus_a, minus_b)
        objective_plus = dot_product(a_seed, plus_a) + &
            dot_product(b_seed, plus_b)
        objective_minus = dot_product(a_seed, minus_a) + &
            dot_product(b_seed, minus_b)
        fd = (objective_plus - objective_minus)/(2.0_dp*h)
        call check_close_tol("lh026 directional finite difference", fd, &
            objective_tangent, 2.0e-6_dp, ok)
    end do

    do i = 1, size(selected)
        plus_a = a0
        plus_b = b0
        minus_a = a0
        minus_b = b0
        h = 1.0e-5_dp
        plus_a(selected(i)) = plus_a(selected(i)) + h
        minus_a(selected(i)) = minus_a(selected(i)) - h
        call set01_lh026(plus_a, plus_b)
        call set01_lh026(minus_a, minus_b)
        expected = (dot_product(a_seed, plus_a) - &
            dot_product(a_seed, minus_a) + dot_product(b_seed, plus_b) - &
            dot_product(b_seed, minus_b))/(2.0_dp*h)
        call check_close_tol("lh026 VJP a component", a_bar(selected(i)), &
            expected, 2.0e-5_dp, ok)

        plus_a = a0
        plus_b = b0
        minus_a = a0
        minus_b = b0
        plus_b(selected(i)) = plus_b(selected(i)) + h
        minus_b(selected(i)) = minus_b(selected(i)) - h
        call set01_lh026(plus_a, plus_b)
        call set01_lh026(minus_a, minus_b)
        expected = (dot_product(a_seed, plus_a) - &
            dot_product(a_seed, minus_a) + dot_product(b_seed, plus_b) - &
            dot_product(b_seed, minus_b))/(2.0_dp*h)
        call check_close_tol("lh026 VJP b component", b_bar(selected(i)), &
            expected, 2.0e-5_dp, ok)
    end do

    if (.not. ok) error stop "Tapenade set01 lh026 oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_close(label, actual, expected, ok)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected
        logical, intent(inout) :: ok

        if (abs(actual - expected) > 3.0e-9_dp*max(1.0_dp, abs(expected))) then
            print '(a,2(1x,es16.8))', "FAIL "//trim(label), actual, expected
            ok = .false.
        end if
    end subroutine check_close

    subroutine check_close_tol(label, actual, expected, tolerance, ok)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected, tolerance
        logical, intent(inout) :: ok

        if (abs(actual - expected) > tolerance*max(1.0_dp, abs(expected))) then
            print '(a,2(1x,es16.8))', "FAIL "//trim(label), actual, expected
            ok = .false.
        end if
    end subroutine check_close_tol

    subroutine check_array(label, actual, expected, ok)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual(:), expected(:)
        logical, intent(inout) :: ok

        call check_close(label, maxval(abs(actual - expected)), 0.0_dp, ok)
    end subroutine check_array

end program bench_tapenade_set01_lh026
