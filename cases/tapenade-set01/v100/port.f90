subroutine head_v100_port(x_in, x_out, y)
  implicit none
  double precision, dimension(1) :: x_in
  double precision, dimension(1) :: x_out
  double precision, dimension(1) :: y

  ! The exact source is equivalent to this affine form only when
  ! 0.2D0 < x_in(1) < 0.4D0.  On that open interval MOD(10*x, 2) is
  ! 10*x - 2.  x_out makes the original in-place update explicit.
  x_out(1) = x_in(1) * 10.0D0
  y(1) = x_out(1) - 2.0D0
end subroutine head_v100_port
