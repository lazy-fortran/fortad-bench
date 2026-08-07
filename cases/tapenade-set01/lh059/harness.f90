program tapenade_set01_lh059_harness
    use tapenade_set01_lh059_hand, only: hand_value, hand_jvp
    use lh059_forward_mod, only: lh059_forward
    implicit none
    integer, parameter :: n = 31
    integer, parameter :: initial_i = 6
    real :: t(n), u(n), td(n), ud(n)
    real :: ht(n), hu(n), htd(n), hud(n)
    real :: gt(n), gu(n), gtd(n), gud(n)
    integer :: hi, gi, i
    real :: error

    interface
        subroutine set01_lh059(t, u, n, i)
            integer, intent(in) :: n
            integer, intent(inout) :: i
            real, intent(inout) :: t(31), u(31)
        end subroutine set01_lh059
    end interface

    do i = 1, n
        t(i) = 0.10 + 0.013*i
        u(i) = -0.20 + 0.007*i
        td(i) = 0.002 - 0.00011*i
        ud(i) = -0.003 + 0.00017*i
    end do
    t(6) = 2.0
    u(6) = -0.4
    do i = 11, 26, 5
        t(i) = -0.25
        u(i) = -1.0
    end do
    t(31) = -1.0

    ht = t
    hu = u
    hi = initial_i
    call hand_value(ht, hu, n, hi)

    gt = t
    gu = u
    gi = initial_i
    call set01_lh059(gt, gu, n, gi)
    error = max(maxval(abs(gt - ht)), maxval(abs(gu - hu)))
    if (gi /= hi .or. error > 2.0e-5) error stop "bounded primal mismatch"

    ht = t
    hu = u
    htd = td
    hud = ud
    hi = initial_i
    call hand_jvp(ht, htd, hu, hud, n, hi)

    gt = t
    gu = u
    gtd = td
    gud = ud
    gi = initial_i
    call lh059_forward(gt, gtd, gu, gud, n, gi)
    error = max(maxval(abs(gt - ht)), maxval(abs(gu - hu)))
    error = max(error, maxval(abs(gtd - htd)))
    error = max(error, maxval(abs(gud - hud)))
    if (gi /= hi .or. error > 5.0e-5) error stop "bounded JVP mismatch"

    write (*, '(a,es12.4)') 'harness_status: pass max_error=', error
end program tapenade_set01_lh059_harness
