module tapenade_set01_v101_case
  implicit none
contains

  subroutine head_v101(x, y)
    double precision, intent(in) :: x(2)
    double precision, intent(out) :: y(1)
    double precision :: a(2)

    ! The exact case always allocates a(2) before testing ALLOCATED(a).
    ! This bounded port removes only that allocation-state bookkeeping.
    a(1) = x(1) * 2.0d0
    a(2) = x(2) * 2.0d0
    y(1) = a(1) * a(2)
  end subroutine head_v101

end module tapenade_set01_v101_case
