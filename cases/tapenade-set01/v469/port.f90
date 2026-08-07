module tapenade_set01_v469_case
    implicit none
    private
    public :: v469_head

contains

    ! Bounded standard-conforming port of v469's head routine.  The explicit
    ! domain is one-element finite real(8) input/output arrays.
    subroutine v469_head(x, y)
        double precision, intent(in) :: x(1)
        double precision, intent(out) :: y(1)

        y(1) = sin(x(1) * 3.14159265358979323844d0 * 2.0d0)
    end subroutine v469_head

end module tapenade_set01_v469_case
