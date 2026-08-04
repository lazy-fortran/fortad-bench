program plot_threads
    !! Parallel scaling of the generated derivative kernel.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use fortplot, only: figure, plot, xlabel, ylabel, title, legend, savefig
    implicit none

    real(dp) :: threads(16), speedup(16), ideal(16)
    character(len=256) :: line
    integer :: unit, ios, n
    real(dp) :: seconds, diff

    open (newunit=unit, file="results/threads_raw.csv", status="old", &
          action="read", iostat=ios)
    if (ios /= 0) then
        print *, "no results; run the thread benchmark first"
        error stop 1
    end if
    read (unit, '(a)', iostat=ios) line
    n = 0
    do
        read (unit, '(a)', iostat=ios) line
        if (ios /= 0) exit
        n = n + 1
        read (line, *) threads(n), seconds, speedup(n), diff
        ideal(n) = threads(n)
    end do
    close (unit)

    call figure(figsize=[8.0_dp, 6.0_dp])
    call plot(threads(1:n), speedup(1:n), label="fortad generated JVP")
    call plot(threads(1:n), ideal(1:n), label="ideal linear scaling")
    call xlabel("OpenMP threads")
    call ylabel("speedup over one thread")
    call title("Generated derivative kernel: parallel scaling")
    call legend()
    call savefig("results/threads_scaling.png")
    print *, "wrote results/threads_scaling.png"

end program plot_threads
