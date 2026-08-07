program bench_tapenade_set02_lh163
    use, intrinsic :: iso_fortran_env, only: error_unit, output_unit, real32
    use program_jvp_mod, only: generated_jvp => test_jvp
    use program_vjp_mod, only: generated_vjp => test_vjp
    use tapenade_set02_lh163_hand, only: hand_primal => primal, &
        hand_jvp => jvp, hand_vjp => vjp
    implicit none

    logical :: ok
    real(real32) :: v, vd, p, pd, q, qd, s, sd
    real(real32) :: vh, vdh, ph, pdh, qh, qdh, sh, sdh
    real(real32) :: vb, pb, qb, vbh, pbh, qbh, sb
    real(real32) :: h, sp, sm, fd
    integer :: step

    ok = .true.
    v = 2.0
    vd = -0.3
    p = 1.5
    pd = 0.8
    q = -0.75
    qd = 0.4
    sb = 0.65

    vh = v
    vdh = vd
    ph = p
    pdh = pd
    qh = q
    qdh = qd
    call generated_jvp(v, vd, p, pd, q, qd, s, sd)
    call hand_jvp(vh, vdh, ph, pdh, qh, qdh, sh, sdh)
    call check_close("JVP primal s", s, sh, ok)
    call check_close("JVP tangent s", sd, sdh, ok)
    call check_close("JVP final v", v, vh, ok)
    call check_close("JVP final q", q, qh, ok)

    ! Reverse mode receives the original primal values, not the values after
    ! the forward routine's intentional write-after-read updates.
    v = 2.0
    vd = -0.3
    p = 1.5
    pd = 0.8
    q = -0.75
    qd = 0.4
    s = 0.0
    vbh = 0.0
    pbh = 0.0
    qbh = 0.0
    call generated_vjp(v, p, q, s, sb, vb, pb, qb)
    call hand_vjp(v, p, q, s, sb, vbh, pbh, qbh)
    call check_close("VJP v", vb, vbh, ok)
    call check_close("VJP p", pb, pbh, ok)
    call check_close("VJP q", qb, qbh, ok)
    call check_close("adjoint identity", vb*vd + pb*pd + qb*qd, sb*sd, ok)

    do step = 1, 3
        h = 10.0_real32**(-step)
        call hand_primal(vh, ph, qh, sp)
        vh = v + h*vd
        ph = p + h*pd
        qh = q + h*qd
        call hand_primal(vh, ph, qh, sp)
        vh = v - h*vd
        ph = p - h*pd
        qh = q - h*qd
        call hand_primal(vh, ph, qh, sm)
        fd = (sp - sm)/(2.0*h)
        call check_close_tol("central difference", fd, sd, 2.0e-3_real32, ok)
    end do

    if (.not. ok) then
        flush (output_unit)
        stop 1
    end if
    print '(a)', "oracle_status: pass"

contains

    subroutine check_close(label, actual, expected, ok)
        character(len=*), intent(in) :: label
        real(real32), intent(in) :: actual, expected
        logical, intent(inout) :: ok

        if (abs(actual - expected) > 3.0e-5_real32*max(1.0_real32, abs(expected))) then
            write (error_unit, '(a,2(1x,es16.8))') "FAIL "//trim(label), actual, expected
            ok = .false.
        end if
    end subroutine check_close

    subroutine check_close_tol(label, actual, expected, tolerance, ok)
        character(len=*), intent(in) :: label
        real(real32), intent(in) :: actual, expected, tolerance
        logical, intent(inout) :: ok

        if (abs(actual - expected) > tolerance*max(1.0_real32, abs(expected))) then
            write (error_unit, '(a,2(1x,es16.8))') "FAIL "//trim(label), actual, expected
            ok = .false.
        end if
    end subroutine check_close_tol

end program bench_tapenade_set02_lh163
