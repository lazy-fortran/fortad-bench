program bench_tapenade_set01_tranche_l
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use lh017_forward_ad, only: lh017_jvp_generated => lh017_jvp
    use lh017_reverse_b1_ad, only: lh017_vjp_b1
    use lh017_reverse_b2_ad, only: lh017_vjp_b2
    use lh022_forward_ad, only: lh022_jvp_generated => lh022_jvp
    use lh028_forward_ad, only: lh028_jvp_generated => lh028_jvp
    use tapenade_set01_tranche_l_hand, only: lh017_jvp_hand => lh017_jvp, &
        lh022_jvp_hand => lh022_jvp, lh022_primal, lh022_vjp, &
        lh028_jvp_hand => lh028_jvp, lh028_primal, lh028_vjp
    implicit none

    logical :: ok

    interface
        subroutine set01_lh017(a1, a2, branch, b1, b2)
            import dp
            real(dp), intent(in) :: a1, a2
            integer, intent(in) :: branch
            real(dp), intent(out) :: b1, b2
        end subroutine set01_lh017
        subroutine set01_lh022(x, y)
            import dp
            real(dp), intent(inout) :: x(100), y(100)
        end subroutine set01_lh022
        subroutine set01_lh028(a, b)
            import dp
            real(dp), intent(inout) :: a(100), b(100)
        end subroutine set01_lh028
    end interface

    ok = .true.
    call check_lh017(ok)
    call check_lh022(ok)
    call check_lh028(ok)
    if (.not. ok) error stop "Tapenade set01 tranche L oracle failed"
    print '(a)', "oracle_status: pass"

