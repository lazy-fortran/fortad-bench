program bench_tapenade_set05_v054
  use tapenade_set05_v054, only: f_vector
  use tapenade_set05_v054_hand, only: primal_v054, jvp_v054, vjp_v054
  use tapenade_set05_v054_forward_ad, only: f_vector_jvp
  use tapenade_set05_v054_reverse_ad, only: f_vector_vjp
  implicit none
  real, parameter :: tol = 3.0e-5
  real :: x(4), xd(4), y(4), yd(4), yb(4), xb(4)
  real :: expected(4), expected_d(4), expected_b(4), fd(4), h
  integer :: k
  x = [0.75, 1.25, 1.75, 2.5]
  xd = [-0.5, 0.25, 0.75, -1.0]
  yb = [1.0, -0.25, 0.5, 1.5]
  y = f_vector(x)
  expected = primal_v054(x)
  call assert_close("primal", y, expected, tol)
  call f_vector_jvp(x, xd, y, yd)
  expected_d = jvp_v054(x, xd)
  call assert_close("JVP", yd, expected_d, tol)
  xb = 0.0
  call f_vector_vjp(x, y, yb, xb)
  expected_b = vjp_v054(x, yb)
  call assert_close("VJP", xb, expected_b, tol)
  do k = 2, 5
    h = 10.0**(-k)
    fd = (primal_v054(x + h*xd) - primal_v054(x - h*xd))/(2.0*h)
    call assert_close("central difference", fd, expected_d, 2.0e-2)
  end do
  call assert_close("adjoint identity", yd*yb, xd*xb, tol)
  print '(a)', "oracle_status: pass"
contains
  subroutine assert_close(label, actual, expected_value, limit)
    character(len=*), intent(in) :: label
    real, intent(in) :: actual(:), expected_value(:), limit
    if (maxval(abs(actual - expected_value)) > limit) error stop trim(label)//" mismatch"
  end subroutine assert_close
end program bench_tapenade_set05_v054
