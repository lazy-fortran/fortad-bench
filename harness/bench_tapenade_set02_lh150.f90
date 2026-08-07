program bench_tapenade_set02_lh150
  use iso_fortran_env, only : dp => real64
  use tapenade_set02_lh150_hand, only : hand_jvp => jvp_lh150, &
       hand_primal => primal_lh150, hand_vjp => vjp_lh150
  use lh150_forward_ad, only : generated_jvp => set02_lh150_jvp
  use lh150_reverse_ad, only : generated_vjp => set02_lh150_vjp
  implicit none

  real(dp), parameter :: x = 0.37_dp
  real(dp), parameter :: dx = -0.61_dp
  real(dp), parameter :: yb = 0.83_dp
  real(dp), parameter :: tol = 2.0e-11_dp
  real(dp) :: y_hand, dy_hand, xb_hand
  real(dp) :: y_generated, dy_generated, xb_generated
  real(dp) :: yp, ym, h, fd, previous_error
  integer :: i

  call hand_primal(x, y_hand)
  call hand_jvp(x, dx, yp, dy_hand)
  call generated_jvp(x, dx, y_generated, dy_generated)
  call generated_vjp(x, y_generated, yb, xb_generated)
  call hand_vjp(x, yb, xb_hand)
  call assert_close("primal", y_generated, y_hand, tol)
  call assert_close("jvp", dy_generated, dy_hand, tol)
  call assert_close("vjp", xb_generated, xb_hand, tol)
  call assert_close("adjoint identity", dy_generated * yb, dx * xb_generated, tol)

  previous_error = huge(1.0_dp)
  do i = 2, 5
    h = 10.0_dp ** (-real(i, dp))
    call generated_jvp(x + h, 0.0_dp, yp, dy_generated)
    call generated_jvp(x - h, 0.0_dp, ym, dy_generated)
    fd = (yp - ym) / (2.0_dp * h)
    if (abs(fd - dy_hand / dx) >= previous_error * 1.01_dp) then
      error stop "central difference did not converge"
    end if
    previous_error = abs(fd - dy_hand / dx)
  end do
  print '(a)', "oracle_status: pass"

contains
  subroutine assert_close(label, actual, expected, tolerance)
    character(*), intent(in) :: label
    real(dp), intent(in) :: actual, expected, tolerance
    if (abs(actual - expected) > tolerance * max(1.0_dp, abs(expected))) then
      print '(a,1x,es24.16,1x,es24.16)', label, actual, expected
      error stop "independent oracle mismatch"
    end if
  end subroutine assert_close
end program bench_tapenade_set02_lh150
