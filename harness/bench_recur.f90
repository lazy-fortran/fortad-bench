program bench_recur
    !! Gradient of a nonlinear loop-carried recurrence.
    !!
    !! This is the case fortad's other advantages do not cover. Loop fusion is
    !! impossible - the adjoint runs backwards - and recomputation is
    !! impossible, because the carried value cannot be rebuilt from
    !! loop-invariant data. Both engines must store per-iteration history, so
    !! this is the fair fight, and it is worth measuring precisely because
    !! fortad might lose it.
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    interface
        subroutine recur_vjp_enzyme(n, a, ab, b, bb, s, sb) &
            bind(C, name="recur_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: a(*), ab(*), b(*), bb(*)
            real(c_double) :: s, sb
        end subroutine recur_vjp_enzyme

        pure subroutine recur_vjp(n, a, b, s, s_b, a_b, b_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: a(n), b(n)
            real(dp), intent(out) :: s
            real(dp), intent(in) :: s_b
            real(dp), intent(out) :: a_b(n), b_b(n)
        end subroutine recur_vjp
    end interface

    integer, parameter :: SIZES(*) = [1000, 10000, 100000, 1000000]
    real(dp), allocatable :: a(:), b(:), ab(:), bb(:), ra(:), rb(:)
    real(dp) :: s, sb, t0, t1
    integer :: unit, is, n, reps, r, i

    open (newunit=unit, file="results/recur_grad.csv", status="replace", &
          action="write")
    write (unit, '(a)') "engine,n,n_dir,seconds_total,ns_per_element_per_dir"

    do is = 1, size(SIZES)
        n = SIZES(is)
        allocate (a(n), b(n), ab(n), bb(n), ra(n), rb(n))
        do i = 1, n
            a(i) = 0.5_dp + 0.25_dp*sin(0.37_dp*i)
            b(i) = 0.9_dp + 0.50_dp*cos(0.11_dp*i)
        end do
        reps = max(3, min(2000, 20000000/n))

        ! Reference gradient, from a hand-written adjoint of the recurrence.
        call analytical(n, a, b, s, ra, rb)

        sb = 1.0_dp
        call recur_vjp(n, a, b, s, sb, ab, bb)
        call check("fortad", ra, rb, ab, bb)
        call cpu_time(t0)
        do r = 1, reps
            call recur_vjp(n, a, b, s, sb, ab, bb)
        end do
        call cpu_time(t1)
        call row(unit, "fortad-reverse", n, t1 - t0, reps)

        ab = 0.0_dp
        bb = 0.0_dp
        sb = 1.0_dp
        call recur_vjp_enzyme(n, a, ab, b, bb, s, sb)
        call check("enzyme", ra, rb, ab, bb)
        call cpu_time(t0)
        do r = 1, reps
            ab = 0.0_dp
            bb = 0.0_dp
            sb = 1.0_dp
            call recur_vjp_enzyme(n, a, ab, b, bb, s, sb)
        end do
        call cpu_time(t1)
        call row(unit, "enzyme-reverse", n, t1 - t0, reps)

        call cpu_time(t0)
        do r = 1, reps
            call analytical(n, a, b, s, ab, bb)
        end do
        call cpu_time(t1)
        call row(unit, "analytical-reverse", n, t1 - t0, reps)

        deallocate (a, b, ab, bb, ra, rb)
    end do

    close (unit)
    print *, "wrote results/recur_grad.csv"

contains

    subroutine analytical(n, a, b, s, ab, bb)
        !! Hand-written adjoint of the recurrence, taping u exactly as any
        !! correct implementation must. This is the ceiling for both engines.
        integer, intent(in) :: n
        real(dp), intent(in) :: a(n), b(n)
        real(dp), intent(out) :: s, ab(n), bb(n)
        real(dp), allocatable :: tape(:)
        real(dp) :: u, ub, e
        integer :: i

        allocate (tape(n))
        u = 1.0_dp
        s = 0.0_dp
        do i = 1, n
            tape(i) = u
            u = u*exp(0.01_dp*a(i)) + 0.1_dp*b(i)
            s = s + u*u
        end do

        ub = 0.0_dp
        do i = n, 1, -1
            e = exp(0.01_dp*a(i))
            u = tape(i)*e + 0.1_dp*b(i)
            ub = ub + 2.0_dp*u
            ab(i) = ub*tape(i)*e*0.01_dp
            bb(i) = ub*0.1_dp
            ub = ub*e
        end do
    end subroutine analytical

    subroutine check(engine, ra, rb, ga, gb)
        !! No timing is reported for a wrong gradient.
        character(len=*), intent(in) :: engine
        real(dp), intent(in) :: ra(:), rb(:), ga(:), gb(:)
        real(dp) :: err

        ! Relative, because this recurrence grows geometrically: at n = 1e6 the
        ! gradient entries are enormous and an absolute tolerance would reject
        ! a correct answer for being large.
        err = max(maxval(abs(ga - ra))/max(1.0_dp, maxval(abs(ra))), &
                  maxval(abs(gb - rb))/max(1.0_dp, maxval(abs(rb))))
        if (err > 1.0e-11_dp) then
            print *, "engine "//engine//" gradient disagrees, max relative error", err
            error stop 1
        end if
    end subroutine check

    subroutine row(unit, engine, n, seconds, reps)
        integer, intent(in) :: unit, n, reps
        character(len=*), intent(in) :: engine
        real(dp), intent(in) :: seconds

        write (unit, '(a,",",i0,",1,",es14.6,",",f12.4)') &
            engine, n, seconds, seconds*1.0e9_dp/(real(reps, dp)*real(n, dp))
    end subroutine row

end program bench_recur
