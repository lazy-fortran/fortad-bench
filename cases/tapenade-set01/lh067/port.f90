! Bounded normal-read-path port of nonRegressions/set01/lh067/program.f.
! The original READ has no computational effect on the successful path.  This
! witness retains its integer ncmax conversion and deliberately excludes the
! legacy error/end branches, whose implicit output state leaves read7
! undefined in the upstream function.
subroutine set01_lh067(z, read7)
    implicit none
    real, intent(in) :: z
    real, intent(out) :: read7
    ! For the derivative probe z=1.7 and nearby central-difference points,
    ! the original INT(z+10) is exactly 11.  Specializing that locally avoids
    ! assigning a fictitious derivative to the integer conversion.
    read7 = 11.0 * z
end subroutine set01_lh067
