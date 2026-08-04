program plot_fortnum
    !! Bar chart of fortnum's operators, fortad against Enzyme.
    !!
    !! One panel: both engines return the primal value here, so the comparison
    !! is like for like. fortad's gradient-only variant is drawn alongside,
    !! since a caller that already has the value can have it.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use fortplot, only: figure, bar, xlabel, ylabel, title, savefig, legend, &
                        set_xticks
    implicit none

    integer, parameter :: NW = 8
    character(len=16) :: names(NW)
    real(dp) :: fortad(NW), enzyme(NW), tapenade(NW), fortad_g(NW)
    real(dp) :: pos(NW), unity(NW)
    integer :: i, n

    call read_results(names, fortad, enzyme, tapenade, fortad_g, n)
    if (n == 0) then
        print *, "no suite results; run scripts/build_fortnum_suite.sh first"
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
    call bar(pos(1:n) - 0.24_dp, fortad(1:n), width=0.24_dp, label="fortad")
    call bar(pos(1:n), enzyme(1:n), width=0.24_dp, label="Enzyme")
    call bar(pos(1:n) + 0.24_dp, fortad_g(1:n), width=0.24_dp, &
             label="fortad, gradient only")
    call set_xticks(pos(1:n), [(trim(names(i)), i=1, n)])
    call ylabel("nanoseconds per input (lower is better)")
    call title("fortnum operators: reverse-mode gradient over a batch")
    call legend()
    call savefig("results/fortnum_bars.png")
    print *, "wrote results/fortnum_bars.png"



contains

    subroutine read_results(names, fortad, enzyme, tapenade, fortad_g, n)
        !! Read the committed CSV.
        character(len=16), intent(out) :: names(:)
        real(dp), intent(out) :: fortad(:), enzyme(:), tapenade(:), fortad_g(:)
        integer, intent(out) :: n
        character(len=256) :: line
        character(len=32) :: w, e
        real(dp) :: secs, per
        integer :: unit, ios, nn, i, p1, p2, p3, p4

        n = 0
        open (newunit=unit, file="results/fortnum_suite.csv", status="old", &
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
            case ("primal")
                tapenade(i) = per
            case ("fortad-grad")
                fortad_g(i) = per
            end select
        end do
        close (unit)
    end subroutine read_results

    integer function slot(names, n, w) result(i)
        !! Index of workload `w`, appending it if new.
        character(len=16), intent(inout) :: names(:)
        integer, intent(inout) :: n
        character(len=*), intent(in) :: w

        do i = 1, n
            if (trim(names(i)) == w) return
        end do
        n = n + 1
        names(n) = w
        i = n
    end function slot

end program plot_fortnum
