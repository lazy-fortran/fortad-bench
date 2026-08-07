program bench_tapenade_set01_lh010
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    use tapenade_set01_lh010_case, only: set01_lh010
    use tapenade_set01_lh010_hand, only: lh010_hand
    use lh010_forward_ad, only: lh010_jvp
    use lh010_reverse_ad, only: lh010_vjp
    implicit none

    integer, parameter :: repetitions = 200000
    real(dp), parameter :: steps(4) = [1.0e-2_dp, 1.0e-3_dp, 1.0e-4_dp, &
                                       1.0e-5_dp]
    real(dp) :: x(100), direction(100), vjp_hand(100), vjp_generated(100)
    real(dp) :: total, total_hand, total_forward, total_reverse
    real(dp) :: jvp_hand, jvp_generated, seed, lhs, rhs
    real(dp) :: plus, minus, fd, fd_errors(4), checksum
    real(dp) :: primal_ns, jvp_ns, vjp_ns
    integer :: i, k
    integer(int64) :: tick_start, tick_stop, tick_rate

    do i = 1, 100
        x(i) = 0.995_dp + 0.0001_dp*real(i, dp)
        direction(i) = 0.01_dp*sin(real(i, dp))
    end do
    seed = -0.75_dp

    call set01_lh010(x, total)
    call lh010_hand(x, direction, seed, total_hand, jvp_hand, vjp_hand)
    call lh010_jvp(x, direction, total_forward, jvp_generated)
    call lh010_vjp(x, total_reverse, seed, vjp_generated)
    call check_close(total, total_hand, 2.0e-13_dp, "primal versus hand")
    call check_close(total_forward, total, 2.0e-13_dp, "forward primal")
    call check_close(total_reverse, total, 2.0e-13_dp, "reverse primal")
    call check_close(jvp_generated, jvp_hand, 2.0e-12_dp, "JVP")
    if (maxval(abs(vjp_generated - vjp_hand)) > 2.0e-12_dp) then
        error stop "lh010 VJP mismatch"
    end if

    do k = 1, size(steps)
        call set01_lh010(x + steps(k)*direction, plus)
        call set01_lh010(x - steps(k)*direction, minus)
        fd = (plus - minus)/(2.0_dp*steps(k))
        fd_errors(k) = abs(fd - jvp_hand)
    end do
    if (minval(fd_errors) > 2.0e-8_dp) then
        error stop "lh010 finite-difference sweep did not converge"
    end if
    if (fd_errors(2) >= fd_errors(1)) then
        error stop "lh010 finite-difference refinement did not improve"
    end if

    lhs = seed*jvp_generated
    rhs = dot_product(vjp_generated, direction)
    call check_close(lhs, rhs, 2.0e-12_dp, "adjoint identity")

    checksum = 0.0_dp
    call system_clock(tick_start, tick_rate)
    do k = 1, repetitions
        call set01_lh010(x, total)
        checksum = checksum + total
    end do
    call system_clock(tick_stop)
    primal_ns = elapsed_ns(tick_start, tick_stop, tick_rate, repetitions)

    call system_clock(tick_start)
    do k = 1, repetitions
        call lh010_jvp(x, direction, total_forward, jvp_generated)
        checksum = checksum + jvp_generated
    end do
    call system_clock(tick_stop)
    jvp_ns = elapsed_ns(tick_start, tick_stop, tick_rate, repetitions)

    call system_clock(tick_start)
    do k = 1, repetitions
        call lh010_vjp(x, total_reverse, seed, vjp_generated)
        checksum = checksum + vjp_generated(1)
    end do
    call system_clock(tick_stop)
    vjp_ns = elapsed_ns(tick_start, tick_stop, tick_rate, repetitions)

    write (*, '(a)') "oracle_status: pass"
    write (*, '(a,es24.16)') "jvp: ", jvp_generated
    write (*, '(a,4(1x,es12.4))') "fd_errors:", fd_errors
    write (*, '(a,es24.16)') "adjoint_residual: ", abs(lhs - rhs)
    write (*, '(a,es24.16)') "checksum: ", checksum
    write (*, '(a,es24.16)') "primal_ns_per_call: ", primal_ns
    write (*, '(a,es24.16)') "jvp_ns_per_call: ", jvp_ns
    write (*, '(a,es24.16)') "vjp_ns_per_call: ", vjp_ns
contains
    subroutine check_close(actual, expected, tolerance, label)
        real(dp), intent(in) :: actual, expected, tolerance
        character(len=*), intent(in) :: label

        if (abs(actual - expected) > tolerance*max(1.0_dp, abs(expected))) then
            write (*, '(a,2(1x,es24.16))') trim(label), actual, expected
            error stop "lh010 scalar mismatch"
        end if
    end subroutine check_close

    real(dp) function elapsed_ns(first, last, rate, count) result(value)
        integer(int64), intent(in) :: first, last, rate
        integer, intent(in) :: count

        value = real(last - first, dp)*1.0e9_dp/ &
                (real(rate, dp)*real(count, dp))
    end function elapsed_ns
end program bench_tapenade_set01_lh010
