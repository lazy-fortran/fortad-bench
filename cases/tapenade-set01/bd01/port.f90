module tapenade_set01_bd01_case
    implicit none
    private
    public :: set01_bd01

contains

    subroutine set01_bd01(a, b, c)
        real, intent(inout) :: a
        real, intent(in) :: b, c

        a = b * c
    end subroutine set01_bd01

end module tapenade_set01_bd01_case
