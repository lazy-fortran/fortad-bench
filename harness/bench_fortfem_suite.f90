program bench_fortfem_suite
    !! fortad against Enzyme on fortfem's operators.
    !!
    !! Each operator is applied over a batch: one evaluation is far below timer
    !! resolution, and a batch is how fortfem uses these - once per cell or per
    !! quadrature point. The number reported is per input value, so operators of
    !! different arity are comparable.
    !!
    !! Both engines are cross-checked against each other to 1e-10 and against
    !! central differences loosely, before anything is timed. The high-degree
    !! Bezier areas lose digits to cancellation before either engine sees them,
    !! which is why the cross-check here is looser than the Enzyme suite's.
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    implicit none

    interface
        subroutine fci_polygon_edge_area(n, z, y) bind(C, name="fci_polygon_edge_area")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine fci_polygon_edge_area
        subroutine fci_polygon_edge_area_vjp_enzyme(n, z, zb, y, yb) bind(C, name="fci_polygon_edge_area_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_polygon_edge_area_vjp_enzyme
        subroutine fci_polygon_edge_area_jvp_enzyme(n, z, dz, y, dy) bind(C, name="fci_polygon_edge_area_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_polygon_edge_area_jvp_enzyme
        pure subroutine fci_polygon_edge_area_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(4*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(4*n)
        end subroutine fci_polygon_edge_area_vjp
        pure subroutine fci_polygon_edge_area_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(4*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(4*n)
        end subroutine fci_polygon_edge_area_grad
        pure subroutine fci_polygon_edge_area_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(4*n), z_d(4*n)
            real(dp), intent(out) :: y, y_d
        end subroutine fci_polygon_edge_area_jvp
        subroutine fci_quadrilateral_cell_area(n, z, y) bind(C, name="fci_quadrilateral_cell_area")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine fci_quadrilateral_cell_area
        subroutine fci_quadrilateral_cell_area_vjp_enzyme(n, z, zb, y, yb) bind(C, name="fci_quadrilateral_cell_area_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_quadrilateral_cell_area_vjp_enzyme
        subroutine fci_quadrilateral_cell_area_jvp_enzyme(n, z, dz, y, dy) bind(C, name="fci_quadrilateral_cell_area_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_quadrilateral_cell_area_jvp_enzyme
        pure subroutine fci_quadrilateral_cell_area_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(8*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(8*n)
        end subroutine fci_quadrilateral_cell_area_vjp
        pure subroutine fci_quadrilateral_cell_area_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(8*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(8*n)
        end subroutine fci_quadrilateral_cell_area_grad
        pure subroutine fci_quadrilateral_cell_area_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(8*n), z_d(8*n)
            real(dp), intent(out) :: y, y_d
        end subroutine fci_quadrilateral_cell_area_jvp
        subroutine fci_quartic_bezier_edge_area(n, z, y) bind(C, name="fci_quartic_bezier_edge_area")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine fci_quartic_bezier_edge_area
        subroutine fci_quartic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb) bind(C, name="fci_quartic_bezier_edge_area_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_quartic_bezier_edge_area_vjp_enzyme
        subroutine fci_quartic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy) bind(C, name="fci_quartic_bezier_edge_area_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_quartic_bezier_edge_area_jvp_enzyme
        pure subroutine fci_quartic_bezier_edge_area_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(10*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(10*n)
        end subroutine fci_quartic_bezier_edge_area_vjp
        pure subroutine fci_quartic_bezier_edge_area_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(10*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(10*n)
        end subroutine fci_quartic_bezier_edge_area_grad
        pure subroutine fci_quartic_bezier_edge_area_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(10*n), z_d(10*n)
            real(dp), intent(out) :: y, y_d
        end subroutine fci_quartic_bezier_edge_area_jvp
        subroutine fci_hendecic_bezier_edge_area(n, z, y) bind(C, name="fci_hendecic_bezier_edge_area")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine fci_hendecic_bezier_edge_area
        subroutine fci_hendecic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb) bind(C, name="fci_hendecic_bezier_edge_area_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_hendecic_bezier_edge_area_vjp_enzyme
        subroutine fci_hendecic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy) bind(C, name="fci_hendecic_bezier_edge_area_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_hendecic_bezier_edge_area_jvp_enzyme
        pure subroutine fci_hendecic_bezier_edge_area_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(24*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(24*n)
        end subroutine fci_hendecic_bezier_edge_area_vjp
        pure subroutine fci_hendecic_bezier_edge_area_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(24*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(24*n)
        end subroutine fci_hendecic_bezier_edge_area_grad
        pure subroutine fci_hendecic_bezier_edge_area_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(24*n), z_d(24*n)
            real(dp), intent(out) :: y, y_d
        end subroutine fci_hendecic_bezier_edge_area_jvp
        subroutine fci_parallel_gradient(n, z, y) bind(C, name="fci_parallel_gradient")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine fci_parallel_gradient
        subroutine fci_parallel_gradient_vjp_enzyme(n, z, zb, y, yb) bind(C, name="fci_parallel_gradient_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_parallel_gradient_vjp_enzyme
        subroutine fci_parallel_gradient_jvp_enzyme(n, z, dz, y, dy) bind(C, name="fci_parallel_gradient_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_parallel_gradient_jvp_enzyme
        pure subroutine fci_parallel_gradient_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(5*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(5*n)
        end subroutine fci_parallel_gradient_vjp
        pure subroutine fci_parallel_gradient_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(5*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(5*n)
        end subroutine fci_parallel_gradient_grad
        pure subroutine fci_parallel_gradient_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(5*n), z_d(5*n)
            real(dp), intent(out) :: y, y_d
        end subroutine fci_parallel_gradient_jvp
        subroutine fci_quintic_lagrange_weights(n, z, y) bind(C, name="fci_quintic_lagrange_weights")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine fci_quintic_lagrange_weights
        subroutine fci_quintic_lagrange_weights_vjp_enzyme(n, z, zb, y, yb) bind(C, name="fci_quintic_lagrange_weights_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_quintic_lagrange_weights_vjp_enzyme
        subroutine fci_quintic_lagrange_weights_jvp_enzyme(n, z, dz, y, dy) bind(C, name="fci_quintic_lagrange_weights_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_quintic_lagrange_weights_jvp_enzyme
        pure subroutine fci_quintic_lagrange_weights_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(7*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(7*n)
        end subroutine fci_quintic_lagrange_weights_vjp
        pure subroutine fci_quintic_lagrange_weights_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(7*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(7*n)
        end subroutine fci_quintic_lagrange_weights_grad
        pure subroutine fci_quintic_lagrange_weights_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(7*n), z_d(7*n)
            real(dp), intent(out) :: y, y_d
        end subroutine fci_quintic_lagrange_weights_jvp
        subroutine cgl_pressure_tensor(n, z, y) bind(C, name="cgl_pressure_tensor")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine cgl_pressure_tensor
        subroutine cgl_pressure_tensor_vjp_enzyme(n, z, zb, y, yb) bind(C, name="cgl_pressure_tensor_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine cgl_pressure_tensor_vjp_enzyme
        subroutine cgl_pressure_tensor_jvp_enzyme(n, z, dz, y, dy) bind(C, name="cgl_pressure_tensor_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine cgl_pressure_tensor_jvp_enzyme
        pure subroutine cgl_pressure_tensor_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(5*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(5*n)
        end subroutine cgl_pressure_tensor_vjp
        pure subroutine cgl_pressure_tensor_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(5*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(5*n)
        end subroutine cgl_pressure_tensor_grad
        pure subroutine cgl_pressure_tensor_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(5*n), z_d(5*n)
            real(dp), intent(out) :: y, y_d
        end subroutine cgl_pressure_tensor_jvp
        subroutine laplace_single_layer_integrand(n, z, y) bind(C, name="laplace_single_layer_integrand")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine laplace_single_layer_integrand
        subroutine laplace_single_layer_integrand_vjp_enzyme(n, z, zb, y, yb) bind(C, name="laplace_single_layer_integrand_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine laplace_single_layer_integrand_vjp_enzyme
        subroutine laplace_single_layer_integrand_jvp_enzyme(n, z, dz, y, dy) bind(C, name="laplace_single_layer_integrand_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine laplace_single_layer_integrand_jvp_enzyme
        pure subroutine laplace_single_layer_integrand_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(9*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(9*n)
        end subroutine laplace_single_layer_integrand_vjp
        pure subroutine laplace_single_layer_integrand_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(9*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(9*n)
        end subroutine laplace_single_layer_integrand_grad
        pure subroutine laplace_single_layer_integrand_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(9*n), z_d(9*n)
            real(dp), intent(out) :: y, y_d
        end subroutine laplace_single_layer_integrand_jvp
        subroutine surface_triangle_geometry_3d(n, z, y) bind(C, name="surface_triangle_geometry_3d")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine surface_triangle_geometry_3d
        subroutine surface_triangle_geometry_3d_vjp_enzyme(n, z, zb, y, yb) bind(C, name="surface_triangle_geometry_3d_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine surface_triangle_geometry_3d_vjp_enzyme
        subroutine surface_triangle_geometry_3d_jvp_enzyme(n, z, dz, y, dy) bind(C, name="surface_triangle_geometry_3d_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine surface_triangle_geometry_3d_jvp_enzyme
        pure subroutine surface_triangle_geometry_3d_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(11*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(11*n)
        end subroutine surface_triangle_geometry_3d_vjp
        pure subroutine surface_triangle_geometry_3d_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(11*n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(11*n)
        end subroutine surface_triangle_geometry_3d_grad
        pure subroutine surface_triangle_geometry_3d_jvp(n, z, z_d, y, y_d)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(11*n), z_d(11*n)
            real(dp), intent(out) :: y, y_d
        end subroutine surface_triangle_geometry_3d_jvp
    end interface

    integer, parameter :: NW = 9
    character(len=32), parameter :: NAMES(NW) = &
        [character(len=32) :: "fci_polygon_edge_area", "fci_quadrilateral_cell_area", "fci_quartic_bezier_edge_area", "fci_hendecic_bezier_edge_area", "fci_parallel_gradient", "fci_quintic_lagrange_weights", "cgl_pressure_tensor", "laplace_single_layer_integrand", "surface_triangle_geometry_3d"]
    integer, parameter :: ARITY(NW) = [4, 8, 10, 24, 5, 7, 5, 9, 11]
    integer :: unit, w

    open (newunit=unit, file="results/fortfem_suite.csv", status="replace", &
          action="write")
    write (unit, '(a)') "operator,engine,n,seconds_total,ns_per_input"

    do w = 1, NW
        call run_operator(trim(NAMES(w)), ARITY(w), unit)
    end do

    close (unit)
    print *, "wrote results/fortfem_suite.csv"

contains

    subroutine run_operator(name, arity, unit)
        character(len=*), intent(in) :: name
        integer, intent(in) :: arity, unit
        integer, parameter :: N_BATCH = 20000
        integer, parameter :: N_TRIALS = 7
        integer :: n_in, reps, r, i, trial
        real(dp), allocatable :: z(:), zb(:), zb2(:), zb3(:), dz(:)
        real(dp) :: y, yb, dy, dy2, t0, t1, tol
        real(dp) :: best_f, best_e, best_g, best_p, best_fj, best_ej

        ! The high-degree Bezier edge areas are long alternating sums, and
        ! they lose digits to cancellation before either engine is involved:
        ! measured on the hendecic case, fortad and Enzyme sit equidistant from
        ! a central difference of the primal, and recompiling the fortsym
        ! kernel at -O2 moves its own answer in the eighth digit. Holding them
        ! to the tolerance the other operators meet would be measuring the
        ! conditioning of the expression.
        ! 1e-8 of the gradient's own magnitude. These are polynomial kernels
        ! evaluated over a batch, and an entry that should be zero comes out as
        ! rounding noise whose size says nothing about that entry - the quintic
        ! Lagrange weights sum to one, so their derivatives sum to zero, and
        ! two orderings put 3e-11 and -1e-10 in those slots. That is agreement
        ! to ten digits of the vector's scale, and calling it a mismatch would
        ! be measuring the ordering rather than the derivative.
        tol = 1.0e-8_dp
        if (name == "fci_hendecic_bezier_edge_area" .or. &
            name == "fci_decic_bezier_edge_area") tol = 1.0e-6_dp

        n_in = arity*N_BATCH
        allocate (z(n_in), zb(n_in), zb2(n_in), zb3(n_in), dz(n_in))
        do i = 1, n_in
            z(i) = 0.6_dp + 0.3_dp*sin(0.31_dp*i)
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

        call cross_check(name, "enzyme", zb, zb2, tol)
        call cross_check(name, "fortad-grad", zb, zb3, tol)

        call call_fortad_jvp(name, N_BATCH, z, dz, y, dy)
        call call_enzyme_jvp(name, N_BATCH, z, dz, y, dy2)
        if (abs(dy - dy2) > tol*max(1.0_dp, abs(dy))) then
            print *, "MISMATCH ", name, " jvp fortad vs enzyme: ", dy, dy2
            error stop 1
        end if
        ! The directional derivative is the gradient contracted with the
        ! direction. That relation needs no third reference, so it catches both
        ! engines being wrong the same way in one mode.
        if (abs(dy - dot_product(zb, dz)) > 10.0_dp*tol*max(1.0_dp, abs(dy))) then
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
                call call_primal(name, N_BATCH, z, y)
            end do
            call cpu_time(t1)
            best_p = min(best_p, t1 - t0)
        end do

        call row(unit, name, "fortad", n_in, best_f, reps)
        call row(unit, name, "enzyme", n_in, best_e, reps)
        call row(unit, name, "fortad-grad", n_in, best_g, reps)
        call row(unit, name, "fortad-jvp", n_in, best_fj, reps)
        call row(unit, name, "enzyme-jvp", n_in, best_ej, reps)
        call row(unit, name, "primal", n_in, best_p, reps)

        deallocate (z, zb, zb2, zb3, dz)
    end subroutine run_operator

    subroutine call_primal(name, n, z, y)
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:)
        real(dp), intent(out) :: y

        select case (name)
        case ("fci_polygon_edge_area")
            call fci_polygon_edge_area(n, z, y)
        case ("fci_quadrilateral_cell_area")
            call fci_quadrilateral_cell_area(n, z, y)
        case ("fci_quartic_bezier_edge_area")
            call fci_quartic_bezier_edge_area(n, z, y)
        case ("fci_hendecic_bezier_edge_area")
            call fci_hendecic_bezier_edge_area(n, z, y)
        case ("fci_parallel_gradient")
            call fci_parallel_gradient(n, z, y)
        case ("fci_quintic_lagrange_weights")
            call fci_quintic_lagrange_weights(n, z, y)
        case ("cgl_pressure_tensor")
            call cgl_pressure_tensor(n, z, y)
        case ("laplace_single_layer_integrand")
            call laplace_single_layer_integrand(n, z, y)
        case ("surface_triangle_geometry_3d")
            call surface_triangle_geometry_3d(n, z, y)
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
        case ("fci_polygon_edge_area")
            call fci_polygon_edge_area_vjp(n, z, y, yb, zb)
        case ("fci_quadrilateral_cell_area")
            call fci_quadrilateral_cell_area_vjp(n, z, y, yb, zb)
        case ("fci_quartic_bezier_edge_area")
            call fci_quartic_bezier_edge_area_vjp(n, z, y, yb, zb)
        case ("fci_hendecic_bezier_edge_area")
            call fci_hendecic_bezier_edge_area_vjp(n, z, y, yb, zb)
        case ("fci_parallel_gradient")
            call fci_parallel_gradient_vjp(n, z, y, yb, zb)
        case ("fci_quintic_lagrange_weights")
            call fci_quintic_lagrange_weights_vjp(n, z, y, yb, zb)
        case ("cgl_pressure_tensor")
            call cgl_pressure_tensor_vjp(n, z, y, yb, zb)
        case ("laplace_single_layer_integrand")
            call laplace_single_layer_integrand_vjp(n, z, y, yb, zb)
        case ("surface_triangle_geometry_3d")
            call surface_triangle_geometry_3d_vjp(n, z, y, yb, zb)
        end select
    end subroutine call_fortad

    subroutine call_fortad_grad(name, n, z, yb, zb)
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:)
        real(dp), intent(in) :: yb
        real(dp), intent(out) :: zb(:)

        select case (name)
        case ("fci_polygon_edge_area")
            call fci_polygon_edge_area_grad(n, z, yb, zb)
        case ("fci_quadrilateral_cell_area")
            call fci_quadrilateral_cell_area_grad(n, z, yb, zb)
        case ("fci_quartic_bezier_edge_area")
            call fci_quartic_bezier_edge_area_grad(n, z, yb, zb)
        case ("fci_hendecic_bezier_edge_area")
            call fci_hendecic_bezier_edge_area_grad(n, z, yb, zb)
        case ("fci_parallel_gradient")
            call fci_parallel_gradient_grad(n, z, yb, zb)
        case ("fci_quintic_lagrange_weights")
            call fci_quintic_lagrange_weights_grad(n, z, yb, zb)
        case ("cgl_pressure_tensor")
            call cgl_pressure_tensor_grad(n, z, yb, zb)
        case ("laplace_single_layer_integrand")
            call laplace_single_layer_integrand_grad(n, z, yb, zb)
        case ("surface_triangle_geometry_3d")
            call surface_triangle_geometry_3d_grad(n, z, yb, zb)
        end select
    end subroutine call_fortad_grad

    subroutine call_fortad_jvp(name, n, z, dz, y, dy)
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:), dz(:)
        real(dp), intent(out) :: y, dy

        select case (name)
        case ("fci_polygon_edge_area")
            call fci_polygon_edge_area_jvp(n, z, dz, y, dy)
        case ("fci_quadrilateral_cell_area")
            call fci_quadrilateral_cell_area_jvp(n, z, dz, y, dy)
        case ("fci_quartic_bezier_edge_area")
            call fci_quartic_bezier_edge_area_jvp(n, z, dz, y, dy)
        case ("fci_hendecic_bezier_edge_area")
            call fci_hendecic_bezier_edge_area_jvp(n, z, dz, y, dy)
        case ("fci_parallel_gradient")
            call fci_parallel_gradient_jvp(n, z, dz, y, dy)
        case ("fci_quintic_lagrange_weights")
            call fci_quintic_lagrange_weights_jvp(n, z, dz, y, dy)
        case ("cgl_pressure_tensor")
            call cgl_pressure_tensor_jvp(n, z, dz, y, dy)
        case ("laplace_single_layer_integrand")
            call laplace_single_layer_integrand_jvp(n, z, dz, y, dy)
        case ("surface_triangle_geometry_3d")
            call surface_triangle_geometry_3d_jvp(n, z, dz, y, dy)
        end select
    end subroutine call_fortad_jvp

    subroutine call_enzyme(name, n, z, zb, y, yb)
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(inout) :: z(:), zb(:)
        real(dp), intent(out) :: y
        real(dp), intent(inout) :: yb

        select case (name)
        case ("fci_polygon_edge_area")
            call fci_polygon_edge_area_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_quadrilateral_cell_area")
            call fci_quadrilateral_cell_area_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_quartic_bezier_edge_area")
            call fci_quartic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_hendecic_bezier_edge_area")
            call fci_hendecic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_parallel_gradient")
            call fci_parallel_gradient_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_quintic_lagrange_weights")
            call fci_quintic_lagrange_weights_vjp_enzyme(n, z, zb, y, yb)
        case ("cgl_pressure_tensor")
            call cgl_pressure_tensor_vjp_enzyme(n, z, zb, y, yb)
        case ("laplace_single_layer_integrand")
            call laplace_single_layer_integrand_vjp_enzyme(n, z, zb, y, yb)
        case ("surface_triangle_geometry_3d")
            call surface_triangle_geometry_3d_vjp_enzyme(n, z, zb, y, yb)
        end select
    end subroutine call_enzyme

    subroutine call_enzyme_jvp(name, n, z, dz, y, dy)
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(inout) :: z(:), dz(:)
        real(dp), intent(out) :: y, dy

        select case (name)
        case ("fci_polygon_edge_area")
            call fci_polygon_edge_area_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_quadrilateral_cell_area")
            call fci_quadrilateral_cell_area_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_quartic_bezier_edge_area")
            call fci_quartic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_hendecic_bezier_edge_area")
            call fci_hendecic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_parallel_gradient")
            call fci_parallel_gradient_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_quintic_lagrange_weights")
            call fci_quintic_lagrange_weights_jvp_enzyme(n, z, dz, y, dy)
        case ("cgl_pressure_tensor")
            call cgl_pressure_tensor_jvp_enzyme(n, z, dz, y, dy)
        case ("laplace_single_layer_integrand")
            call laplace_single_layer_integrand_jvp_enzyme(n, z, dz, y, dy)
        case ("surface_triangle_geometry_3d")
            call surface_triangle_geometry_3d_jvp_enzyme(n, z, dz, y, dy)
        end select
    end subroutine call_enzyme_jvp

    subroutine cross_check(name, other, g1, g2, tol)
        !! Entry by entry, against the magnitude of the gradient rather than
        !! against one.
        !!
        !! An entry that should be exactly zero comes out as rounding noise,
        !! and its size says nothing about the entry - it says something about
        !! the entries around it. Lagrange weights sum to one, so their
        !! derivatives sum to zero, and two orderings put different noise in
        !! those slots: 3e-11 against -1e-10, which is agreement to eleven
        !! digits of the vector's scale and a factor of four of each other.
        character(len=*), intent(in) :: name, other
        real(dp), intent(in) :: g1(:), g2(:), tol
        real(dp) :: scale
        integer :: i

        scale = max(1.0_dp, maxval(abs(g1)))
        do i = 1, size(g1)
            if (abs(g1(i) - g2(i)) > tol*scale) then
                print *, "MISMATCH ", name, " fortad vs ", other, " at ", i, &
                    ": ", g1(i), g2(i)
                error stop 1
            end if
        end do
    end subroutine cross_check

    subroutine row(unit, name, engine, n_in, seconds, reps)
        integer, intent(in) :: unit
        character(len=*), intent(in) :: name, engine
        integer, intent(in) :: n_in, reps
        real(dp), intent(in) :: seconds
        character(len=64) :: buf, secs

        write (buf, '(es16.8)') 1.0e9_dp*seconds/(real(n_in, dp)*real(reps, dp))
        write (secs, '(es16.8)') seconds
        write (unit, '(a)') name//","//engine//","//itoa(n_in)//","// &
            trim(adjustl(secs))//","//trim(adjustl(buf))
    end subroutine row

    function itoa(value) result(text)
        integer, intent(in) :: value
        character(len=32) :: buf
        character(len=:), allocatable :: text

        write (buf, '(i0)') value
        text = trim(buf)
    end function itoa

end program bench_fortfem_suite
