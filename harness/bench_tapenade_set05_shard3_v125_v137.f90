program bench_tapenade_set05_shard3
  use set05_v125_jvp_mod, only: set05_v125_jvp
  use set05_v125_vjp_mod, only: set05_v125_vjp
  use set05_v137_jvp_mod, only: set05_v137_jvp
  use set05_v137_vjp_mod, only: set05_v137_vjp
  implicit none

  call check_v125()
  call check_v137()
  print '(a)', 'oracle_status: pass'

contains

  subroutine check_v125()
    real :: x1, x2, y1, y2, dx1, dx2, dy1, dy2, z, zd
    real :: zb, x1b, x2b, y1b, y2b
    real :: eps, zp, zm, finite, hand, lhs, rhs
    x1 = 0.7; x2 = -1.3; y1 = 2.1; y2 = -0.8
    dx1 = 0.4; dx2 = -0.2; dy1 = 0.3; dy2 = -0.5
    eps = 1.0e-2
    call set05_v125_jvp(x1, dx1, x2, dx2, y1, dy1, y2, dy2, z, zd)
    hand = (dx1-dx2)*(y1-y2) + (x1-x2)*(dy1-dy2)
    zp = (x1+eps*dx1-x2-eps*dx2)*(y1+eps*dy1-y2-eps*dy2)
    zm = (x1-eps*dx1-x2+eps*dx2)*(y1-eps*dy1-y2+eps*dy2)
    finite = (zp-zm)/(2.0*eps)
    call require_close('v125 JVP hand', zd, hand, 1.0e-4)
    call require_close('v125 JVP finite difference', zd, finite, 1.0e-4)
    zb = -0.6
    call set05_v125_vjp(x1, x2, y1, y2, z, zb, x1b, x2b, y1b, y2b)
    lhs = zb*zd
    rhs = x1b*dx1 + x2b*dx2 + y1b*dy1 + y2b*dy2
    call require_close('v125 adjoint identity', lhs, rhs, 1.0e-4)
  end subroutine check_v125

  subroutine check_v137()
    real :: x, y, dx, dy, s, sd, sb, xb, yb
    real :: eps, sp, sm, finite, hand, lhs, rhs
    x = 0.7; y = -1.3; dx = 0.4; dy = -0.2
    eps = 1.0e-2
    call set05_v137_jvp(x, dx, y, dy, s, sd)
    hand = (y+1.0)*dx + x*dy
    sp = (x+eps*dx)*(y+eps*dy) + x + eps*dx
    sm = (x-eps*dx)*(y-eps*dy) + x - eps*dx
    finite = (sp-sm)/(2.0*eps)
    call require_close('v137 JVP hand', sd, hand, 1.0e-4)
    call require_close('v137 JVP finite difference', sd, finite, 1.0e-4)
    sb = -0.6
    call set05_v137_vjp(x, y, s, sb, xb, yb)
    lhs = sb*sd
    rhs = xb*dx + yb*dy
    call require_close('v137 adjoint identity', lhs, rhs, 1.0e-4)
  end subroutine check_v137

  subroutine require_close(label, got, expected, tolerance)
    character(len=*), intent(in) :: label
    real, intent(in) :: got, expected, tolerance
    if (abs(got-expected) > tolerance) then
      error stop trim(label)//' failed'
    end if
  end subroutine require_close

end program bench_tapenade_set05_shard3
