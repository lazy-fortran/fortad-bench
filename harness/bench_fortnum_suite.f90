program bench_fortnum_suite
    !! fortad against Enzyme on fortnum's operators.
    !!
    !! Each operator is applied over a batch: one scalar evaluation is far below
    !! timer resolution, and a batch is also how fortnum's callers use it. The
    !! gradient with respect to the whole batch is what is timed, so the number
    !! reported is per input value and comparable across operators of different
    !! arity.
    !!
    !! Both engines are cross-checked against each other to 1e-12 and against
    !! central differences loosely, before anything is timed. Two independent
    !! implementations agreeing tightly is a far sharper check than differences
    !! alone; the differences catch both being wrong the same way.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    implicit none

    interface
        subroutine det2(n, z, y) bind(C, name="det2")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine det2
        subroutine det3(n, z, y) bind(C, name="det3")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine det3
        subroutine lagrange4(n, z, y) bind(C, name="lagrange4")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine lagrange4
        subroutine erfsum(n, z, y) bind(C, name="erfsum")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine erfsum
        subroutine multi_input_p2(n, z, y) bind(C, name="multi_input_p2")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine multi_input_p2
        subroutine multi_input_p4(n, z, y) bind(C, name="multi_input_p4")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine multi_input_p4
        subroutine multi_input_p8(n, z, y) bind(C, name="multi_input_p8")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine multi_input_p8
        subroutine multi_input_p16(n, z, y) bind(C, name="multi_input_p16")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine multi_input_p16
        subroutine det2_vjp_enzyme(n, z, zb, y, yb) bind(C, name="det2_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine det2_vjp_enzyme
        subroutine det3_vjp_enzyme(n, z, zb, y, yb) bind(C, name="det3_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine det3_vjp_enzyme
        subroutine lagrange4_vjp_enzyme(n, z, zb, y, yb) bind(C, name="lagrange4_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine lagrange4_vjp_enzyme
        subroutine erfsum_vjp_enzyme(n, z, zb, y, yb) bind(C, name="erfsum_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine erfsum_vjp_enzyme
        subroutine multi_input_p2_vjp_enzyme(n, z, zb, y, yb) bind(C, name="multi_input_p2_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine multi_input_p2_vjp_enzyme
        subroutine multi_input_p4_vjp_enzyme(n, z, zb, y, yb) bind(C, name="multi_input_p4_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine multi_input_p4_vjp_enzyme
        subroutine multi_input_p8_vjp_enzyme(n, z, zb, y, yb) bind(C, name="multi_input_p8_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine multi_input_p8_vjp_enzyme
        subroutine multi_input_p16_vjp_enzyme(n, z, zb, y, yb) bind(C, name="multi_input_p16_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine multi_input_p16_vjp_enzyme
        pure subroutine det2_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(4*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(4*n)
        end subroutine det2_vjp
        pure subroutine det3_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(9*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(9*n)
        end subroutine det3_vjp
        pure subroutine lagrange4_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(5*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(5*n)
        end subroutine lagrange4_vjp
        pure subroutine erfsum_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(1*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(1*n)
        end subroutine erfsum_vjp
        pure subroutine multi_input_p2_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(2*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(2*n)
        end subroutine multi_input_p2_vjp
        pure subroutine multi_input_p4_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(4*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(4*n)
        end subroutine multi_input_p4_vjp
        pure subroutine multi_input_p8_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(8*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(8*n)
        end subroutine multi_input_p8_vjp
        pure subroutine multi_input_p16_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(16*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(16*n)
        end subroutine multi_input_p16_vjp
        pure subroutine det2_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(4*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(4*n)
        end subroutine det2_grad
        pure subroutine det3_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(9*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(9*n)
        end subroutine det3_grad
        pure subroutine lagrange4_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(5*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(5*n)
        end subroutine lagrange4_grad
        pure subroutine erfsum_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(1*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(1*n)
        end subroutine erfsum_grad
        pure subroutine multi_input_p2_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(2*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(2*n)
        end subroutine multi_input_p2_grad
        pure subroutine multi_input_p4_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(4*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(4*n)
        end subroutine multi_input_p4_grad
        pure subroutine multi_input_p8_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(8*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(8*n)
        end subroutine multi_input_p8_grad
        pure subroutine multi_input_p16_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(16*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(16*n)
        end subroutine multi_input_p16_grad
    end interface

    integer, parameter :: NW = 8
    character(len=16), parameter :: NAMES(NW) = &
        [character(len=16) :: "det2", "det3", "lagrange4", "erfsum", "multi_input_p2", "multi_input_p4", "multi_input_p8", "multi_input_p16"]
    integer, parameter :: ARITY(NW) = [4, 9, 5, 1, 2, 4, 8, 16]
    integer :: unit, w

    open (newunit=unit, file="results/fortnum_suite.csv", status="replace", &
          action="write")
    write (unit, '(a)') "operator,engine,n,seconds_total,ns_per_input"

    do w = 1, NW
        call run_operator(trim(NAMES(w)), ARITY(w), unit)
    end do

    close (unit)
    print *, "wrote results/fortnum_suite.csv"

contains

    subroutine run_operator(name, arity, unit)
        character(len=*), intent(in) :: name
        integer, intent(in) :: arity, unit
        integer, parameter :: N_BATCH = 20000
        integer, parameter :: N_TRIALS = 7
        integer :: n_in, reps, r, i, trial
        real(dp), allocatable :: z(:), zb(:), zb2(:), zb3(:)
        real(dp) :: y, yb, t0, t1, best_f, best_e, best_g, best_p

        n_in = arity*N_BATCH
        allocate (z(n_in), zb(n_in), zb2(n_in), zb3(n_in))
        do i = 1, n_in
            z(i) = 0.4_dp + 0.3_dp*sin(0.31_dp*i)
        end do
        reps = max(3, 2000000/n_in)

        yb = 1.0_dp
        call call_fortad(name, N_BATCH, z, y, yb, zb)
        zb2 = 0.0_dp
        yb = 1.0_dp
        call call_enzyme(name, N_BATCH, z, zb2, y, yb)
        zb3 = 0.0_dp
        yb = 1.0_dp
        call call_fortad_grad(name, N_BATCH, z, yb, zb3)

        call cross_check(name, "enzyme", zb, zb2)
        call cross_check(name, "fortad-grad", zb, zb3)
        call check_differences(name, N_BATCH, z, zb)

        best_f = huge(1.0_dp)
        best_e = huge(1.0_dp)
        best_g = huge(1.0_dp)
        best_p = huge(1.0_dp)
        do trial = 1, N_TRIALS
            call cpu_time(t0)
            do r = 1, reps
                yb = 1.0_dp
                call call_fortad(name, N_BATCH, z, y, yb, zb)
            end do
            call cpu_time(t1)
            best_f = min(best_f, t1 - t0)

            call cpu_time(t0)
            do r = 1, reps
                zb2 = 0.0_dp
                yb = 1.0_dp
                call call_enzyme(name, N_BATCH, z, zb2, y, yb)
            end do
            call cpu_time(t1)
            best_e = min(best_e, t1 - t0)

            call cpu_time(t0)
            do r = 1, reps
                yb = 1.0_dp
                call call_fortad_grad(name, N_BATCH, z, yb, zb3)
            end do
            call cpu_time(t1)
            best_g = min(best_g, t1 - t0)

            call cpu_time(t0)
            do r = 1, reps
                call call_primal(name, N_BATCH, z, y)
            end do
            call cpu_time(t1)
            best_p = min(best_p, t1 - t0)
        end do

        call row(unit, name, "fortad", n_in, best_f, reps)
        call row(unit, name, "enzyme", n_in, best_e, reps)
        call row(unit, name, "fortad-grad", n_in, best_g, reps)
        call row(unit, name, "primal", n_in, best_p, reps)

        deallocate (z, zb, zb2, zb3)
    end subroutine run_operator

    subroutine call_primal(name, n, z, y)
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:)
        real(dp), intent(out) :: y

        select case (name)
        case ("det2")
            call det2(n, z, y)
        case ("det3")
            call det3(n, z, y)
        case ("lagrange4")
            call lagrange4(n, z, y)
        case ("erfsum")
            call erfsum(n, z, y)
        case ("multi_input_p2")
            call multi_input_p2(n, z, y)
        case ("multi_input_p4")
            call multi_input_p4(n, z, y)
        case ("multi_input_p8")
            call multi_input_p8(n, z, y)
        case ("multi_input_p16")
            call multi_input_p16(n, z, y)
        end select
    end subroutine call_primal

    subroutine call_fortad(name, n, z, y, yb, zb)
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:)
        real(dp), intent(out) :: y
        real(dp), intent(in) :: yb
        real(dp), intent(out) :: zb(:)

        select case (name)
        case ("det2")
            call det2_vjp(n, z, y, yb, zb)
        case ("det3")
            call det3_vjp(n, z, y, yb, zb)
        case ("lagrange4")
            call lagrange4_vjp(n, z, y, yb, zb)
        case ("erfsum")
            call erfsum_vjp(n, z, y, yb, zb)
        case ("multi_input_p2")
            call multi_input_p2_vjp(n, z, y, yb, zb)
        case ("multi_input_p4")
            call multi_input_p4_vjp(n, z, y, yb, zb)
        case ("multi_input_p8")
            call multi_input_p8_vjp(n, z, y, yb, zb)
        case ("multi_input_p16")
            call multi_input_p16_vjp(n, z, y, yb, zb)
        end select
    end subroutine call_fortad

    subroutine call_fortad_grad(name, n, z, yb, zb)
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:)
        real(dp), intent(in) :: yb
        real(dp), intent(out) :: zb(:)

        select case (name)
        case ("det2")
            call det2_grad(n, z, yb, zb)
        case ("det3")
            call det3_grad(n, z, yb, zb)
        case ("lagrange4")
            call lagrange4_grad(n, z, yb, zb)
        case ("erfsum")
            call erfsum_grad(n, z, yb, zb)
        case ("multi_input_p2")
            call multi_input_p2_grad(n, z, yb, zb)
        case ("multi_input_p4")
            call multi_input_p4_grad(n, z, yb, zb)
        case ("multi_input_p8")
            call multi_input_p8_grad(n, z, yb, zb)
        case ("multi_input_p16")
            call multi_input_p16_grad(n, z, yb, zb)
        end select
    end subroutine call_fortad_grad

    subroutine call_enzyme(name, n, z, zb, y, yb)
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(inout) :: z(:), zb(:)
        real(dp), intent(out) :: y
        real(dp), intent(inout) :: yb

        select case (name)
        case ("det2")
            call det2_vjp_enzyme(n, z, zb, y, yb)
        case ("det3")
            call det3_vjp_enzyme(n, z, zb, y, yb)
        case ("lagrange4")
            call lagrange4_vjp_enzyme(n, z, zb, y, yb)
        case ("erfsum")
            call erfsum_vjp_enzyme(n, z, zb, y, yb)
        case ("multi_input_p2")
            call multi_input_p2_vjp_enzyme(n, z, zb, y, yb)
        case ("multi_input_p4")
            call multi_input_p4_vjp_enzyme(n, z, zb, y, yb)
        case ("multi_input_p8")
            call multi_input_p8_vjp_enzyme(n, z, zb, y, yb)
        case ("multi_input_p16")
            call multi_input_p16_vjp_enzyme(n, z, zb, y, yb)
        end select
    end subroutine call_enzyme

    subroutine cross_check(name, other, g1, g2)
        character(len=*), intent(in) :: name, other
        real(dp), intent(in) :: g1(:), g2(:)
        integer :: i

        do i = 1, size(g1)
            if (abs(g1(i) - g2(i)) > 1.0e-12_dp*max(1.0_dp, abs(g1(i)))) then
                print *, "MISMATCH ", name, " fortad vs ", other, " at ", i, &
                    ": ", g1(i), g2(i)
                error stop 1
            end if
        end do
    end subroutine cross_check

    subroutine check_differences(name, n, z, g)
        !! A loose central-difference check on a few entries.
        !!
        !! Loose on purpose: it is here to catch both engines being wrong the
        !! same way, which is the one thing cross-checking cannot see. Cancellation
        !! in the difference costs several digits, so demanding more would only
        !! measure the step size.
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:), g(:)
        real(dp), allocatable :: work(:)
        real(dp) :: h, yp, ym, fd
        integer :: i, k

        work = z
        do k = 1, min(8, size(z))
            i = 1 + (k - 1)*(size(z)/8)
            h = 1.0e-6_dp*max(1.0_dp, abs(z(i)))
            work(i) = z(i) + h
            call call_primal(name, n, work, yp)
            work(i) = z(i) - h
            call call_primal(name, n, work, ym)
            work(i) = z(i)
            fd = (yp - ym)/(2.0_dp*h)
            if (abs(g(i) - fd) > 1.0e-5_dp*max(1.0_dp, abs(fd))) then
                print *, "DIFFERENCE MISMATCH ", name, " at ", i, ": ", g(i), fd
                error stop 1
            end if
        end do
    end subroutine check_differences

    subroutine row(unit, name, engine, n_in, seconds, reps)
        integer, intent(in) :: unit
        character(len=*), intent(in) :: name, engine
        integer, intent(in) :: n_in, reps
        real(dp), intent(in) :: seconds
        character(len=64) :: buf

        write (buf, '(es16.8)') 1.0e9_dp*seconds/(real(n_in, dp)*real(reps, dp))
        write (unit, '(a)') name//","//engine//","//itoa(n_in)//","// &
            trim(adjustl(seconds_text(seconds)))//","//trim(adjustl(buf))
    end subroutine row

    function seconds_text(seconds) result(text)
        real(dp), intent(in) :: seconds
        character(len=32) :: buf
        character(len=:), allocatable :: text

        write (buf, '(es16.8)') seconds
        text = trim(adjustl(buf))
    end function seconds_text

    function itoa(value) result(text)
        integer, intent(in) :: value
        character(len=32) :: buf
        character(len=:), allocatable :: text

        write (buf, '(i0)') value
        text = trim(buf)
    end function itoa

end program bench_fortnum_suite
