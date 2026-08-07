! Port of Tapenade todoF90/REFERENCES/v420/program.f90.
! Upstream source is MIT-licensed; this port keeps the original arithmetic.
module tapenade_v420_case
    use, intrinsic :: iso_fortran_env, only: real64
    implicit none
    private
    public :: v420
contains
    subroutine v420(u, v)
        real(real64), intent(in) :: u
        real(real64), intent(out) :: v
        real(real64) :: w, x

        w = 5.0_real64
        x = 10.0_real64
        v = u*w
        v = v*x
    end subroutine v420
end module tapenade_v420_case
