module tapenade_set01_lh015_hand
    use, intrinsic :: iso_fortran_env, only: real64
    implicit none

    integer, parameter :: dp = real64

contains

    ! This is a deliberately bounded, conforming observation of the loop body
    ! in the invalid upstream source.  It is not a repaired port of S2: the
    ! trip count is explicit and integer, and no COMMON or uninitialized value
    ! is retained.
    subroutine set01_lh015_safe_primal(n, p, t1)
        integer, intent(in) :: n
        real(dp), intent(in) :: p
        real(dp), intent(out) :: t1(:)
        integer :: i

        if (n < 1 .or. n > size(t1)) error stop "invalid safe trip count"
        t1 = 0.0_dp
        do i = 1, n
            t1(i) = 2.0_dp * p
        end do
    end subroutine set01_lh015_safe_primal

    subroutine set01_lh015_hand(n, p, pd, seed, t1, t1d, pb, jvp)
        integer, intent(in) :: n
        real(dp), intent(in) :: p, pd
        real(dp), intent(in) :: seed(:)
        real(dp), intent(out) :: t1(:), t1d(:), pb, jvp
        integer :: i

        if (n < 1 .or. n > size(t1) .or. n > size(t1d) .or. &
            n > size(seed)) error stop "invalid safe derivative shape"
        call set01_lh015_safe_primal(n, p, t1)
        t1d = 0.0_dp
        do i = 1, n
            t1d(i) = 2.0_dp * pd
        end do
        jvp = dot_product(seed, t1d)
        pb = 2.0_dp * sum(seed(1:n))
    end subroutine set01_lh015_hand

end module tapenade_set01_lh015_hand
