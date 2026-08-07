program lh076_harness
    use tapenade_set01_lh076, only: set01_lh076
    use tapenade_set01_lh076_hand, only: lh076_hand_jvp, lh076_hand_vjp
    use lh076_jvp_mod, only: lh076_jvp
    implicit none

    real(8) :: pin4, pin4d, pin4b, h, fd_error, jvp_error
    complex(8) :: emipint, emipintd, hand_y, hand_yd, generated_y
    complex(8) :: emipintb, yp, ym
    real(8) :: lhs, rhs

    pin4 = 0.7d0
    pin4d = -0.2d0
    h = 1.0d-6
    emipintb = cmplx(-1.3d0, 0.4d0, 8)

    call set01_lh076(pin4, emipint)
    call lh076_hand_jvp(pin4, pin4d, hand_y, hand_yd)
    call lh076_jvp(pin4, pin4d, generated_y, emipintd)
    jvp_error = abs(generated_y - hand_y) + abs(emipintd - hand_yd)
    if (jvp_error > 1.0d-12) error stop "generated JVP disagrees with hand JVP"
    if (abs(emipint - hand_y) > 1.0d-12) error stop "bounded primal mismatch"

    call set01_lh076(pin4 + h * pin4d, yp)
    call set01_lh076(pin4 - h * pin4d, ym)
    fd_error = abs((yp - ym) / (2.0d0 * h) - hand_yd)
    if (fd_error > 1.0d-8) error stop "central difference disagrees with hand JVP"

    call lh076_hand_vjp(emipintb, pin4b)
    lhs = real(conjg(emipintb) * hand_yd)
    rhs = pin4b * pin4d
    if (abs(lhs - rhs) > 1.0d-13) error stop "adjoint identity failed"

    print '(a,es12.4)', "jvp_error: ", jvp_error
    print '(a,es12.4)', "finite_difference_error: ", fd_error
    print '(a,es12.4)', "adjoint_identity_residual: ", abs(lhs - rhs)
    print '(a)', "harness_status: pass"
end program lh076_harness
