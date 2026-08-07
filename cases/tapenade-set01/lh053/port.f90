! Bounded standard-conforming port of set01/lh053/program.f.
!
! The upstream routine obtains NC and RCAL from COMMON/EQUIVALENCE and calls
! an unavailable external BINAIR.  This port makes those two state values
! explicit and supplies a fixed BINAIR algebra.  It is therefore a
! reproducible derivative probe, not a claim that the incomplete upstream
! source is directly supported.
subroutine set01_lh053(nc, z, tk, rcal, gamai, v, w, g, tau)
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    integer, intent(in) :: nc
    real(dp), intent(in) :: z(nc), tk, rcal
    real(dp), intent(out) :: gamai(nc), v(nc), w(nc)
    real(dp), intent(out) :: g(nc, nc), tau(nc, nc)
    integer :: i, j, j1
    real(dp) :: rcal_tk, zg, temp

    rcal_tk = rcal * tk
    do i = 1, nc
        tau(i, i) = 0.0_dp
        g(i, i) = 0.0_dp
    end do
    do i = 1, nc - 1
        j1 = i + 1
        do j = j1, nc
            tau(i, j) = (0.15_dp + 0.03_dp * i + 0.02_dp * j + 0.01_dp) / rcal_tk
            tau(j, i) = (0.15_dp + 0.03_dp * j + 0.02_dp * i + 0.01_dp) / rcal_tk
            g(i, j) = 0.15_dp + 0.03_dp * i + 0.02_dp * j + 0.02_dp
            g(j, i) = g(i, j)
        end do
    end do
    do j = 1, nc
        do i = 1, nc
            g(j, i) = exp(-g(j, i) * tau(j, i))
        end do
    end do
    do i = 1, nc
        v(i) = 0.0_dp
        w(i) = 0.0_dp
        do j = 1, nc
            zg = z(j) * g(j, i)
            v(i) = v(i) + zg
            w(i) = w(i) + zg * tau(j, i)
        end do
        temp = w(i) / v(i)
        w(i) = temp
        gamai(i) = w(i)
    end do
    do i = 1, nc
        do j = 1, nc
            temp = z(j) / v(j)
            gamai(i) = gamai(i) + z(j) * g(i, j) * (tau(i, j) - w(j)) / v(j)
        end do
        gamai(i) = exp(gamai(i))
    end do
end subroutine set01_lh053
