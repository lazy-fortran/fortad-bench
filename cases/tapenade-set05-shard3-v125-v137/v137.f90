! Copyright (©) 1999-2021 INRIA
! Tapenade source/port; MIT license in LICENSES/Tapenade-MIT.txt.
module tapenade_set05_shard3_v137
  implicit none
contains
  pure subroutine set05_v137(x, y, s)
    real, intent(in) :: x, y
    real, intent(out) :: s

    s = x * y + x
  end subroutine set05_v137
end module tapenade_set05_shard3_v137
