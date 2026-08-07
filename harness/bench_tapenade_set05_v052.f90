program bench_tapenade_set05_v052
  use iso_fortran_env, only: dp => real64
  use tapenade_set05_v052, only: set05_v052
  use tapenade_set05_v052_hand, only: primal_v052, jvp_v052, vjp_v052
  use tapenade_set05_v052_forward_ad, only: set05_v052_jvp
  use tapenade_set05_v052_reverse_ad, only: set05_v052_vjp
  implicit none

  real(dp), parameter :: tol = 5.0e-12_dp
  real(dp), parameter :: x = 1.375_dp
  real(dp), parameter :: xd = -0.625_dp
  real(dp), parameter :: yb = 1.75_dp
  integer, parameter :: i = 3
  real(dp) :: y, yd, expected_y, expected_yd
  real(dp) :: y_ad, x_ad, expected_x_ad
  real(dp) :: h, fd, base
  integer :: k

  y = set05_v052(x, i)
  expected_y = primal_v052(x, i)
  call assert_close("primal", y, expected_y, tol)

  call set05_v052_jvp(x, xd, i, y, yd)
  expected_yd = jvp_v052(x, i, xd)
  call assert_close("JVP", yd, expected_yd, tol)

  x_ad = 0.0_dp
  y_ad = yb
  call set05_v052_vjp(x, i, y_ad, yb, x_ad)
  expected_x_ad = vjp_v052(x, i, yb)
  call assert_close("VJP", x_ad, expected_x_ad, tol)

  ! Independent central-difference oracle over multiple step sizes.
  do k = 2, 5
    h = 10.0_dp**(-k)
    fd = (primal_v052(x + h*xd, i) - primal_v052(x - h*xd, i))/(2.0_dp*h)
    call assert_close("central difference", fd, expected_yd, 2.0e-10_dp)
  end do

  ! Independent adjoint identity: <J v, w> = <v, J^T w>.
  base = yd*yb
  call assert_close("adjoint identity", base, xd*x_ad, tol)

  print '(a)', "oracle_status: pass"

contains

  subroutine assert_close(label, actual, expected, limit)
    character(len=*), intent(in) :: label
    real(dp), intent(in) :: actual, expected, limit
    if (abs(actual - expected) > limit) then
      error stop trim(label)//" mismatch"
    end if
  end subroutine assert_close

end program bench_tapenade_set05_v052
