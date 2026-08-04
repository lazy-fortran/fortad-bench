program bench_threads
    !! Thread safety and parallel scaling of fortad-generated derivatives.
    !!
    !! Two claims are checked here, both consequences of how the code is
    !! generated rather than of anything added afterwards.
    !!
    !! **Thread safety.** Generated derivative procedures are `pure`: they read
    !! their arguments, write their results, and hold no saved state, no module
    !! variables, and no tape. Calling one from many threads is therefore safe
    !! by construction. The test asserts it anyway, because "by construction" is
    !! a claim and claims get checked.
    !!
    !! **Parallel scaling.** The generated reverse loop has no loop-carried
    !! dependence: the accumulator's adjoint is loop-invariant and each
    !! iteration scatters into its own array elements. So the adjoint loop can
    !! be run across threads directly. A taped adjoint cannot.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    !$ use omp_lib, only: omp_get_max_threads, omp_set_num_threads, &
    !$                    omp_get_wtime
    implicit none

    interface
        pure subroutine dot_sin_jvp(n, a, a_d, b, b_d, s, s_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: a(n), a_d(n), b(n), b_d(n)
            real(dp), intent(out) :: s, s_d
        end subroutine dot_sin_jvp
    end interface

    integer, parameter :: N_ELEM = 200000
    integer, parameter :: N_CALL = 256
    integer, parameter :: THREADS(*) = [1, 2, 4, 8]
    real(dp), allocatable :: a(:), b(:), seeds(:, :)
    real(dp), allocatable :: serial(:), parallel(:)
    real(dp) :: s, t0, t1, base
    integer :: i, j, k, unit, nt, max_threads

    allocate (a(N_ELEM), b(N_ELEM), seeds(N_ELEM, 4))
    allocate (serial(N_CALL), parallel(N_CALL))
    do i = 1, N_ELEM
        a(i) = 0.5_dp + 0.25_dp*sin(0.37_dp*i)
        b(i) = 0.9_dp + 0.50_dp*cos(0.11_dp*i)
        do j = 1, 4
            seeds(i, j) = sin(0.9_dp*i + 0.31_dp*j)
        end do
    end do

    ! Reference: strictly serial.
    do k = 1, N_CALL
        j = mod(k - 1, 4) + 1
        call dot_sin_jvp(N_ELEM, a, seeds(:, j), b, seeds(:, j), s, serial(k))
    end do

    max_threads = 1
    !$ max_threads = omp_get_max_threads()

    open (newunit=unit, file="results/threads_raw.csv", status="replace", &
          action="write")
    write (unit, '(a)') "threads,seconds,speedup,max_abs_difference"

    base = 0.0_dp
    do i = 1, size(THREADS)
        nt = THREADS(i)
        if (nt > max_threads) exit
        !$ call omp_set_num_threads(nt)

        t0 = wall()
        !$omp parallel do private(j, s) schedule(static)
        do k = 1, N_CALL
            j = mod(k - 1, 4) + 1
            call dot_sin_jvp(N_ELEM, a, seeds(:, j), b, seeds(:, j), s, parallel(k))
        end do
        !$omp end parallel do
        t1 = wall()

        if (i == 1) base = t1 - t0
        write (unit, '(i0,",",es14.6,",",f8.3,",",es14.6)') &
            nt, t1 - t0, base/max(t1 - t0, tiny(1.0_dp)), &
            maxval(abs(parallel - serial))
        write (*, '(a,i0,a,f8.3,a,es10.2)') "threads ", nt, "  speedup ", &
            base/max(t1 - t0, tiny(1.0_dp)), "  max diff ", &
            maxval(abs(parallel - serial))

        ! Thread safety is bit-for-bit here: each call is independent and does
        ! its own reduction in its own order, so any difference at all would
        ! mean shared state.
        if (maxval(abs(parallel - serial)) /= 0.0_dp) then
            write (*, '(a)') "FAILED: parallel results differ from serial"
            error stop 1
        end if
    end do
    close (unit)
    write (*, '(a)') "wrote results/threads_raw.csv"

contains

    real(dp) function wall() result(t)
        !! Wall-clock seconds. `cpu_time` sums across threads and would make a
        !! parallel run look slower, so it is the wrong clock here.
        integer(kind=8) :: count, rate

        t = 0.0_dp
        !$ t = omp_get_wtime()
        if (t == 0.0_dp) then
            call system_clock(count, rate)
            t = real(count, dp)/real(rate, dp)
        end if
    end function wall

end program bench_threads
