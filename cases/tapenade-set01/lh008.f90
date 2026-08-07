! Port of Tapenade nonRegressions/set01/lh008/program.f at e59864c.
! objective gives reverse mode one scalar dependent while retaining the
! original local-state updates and final y=0 write.
subroutine set01_lh008(y, x, z, objective)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    real(dp), intent(inout) :: y
    real(dp), intent(out) :: x, z, objective
    real(dp) :: a

    a = 10.5_dp
    x = a * y
    a = a + 1.0_dp
    z = a * y
    objective = x + 0.5_dp * z
    y = 0.0_dp
end subroutine set01_lh008
