module tapenade_set05_shard3_v125
  implicit none
contains
  pure subroutine set05_v125(x1, x2, y1, y2, z)
    real, intent(in) :: x1, x2, y1, y2
    real, intent(out) :: z

    z = (x1 - x2) * (y1 - y2)
  end subroutine set05_v125
end module tapenade_set05_shard3_v125
