program bench_grad
    !! Gradient (reverse mode) comparison for the dot_sin kernel.
    !!
    !! One reverse sweep yields the gradient with respect to all 2n inputs,
    !! which is the cheap-gradient principle. The comparison against forward
    !! mode is therefore not a fair fight and is not the point; the point is
    !! fortad's adjoint against Enzyme's adjoint on the same kernel, and against
    !! the hand-written one that bounds them both.
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    interface
        subroutine dot_sin_vjp_enzyme(n, a, ab, b, bb, s, sb) &
            bind(C, name="dot_sin_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: a(*), ab(*), b(*), bb(*)
            real(c_double) :: s, sb
        end subroutine dot_sin_vjp_enzyme

        pure subroutine dot_sin_vjp(n, a, b, s, s_b, a_b, b_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: a(n), b(n)
            real(dp), intent(out) :: s
            real(dp), intent(in) :: s_b
            real(dp), intent(out) :: a_b(n), b_b(n)
        end subroutine dot_sin_vjp
    end interface

    integer, parameter :: SIZES(*) = [1000, 10000, 100000, 1000000]
    real(dp), allocatable :: a(:), b(:), ab(:), bb(:), ab2(:), bb2(:)
    real(dp), allocatable :: ref_a(:), ref_b(:)
    real(dp) :: s, sb, t0, t1
    integer :: unit, is, n, reps, r, i

    open (newunit=unit, file="results/dot_sin_grad.csv", status="replace", &
          action="write")
    ! Same schema as the other raw files, so one reader serves both.
    write (unit, '(a)') "engine,n,n_dir,seconds_total,ns_per_element_per_dir"

    do is = 1, size(SIZES)
        n = SIZES(is)
        allocate (a(n), b(n), ab(n), bb(n), ab2(n), bb2(n), ref_a(n), ref_b(n))
        do i = 1, n
            a(i) = 0.5_dp + 0.25_dp*sin(0.37_dp*i)
            b(i) = 0.9_dp + 0.50_dp*cos(0.11_dp*i)
        end do
        reps = max(3, min(2000, 20000000/n))

        ! Analytical gradient, by hand: d/da_i = sin(b_i), d/db_i = a_i cos(b_i).
        ref_a = sin(b)
        ref_b = a*cos(b)

        sb = 1.0_dp
        call dot_sin_vjp(n, a, b, s, sb, ab, bb)
        call check("fortad", ref_a, ref_b, ab, bb)
        call cpu_time(t0)
        do r = 1, reps
            call dot_sin_vjp(n, a, b, s, sb, ab, bb)
        end do
        call cpu_time(t1)
        call row(unit, "fortad-reverse", n, t1 - t0, reps)

        ! Enzyme accumulates into caller-zeroed shadows.
        ab2 = 0.0_dp
        bb2 = 0.0_dp
        sb = 1.0_dp
        call dot_sin_vjp_enzyme(n, a, ab2, b, bb2, s, sb)
        call check("enzyme", ref_a, ref_b, ab2, bb2)
        call cpu_time(t0)
        do r = 1, reps
            ab2 = 0.0_dp
            bb2 = 0.0_dp
            sb = 1.0_dp
            call dot_sin_vjp_enzyme(n, a, ab2, b, bb2, s, sb)
        end do
        call cpu_time(t1)
        call row(unit, "enzyme-reverse", n, t1 - t0, reps)

        ! Hand-written adjoint: the ceiling.
        call cpu_time(t0)
        do r = 1, reps
            call analytical_grad(n, a, b, s, ab2, bb2)
        end do
        call cpu_time(t1)
        call row(unit, "analytical-reverse", n, t1 - t0, reps)

        deallocate (a, b, ab, bb, ab2, bb2, ref_a, ref_b)
    end do

    close (unit)
    print *, "wrote results/dot_sin_grad.csv"

contains

    subroutine analytical_grad(n, a, b, s, ab, bb)
        !! The gradient a competent person would write by hand.
        integer, intent(in) :: n
        real(dp), intent(in) :: a(n), b(n)
        real(dp), intent(out) :: s, ab(n), bb(n)
        real(dp) :: sbv, cbv
        integer :: i

        s = 0.0_dp
        do i = 1, n
            sbv = sin(b(i))
            cbv = cos(b(i))
            s = s + a(i)*sbv
            ab(i) = sbv
            bb(i) = a(i)*cbv
        end do
    end subroutine analytical_grad

    subroutine check(engine, ref_a, ref_b, ga, gb)
        !! No timing is reported for a wrong gradient.
        character(len=*), intent(in) :: engine
        real(dp), intent(in) :: ref_a(:), ref_b(:), ga(:), gb(:)
        real(dp) :: err

        err = max(maxval(abs(ga - ref_a)), maxval(abs(gb - ref_b)))
        if (err > 1.0e-12_dp) then
            print *, "engine "//engine//" gradient disagrees, max error", err
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

end program bench_grad
