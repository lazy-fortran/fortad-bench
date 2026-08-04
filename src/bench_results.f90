module bench_results
    !! Reading the committed measurement records.
    !!
    !! Plots are generated from the CSV, never from numbers typed into the
    !! plotting code, so a figure cannot drift away from the run it claims to
    !! show.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private

    public :: row_t, read_rows

    type :: row_t
        character(len=32) :: engine = ""
        integer :: n = 0
        integer :: n_dir = 0
        real(dp) :: seconds = 0.0_dp
        real(dp) :: ns_per_element_per_dir = 0.0_dp
    end type row_t

contains

    subroutine read_rows(path, rows, n_rows)
        !! Read a raw results file.
        character(len=*), intent(in) :: path
        type(row_t), allocatable, intent(out) :: rows(:)
        integer, intent(out) :: n_rows
        character(len=256) :: line
        integer :: unit, ios, cap
        type(row_t), allocatable :: tmp(:)

        cap = 256
        allocate (rows(cap))
        n_rows = 0

        open (newunit=unit, file=path, status="old", action="read", iostat=ios)
        if (ios /= 0) return
        read (unit, '(a)', iostat=ios) line          ! header
        do
            read (unit, '(a)', iostat=ios) line
            if (ios /= 0) exit
            if (len_trim(line) == 0) cycle
            if (n_rows >= cap) then
                allocate (tmp(2*cap))
                tmp(1:cap) = rows
                call move_alloc(tmp, rows)
                cap = 2*cap
            end if
            n_rows = n_rows + 1
            call parse_row(line, rows(n_rows))
        end do
        close (unit)
    end subroutine read_rows

    subroutine parse_row(line, row)
        !! One comma-separated record.
        character(len=*), intent(in) :: line
        type(row_t), intent(out) :: row
        integer :: p1, p2, p3, p4

        p1 = index(line, ",")
        p2 = index(line(p1 + 1:), ",") + p1
        p3 = index(line(p2 + 1:), ",") + p2
        p4 = index(line(p3 + 1:), ",") + p3

        row%engine = adjustl(line(1:p1 - 1))
        read (line(p1 + 1:p2 - 1), *) row%n
        read (line(p2 + 1:p3 - 1), *) row%n_dir
        read (line(p3 + 1:p4 - 1), *) row%seconds
        read (line(p4 + 1:), *) row%ns_per_element_per_dir
    end subroutine parse_row

end module bench_results
