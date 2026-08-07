program bench_tapenade_set05_set06_tranche_b
  use iso_fortran_env, only: dp => real64
  use tapenade_set05_v150_hand, only: primal_v150, jvp_v150, vjp_v150
  use tapenade_set05_v168_hand, only: primal_v168, jvp_v168, vjp_v168
  use tapenade_set06_v314_hand, only: primal_v314, jvp_v314, vjp_v314
  use tapenade_set06_v379_hand, only: primal_v379, jvp_v379, vjp_v379
  use v150_forward_ad, only: v150_jvp
  use v150_reverse_ad, only: v150_vjp
  use v168_forward_ad, only: v168_jvp
  use v168_reverse_ad, only: v168_vjp
  use v314_forward_ad, only: v314_jvp
  use v314_reverse_ad, only: v314_vjp
  use v379_forward_ad, only: v379_jvp
  use v379_reverse_ad, only: v379_vjp
  implicit none

  call check_v150()
  call check_v168()
  call check_v314()
  call check_v379()
  print '(a)', 'oracle_status: pass'

contains

  subroutine require_close(label, actual, expected, tolerance)
    character(*), intent(in) :: label
    real(dp), intent(in) :: actual(:), expected(:), tolerance
    real(dp) :: error

    error = maxval(abs(actual - expected))
    if (error > tolerance) then
      print '(a,1x,es12.4)', trim(label)//' error:', error
      error stop 1
    end if
  end subroutine require_close

  subroutine require_close_scalar(label, actual, expected, tolerance)
    character(*), intent(in) :: label
    real(dp), intent(in) :: actual, expected, tolerance

    if (abs(actual - expected) > tolerance) then
      print '(a,1x,es12.4)', trim(label)//' error:', abs(actual - expected)
      error stop 1
    end if
  end subroutine require_close_scalar

  subroutine check_v150()
    real(dp) :: t, td, f, fd, f_hand, fd_hand, fb, tb, tb_hand
    real(dp) :: fp, fm, eps
    integer :: i

    t = 0.7_dp
    td = -0.3_dp
    fb = 0.8_dp
    call primal_v150(t, f_hand)
    call jvp_v150(t, td, f_hand, fd_hand)
    call v150_jvp(t, td, f, fd)
    call require_close_scalar('v150 primal', f, f_hand, 2.0e-13_dp)
    call require_close_scalar('v150 jvp', fd, fd_hand, 2.0e-13_dp)
    call vjp_v150(t, fb, tb_hand)
    call v150_vjp(t, f, fb, tb)
    call require_close_scalar('v150 vjp', tb, tb_hand, 2.0e-13_dp)
    call require_close_scalar('v150 adjoint identity', fb * fd, &
                              tb * td, 2.0e-12_dp)
    do i = 1, 3
      eps = 10.0_dp**(-real(i + 2, dp))
      call primal_v150(t + eps * td, fp)
      call primal_v150(t - eps * td, fm)
      call require_close_scalar('v150 finite difference', (fp - fm) / (2.0_dp * eps), &
                                fd_hand, 2.0e-7_dp)
    end do
  end subroutine check_v150

  subroutine check_v168()
    real(dp) :: x(4), xd(4), y(4), yd(4), y_hand(4), yd_hand(4)
    real(dp) :: yb(4), xb(4), xb_hand(4), yp(4), ym(4), eps
    integer :: i

    x = [1.0_dp, 3.0_dp, -2.5_dp, 0.5_dp]
    xd = [0.3_dp, -0.2_dp, 0.4_dp, -0.5_dp]
    yb = [0.7_dp, -0.3_dp, 0.5_dp, -0.2_dp]
    call primal_v168(x, y_hand)
    call jvp_v168(x, xd, y_hand, yd_hand)
    call v168_jvp(x, xd, y, yd)
    call require_close('v168 primal', y, y_hand, 2.0e-13_dp)
    call require_close('v168 jvp', yd, yd_hand, 2.0e-13_dp)
    call vjp_v168(x, yb, xb_hand)
    call v168_vjp(x, y, yb, xb)
    call require_close('v168 vjp', xb, xb_hand, 2.0e-13_dp)
    call require_close_scalar('v168 adjoint identity', dot_product(yb, yd), &
                              dot_product(xb, xd), 2.0e-12_dp)
    do i = 1, 3
      eps = 10.0_dp**(-real(i + 2, dp))
      call primal_v168(x + eps * xd, yp)
      call primal_v168(x - eps * xd, ym)
      call require_close('v168 finite difference', (yp - ym) / (2.0_dp * eps), &
                         yd_hand, 2.0e-7_dp)
    end do
  end subroutine check_v168

  subroutine check_v314()
    real(dp) :: y, z, yd, zd, x, xd, x_hand, xd_hand
    real(dp) :: xb, yb, zb, yb_hand, zb_hand, xp, xm, eps
    integer :: i

    y = 1.2_dp
    z = 2.3_dp
    yd = -0.4_dp
    zd = 0.7_dp
    xb = 0.8_dp
    call primal_v314(y, z, x_hand)
    call jvp_v314(y, z, yd, zd, x_hand, xd_hand)
    call v314_jvp(x, xd, y, yd, z, zd)
    call require_close_scalar('v314 primal', x, x_hand, 2.0e-13_dp)
    call require_close_scalar('v314 jvp', xd, xd_hand, 2.0e-13_dp)
    call vjp_v314(y, z, xb, yb_hand, zb_hand)
    call v314_vjp(x, y, z, xb, yb, zb)
    call require_close_scalar('v314 y vjp', yb, yb_hand, 2.0e-13_dp)
    call require_close_scalar('v314 z vjp', zb, zb_hand, 2.0e-13_dp)
    call require_close_scalar('v314 adjoint identity', xb * xd, &
                              yb * yd + zb * zd, 2.0e-12_dp)
    do i = 1, 3
      eps = 10.0_dp**(-real(i + 2, dp))
      call primal_v314(y + eps * yd, z + eps * zd, xp)
      call primal_v314(y - eps * yd, z - eps * zd, xm)
      call require_close_scalar('v314 finite difference', (xp - xm) / (2.0_dp * eps), &
                                xd_hand, 2.0e-7_dp)
    end do
  end subroutine check_v314

  subroutine check_v379()
    integer :: n, i
    real(dp) :: x(4), xd(4), f, fd, f_hand, fd_hand, fb, xb(4), xb_hand(4)
    real(dp) :: fp, fm, eps

    n = 4
    x = [1.0_dp, 2.0_dp, 3.0_dp, 4.0_dp]
    xd = [0.3_dp, -0.2_dp, 0.4_dp, -0.5_dp]
    fb = 0.8_dp
    call primal_v379(n, x, f_hand)
    call jvp_v379(n, x, xd, f_hand, fd_hand)
    call v379_jvp(n, x, xd, f, fd)
    call require_close_scalar('v379 primal', f, f_hand, 2.0e-13_dp)
    call require_close_scalar('v379 jvp', fd, fd_hand, 2.0e-13_dp)
    call vjp_v379(n, x, fb, xb_hand)
    call v379_vjp(n, x, f, fb, xb)
    call require_close('v379 vjp', xb, xb_hand, 2.0e-13_dp)
    call require_close_scalar('v379 adjoint identity', fb * fd, &
                              dot_product(xb, xd), 2.0e-12_dp)
    do i = 1, 3
      eps = 10.0_dp**(-real(i + 2, dp))
      call primal_v379(n, x + eps * xd, fp)
      call primal_v379(n, x - eps * xd, fm)
      call require_close_scalar('v379 finite difference', (fp - fm) / (2.0_dp * eps), &
                                fd_hand, 2.0e-7_dp)
    end do
  end subroutine check_v379

end program bench_tapenade_set05_set06_tranche_b
