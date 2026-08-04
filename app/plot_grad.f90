program plot_grad
    !! Gradient cost against problem size, for each engine.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use bench_results, only: row_t, read_rows
    use fortplot, only: figure, plot, xlabel, ylabel, title, legend, savefig, &
                        set_xscale
    implicit none

    type(row_t), allocatable :: rows(:)
    real(dp), allocatable :: x(:), y(:)
    integer :: n_rows

    call read_rows("results/dot_sin_grad.csv", rows, n_rows)
    if (n_rows == 0) then
        print *, "no gradient results; run the gradient benchmark first"
        error stop 1
    end if

    call figure(figsize=[8.0_dp, 6.0_dp])
    call series(rows, n_rows, "fortad-reverse", x, y)
    call plot(x, y, label="fortad reverse (fused)")
    call series(rows, n_rows, "enzyme-reverse", x, y)
    call plot(x, y, label="Enzyme reverse")
    call series(rows, n_rows, "analytical-reverse", x, y)
    call plot(x, y, label="hand-written adjoint")
    call set_xscale("log")
    call xlabel("array length n")
    call ylabel("nanoseconds per element")
    call title("dot_sin gradient: one reverse sweep over 2n inputs")
    call legend()
    call savefig("results/dot_sin_grad.png")
    print *, "wrote results/dot_sin_grad.png"

contains

    subroutine series(rows, n_rows, engine, x, y)
        !! Size sweep for one engine.
        type(row_t), intent(in) :: rows(:)
        integer, intent(in) :: n_rows
        character(len=*), intent(in) :: engine
        real(dp), allocatable, intent(out) :: x(:), y(:)
        integer :: i, k

        k = count([(trim(rows(i)%engine) == engine, i=1, n_rows)])
        allocate (x(k), y(k))
        k = 0
        do i = 1, n_rows
            if (trim(rows(i)%engine) /= engine) cycle
            k = k + 1
            x(k) = real(rows(i)%n, dp)
            y(k) = rows(i)%ns_per_element_per_dir
        end do
    end subroutine series

end program plot_grad