contains
    subroutine check_lh017(ok)
        logical, intent(inout) :: ok
        real(dp), parameter :: a1_0 = 1.3_dp, a2_0 = -0.7_dp
        real(dp), parameter :: a1d = 0.2_dp, a2d = -0.4_dp
        real(dp), parameter :: b1_seed = 0.73_dp, b2_seed = -0.41_dp
        real(dp) :: a1, a2, b1, b2, b1d, b2d
        real(dp) :: hb1, hb2, hb1d, hb2d, a1b, a2b
        real(dp) :: hb1b, hb2b, plus, minus, fd, h
        integer :: branch

        do branch = -1, 42, 43
            a1 = a1_0
            a2 = a2_0
            call lh017_jvp_generated(a1, a1d, a2, a2d, branch, b1, b1d, b2, b2d)
            call lh017_jvp_hand(a1_0, a1d, a2_0, a2d, branch, hb1, hb1d, hb2, hb2d)
            call check_close("lh017 JVP b1", b1, hb1, ok)
            call check_close("lh017 JVP b2", b2, hb2, ok)
            call check_close("lh017 JVP b1d", b1d, hb1d, ok)
            call check_close("lh017 JVP b2d", b2d, hb2d, ok)

            a1 = a1_0
            a2 = a2_0
            call lh017_vjp_b1(a1, a2, branch, b1, b2, b1_seed, a1b, a2b)
            call lh017_vjp_b2(a1, a2, branch, b1, b2, b2_seed, hb1b, hb2b)
            if (branch > 37) then
                call check_close("lh017 b1 reverse a1", a1b, b1_seed*(2*a1_0*a2_0+1), ok)
                call check_close("lh017 b1 reverse a2", a2b, b1_seed*a1_0**2, ok)
                call check_close("lh017 b2 reverse a1", hb1b, 0.0_dp, ok)
                call check_close("lh017 b2 reverse a2", hb2b, 0.0_dp, ok)
            else
                call check_close("lh017 b1 reverse a1", a1b, 0.0_dp, ok)
                call check_close("lh017 b1 reverse a2", a2b, 0.0_dp, ok)
                call check_close("lh017 b2 reverse a1", hb1b, b2_seed*3*a1_0**2, ok)
                call check_close("lh017 b2 reverse a2", hb2b, 0.0_dp, ok)
            end if
            call check_close("lh017 adjoint identity", b1_seed*b1d+b2_seed*b2d, &
                a1b*a1d+a2b*a2d+hb1b*a1d+hb2b*a2d, ok)

            h = 1.0e-5_dp
            call set01_lh017(a1_0+h*a1d, a2_0+h*a2d, branch, plus, hb2)
            call set01_lh017(a1_0-h*a1d, a2_0-h*a2d, branch, minus, hb2)
            fd = (b1_seed*(plus-minus))/(2*h)
            if (abs(fd-b1_seed*b1d) > 2.0e-8_dp) ok = .false.
        end do
    end subroutine check_lh017

    subroutine check_lh022(ok)
        logical, intent(inout) :: ok
        real(dp) :: x(100), y(100), xd(100), yd(100), sx(100), sy(100)
        real(dp) :: x0(100), y0(100), xd0(100), yd0(100)
        real(dp) :: hx(100), hy(100), hxd(100), hyd(100), xb(100), yb(100)
        real(dp) :: plus_x(100), plus_y(100), minus_x(100), minus_y(100)
        real(dp) :: objective_plus, objective_minus, objective_tangent, h
        integer :: i

        do i = 1, 100
            x(i) = 0.20_dp+0.001_dp*i
            y(i) = 0.30_dp+0.0007_dp*i
            xd(i) = 0.01_dp*sin(real(i, dp))
            yd(i) = -0.02_dp*cos(real(i, dp))
            sx(i) = 0.3_dp*sin(real(i, dp))
            sy(i) = -0.2_dp*cos(real(i, dp))
        end do
        x0 = x
        y0 = y
        xd0 = xd
        yd0 = yd
        hx = x
        hy = y
        hxd = xd
        hyd = yd
        call lh022_jvp_generated(x, xd, y, yd)
        call lh022_jvp_hand(hx, hxd, hy, hyd)
        call check_array("lh022 primal x", x, hx, ok)
        call check_array("lh022 primal y", y, hy, ok)
        call check_array("lh022 JVP x", xd, hxd, ok)
        call check_array("lh022 JVP y", yd, hyd, ok)

        xb = sx
        yb = sy
        call lh022_vjp(x0, y0, xb, yb)
        objective_tangent = dot_product(sx, xd)+dot_product(sy, yd)
        call check_close("lh022 adjoint identity", objective_tangent, &
            dot_product(xb, xd0)+dot_product(yb, yd0), ok)

        h = 1.0e-5_dp
        plus_x = x*0.0_dp
        plus_y = y*0.0_dp
        do i = 1, 100
            plus_x(i) = 0.20_dp+0.001_dp*i+h*xd0(i)
            plus_y(i) = 0.30_dp+0.0007_dp*i+h*yd0(i)
            minus_x(i) = 0.20_dp+0.001_dp*i-h*xd0(i)
            minus_y(i) = 0.30_dp+0.0007_dp*i-h*yd0(i)
        end do
        call set01_lh022(plus_x, plus_y)
        call set01_lh022(minus_x, minus_y)
        objective_plus = dot_product(sx, plus_x)+dot_product(sy, plus_y)
        objective_minus = dot_product(sx, minus_x)+dot_product(sy, minus_y)
        call check_close("lh022 finite difference", (objective_plus-objective_minus)/(2*h), &
            objective_tangent, ok)
    end subroutine check_lh022

    subroutine check_lh028(ok)
        logical, intent(inout) :: ok
        real(dp) :: a(100), b(100), ad(100), bd(100), sa(100), sb(100)
        real(dp) :: a0(100), b0(100), ad0(100), bd0(100)
        real(dp) :: ha(100), hb(100), had(100), hbd(100), ab(100), bb(100)
        real(dp) :: plus_a(100), plus_b(100), minus_a(100), minus_b(100)
        real(dp) :: objective_plus, objective_minus, objective_tangent, h
        integer :: i

        do i = 1, 100
            if (mod(i, 2) == 0) then
                a(i) = 0.7_dp+0.001_dp*i
                b(i) = 0.4_dp+0.002_dp*i
            else
                a(i) = -0.7_dp-0.001_dp*i
                b(i) = -0.4_dp-0.002_dp*i
            end if
            ad(i) = 0.01_dp*sin(real(i, dp))
            bd(i) = -0.02_dp*cos(real(i, dp))
            sa(i) = 0.3_dp*sin(real(i, dp))
            sb(i) = -0.2_dp*cos(real(i, dp))
        end do
        a0 = a
        b0 = b
        ad0 = ad
        bd0 = bd
        ha = a
        hb = b
        had = ad
        hbd = bd
        call lh028_jvp_generated(a, ad, b, bd)
        call lh028_jvp_hand(ha, had, hb, hbd)
        call check_array("lh028 primal a", a, ha, ok)
        call check_array("lh028 primal b", b, hb, ok)
        call check_array("lh028 JVP a", ad, had, ok)
        call check_array("lh028 JVP b", bd, hbd, ok)

        ab = sa
        bb = sb
        call lh028_vjp(a0, b0, ab, bb)
        objective_tangent = dot_product(sa, ad)+dot_product(sb, bd)
        call check_close("lh028 adjoint identity", objective_tangent, &
            dot_product(ab, ad0)+dot_product(bb, bd0), ok)

        h = 1.0e-5_dp
        do i = 1, 100
            plus_a(i) = (merge(0.7_dp+0.001_dp*i, -0.7_dp-0.001_dp*i, mod(i,2)==0))+h*ad0(i)
            plus_b(i) = (merge(0.4_dp+0.002_dp*i, -0.4_dp-0.002_dp*i, mod(i,2)==0))+h*bd0(i)
            minus_a(i) = plus_a(i)-2*h*ad0(i)
            minus_b(i) = plus_b(i)-2*h*bd0(i)
        end do
        call set01_lh028(plus_a, plus_b)
        call set01_lh028(minus_a, minus_b)
        objective_plus = dot_product(sa, plus_a)+dot_product(sb, plus_b)
        objective_minus = dot_product(sa, minus_a)+dot_product(sb, minus_b)
        call check_close("lh028 finite difference", (objective_plus-objective_minus)/(2*h), &
            objective_tangent, ok)
    end subroutine check_lh028

    subroutine check_close(label, actual, expected, ok)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected
        logical, intent(inout) :: ok
        if (abs(actual-expected) > 3.0e-9_dp*max(1.0_dp, abs(expected))) then
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
end program bench_tapenade_set01_tranche_l
