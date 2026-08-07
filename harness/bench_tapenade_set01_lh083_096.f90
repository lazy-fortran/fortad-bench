program bench_tapenade_set01_lh083_096
    use lh085_forward_ad, only: lh085_jvp_generated => lh085_jvp
    use lh085_reverse_ad, only: lh085_vjp_generated => lh085_vjp
    use lh092_forward_ad, only: lh092_jvp_generated => lh092_jvp
    use lh092_reverse_ad, only: lh092_vjp_generated => lh092_vjp
    use tapenade_set01_lh085_092_hand, only: lh085_jvp_hand => lh085_jvp, &
        lh085_vjp_hand => lh085_vjp, lh092_jvp_hand => lh092_jvp, &
        lh092_vjp_hand => lh092_vjp
    implicit none

    logical :: ok
    ok = .true.
    call check_lh085(ok)
    call check_lh092(ok)
    if (.not. ok) error stop "Tapenade set01 lh083-096 oracle failed"
    print '(a)', "oracle_status: pass"

contains

    subroutine check_lh085(ok)
        logical, intent(inout) :: ok
        real(8) :: v(0:100), vd(0:100), vh(0:100), vplus(0:100), vminus(0:100)
        real(8) :: flur1, fltr1, aux1, dpex, e2, dpm, aux2, dpor, v3, v6
        real(8) :: r1, r1d, r2, r2d, rh, rhd, r1b, vb(0:100), vbh(0:100)
        real(8) :: h, fd, objective_tangent
        integer :: i

        do i = 0, 100
            v(i) = 0.2d0 + 0.013d0*i
            vd(i) = -0.04d0 + 0.002d0*i
        end do
        v(0) = 1.1d0
        v(1) = 0.8d0
        v(2) = 0.5d0
        v(4) = 1.2d0
        v(5) = 0.9d0
        v(7) = 0.7d0
        v(8) = 0.4d0
        v(9) = 1.5d0
        v(10) = 1.3d0
        v(11) = 0.7d0
        v(12) = 1.1d0
        v(13) = 0.9d0
        v(14) = 1.2d0
        v(15) = 0.8d0
        aux1 = 0.8d0
        dpex = 1.4d0
        e2 = 2.1d0
        dpm = 1.1d0
        aux2 = -0.6d0
        dpor = 1.7d0

        vh = v
        call lh085_jvp_generated(flur1, fltr1, aux1, dpex, e2, dpm, aux2, dpor, &
            r1, r1d, r2, r2d, v, vd, v3, v6)
        call lh085_jvp_hand(vh, vd, rh, rhd)
        call check_close("lh085 primal", r1, rh, ok)
        call check_close("lh085 JVP", r1d, rhd, ok)

        r1b = 0.37d0
        call lh085_vjp_generated(flur1, fltr1, aux1, dpex, e2, dpm, aux2, dpor, &
            r1, r2, v, v3, v6, r1b, vb)
        call lh085_vjp_hand(v, r1b, vbh)
        call check_array("lh085 VJP", vb, vbh, ok)
        objective_tangent = dot_product(vd, vb)
        call check_close("lh085 adjoint identity", objective_tangent, r1b*r1d, ok)

        h = 1.0d-6
        vplus = v + h*vd
        vminus = v - h*vd
        call primal_lh085(vplus, fd)
        call primal_lh085(vminus, rh)
        call check_close("lh085 finite difference", r1b*(fd-rh)/(2.0d0*h), &
            r1b*r1d, ok)
    end subroutine check_lh085

    subroutine check_lh092(ok)
        logical, intent(inout) :: ok
        real(8) :: a, ad, b, bd, c, cd, ch, chd, cb, ab, bb, abh, bbh
        real(8) :: h, cp, cm

        a = 0.73d0
        b = -0.41d0
        ad = -0.22d0
        bd = 0.31d0
        call lh092_jvp_generated(a, ad, b, bd, c, cd)
        call lh092_jvp_hand(a, ad, b, bd, ch, chd)
        call check_close("lh092 primal", c, ch, ok)
        call check_close("lh092 JVP", cd, chd, ok)

        cb = 0.61d0
        call lh092_vjp_generated(a, b, c, cb, ab, bb)
        call lh092_vjp_hand(a, b, cb, abh, bbh, ch)
        call check_close("lh092 a VJP", ab, abh, ok)
        call check_close("lh092 b VJP", bb, bbh, ok)
        call check_close("lh092 adjoint identity", ab*ad + bb*bd, cb*cd, ok)

        h = 1.0d-6
        call primal_lh092(a+h*ad, b+h*bd, cp)
        call primal_lh092(a-h*ad, b-h*bd, cm)
        call check_close("lh092 finite difference", (cp-cm)/(2.0d0*h), cd, ok)
    end subroutine check_lh092

    subroutine primal_lh085(v, r1)
        real(8), intent(in) :: v(0:100)
        real(8), intent(out) :: r1
        r1 = (v(0)*v(1) + v(2)/2.5d0) * (v(4)*v(5)/(3.5d0+v(7))) + &
            (v(8)*v(9) + v(10)**v(11)) * (v(12)*v(13))**(v(14)*v(15))
    end subroutine primal_lh085

    subroutine primal_lh092(a, b, c)
        real(8), intent(in) :: a, b
        real(8), intent(out) :: c
        c = (1.0d0 - (2.0d0*a-b))**2
    end subroutine primal_lh092

    subroutine check_close(label, actual, expected, ok)
        character(len=*), intent(in) :: label
        real(8), intent(in) :: actual, expected
        logical, intent(inout) :: ok
        if (abs(actual-expected) > 2.0d-10*max(1.0d0, abs(expected))) then
            print '(a,2(1x,es16.8))', "FAIL "//trim(label), actual, expected
            ok = .false.
        end if
    end subroutine check_close

    subroutine check_array(label, actual, expected, ok)
        character(len=*), intent(in) :: label
        real(8), intent(in) :: actual(:), expected(:)
        logical, intent(inout) :: ok
        call check_close(label, maxval(abs(actual-expected)), 0.0d0, ok)
    end subroutine check_array
end program bench_tapenade_set01_lh083_096
