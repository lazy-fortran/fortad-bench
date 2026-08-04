program bench_stencil
    !! Gradient of a nonlinear stencil reduction.
    !!
    !! This case exists because dot_sin does not exercise scatter adjoints: the
    !! stencil writes a per-element intermediate to an array and then reduces
    !! it, which is the shape a PDE residual takes and the shape where an AD
    !! tool's handling of a written array shows.
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    interface
        subroutine stencil_vjp_enzyme(n, a, ab, b, bb, s, sb) &
            bind(C, name="stencil_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: a(*), ab(*), b(*), bb(*)
            real(c_double) :: s, sb
        end subroutine stencil_vjp_enzyme

        pure subroutine stencil_vjp(n, a, b, s, s_b, a_b, b_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: a(n), b(n)
            real(dp), intent(out) :: s
            real(dp), intent(in) :: s_b
            real(dp), intent(out) :: a_b(n), b_b(n)
        end subroutine stencil_vjp
    end interface

    integer, parameter :: SIZES(*) = [1000, 10000, 100000, 1000000]
    real(dp), allocatable :: a(:), b(:), ab(:), bb(:), ra(:), rb(:)
    real(dp) :: s, sb, t0, t1
    integer :: unit, is, n, reps, r, i

    open (newunit=unit, file="results/stencil_grad.csv", status="replace", &
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

        ! Analytical gradient. With c = sqrt(1+a^2)*tanh(b) and s = sum c^2:
        !   ds/da_i = 2 c_i * tanh(b_i) * a_i/sqrt(1+a_i^2)
        !   ds/db_i = 2 c_i * sqrt(1+a_i^2) * (1 - tanh(b_i)^2)
        do i = 1, n
            block
                real(dp) :: root, th, cval
                root = sqrt(1.0_dp + a(i)*a(i))
                th = tanh(b(i))
                cval = root*th
                ra(i) = 2.0_dp*cval*th*a(i)/root
                rb(i) = 2.0_dp*cval*root*(1.0_dp - th*th)
            end block
        end do

        sb = 1.0_dp
        call stencil_vjp(n, a, b, s, sb, ab, bb)
        call check("fortad", ra, rb, ab, bb)
        call cpu_time(t0)
        do r = 1, reps
            call stencil_vjp(n, a, b, s, sb, ab, bb)
        end do
        call cpu_time(t1)
        call row(unit, "fortad-reverse", n, t1 - t0, reps)

        ab = 0.0_dp
        bb = 0.0_dp
        sb = 1.0_dp
        call stencil_vjp_enzyme(n, a, ab, b, bb, s, sb)
        call check("enzyme", ra, rb, ab, bb)
        call cpu_time(t0)
        do r = 1, reps
            ab = 0.0_dp
            bb = 0.0_dp
            sb = 1.0_dp
            call stencil_vjp_enzyme(n, a, ab, b, bb, s, sb)
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
    print *, "wrote results/stencil_grad.csv"

contains

    subroutine analytical(n, a, b, s, ab, bb)
        !! The hand-written adjoint: the ceiling for both tools.
        integer, intent(in) :: n
        real(dp), intent(in) :: a(n), b(n)
        real(dp), intent(out) :: s, ab(n), bb(n)
        real(dp) :: root, th, cval
        integer :: i

        s = 0.0_dp
        do i = 1, n
            root = sqrt(1.0_dp + a(i)*a(i))
            th = tanh(b(i))
            cval = root*th
            s = s + cval*cval
            ab(i) = 2.0_dp*cval*th*a(i)/root
            bb(i) = 2.0_dp*cval*root*(1.0_dp - th*th)
        end do
    end subroutine analytical

    subroutine check(engine, ra, rb, ga, gb)
        !! No timing is reported for a wrong gradient.
        character(len=*), intent(in) :: engine
        real(dp), intent(in) :: ra(:), rb(:), ga(:), gb(:)
        real(dp) :: err

        err = max(maxval(abs(ga - ra)), maxval(abs(gb - rb)))
        if (err > 1.0e-11_dp) then
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

end program bench_stencil
