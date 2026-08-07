module tapenade_bd11_case
  implicit none
contains

  ! Bounded port of todoF90/REFERENCES/bd11/program.f90.
  ! The only source change is scalarizing the two array sections.  The
  ! objective is an explicit observation of the first output element for
  ! a scalar reverse probe.
  subroutine top_bd11(i1, i2, i3, objective)
    real, intent(inout) :: i1(10, 10), i2(10)
    real, intent(in) :: i3(10)
    real, intent(out) :: objective
    integer :: i, j
    real :: root

    do i = 1, 10
      do j = 1, 10
        root = sqrt(i * abs(i * i3(j)))
        i2(j) = root
        i1(j, i) = root * i3(j)
      end do
    end do
    objective = i1(1, 1)
  end subroutine top_bd11

end module tapenade_bd11_case
