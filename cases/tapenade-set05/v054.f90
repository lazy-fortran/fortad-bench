! Standards-clean module extraction of Tapenade nonRegressions/set05/v054.
! SPDX-License-Identifier: MIT
module tapenade_set05_v054
  implicit none
  interface f
    module procedure f_vector, f_elemental
  end interface f
contains
  pure function f_vector(x) result(y)
    real, intent(in) :: x(:)
    real :: y(size(x))
    y = 1.0 / x
  end function f_vector
  elemental function f_elemental(x)
    real, intent(in) :: x
    real :: f_elemental
    f_elemental = 1.0 / x
  end function f_elemental
end module tapenade_set05_v054
