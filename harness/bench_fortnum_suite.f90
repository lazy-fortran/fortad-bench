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
    use fortnum_fortsym_det2, only: det2_jvp_fortsym, det2_vjp_fortsym
    use fortnum_fortsym_det3, only: det3_jvp_fortsym, det3_vjp_fortsym
    use fortnum_fortsym_lagrange4, only: lagrange4_jvp_fortsym, lagrange4_vjp_fortsym
    use fortnum_fortsym_multi_input_p2, only: multi_input_p2_jvp_fortsym, multi_input_p2_vjp_fortsym
    use fortnum_fortsym_multi_input_p4, only: multi_input_p4_jvp_fortsym, multi_input_p4_vjp_fortsym
    use fortnum_fortsym_multi_input_p8, only: multi_input_p8_jvp_fortsym, multi_input_p8_vjp_fortsym
    use fortnum_fortsym_multi_input_p16, only: multi_input_p16_jvp_fortsym, multi_input_p16_vjp_fortsym
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
        subroutine smoke_square_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="smoke_square_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine smoke_square_vjp_enzyme
        subroutine smoke_square_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="smoke_square_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine smoke_square_jvp_enzyme
        subroutine scalar_root_residual_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="scalar_root_residual_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine scalar_root_residual_vjp_enzyme
        subroutine scalar_root_residual_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="scalar_root_residual_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine scalar_root_residual_jvp_enzyme
        subroutine ode_scalar_rhs_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="ode_scalar_rhs_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine ode_scalar_rhs_vjp_enzyme
        subroutine ode_scalar_rhs_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="ode_scalar_rhs_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine ode_scalar_rhs_jvp_enzyme
        subroutine fixed_quadrature_integrand_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fixed_quadrature_integrand_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fixed_quadrature_integrand_vjp_enzyme
        subroutine fixed_quadrature_integrand_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fixed_quadrature_integrand_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fixed_quadrature_integrand_jvp_enzyme
        subroutine vector_root_residual_one_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="vector_root_residual_one_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine vector_root_residual_one_vjp_enzyme
        subroutine vector_root_residual_one_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="vector_root_residual_one_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine vector_root_residual_one_jvp_enzyme
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

        subroutine det2_jvp_enzyme(n, z, dz, y, dy) bind(C, name="det2_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine det2_jvp_enzyme
        pure subroutine det2_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(4*n), z_d(4*n)
            real(dp), intent(out) :: y, y_d
        end subroutine det2_jvp
        subroutine det3_jvp_enzyme(n, z, dz, y, dy) bind(C, name="det3_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine det3_jvp_enzyme
        pure subroutine det3_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(9*n), z_d(9*n)
            real(dp), intent(out) :: y, y_d
        end subroutine det3_jvp
        subroutine lagrange4_jvp_enzyme(n, z, dz, y, dy) bind(C, name="lagrange4_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine lagrange4_jvp_enzyme
        pure subroutine lagrange4_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(5*n), z_d(5*n)
            real(dp), intent(out) :: y, y_d
        end subroutine lagrange4_jvp
        subroutine erfsum_jvp_enzyme(n, z, dz, y, dy) bind(C, name="erfsum_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine erfsum_jvp_enzyme
        pure subroutine erfsum_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(1*n), z_d(1*n)
            real(dp), intent(out) :: y, y_d
        end subroutine erfsum_jvp
        subroutine multi_input_p2_jvp_enzyme(n, z, dz, y, dy) bind(C, name="multi_input_p2_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine multi_input_p2_jvp_enzyme
        pure subroutine multi_input_p2_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(2*n), z_d(2*n)
            real(dp), intent(out) :: y, y_d
        end subroutine multi_input_p2_jvp
        subroutine multi_input_p4_jvp_enzyme(n, z, dz, y, dy) bind(C, name="multi_input_p4_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine multi_input_p4_jvp_enzyme
        pure subroutine multi_input_p4_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(4*n), z_d(4*n)
            real(dp), intent(out) :: y, y_d
        end subroutine multi_input_p4_jvp
        subroutine multi_input_p8_jvp_enzyme(n, z, dz, y, dy) bind(C, name="multi_input_p8_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine multi_input_p8_jvp_enzyme
        pure subroutine multi_input_p8_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(8*n), z_d(8*n)
            real(dp), intent(out) :: y, y_d
        end subroutine multi_input_p8_jvp
        subroutine multi_input_p16_jvp_enzyme(n, z, dz, y, dy) bind(C, name="multi_input_p16_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine multi_input_p16_jvp_enzyme
        pure subroutine multi_input_p16_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(16*n), z_d(16*n)
            real(dp), intent(out) :: y, y_d
        end subroutine multi_input_p16_jvp
    end interface

    integer, parameter :: NW = 13
    character(len=28), parameter :: NAMES(NW) = &
        [character(len=28) :: "det2", "det3", "lagrange4", "erfsum", &
         "multi_input_p2", "multi_input_p4", "multi_input_p8", &
         "multi_input_p16", "smoke_square", "scalar_root_residual", &
         "ode_scalar_rhs", "fixed_quadrature_integrand", &
         "vector_root_residual_one"]
    integer, parameter :: ARITY(NW) = [4, 9, 5, 1, 2, 4, 8, 16, 1, 3, 3, 5, 4]
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
        real(dp), allocatable :: z(:), zb(:), zb2(:), zb3(:), zb4(:), dz(:)
        real(dp) :: y, yb, t0, t1, best_f, best_e, best_g, best_p
        real(dp) :: best_fj, best_ej, dy, dy2, dy3
        real(dp) :: best_s, best_sj
        logical :: has_fortsym

        n_in = arity*N_BATCH
        allocate (z(n_in), zb(n_in), zb2(n_in), zb3(n_in), zb4(n_in), dz(n_in))
        do i = 1, n_in
            z(i) = 0.4_dp + 0.3_dp*sin(0.31_dp*i)
            dz(i) = cos(0.77_dp*i)
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

        ! fortsym generates these kernels symbolically from the same operator,
        ! so its gradient is a third independent answer rather than a variant.
        zb4 = 0.0_dp
        call call_fortsym(name, N_BATCH, z, 1.0_dp, zb4, has_fortsym)
        if (has_fortsym) call cross_check(name, "fortsym", zb, zb4)

        ! Forward mode, both engines, against each other and against the
        ! gradient: the directional derivative is the gradient contracted with
        ! the direction, which ties the two modes together without a third
        ! reference.
        call call_fortad_jvp(name, N_BATCH, z, dz, y, dy)
        call call_enzyme_jvp(name, N_BATCH, z, dz, y, dy2)
        if (abs(dy - dy2) > 1.0e-12_dp*max(1.0_dp, abs(dy))) then
            print *, "MISMATCH ", name, " jvp fortad vs enzyme: ", dy, dy2
            error stop 1
        end if
        if (abs(dy - dot_product(zb, dz)) > 1.0e-10_dp*max(1.0_dp, abs(dy))) then
            print *, "MISMATCH ", name, " jvp vs gradient: ", dy, &
                dot_product(zb, dz)
            error stop 1
        end if

        best_f = huge(1.0_dp)
        best_e = huge(1.0_dp)
        best_g = huge(1.0_dp)
        best_p = huge(1.0_dp)
        best_fj = huge(1.0_dp)
        best_ej = huge(1.0_dp)
        best_s = huge(1.0_dp)
        best_sj = huge(1.0_dp)
        do trial = 1, N_TRIALS
            if (has_fortsym) then
                call cpu_time(t0)
                do r = 1, reps
                    call call_fortsym(name, N_BATCH, z, 1.0_dp, zb4, has_fortsym)
                end do
                call cpu_time(t1)
                best_s = min(best_s, t1 - t0)

                call cpu_time(t0)
                do r = 1, reps
                    call call_fortsym_jvp(name, N_BATCH, z, dz, y, dy3, &
                                          has_fortsym)
                end do
                call cpu_time(t1)
                best_sj = min(best_sj, t1 - t0)
            end if

            call cpu_time(t0)
            do r = 1, reps
                call call_fortad_jvp(name, N_BATCH, z, dz, y, dy)
            end do
            call cpu_time(t1)
            best_fj = min(best_fj, t1 - t0)

            call cpu_time(t0)
            do r = 1, reps
                call call_enzyme_jvp(name, N_BATCH, z, dz, y, dy2)
            end do
            call cpu_time(t1)
            best_ej = min(best_ej, t1 - t0)

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
        call row(unit, name, "fortad-jvp", n_in, best_fj, reps)
        call row(unit, name, "enzyme-jvp", n_in, best_ej, reps)
        if (has_fortsym) then
            call row(unit, name, "fortsym", n_in, best_s, reps)
            call row(unit, name, "fortsym-jvp", n_in, best_sj, reps)
        end if

        deallocate (z, zb, zb2, zb3, zb4, dz)
    end subroutine run_operator

    subroutine call_primal(name, n, z, y)
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:)
        real(dp), intent(out) :: y

        select case (name)
        case ("det2")
            call det2(n, z, y)
        case ("smoke_square")
            call smoke_square(n, z, y)
        case ("scalar_root_residual")
            call scalar_root_residual(n, z, y)
        case ("ode_scalar_rhs")
            call ode_scalar_rhs(n, z, y)
        case ("fixed_quadrature_integrand")
            call fixed_quadrature_integrand(n, z, y)
        case ("vector_root_residual_one")
            call vector_root_residual_one(n, z, y)
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
        case ("smoke_square")
            call smoke_square_vjp(n, z, y, yb, zb)
        case ("scalar_root_residual")
            call scalar_root_residual_vjp(n, z, y, yb, zb)
        case ("ode_scalar_rhs")
            call ode_scalar_rhs_vjp(n, z, y, yb, zb)
        case ("fixed_quadrature_integrand")
            call fixed_quadrature_integrand_vjp(n, z, y, yb, zb)
        case ("vector_root_residual_one")
            call vector_root_residual_one_vjp(n, z, y, yb, zb)
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
        case ("smoke_square")
            call smoke_square_grad(n, z, yb, zb)
        case ("scalar_root_residual")
            call scalar_root_residual_grad(n, z, yb, zb)
        case ("ode_scalar_rhs")
            call ode_scalar_rhs_grad(n, z, yb, zb)
        case ("fixed_quadrature_integrand")
            call fixed_quadrature_integrand_grad(n, z, yb, zb)
        case ("vector_root_residual_one")
            call vector_root_residual_one_grad(n, z, yb, zb)
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

    subroutine call_fortad_jvp(name, n, z, dz, y, dy)
        !! Dispatch to the fortad-generated tangent.
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:), dz(:)
        real(dp), intent(out) :: y, dy

        select case (name)
        case ("det2")
            call det2_jvp(n, z, dz, y, dy)
        case ("smoke_square")
            call smoke_square_jvp(n, z, dz, y, dy)
        case ("scalar_root_residual")
            call scalar_root_residual_jvp(n, z, dz, y, dy)
        case ("ode_scalar_rhs")
            call ode_scalar_rhs_jvp(n, z, dz, y, dy)
        case ("fixed_quadrature_integrand")
            call fixed_quadrature_integrand_jvp(n, z, dz, y, dy)
        case ("vector_root_residual_one")
            call vector_root_residual_one_jvp(n, z, dz, y, dy)
        case ("det3")
            call det3_jvp(n, z, dz, y, dy)
        case ("lagrange4")
            call lagrange4_jvp(n, z, dz, y, dy)
        case ("erfsum")
            call erfsum_jvp(n, z, dz, y, dy)
        case ("multi_input_p2")
            call multi_input_p2_jvp(n, z, dz, y, dy)
        case ("multi_input_p4")
            call multi_input_p4_jvp(n, z, dz, y, dy)
        case ("multi_input_p8")
            call multi_input_p8_jvp(n, z, dz, y, dy)
        case ("multi_input_p16")
            call multi_input_p16_jvp(n, z, dz, y, dy)
        end select
    end subroutine call_fortad_jvp

    subroutine call_enzyme_jvp(name, n, z, dz, y, dy)
        !! Dispatch to the Enzyme-generated tangent.
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(inout) :: z(:), dz(:)
        real(dp), intent(out) :: y, dy

        select case (name)
        case ("det2")
            call det2_jvp_enzyme(n, z, dz, y, dy)
        case ("smoke_square")
            call smoke_square_jvp_enzyme(n, z, dz, y, dy)
        case ("scalar_root_residual")
            call scalar_root_residual_jvp_enzyme(n, z, dz, y, dy)
        case ("ode_scalar_rhs")
            call ode_scalar_rhs_jvp_enzyme(n, z, dz, y, dy)
        case ("fixed_quadrature_integrand")
            call fixed_quadrature_integrand_jvp_enzyme(n, z, dz, y, dy)
        case ("vector_root_residual_one")
            call vector_root_residual_one_jvp_enzyme(n, z, dz, y, dy)
        case ("det3")
            call det3_jvp_enzyme(n, z, dz, y, dy)
        case ("lagrange4")
            call lagrange4_jvp_enzyme(n, z, dz, y, dy)
        case ("erfsum")
            call erfsum_jvp_enzyme(n, z, dz, y, dy)
        case ("multi_input_p2")
            call multi_input_p2_jvp_enzyme(n, z, dz, y, dy)
        case ("multi_input_p4")
            call multi_input_p4_jvp_enzyme(n, z, dz, y, dy)
        case ("multi_input_p8")
            call multi_input_p8_jvp_enzyme(n, z, dz, y, dy)
        case ("multi_input_p16")
            call multi_input_p16_jvp_enzyme(n, z, dz, y, dy)
        end select
    end subroutine call_enzyme_jvp

    subroutine call_fortsym(name, n, z, yb, zb, ok)
        !! Dispatch to fortsym's kernel, wrapped in the same batch loop.
        !!
        !! Not every operator has one: erf and erfc are scalar kernels behind
        !! array-shaped signatures, so a batch of them would measure one point.
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:)
        real(dp), intent(in) :: yb
        real(dp), intent(out) :: zb(:)
        logical, intent(out) :: ok

        ok = .true.
        select case (name)
        case ("det2")
            call det2_vjp_fortsym(n, z, yb, zb)
        case ("__none_smoke_square")
            call det2_vjp_fortsym(n, z, yb, zb)
        case ("__none_scalar_root_residual")
            call det2_vjp_fortsym(n, z, yb, zb)
        case ("__none_ode_scalar_rhs")
            call det2_vjp_fortsym(n, z, yb, zb)
        case ("__none_fixed_quadrature_integrand")
            call det2_vjp_fortsym(n, z, yb, zb)
        case ("__none_vector_root_residual_one")
            call det2_vjp_fortsym(n, z, yb, zb)
        case ("det3")
            call det3_vjp_fortsym(n, z, yb, zb)
        case ("lagrange4")
            call lagrange4_vjp_fortsym(n, z, yb, zb)
        case ("multi_input_p2")
            call multi_input_p2_vjp_fortsym(n, z, yb, zb)
        case ("multi_input_p4")
            call multi_input_p4_vjp_fortsym(n, z, yb, zb)
        case ("multi_input_p8")
            call multi_input_p8_vjp_fortsym(n, z, yb, zb)
        case ("multi_input_p16")
            call multi_input_p16_vjp_fortsym(n, z, yb, zb)
        case default
            ok = .false.
        end select
    end subroutine call_fortsym

    subroutine call_fortsym_jvp(name, n, z, dz, y, dy, ok)
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:), dz(:)
        real(dp), intent(out) :: y, dy
        logical, intent(out) :: ok

        ok = .true.
        select case (name)
        case ("det2")
            call det2_jvp_fortsym(n, z, dz, y, dy)
        case ("__none_smoke_square")
            call det2_jvp_fortsym(n, z, dz, y, dy)
        case ("__none_scalar_root_residual")
            call det2_jvp_fortsym(n, z, dz, y, dy)
        case ("__none_ode_scalar_rhs")
            call det2_jvp_fortsym(n, z, dz, y, dy)
        case ("__none_fixed_quadrature_integrand")
            call det2_jvp_fortsym(n, z, dz, y, dy)
        case ("__none_vector_root_residual_one")
            call det2_jvp_fortsym(n, z, dz, y, dy)
        case ("det3")
            call det3_jvp_fortsym(n, z, dz, y, dy)
        case ("lagrange4")
            call lagrange4_jvp_fortsym(n, z, dz, y, dy)
        case ("multi_input_p2")
            call multi_input_p2_jvp_fortsym(n, z, dz, y, dy)
        case ("multi_input_p4")
            call multi_input_p4_jvp_fortsym(n, z, dz, y, dy)
        case ("multi_input_p8")
            call multi_input_p8_jvp_fortsym(n, z, dz, y, dy)
        case ("multi_input_p16")
            call multi_input_p16_jvp_fortsym(n, z, dz, y, dy)
        case default
            ok = .false.
        end select
    end subroutine call_fortsym_jvp

    subroutine call_enzyme(name, n, z, zb, y, yb)
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(inout) :: z(:), zb(:)
        real(dp), intent(out) :: y
        real(dp), intent(inout) :: yb

        select case (name)
        case ("det2")
            call det2_vjp_enzyme(n, z, zb, y, yb)
        case ("smoke_square")
            call smoke_square_vjp_enzyme(n, z, zb, y, yb)
        case ("scalar_root_residual")
            call scalar_root_residual_vjp_enzyme(n, z, zb, y, yb)
        case ("ode_scalar_rhs")
            call ode_scalar_rhs_vjp_enzyme(n, z, zb, y, yb)
        case ("fixed_quadrature_integrand")
            call fixed_quadrature_integrand_vjp_enzyme(n, z, zb, y, yb)
        case ("vector_root_residual_one")
            call vector_root_residual_one_vjp_enzyme(n, z, zb, y, yb)
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
