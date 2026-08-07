module bd11_hand
  implicit none
contains

  subroutine hand_jvp(i1, i1d, i2, i2d, i3, i3d, objective, objectived)
    real, intent(inout) :: i1(10, 10), i1d(10, 10)
    real, intent(inout) :: i2(10), i2d(10)
    real, intent(in) :: i3(10), i3d(10)
    real, intent(out) :: objective, objectived
    real :: root, droot
    integer :: i, j

    do i = 1, 10
      do j = 1, 10
        root = sqrt(i * abs(i * i3(j)))
        droot = i * (sign(1.0, i * i3(j)) * (i * i3d(j))) / (2.0 * root)
        i2d(j) = droot
        i2(j) = root
        i1d(j, i) = i2d(j) * i3(j) + i2(j) * i3d(j)
        i1(j, i) = i2(j) * i3(j)
      end do
    end do
    objective = i1(1, 1)
    objectived = i1d(1, 1)
  end subroutine hand_jvp

end module bd11_hand
