! Independent analytic JVP/VJP oracles for the lh085 and lh092 ports.
module tapenade_set01_lh085_092_hand
    implicit none
contains
    subroutine lh085_jvp(v, vd, r1, r1d)
        real(8), intent(in) :: v(0:100), vd(0:100)
        real(8), intent(out) :: r1, r1d
        real(8) :: a, ad, s, sd, t, td, u, ud, base, based, w, wd
        real(8) :: p, pd

        a = v(0)*v(1) + v(2)/2.5d0
        ad = vd(0)*v(1) + v(0)*vd(1) + vd(2)/2.5d0
        s = v(4)*v(5)/(3.5d0 + v(7))
        sd = ((vd(4)*v(5) + v(4)*vd(5))*(3.5d0 + v(7)) - &
            v(4)*v(5)*vd(7))/(3.5d0 + v(7))**2
        p = v(10)**v(11)
        pd = p*(vd(11)*log(v(10)) + v(11)*vd(10)/v(10))
        t = v(8)*v(9) + p
        td = vd(8)*v(9) + v(8)*vd(9) + pd
        base = v(12)*v(13)
        based = vd(12)*v(13) + v(12)*vd(13)
        w = v(14)*v(15)
        wd = vd(14)*v(15) + v(14)*vd(15)
        u = base**w
        ud = u*(wd*log(base) + w*based/base)
        r1 = a*s + t*u
        r1d = ad*s + a*sd + td*u + t*ud
    end subroutine lh085_jvp

    subroutine lh085_vjp(v, r1b, vb)
        real(8), intent(in) :: v(0:100), r1b
        real(8), intent(out) :: vb(0:100)
        real(8) :: a, s, t, u, p, base, w
        real(8) :: abar, sbar, tbar, ubar, pbar, basebar, wbar

        vb = 0.0d0
        a = v(0)*v(1) + v(2)/2.5d0
        s = v(4)*v(5)/(3.5d0 + v(7))
        p = v(10)**v(11)
        t = v(8)*v(9) + p
        base = v(12)*v(13)
        w = v(14)*v(15)
        u = base**w
        abar = r1b*s
        sbar = r1b*a
        vb(0) = abar*v(1)
        vb(1) = abar*v(0)
        vb(2) = abar/2.5d0
        vb(4) = sbar*v(5)/(3.5d0 + v(7))
        vb(5) = sbar*v(4)/(3.5d0 + v(7))
        vb(7) = -sbar*v(4)*v(5)/(3.5d0 + v(7))**2
        tbar = r1b*u
        vb(8) = tbar*v(9)
        vb(9) = tbar*v(8)
        pbar = tbar
        vb(10) = pbar*v(11)*v(10)**(v(11)-1.0d0)
        vb(11) = pbar*p*log(v(10))
        ubar = r1b*t
        basebar = ubar*u*w/base
        wbar = ubar*u*log(base)
        vb(12) = basebar*v(13)
        vb(13) = basebar*v(12)
        vb(14) = wbar*v(15)
        vb(15) = wbar*v(14)
    end subroutine lh085_vjp

    subroutine lh092_jvp(a, ad, b, bd, c, cd)
        real(8), intent(in) :: a, ad, b, bd
        real(8), intent(out) :: c, cd
        real(8) :: x, xd

        x = 1.0d0 - (2.0d0*a - b)
        xd = -(2.0d0*ad - bd)
        c = x*x
        cd = 2.0d0*x*xd
    end subroutine lh092_jvp

    subroutine lh092_vjp(a, b, cb, ab, bb, c)
        real(8), intent(in) :: a, b, cb
        real(8), intent(out) :: ab, bb, c
        real(8) :: x

        x = 1.0d0 - (2.0d0*a - b)
        c = x*x
        ab = cb*(-4.0d0*x)
        bb = cb*(2.0d0*x)
    end subroutine lh092_vjp
end module tapenade_set01_lh085_092_hand
