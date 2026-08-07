program bench_tapenade_set01_lh070_082
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use lh074_forward_ad, only: lh074_jvp_generated => lh074_jvp
    use lh080_forward_ad, only: lh080_jvp_generated => lh080_jvp
    use lh082_forward_ad, only: lh082_jvp_generated => lh082_jvp
    use tapenade_set01_lh074_hand, only: lh074_jvp_hand => lh074_jvp, &
        lh074_vjp_hand => lh074_vjp
    use tapenade_set01_lh080_hand, only: lh080_jvp_hand => lh080_jvp, &
        lh080_vjp_hand => lh080_vjp
    use tapenade_set01_lh082_hand, only: lh082_primal_hand => lh082_primal
    implicit none

    logical :: ok
    ok = .true.
    call check_lh074(ok)
    call check_lh080(ok)
    call check_lh082(ok)
    if (.not. ok) error stop "Tapenade set01 lh070-082 oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_lh074(ok)
        logical, intent(inout) :: ok
        real(dp) :: a, b, ad, bd, chem(2), chemd(2), h
        real(dp) :: ha, hb, hchem(2), hchemd(2), chemb(2), ab, bb
        real(dp) :: plus(2), minus(2), objective_tangent

        a = 0.63_dp
        b = -1.17_dp
        ad = 0.21_dp
        bd = -0.34_dp
        chem = [0.8_dp, -1.2_dp]
        chemd = 0.0_dp
        call lh074_jvp_generated(a, ad, b, bd, chem, chemd)
        hchem = [0.8_dp, -1.2_dp]
        hchemd = 0.0_dp
        call lh074_jvp_hand(0.63_dp, ad, -1.17_dp, bd, hchem, hchemd)
        call check_array("lh074 primal", chem, hchem, ok)
        call check_array("lh074 JVP", chemd, hchemd, ok)

        chemb = [0.37_dp, -0.22_dp]
        call lh074_vjp_hand(0.63_dp, -1.17_dp, chemb, ab, bb)
        objective_tangent = dot_product(chemb, chemd)
        call check_close("lh074 adjoint identity", objective_tangent, &
            ab*ad + bb*bd, ok)

        h = 1.0e-6_dp
        call primal_lh074(0.63_dp + h*ad, -1.17_dp + h*bd, plus)
        call primal_lh074(0.63_dp - h*ad, -1.17_dp - h*bd, minus)
        call check_close("lh074 finite difference", &
            dot_product(chemb, (plus-minus)/(2.0_dp*h)), objective_tangent, ok)
    end subroutine check_lh074

    subroutine check_lh080(ok)
        logical, intent(inout) :: ok
        real(dp) :: a, ad, b, bd, hb, hbd, bb, ab, h
        real(dp) :: plus, minus

        a = 0.73_dp
        ad = -0.22_dp
        call lh080_jvp_generated(a, ad, b, bd)
        call lh080_jvp_hand(0.73_dp, ad, hb, hbd)
        call check_close("lh080 primal", b, hb, ok)
        call check_close("lh080 JVP", bd, hbd, ok)
        bb = 0.41_dp
        call lh080_vjp_hand(0.73_dp, b, bb, ab)
        call check_close("lh080 adjoint identity", bb*bd, ab*ad, ok)

        h = 1.0e-6_dp
        call primal_lh080(0.73_dp + h*ad, plus)
        call primal_lh080(0.73_dp - h*ad, minus)
        call check_close("lh080 finite difference", bb*(plus-minus)/(2.0_dp*h), &
            bb*bd, ok)
    end subroutine check_lh080

    subroutine check_lh082(ok)
        logical, intent(inout) :: ok
        integer, parameter :: n = 0
        real(dp) :: a(1:8), ad(1:8), ha(1:8), had(1:8), seed(1:8)
        real(dp) :: x, h, plus(1:8), minus(1:8), objective_tangent
        integer :: i

        do i = 1, 8
            a(i) = 0.2_dp + 0.07_dp*i
            ad(i) = -0.03_dp + 0.01_dp*i
            seed(i) = 0.11_dp - 0.02_dp*i
        end do
        x = 0.91_dp
        ha = a
        call lh082_primal_hand(ha, n, x)
        call lh082_jvp_generated(a, ad, n, x)
        had = ad
        had(5) = 0.0_dp
        had(4) = 8.0_dp*ad(3)
        call check_array("lh082 primal", a, ha, ok)
        call check_array("lh082 JVP", ad, had, ok)

        objective_tangent = dot_product(seed, ad)
        h = 1.0e-6_dp
        plus = a
        minus = a
        call lh082_primal_hand(plus, n, x)
        call lh082_primal_hand(minus, n, x)
        ! The n=0 bounded probe has no loop body.  Re-run from the original
        ! state with opposite active-array perturbations for an FD check.
        do i = 1, 8
            plus(i) = (0.2_dp + 0.07_dp*i) + h*ad(i)
            minus(i) = (0.2_dp + 0.07_dp*i) - h*ad(i)
        end do
        call lh082_primal_hand(plus, n, x)
        call lh082_primal_hand(minus, n, x)
        call check_close("lh082 finite difference", &
            dot_product(seed, (plus-minus)/(2.0_dp*h)), objective_tangent, ok)
    end subroutine check_lh082

    subroutine primal_lh074(a, b, chem)
        real(dp), intent(in) :: a, b
        real(dp), intent(out) :: chem(2)
        chem = [0.8_dp, -1.2_dp]
        chem(1) = chem(1) - a*b
        chem(2) = chem(2) - a - b
    end subroutine primal_lh074

    subroutine primal_lh080(a, b)
        real(dp), intent(in) :: a
        real(dp), intent(out) :: b
        b = 3.0_dp*a
    end subroutine primal_lh080

    subroutine check_close(label, actual, expected, ok)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected
        logical, intent(inout) :: ok
        if (abs(actual-expected) > 2.0e-8_dp*max(1.0_dp, abs(expected))) then
            print '(a,2(1x,es16.8))', "FAIL "//trim(label), actual, expected
            ok = .false.
        end if
    end subroutine check_close

    subroutine check_array(label, actual, expected, ok)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual(:), expected(:)
        logical, intent(inout) :: ok
        call check_close(label, maxval(abs(actual-expected)), 0.0_dp, ok)
    end subroutine check_array
end program bench_tapenade_set01_lh070_082
