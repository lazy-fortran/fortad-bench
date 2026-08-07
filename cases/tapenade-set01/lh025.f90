! SPDX-License-Identifier: MIT
! Bounded standard-conforming port of Tapenade nonRegressions/set01/lh025/program.f.
module tapenade_set01_lh025_case
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine set01_lh025(a, x, lambda, y)
        real(dp), intent(in) :: a(4, 3), x(3), lambda
        real(dp), intent(out) :: y(3)
        real(dp) :: dense1, dense2, dense3, dense4

        dense1 = a(1,1)*x(1) + a(1,2)*x(2) + a(1,3)*x(3)
        dense2 = a(2,1)*x(1) + a(2,2)*x(2) + a(2,3)*x(3)
        dense3 = a(3,1)*x(1) + a(3,2)*x(2) + a(3,3)*x(3)
        dense4 = a(4,1)*x(1) + a(4,2)*x(2) + a(4,3)*x(3)

        y(1) = dense1*a(1,1) + dense2*a(2,1) + dense3*a(3,1) + &
               dense4*a(4,1) + lambda*lambda*x(1)
        y(2) = dense1*a(1,2) + dense2*a(2,2) + dense3*a(3,2) + &
               dense4*a(4,2) + lambda*lambda*x(2)
        y(3) = dense1*a(1,3) + dense2*a(2,3) + dense3*a(3,3) + &
               dense4*a(4,3) + lambda*lambda*x(3)
    end subroutine set01_lh025
end module tapenade_set01_lh025_case
