program plot_suite
    !! Bar chart of the Enzyme README workloads.
    !!
    !! Two panels, because the engines do not all offer the same contract.
    !! Tapenade's reverse routine never assigns the primal output; Enzyme's
    !! must, because the seed rides on a duplicated output. Comparing across
    !! that difference credits Tapenade with a forward loop it does not run,
    !! so with-primal and gradient-only engines are drawn separately.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use fortplot, only: figure, bar, xlabel, ylabel, title, savefig, legend, &
                        set_xticks
    implicit none

    integer, parameter :: NW = 5
    character(len=8) :: names(NW)
    real(dp) :: fortad(NW), enzyme(NW), tapenade(NW), fortad_g(NW)
    real(dp) :: pos(NW), unity(NW)
    integer :: i, n

    call read_results(names, fortad, enzyme, tapenade, fortad_g, n)
    if (n == 0) then
        print *, "no suite results; run scripts/build_enzyme_suite.sh first"
        error stop 1
    end if

    ! Absolute cost, not a speedup ratio: a ratio has to pick a denominator,
    ! and picking one quietly makes it the reference. Bars of nanoseconds per
    ! input let every pair be compared directly, and the shortest bar wins with
    ! no further arithmetic.
    do i = 1, n
        pos(i) = real(i, dp)
        unity(i) = 1.0_dp
    end do

    call figure(figsize=[10.0_dp, 6.0_dp])
    call bar(pos(1:n) - 0.18_dp, fortad(1:n), width=0.36_dp, label="fortad")
    call bar(pos(1:n) + 0.18_dp, enzyme(1:n), width=0.36_dp, label="Enzyme")
    call set_xticks(pos(1:n), [(trim(names(i)), i=1, n)])
    call ylabel("nanoseconds per input (lower is better)")
    call title("Enzyme README workloads: gradient and primal value")
    call legend()
    call savefig("results/enzyme_suite_bars.png")
    print *, "wrote results/enzyme_suite_bars.png"

    call figure(figsize=[10.0_dp, 6.0_dp])
    call bar(pos(1:n) - 0.18_dp, fortad_g(1:n), width=0.36_dp, label="fortad")
    call bar(pos(1:n) + 0.18_dp, tapenade(1:n), width=0.36_dp, label="Tapenade 3.16")
    call set_xticks(pos(1:n), [(trim(names(i)), i=1, n)])
    call ylabel("nanoseconds per input (lower is better)")
    call title("Enzyme README workloads: gradient only, no primal value")
    call legend()
    call savefig("results/enzyme_suite_bars_grad.png")
    print *, "wrote results/enzyme_suite_bars_grad.png"

contains

    subroutine read_results(names, fortad, enzyme, tapenade, fortad_g, n)
        !! Read the committed CSV.
        character(len=8), intent(out) :: names(:)
        real(dp), intent(out) :: fortad(:), enzyme(:), tapenade(:), fortad_g(:)
        integer, intent(out) :: n
        character(len=256) :: line
        character(len=32) :: w, e
        real(dp) :: secs, per
        integer :: unit, ios, nn, i, p1, p2, p3, p4

        n = 0
        open (newunit=unit, file="results/enzyme_suite.csv", status="old", &
              action="read", iostat=ios)
        if (ios /= 0) return
        read (unit, '(a)', iostat=ios) line
        do
            read (unit, '(a)', iostat=ios) line
            if (ios /= 0) exit
            p1 = index(line, ",")
            p2 = index(line(p1 + 1:), ",") + p1
            p3 = index(line(p2 + 1:), ",") + p2
            p4 = index(line(p3 + 1:), ",") + p3
            w = adjustl(line(1:p1 - 1))
            e = adjustl(line(p1 + 1:p2 - 1))
            read (line(p2 + 1:p3 - 1), *) nn
            read (line(p3 + 1:p4 - 1), *) secs
            read (line(p4 + 1:), *) per

            i = slot(names, n, trim(w))
            select case (trim(e))
            case ("fortad")
                fortad(i) = per
            case ("enzyme")
                enzyme(i) = per
            case ("tapenade")
                tapenade(i) = per
            case ("fortad-grad")
                fortad_g(i) = per
            end select
        end do
        close (unit)
    end subroutine read_results

    integer function slot(names, n, w) result(i)
        !! Index of workload `w`, appending it if new.
        character(len=8), intent(inout) :: names(:)
        integer, intent(inout) :: n
        character(len=*), intent(in) :: w

        do i = 1, n
            if (trim(names(i)) == w) return
        end do
        n = n + 1
        names(n) = w
        i = n
    end function slot

end program plot_suite
