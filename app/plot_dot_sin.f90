program plot_dot_sin
    !! Figures for the dot_sin case, generated from the committed CSV.
    !!
    !! Two figures, because there are two separate claims:
    !!
    !!   1. Per-direction cost against direction count. This is where vector
    !!      mode is supposed to win, and by how much.
    !!   2. Single-direction cost against problem size. This is the honest
    !!      like-for-like comparison, where every engine does the same work.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use bench_results, only: row_t, read_rows
    use fortplot, only: figure, plot, xlabel, ylabel, title, legend, savefig, &
                        set_xscale, set_yscale
    implicit none

    type(row_t), allocatable :: rows(:)
    integer :: n_rows

    call read_rows("results/dot_sin_raw.csv", rows, n_rows)
    if (n_rows == 0) then
        print *, "no results found; run scripts/run_bench.sh first"
        error stop 1
    end if

    call plot_directions(rows, n_rows)
    call plot_sizes(rows, n_rows)
    print *, "wrote results/dot_sin_directions.png and results/dot_sin_sizes.png"

contains

    subroutine plot_directions(rows, n_rows)
        !! Cost per direction against direction count, at the largest size.
        type(row_t), intent(in) :: rows(:)
        integer, intent(in) :: n_rows
        real(dp), allocatable :: x(:), y(:)
        integer :: n_big

        n_big = largest_size(rows, n_rows)

        call figure(figsize=[8.0_dp, 6.0_dp])
        call series(rows, n_rows, "fortad-vector", n_big, x, y)
        call plot(x, y, label="fortad vector mode")
        call series(rows, n_rows, "enzyme-repeated", n_big, x, y)
        call plot(x, y, label="Enzyme, one call per direction")
        call series(rows, n_rows, "fortad-scalar-repeated", n_big, x, y)
        call plot(x, y, label="fortad scalar, one call per direction")

        call set_xscale("log")
        call set_yscale("log")
        call xlabel("tangent directions carried")
        call ylabel("nanoseconds per element per direction")
        call title("dot_sin, n = "//itoa(n_big)//": cost per direction")
        call legend()
        call savefig("results/dot_sin_directions.png")
    end subroutine plot_directions

    subroutine plot_sizes(rows, n_rows)
        !! Single-direction cost against problem size: the like-for-like case.
        type(row_t), intent(in) :: rows(:)
        integer, intent(in) :: n_rows
        real(dp), allocatable :: x(:), y(:)

        call figure(figsize=[8.0_dp, 6.0_dp])
        call size_series(rows, n_rows, "fortad-scalar", x, y)
        call plot(x, y, label="fortad")
        call size_series(rows, n_rows, "enzyme", x, y)
        call plot(x, y, label="Enzyme")
        call size_series(rows, n_rows, "analytical", x, y)
        call plot(x, y, label="hand-written analytical")

        call set_xscale("log")
        call xlabel("array length n")
        call ylabel("nanoseconds per element")
        call title("dot_sin, one tangent direction")
        call legend()
        call savefig("results/dot_sin_sizes.png")
    end subroutine plot_sizes

    subroutine series(rows, n_rows, engine, n_fixed, x, y)
        !! Direction sweep for one engine at one problem size.
        type(row_t), intent(in) :: rows(:)
        integer, intent(in) :: n_rows, n_fixed
        character(len=*), intent(in) :: engine
        real(dp), allocatable, intent(out) :: x(:), y(:)
        integer :: i, k

        k = 0
        do i = 1, n_rows
            if (trim(rows(i)%engine) == engine .and. rows(i)%n == n_fixed) k = k + 1
        end do
        allocate (x(k), y(k))
        k = 0
        do i = 1, n_rows
            if (trim(rows(i)%engine) /= engine) cycle
            if (rows(i)%n /= n_fixed) cycle
            k = k + 1
            x(k) = real(rows(i)%n_dir, dp)
            y(k) = rows(i)%ns_per_element_per_dir
        end do
    end subroutine series

    subroutine size_series(rows, n_rows, engine, x, y)
        !! Size sweep for one engine at a single direction.
        type(row_t), intent(in) :: rows(:)
        integer, intent(in) :: n_rows
        character(len=*), intent(in) :: engine
        real(dp), allocatable, intent(out) :: x(:), y(:)
        integer :: i, k

        k = 0
        do i = 1, n_rows
            if (trim(rows(i)%engine) == engine .and. rows(i)%n_dir == 1) k = k + 1
        end do
        allocate (x(k), y(k))
        k = 0
        do i = 1, n_rows
            if (trim(rows(i)%engine) /= engine) cycle
            if (rows(i)%n_dir /= 1) cycle
            k = k + 1
            x(k) = real(rows(i)%n, dp)
            y(k) = rows(i)%ns_per_element_per_dir
        end do
    end subroutine size_series

    integer function largest_size(rows, n_rows) result(n_big)
        !! The largest problem size present.
        type(row_t), intent(in) :: rows(:)
        integer, intent(in) :: n_rows
        integer :: i

        n_big = 0
        do i = 1, n_rows
            n_big = max(n_big, rows(i)%n)
        end do
    end function largest_size

    function itoa(n) result(s)
        !! Integer to trimmed decimal text.
        integer, intent(in) :: n
        character(len=:), allocatable :: s
        character(len=32) :: buf

        write (buf, '(i0)') n
        s = trim(buf)
    end function itoa

end program plot_dot_sin
