program bench_enzyme_suite
    !! The Enzyme README workloads, gradient timings for fortad and Enzyme.
    !!
    !! These are the workloads the Enzyme paper reports: LSTM, bundle
    !! adjustment, Euler, RK4 and a Brusselator, taken from the same numerical
    !! contract used in `differentiable-fortran/studies/enzyme-readme`. Both
    !! engines differentiate the same Fortran kernel and both are compiled by
    !! the same flang, so the comparison is of derivative code rather than of
    !! two compilers.
    !!
    !! Every gradient is checked against central finite differences along a
    !! random direction before any timing is kept. A directional check tests the
    !! whole gradient at once, where checking entries one at a time would cost
    !! `n` extra runs per workload and still miss cross terms.
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    interface
        subroutine euler(n, z, y) bind(C, name="euler")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine euler
        subroutine rk4(n, z, y) bind(C, name="rk4")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine rk4
        subroutine lstm(n, z, y) bind(C, name="lstm")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine lstm
        subroutine ba(n, z, y) bind(C, name="ba")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine ba
        subroutine bruss(n, z, y) bind(C, name="bruss")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine bruss

        subroutine euler_vjp_enzyme(n, z, zb, y, yb) bind(C, name="euler_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine euler_vjp_enzyme
        subroutine rk4_vjp_enzyme(n, z, zb, y, yb) bind(C, name="rk4_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine rk4_vjp_enzyme
        subroutine lstm_vjp_enzyme(n, z, zb, y, yb) bind(C, name="lstm_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine lstm_vjp_enzyme
        subroutine ba_vjp_enzyme(n, z, zb, y, yb) bind(C, name="ba_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine ba_vjp_enzyme
        subroutine bruss_vjp_enzyme(n, z, zb, y, yb) bind(C, name="bruss_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine bruss_vjp_enzyme

        pure subroutine euler_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(n)
        end subroutine euler_vjp
        pure subroutine rk4_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(n)
        end subroutine rk4_vjp
        pure subroutine lstm_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(n)
        end subroutine lstm_vjp
        pure subroutine ba_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(3*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(3*n)
        end subroutine ba_vjp
        pure subroutine bruss_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(n)
        end subroutine bruss_vjp
    end interface

    integer, parameter :: NW = 5
    character(len=8), parameter :: NAMES(NW) = &
        [character(len=8) :: "euler", "rk4", "lstm", "ba", "bruss"]
    integer :: unit, w

    open (newunit=unit, file="results/enzyme_suite.csv", status="replace", &
          action="write")
    write (unit, '(a)') "workload,engine,n,seconds_total,ns_per_input"

    do w = 1, NW
        call run_workload(trim(NAMES(w)), unit)
    end do

    close (unit)
    print *, "wrote results/enzyme_suite.csv"

contains

    subroutine run_workload(name, unit)
        !! Time both engines on one workload after checking both gradients.
        character(len=*), intent(in) :: name
        integer, intent(in) :: unit
        integer, parameter :: N_ELEM = 20000
        integer, parameter :: N_TRIALS = 7
        integer :: n_in, reps, r, i, trial
        real(dp), allocatable :: z(:), zb(:), zb2(:), dir(:)
        real(dp) :: y, yb, t0, t1, best_f, best_e

        n_in = N_ELEM
        if (name == "ba") n_in = 3*N_ELEM

        allocate (z(n_in), zb(n_in), zb2(n_in), dir(n_in))
        do i = 1, n_in
            z(i) = 0.4_dp + 0.3_dp*sin(0.31_dp*i)
            dir(i) = cos(0.77_dp*i)
        end do
        reps = max(3, 4000000/n_in)

        yb = 1.0_dp
        call call_fortad(name, N_ELEM, z, y, yb, zb)
        zb2 = 0.0_dp
        yb = 1.0_dp
        call call_enzyme(name, N_ELEM, z, zb2, y, yb)

        ! Two independent implementations agreeing to near machine precision is
        ! a far sharper check than finite differences, which on BA lose four
        ! digits to cancellation because the objective is order 1e5. So the
        ! engines are cross-checked tightly and differenced loosely: the first
        ! catches a wrong derivative, the second catches both being wrong the
        ! same way.
        call cross_check(name, zb, zb2)
        call check(name, "fortad", N_ELEM, z, dir, zb)

        ! Best of several timing runs, interleaved. A single run of each
        ! engine was swinging 20% between invocations - enough to invent a
        ! winner - and interleaving keeps a thermal or frequency drift from
        ! landing on one engine only.
        best_f = huge(1.0_dp)
        best_e = huge(1.0_dp)
        do trial = 1, N_TRIALS
            call cpu_time(t0)
            do r = 1, reps
                yb = 1.0_dp
                call call_fortad(name, N_ELEM, z, y, yb, zb)
            end do
            call cpu_time(t1)
            best_f = min(best_f, t1 - t0)

            call cpu_time(t0)
            do r = 1, reps
                zb2 = 0.0_dp
                yb = 1.0_dp
                call call_enzyme(name, N_ELEM, z, zb2, y, yb)
            end do
            call cpu_time(t1)
            best_e = min(best_e, t1 - t0)
        end do
        call row(unit, name, "fortad", n_in, best_f, reps)
        call row(unit, name, "enzyme", n_in, best_e, reps)

        deallocate (z, zb, zb2, dir)
    end subroutine run_workload

    subroutine call_fortad(name, n, z, y, yb, zb)
        !! Dispatch to the fortad-generated adjoint.
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:)
        real(dp), intent(out) :: y
        real(dp), intent(in) :: yb
        real(dp), intent(out) :: zb(:)

        select case (name)
        case ("euler")
            call euler_vjp(n, z, y, yb, zb)
        case ("rk4")
            call rk4_vjp(n, z, y, yb, zb)
        case ("lstm")
            call lstm_vjp(n, z, y, yb, zb)
        case ("ba")
            call ba_vjp(n, z, y, yb, zb)
        case ("bruss")
            call bruss_vjp(n, z, y, yb, zb)
        end select
    end subroutine call_fortad

    subroutine call_enzyme(name, n, z, zb, y, yb)
        !! Dispatch to the Enzyme-generated adjoint.
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(inout) :: z(:), zb(:)
        real(dp), intent(inout) :: y, yb

        select case (name)
        case ("euler")
            call euler_vjp_enzyme(n, z, zb, y, yb)
        case ("rk4")
            call rk4_vjp_enzyme(n, z, zb, y, yb)
        case ("lstm")
            call lstm_vjp_enzyme(n, z, zb, y, yb)
        case ("ba")
            call ba_vjp_enzyme(n, z, zb, y, yb)
        case ("bruss")
            call bruss_vjp_enzyme(n, z, zb, y, yb)
        end select
    end subroutine call_enzyme

    subroutine primal(name, n, z, y)
        !! The undifferentiated kernel, for the finite-difference check.
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(inout) :: z(:)
        real(dp), intent(out) :: y

        select case (name)
        case ("euler")
            call euler(n, z, y)
        case ("rk4")
            call rk4(n, z, y)
        case ("lstm")
            call lstm(n, z, y)
        case ("ba")
            call ba(n, z, y)
        case ("bruss")
            call bruss(n, z, y)
        end select
    end subroutine primal

    subroutine cross_check(name, g1, g2)
        !! fortad against Enzyme, entry by entry.
        character(len=*), intent(in) :: name
        real(dp), intent(in) :: g1(:), g2(:)
        real(dp) :: err, scale

        scale = max(1.0_dp, maxval(abs(g2)))
        err = maxval(abs(g1 - g2))/scale
        if (err > 1.0e-12_dp) then
            print *, "workload "//name// &
                ": fortad and Enzyme gradients differ, relative", err
            error stop 1
        end if
    end subroutine cross_check

    subroutine check(name, engine, n, z, dir, g)
        !! Directional finite-difference check of a whole gradient.
        character(len=*), intent(in) :: name, engine
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:), dir(:), g(:)
        real(dp), allocatable :: zp(:), zm(:)
        real(dp) :: sp, sm, fd, ad, h

        allocate (zp(size(z)), zm(size(z)))
        h = 1.0e-7_dp
        zp = z + h*dir
        zm = z - h*dir
        call primal(name, n, zp, sp)
        call primal(name, n, zm, sm)
        fd = (sp - sm)/(2.0_dp*h)
        ad = sum(g*dir)

        ! Loose on purpose: a central difference of a quantity this large
        ! keeps only about half its digits, so a tight bound here would reject
        ! correct gradients rather than catch wrong ones.
        if (abs(fd - ad) > 1.0e-3_dp*max(1.0_dp, abs(ad))) then
            print *, "workload "//name//", engine "//engine// &
                ": gradient disagrees with finite differences"
            print *, "  ad =", ad, " fd =", fd
            error stop 1
        end if
    end subroutine check

    subroutine row(unit, name, engine, n_in, seconds, reps)
        !! One record. Normalised per input so workloads are comparable.
        integer, intent(in) :: unit, n_in, reps
        character(len=*), intent(in) :: name, engine
        real(dp), intent(in) :: seconds

        write (unit, '(a,",",a,",",i0,",",es14.6,",",f12.4)') &
            name, engine, n_in, seconds, &
            seconds*1.0e9_dp/(real(reps, dp)*real(n_in, dp))
    end subroutine row

end program bench_enzyme_suite
