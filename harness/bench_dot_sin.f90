program bench_dot_sin
    !! Runtime comparison for the dot_sin kernel.
    !!
    !! Reports nanoseconds per element per direction, which is the number that
    !! makes scalar and vector modes comparable. Every engine computes the same
    !! mathematical object; correctness is checked before any timing is kept, so
    !! a fast wrong answer cannot win.
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    use, intrinsic :: iso_fortran_env, only: dp => real64, output_unit
    implicit none

    interface
        subroutine dot_sin_jvp_enzyme(n, a, ad, b, bd, s, sd) &
            bind(C, name="dot_sin_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: a(*), ad(*), b(*), bd(*)
            real(c_double) :: s, sd
        end subroutine dot_sin_jvp_enzyme
    end interface

    integer, parameter :: SIZES(*) = [1000, 10000, 100000, 1000000]
    integer, parameter :: DIRS(*) = [1, 2, 4, 8, 16]
    integer :: unit, is, id, n, nd

    open (newunit=unit, file="results/dot_sin_raw.csv", status="replace", &
          action="write")
    write (unit, '(a)') "engine,n,n_dir,seconds_total,ns_per_element_per_dir"

    do is = 1, size(SIZES)
        n = SIZES(is)
        call time_scalar_engines(n, unit)
        do id = 1, size(DIRS)
            nd = DIRS(id)
            call time_vector_engines(n, nd, unit)
        end do
    end do

    close (unit)
    write (output_unit, '(a)') "wrote results/dot_sin_raw.csv"

contains

    subroutine time_scalar_engines(n, unit)
        !! One direction: analytical, fortad scalar, Enzyme, and fortad vector
        !! with n_dir = 1 so the vector machinery's fixed overhead is visible.
        integer, intent(in) :: n, unit
        real(dp), allocatable :: a(:), b(:), ad(:), bd(:)
        real(dp) :: s, sd, ref
        integer :: reps

        allocate (a(n), b(n), ad(n), bd(n))
        call fill(a, b, ad, bd)
        reps = repetitions(n, 1)

        call dot_sin_jvp_analytical(n, a, ad, b, bd, s, sd)
        ref = sd

        call report(unit, "analytical", n, 1, reps, &
                    run_analytical(n, a, ad, b, bd, reps), ref, sd)

        call dot_sin_jvp(n, a, ad, b, bd, s, sd)
        call check("fortad-scalar", ref, sd)
        call report(unit, "fortad-scalar", n, 1, reps, &
                    run_fortad_scalar(n, a, ad, b, bd, reps), ref, sd)

        call dot_sin_jvp_enzyme(n, a, ad, b, bd, s, sd)
        call check("enzyme", ref, sd)
        call report(unit, "enzyme", n, 1, reps, &
                    run_enzyme(n, a, ad, b, bd, reps), ref, sd)
    end subroutine time_scalar_engines

    subroutine time_vector_engines(n, nd, unit)
        !! `nd` directions. fortad carries them in one sweep; the alternatives
        !! must repeat the whole primal per direction, which is the comparison.
        integer, intent(in) :: n, nd, unit
        real(dp), allocatable :: a(:), b(:), ad(:), bd(:)
        real(dp), allocatable :: av(:, :), bv(:, :), sv(:)
        real(dp), allocatable :: adc(:, :), bdc(:, :)
        real(dp) :: s, sd, t0, t1
        integer :: reps, r, j

        allocate (a(n), b(n), ad(n), bd(n))
        allocate (av(nd, n), bv(nd, n), sv(nd))
        ! The per-direction seeds are also held column-major, so the engines
        ! that must be called once per direction can pass a contiguous slice
        ! directly. Copying inside the timing loop would charge them for the
        ! harness's own bookkeeping, which would not be an honest comparison.
        allocate (adc(n, nd), bdc(n, nd))
        call fill(a, b, ad, bd)
        do j = 1, nd
            av(j, :) = ad*(1.0_dp + 0.01_dp*j)
            bv(j, :) = bd*(1.0_dp - 0.02_dp*j)
            adc(:, j) = av(j, :)
            bdc(:, j) = bv(j, :)
        end do
        reps = repetitions(n, nd)

        ! fortad vector: one primal sweep, nd tangents.
        call dot_sin_jvp_v(nd, n, a, av, b, bv, s, sv)
        call cpu_time(t0)
        do r = 1, reps
            call dot_sin_jvp_v(nd, n, a, av, b, bv, s, sv)
        end do
        call cpu_time(t1)
        call write_row(unit, "fortad-vector", n, nd, t1 - t0, reps)

        ! Enzyme: repeat the whole kernel once per direction.
        call cpu_time(t0)
        do r = 1, reps
            do j = 1, nd
                call dot_sin_jvp_enzyme(n, a, adc(:, j), b, bdc(:, j), s, sd)
            end do
        end do
        call cpu_time(t1)
        call write_row(unit, "enzyme-repeated", n, nd, t1 - t0, reps)

        ! fortad scalar, likewise repeated, to separate the vector-mode win
        ! from any difference between the two generated scalar kernels.
        call cpu_time(t0)
        do r = 1, reps
            do j = 1, nd
                call dot_sin_jvp(n, a, adc(:, j), b, bdc(:, j), s, sd)
            end do
        end do
        call cpu_time(t1)
        call write_row(unit, "fortad-scalar-repeated", n, nd, t1 - t0, reps)
    end subroutine time_vector_engines

    real(dp) function run_analytical(n, a, ad, b, bd, reps) result(seconds)
        integer, intent(in) :: n, reps
        real(dp), intent(in) :: a(:), ad(:), b(:), bd(:)
        real(dp) :: s, sd, t0, t1
        integer :: r

        call cpu_time(t0)
        do r = 1, reps
            call dot_sin_jvp_analytical(n, a, ad, b, bd, s, sd)
        end do
        call cpu_time(t1)
        seconds = t1 - t0
    end function run_analytical

    real(dp) function run_fortad_scalar(n, a, ad, b, bd, reps) result(seconds)
        integer, intent(in) :: n, reps
        real(dp), intent(in) :: a(:), ad(:), b(:), bd(:)
        real(dp) :: s, sd, t0, t1
        integer :: r

        call cpu_time(t0)
        do r = 1, reps
            call dot_sin_jvp(n, a, ad, b, bd, s, sd)
        end do
        call cpu_time(t1)
        seconds = t1 - t0
    end function run_fortad_scalar

    real(dp) function run_enzyme(n, a, ad, b, bd, reps) result(seconds)
        integer, intent(in) :: n, reps
        real(dp), intent(in), target :: a(:), ad(:), b(:), bd(:)
        real(dp) :: s, sd, t0, t1
        integer :: r

        call cpu_time(t0)
        do r = 1, reps
            call dot_sin_jvp_enzyme(n, a, ad, b, bd, s, sd)
        end do
        call cpu_time(t1)
        seconds = t1 - t0
    end function run_enzyme

    subroutine report(unit, engine, n, nd, reps, seconds, ref, got)
        integer, intent(in) :: unit, n, nd, reps
        character(len=*), intent(in) :: engine
        real(dp), intent(in) :: seconds, ref, got

        call check(engine, ref, got)
        call write_row(unit, engine, n, nd, seconds, reps)
    end subroutine report

    subroutine write_row(unit, engine, n, nd, seconds, reps)
        !! Normalise to nanoseconds per element per direction so sizes and
        !! direction counts are comparable on one axis.
        integer, intent(in) :: unit, n, nd, reps
        character(len=*), intent(in) :: engine
        real(dp), intent(in) :: seconds
        real(dp) :: per

        per = seconds*1.0e9_dp/(real(reps, dp)*real(n, dp)*real(nd, dp))
        write (unit, '(a,",",i0,",",i0,",",es14.6,",",f12.4)') &
            engine, n, nd, seconds, per
    end subroutine write_row

    subroutine check(engine, ref, got)
        !! No timing is reported for a wrong answer.
        character(len=*), intent(in) :: engine
        real(dp), intent(in) :: ref, got

        if (abs(got - ref) > 1.0e-10_dp*max(1.0_dp, abs(ref))) then
            write (*, '(a)') "engine "//engine//" disagrees with the analytical tangent"
            write (*, *) "  ref =", ref, " got =", got
            error stop 1
        end if
    end subroutine check

    subroutine fill(a, b, ad, bd)
        !! Deterministic inputs, so runs are comparable across machines.
        real(dp), intent(out) :: a(:), b(:), ad(:), bd(:)
        integer :: i

        do i = 1, size(a)
            a(i) = 0.5_dp + 0.25_dp*sin(0.37_dp*i)
            b(i) = 0.9_dp + 0.50_dp*cos(0.11_dp*i)
            ad(i) = sin(0.9_dp*i)
            bd(i) = cos(1.3_dp*i)
        end do
    end subroutine fill

    integer function repetitions(n, nd) result(reps)
        !! Enough work to time reliably without burning the machine: roughly a
        !! fixed number of element-directions per measurement.
        integer, intent(in) :: n, nd

        reps = max(3, min(2000, 20000000/(n*nd)))
    end function repetitions

end program bench_dot_sin
