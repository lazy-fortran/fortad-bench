program bench_tapenade_set01_lh033_047
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use tapenade_set01_lh033_040_hand
    use lh039_jvp_mod, only: lh039_jvp
    use lh039_vjp_mod, only: lh039_vjp
    implicit none

    real(dp) :: data, data_plus, data_minus, resu, resu_plus, resu_minus
    real(dp) :: cumoffrN, h, fd, hand, xdot, ydot
    real(dp) :: t, t_plus, t_minus, fval, f_plus, f_minus, fhand
    real(dp) :: i1, i2, i3, o1, o2, o3
    real(dp) :: x1, x2, x3
    real(dp) :: i1p, i2p, i3p, o1p, o2p, o3p
    real(dp) :: i1m, i2m, i3m, o1m, o2m, o3m
    real(dp) :: i1_d, i2_d, i3_d, o1_d, o3_d
    real(dp) :: i1_b, i2_b, i3_b
    real(dp) :: hand_i1, hand_i2, hand_i3
    real(dp) :: lh033_error, lh040_error
    integer :: iz
    real :: data_single, data_single_plus, data_single_minus, resu_single, cum_single
    double precision :: f

    ! The two exact fixed-form refusal sources retain their original real
    ! declarations.  Their common blocks are independent of the modern port.
    common /ccc/ cum_single
    external absorbN, f

    ! A 1e-4 step remains distinguishable after the exact fixed-form single
    ! precision routines convert the perturbation.
    h = 1.0e-4_dp

    data_single = 1.25
    cum_single = -7.0
    iz = 0
    call absorbN(data_single, resu_single, iz)
    if (abs(real(resu_single, dp) - 12.5_dp) > 1.0e-5_dp) error stop 101
    data_plus = real(data_single, dp) + h
    data_minus = real(data_single, dp) - h
    data_single_plus = real(data_plus, kind=kind(data_single))
    data_single_minus = real(data_minus, kind=kind(data_single))
    call absorbN(data_single_plus, resu_single, iz)
    resu_plus = real(resu_single, dp)
    call absorbN(data_single_minus, resu_single, iz)
    resu_minus = real(resu_single, dp)
    fd = (resu_plus - resu_minus) / (2.0_dp * h)
    call absorbN_jvp_hand(real(data_single, dp), 1.0_dp, resu, hand)
    if (abs(fd - hand) > 1.0e-2_dp) error stop 102
    lh033_error = abs(fd - hand)

    t = 0.7_dp
    fval = f(t)
    t_plus = t + h
    t_minus = t - h
    f_plus = f(t_plus)
    f_minus = f(t_minus)
    fd = (f_plus - f_minus) / (2.0_dp * h)
    call f_jvp_hand(t, 1.0_dp, fval, fhand)
    if (abs(fd - fhand) > 2.0e-3_dp) error stop 103
    lh040_error = abs(fd - fhand)

    x1 = 4.0_dp
    x2 = 0.5_dp
    x3 = 1.3_dp
    i1 = x1
    i2 = x2
    i3 = x3
    i1_d = 0.3_dp
    i2_d = -0.2_dp
    i3_d = 0.4_dp
    call set01_lh039(i1, i2, i3, o1, o2, o3)

    ! The closed form derivative of o1 = 35*i1*i2**2/(i1-3*i2).
    hand = 35.0_dp * x1 * x2 * x2 / (x1 - 3.0_dp * x2)
    hand_i1 = -105.0_dp * x2**3 / (x1 - 3.0_dp * x2)**2
    hand_i2 = 35.0_dp * x1 * x2 * (2.0_dp*x1 - 3.0_dp*x2) / &
              (x1 - 3.0_dp*x2)**2
    hand_i3 = 0.0_dp
    if (abs(o1 - hand) > 1.0e-12_dp .or. abs(o2 - 35.0_dp) > 1.0e-12_dp .or. &
        abs(o3 - 2.0_dp) > 1.0e-12_dp) error stop 104

    i1_d = 0.3_dp
    i2_d = -0.2_dp
    i3_d = 0.4_dp
    i1 = x1
    i2 = x2
    i3 = x3
    call lh039_jvp(i1, i1_d, i2, i2_d, i3, i3_d, &
                   o1, o1_d, o2, o3, o3_d)
    xdot = hand_i1 * 0.3_dp + hand_i2 * (-0.2_dp) + hand_i3 * 0.4_dp
    if (abs(o1_d - xdot) > 1.0e-11_dp .or. abs(o3_d) > 1.0e-12_dp) error stop 105

    i1p = x1; i2p = x2; i3p = x3
    i1m = x1; i2m = x2; i3m = x3
    i1p = i1p + h * 0.3_dp; i2p = i2p - h * 0.2_dp; i3p = i3p + h * 0.4_dp
    i1m = i1m - h * 0.3_dp; i2m = i2m + h * 0.2_dp; i3m = i3m - h * 0.4_dp
    call set01_lh039(i1p, i2p, i3p, o1p, o2p, o3p)
    call set01_lh039(i1m, i2m, i3m, o1m, o2m, o3m)
    fd = (o1p - o1m) / (2.0_dp * h)
    if (abs(fd - o1_d) > 1.0e-7_dp) error stop 106

    call lh039_vjp(x1, x2, x3, o1, o2, o3, 1.0_dp, &
                   i1_b, i2_b, i3_b)
    if (abs(i1_b - hand_i1) > 1.0e-11_dp .or. abs(i2_b - hand_i2) > 1.0e-11_dp .or. &
        abs(i3_b - hand_i3) > 1.0e-12_dp) error stop 107
    ydot = i1_b * 0.3_dp + i2_b * (-0.2_dp) + i3_b * 0.4_dp
    if (abs(ydot - o1_d) > 1.0e-11_dp) error stop 108

    write (*, '(a)') 'oracle_status: pass'
    write (*, '(a,es12.4)') 'lh033_hand_error: ', lh033_error
    write (*, '(a,es12.4)') 'lh039_adjoint_residual: ', abs(ydot - o1_d)
    write (*, '(a,es12.4)') 'lh040_hand_error: ', lh040_error
end program bench_tapenade_set01_lh033_047
