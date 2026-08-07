program tapenade_set01_lh047_harness
  use tapenade_set01_lh047_case, only: set01_lh047
  use tapenade_set01_lh047_hand, only: hand_value, hand_jvp
  use lh047_jvp_ad, only: lh047_jvp
  implicit none
  real :: u, z, t, x1, x8, x9, x10, x11, y, v
  real :: ud, zd, td, x1d, x8d, x9d, x10d, x11d, yd, vd
  real :: hu, hz, ht, hx1, hx8, hx9, hx10, hx11, hy, hv
  real :: hud, hzd, htd, hx1d, hx8d, hx9d, hx10d, hx11d, hyd, hvd
  integer :: i

  do i = 1, 2
    u = 0.7; z = 1.1; t = 2.0; x1 = -99.0
    x8 = 0.5; x9 = 0.6; x10 = 1.3; x11 = 1.4; y = 0.9; v = 0.2
    if (i == 2) then
      u = -0.25; z = 0.8; t = -1.4; x1 = 42.0
      x8 = -0.7; x9 = 1.2; x10 = 0.4; x11 = -0.9; y = 1.6; v = -0.3
    end if
    ud = 0.07; zd = -0.14; td = 0.21; x1d = -0.28
    x8d = 0.35; x9d = -0.42; x10d = 0.49; x11d = -0.56
    yd = 0.63; vd = -0.70

    hu = u; hz = z; ht = t; hx1 = x1; hx8 = x8; hx9 = x9
    hx10 = x10; hx11 = x11; hy = y; hv = v
    call hand_value(hu, hz, ht, hx1, hx8, hx9, hx10, hx11, hy, hv)
    call set01_lh047(u, z, t, x1, x8, x9, x10, x11, y, v)
    if (maxval(abs([u-hu, z-hz, t-ht, x1-hx1, x8-hx8, x9-hx9, &
        x10-hx10, x11-hx11, y-hy, v-hv])) > 1.0e-5) error stop "primal mismatch"

    u = 0.7; z = 1.1; t = 2.0; x1 = -99.0
    x8 = 0.5; x9 = 0.6; x10 = 1.3; x11 = 1.4; y = 0.9; v = 0.2
    if (i == 2) then
      u = -0.25; z = 0.8; t = -1.4; x1 = 42.0
      x8 = -0.7; x9 = 1.2; x10 = 0.4; x11 = -0.9; y = 1.6; v = -0.3
    end if
    ud = 0.07; zd = -0.14; td = 0.21; x1d = -0.28
    x8d = 0.35; x9d = -0.42; x10d = 0.49; x11d = -0.56
    yd = 0.63; vd = -0.70
    hu = u; hz = z; ht = t; hx1 = x1; hx8 = x8; hx9 = x9
    hx10 = x10; hx11 = x11; hy = y; hv = v
    hud = ud; hzd = zd; htd = td; hx1d = x1d; hx8d = x8d; hx9d = x9d
    hx10d = x10d; hx11d = x11d; hyd = yd; hvd = vd
    call hand_jvp(hu, hud, hz, hzd, ht, htd, hx1, hx1d, hx8, hx8d, &
        hx9, hx9d, hx10, hx10d, hx11, hx11d, hy, hyd, hv, hvd)

    hu = u; hz = z; ht = t; hx1 = x1; hx8 = x8; hx9 = x9
    hx10 = x10; hx11 = x11; hy = y; hv = v
    call lh047_jvp(hu, ud, hz, zd, ht, td, hx1, x1d, hx8, x8d, &
        hx9, x9d, hx10, x10d, hx11, x11d, hy, yd, hv, vd)
    if (maxval(abs([ud-hud, zd-hzd, td-htd, x1d-hx1d, x8d-hx8d, &
        x9d-hx9d, x10d-hx10d, x11d-hx11d, yd-hyd, vd-hvd])) > 1.0e-5) then
      error stop "JVP mismatch"
    end if
  end do
  print '(a)', 'oracle_status: pass'
end program tapenade_set01_lh047_harness
