module tapenade_set01_lh010_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    subroutine lh010_hand(x, direction, seed, total, jvp, vjp)
        real(dp), intent(in) :: x(100), direction(100), seed
        real(dp), intent(out) :: total, jvp, vjp(100)
        real(dp) :: product_all, gradient(100)

        product_all = product(x)
        total = sum(x) + 10.0_dp*product_all
        gradient = 1.0_dp + 10.0_dp*product_all/x
        jvp = dot_product(gradient, direction)
        vjp = seed*gradient
    end subroutine lh010_hand
end module tapenade_set01_lh010_hand
