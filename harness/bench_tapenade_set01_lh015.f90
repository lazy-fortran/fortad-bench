program bench_tapenade_set01_lh015
    use, intrinsic :: iso_fortran_env, only: real64
    use tapenade_set01_lh015_hand, only: dp, set01_lh015_hand, &
        set01_lh015_safe_primal
    implicit none

    integer, parameter :: n = 17
    real(dp), parameter :: steps(4) = [1.0e-2_dp, 1.0e-3_dp, &
                                        1.0e-4_dp, 1.0e-5_dp]
    real(dp) :: p, pd, eps, seed(n), t1(n), t1d(n), t1p(n), t1m(n)
    real(dp) :: pb, jvp, fd, fd_errors(4), lhs, rhs
    integer :: i, k

    p = -0.75_dp
    pd = 0.23_dp
    do i = 1, n
        seed(i) = 0.25_dp + 0.03_dp * real(i, dp)
    end do

    call set01_lh015_safe_primal(n, p, t1)
    if (maxval(abs(t1 - 2.0_dp*p)) > 2.0e-14_dp) then
        error stop "safe primal mismatch"
    end if
    call set01_lh015_hand(n, p, pd, seed, t1, t1d, pb, jvp)

    do k = 1, size(steps)
        eps = steps(k)
        call set01_lh015_safe_primal(n, p + eps*pd, t1p)
        call set01_lh015_safe_primal(n, p - eps*pd, t1m)
        fd = dot_product(seed, t1p - t1m) / (2.0_dp*eps)
        fd_errors(k) = abs(fd - jvp)
    end do
    if (maxval(fd_errors) > 2.0e-10_dp) then
        error stop "safe central-difference sweep mismatch"
    end if

    lhs = dot_product(seed, t1d)
    rhs = pb * pd
    if (abs(lhs - rhs) > 2.0e-13_dp) then
        error stop "safe JVP/VJP adjoint identity mismatch"
    end if

    write (*, '(a)') "oracle_status: pass"
    write (*, '(a,4(1x,es12.4))') "central_difference_errors:", fd_errors
    write (*, '(a,es12.4)') "adjoint_residual: ", abs(lhs - rhs)
    write (*, '(a)') "observation: explicit integer-trip loop body only"

end program bench_tapenade_set01_lh015
