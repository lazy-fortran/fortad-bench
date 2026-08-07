subroutine head_v100_hand_forward(x_in, x_in_d, x_out, x_out_d, y, y_d)
  implicit none
  double precision, dimension(1) :: x_in
  double precision, dimension(1) :: x_in_d
  double precision, dimension(1) :: x_out
  double precision, dimension(1) :: x_out_d
  double precision, dimension(1) :: y
  double precision, dimension(1) :: y_d

  x_out(1) = x_in(1) * 10.0D0
  y(1) = x_out(1) - 2.0D0
  x_out_d(1) = x_in_d(1) * 10.0D0
  y_d(1) = x_out_d(1)
end subroutine head_v100_hand_forward

subroutine head_v100_hand_reverse(x_in, x_out, y, y_b, x_in_b)
  implicit none
  double precision, dimension(1) :: x_in
  double precision, dimension(1) :: x_out
  double precision, dimension(1) :: y
  double precision, dimension(1) :: y_b
  double precision, dimension(1) :: x_in_b

  x_out(1) = x_in(1) * 10.0D0
  y(1) = x_out(1) - 2.0D0
  x_in_b(1) = 10.0D0 * y_b(1)
end subroutine head_v100_hand_reverse
