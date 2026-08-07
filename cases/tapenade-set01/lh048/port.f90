module tapenade_set01_lh048_case
  implicit none
contains

  ! Bounded port of the legacy case: COMMON state is explicit, and the
  ! otherwise undefined incoming V is made an explicit inout argument.
  subroutine set01_lh048(u, z, t, v, x, y)
    real, intent(inout) :: u, t, v, x(14), y
    real, intent(in) :: z
    integer :: i

    i = 5
    x(1) = y * u + t
    u = 0.0
    call sub1_port(u, x, i, z, v, y)
    t = t + x(1) * z + 3.0 * v
    y = 0.0
    i = 6
    call sub1_port(u, x, i, z, v, y)
    t = t + x(1) * z + 3.0 * u
  end subroutine set01_lh048

  subroutine sub1_port(u, x, i, z, v, y)
    real, intent(inout) :: u, x(14), v, y
    real, intent(in) :: z
    integer, intent(in) :: i

    ! y2(3) and y2(5) in the upstream scalar-to-array call address
    ! x(i+3) and x(i+5), respectively.
    u = u * y + x(i + 3) * z
    y = z + v * y
    v = u * x(i + 5)
  end subroutine sub1_port

end module tapenade_set01_lh048_case
