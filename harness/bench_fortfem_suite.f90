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
        subroutine block_graph_product_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="block_graph_product_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine block_graph_product_vjp_enzyme
        subroutine block_graph_product_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="block_graph_product_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine block_graph_product_jvp_enzyme
        subroutine cgl_pressure_divergence_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="cgl_pressure_divergence_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine cgl_pressure_divergence_vjp_enzyme
        subroutine cgl_pressure_divergence_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="cgl_pressure_divergence_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine cgl_pressure_divergence_jvp_enzyme
        subroutine fci_cubic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_cubic_bezier_edge_area_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_cubic_bezier_edge_area_vjp_enzyme
        subroutine fci_cubic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_cubic_bezier_edge_area_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_cubic_bezier_edge_area_jvp_enzyme
        subroutine fci_cubic_lagrange_weights_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_cubic_lagrange_weights_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_cubic_lagrange_weights_vjp_enzyme
        subroutine fci_cubic_lagrange_weights_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_cubic_lagrange_weights_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_cubic_lagrange_weights_jvp_enzyme
        subroutine fci_curved_quadrilateral_cell_area_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_curved_quadrilateral_cell_area_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_curved_quadrilateral_cell_area_vjp_enzyme
        subroutine fci_curved_quadrilateral_cell_area_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_curved_quadrilateral_cell_area_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_curved_quadrilateral_cell_area_jvp_enzyme
        subroutine fci_decic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_decic_bezier_edge_area_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_decic_bezier_edge_area_vjp_enzyme
        subroutine fci_decic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_decic_bezier_edge_area_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_decic_bezier_edge_area_jvp_enzyme
        subroutine fci_nonic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_nonic_bezier_edge_area_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_nonic_bezier_edge_area_vjp_enzyme
        subroutine fci_nonic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_nonic_bezier_edge_area_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_nonic_bezier_edge_area_jvp_enzyme
        subroutine fci_octic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_octic_bezier_edge_area_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_octic_bezier_edge_area_vjp_enzyme
        subroutine fci_octic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_octic_bezier_edge_area_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_octic_bezier_edge_area_jvp_enzyme
        subroutine fci_parallel_diffusion_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_parallel_diffusion_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_parallel_diffusion_vjp_enzyme
        subroutine fci_parallel_diffusion_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_parallel_diffusion_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_parallel_diffusion_jvp_enzyme
        subroutine fci_parallel_flux_power_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_parallel_flux_power_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_parallel_flux_power_vjp_enzyme
        subroutine fci_parallel_flux_power_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_parallel_flux_power_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_parallel_flux_power_jvp_enzyme
        subroutine fci_perpendicular_power_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_perpendicular_power_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_perpendicular_power_vjp_enzyme
        subroutine fci_perpendicular_power_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_perpendicular_power_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_perpendicular_power_jvp_enzyme
        subroutine fci_quadratic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_quadratic_bezier_edge_area_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_quadratic_bezier_edge_area_vjp_enzyme
        subroutine fci_quadratic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_quadratic_bezier_edge_area_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_quadratic_bezier_edge_area_jvp_enzyme
        subroutine fci_quadratic_lagrange_weights_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_quadratic_lagrange_weights_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_quadratic_lagrange_weights_vjp_enzyme
        subroutine fci_quadratic_lagrange_weights_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_quadratic_lagrange_weights_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_quadratic_lagrange_weights_jvp_enzyme
        subroutine fci_quartic_lagrange_weights_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_quartic_lagrange_weights_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_quartic_lagrange_weights_vjp_enzyme
        subroutine fci_quartic_lagrange_weights_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_quartic_lagrange_weights_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_quartic_lagrange_weights_jvp_enzyme
        subroutine fci_quintic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_quintic_bezier_edge_area_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_quintic_bezier_edge_area_vjp_enzyme
        subroutine fci_quintic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_quintic_bezier_edge_area_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_quintic_bezier_edge_area_jvp_enzyme
        subroutine fci_septic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_septic_bezier_edge_area_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_septic_bezier_edge_area_vjp_enzyme
        subroutine fci_septic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_septic_bezier_edge_area_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_septic_bezier_edge_area_jvp_enzyme
        subroutine fci_sextic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_sextic_bezier_edge_area_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_sextic_bezier_edge_area_vjp_enzyme
        subroutine fci_sextic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_sextic_bezier_edge_area_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_sextic_bezier_edge_area_jvp_enzyme
        subroutine fci_sextic_lagrange_weights_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_sextic_lagrange_weights_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_sextic_lagrange_weights_vjp_enzyme
        subroutine fci_sextic_lagrange_weights_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_sextic_lagrange_weights_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_sextic_lagrange_weights_jvp_enzyme
        subroutine fci_staggered_flux_box_volume_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="fci_staggered_flux_box_volume_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine fci_staggered_flux_box_volume_vjp_enzyme
        subroutine fci_staggered_flux_box_volume_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="fci_staggered_flux_box_volume_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine fci_staggered_flux_box_volume_jvp_enzyme
        subroutine field_aligned_flux_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="field_aligned_flux_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine field_aligned_flux_vjp_enzyme
        subroutine field_aligned_flux_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="field_aligned_flux_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine field_aligned_flux_jvp_enzyme
        subroutine field_aligned_hall_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="field_aligned_hall_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine field_aligned_hall_vjp_enzyme
        subroutine field_aligned_hall_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="field_aligned_hall_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine field_aligned_hall_jvp_enzyme
        subroutine force_balance_product_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="force_balance_product_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine force_balance_product_vjp_enzyme
        subroutine force_balance_product_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="force_balance_product_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine force_balance_product_jvp_enzyme
        subroutine helmholtz_single_layer_integrand_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="helmholtz_single_layer_integrand_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine helmholtz_single_layer_integrand_vjp_enzyme
        subroutine helmholtz_single_layer_integrand_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="helmholtz_single_layer_integrand_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine helmholtz_single_layer_integrand_jvp_enzyme
        subroutine helmholtz_single_layer_smooth_integrand_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="helmholtz_single_layer_smooth_integrand_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine helmholtz_single_layer_smooth_integrand_vjp_enzyme
        subroutine helmholtz_single_layer_smooth_integrand_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="helmholtz_single_layer_smooth_integrand_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine helmholtz_single_layer_smooth_integrand_jvp_enzyme
        subroutine laplace_singular_edge_potential_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="laplace_singular_edge_potential_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine laplace_singular_edge_potential_vjp_enzyme
        subroutine laplace_singular_edge_potential_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="laplace_singular_edge_potential_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine laplace_singular_edge_potential_jvp_enzyme
        subroutine regularized_surface_current_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="regularized_surface_current_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine regularized_surface_current_vjp_enzyme
        subroutine regularized_surface_current_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="regularized_surface_current_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine regularized_surface_current_jvp_enzyme
        subroutine sphere_curved_panel_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="sphere_curved_panel_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine sphere_curved_panel_vjp_enzyme
        subroutine sphere_curved_panel_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="sphere_curved_panel_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine sphere_curved_panel_jvp_enzyme
        subroutine surface_integral_contribution_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="surface_integral_contribution_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine surface_integral_contribution_vjp_enzyme
        subroutine surface_integral_contribution_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="surface_integral_contribution_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine surface_integral_contribution_jvp_enzyme
        subroutine surface_shape_objective_contribution_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="surface_shape_objective_contribution_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine surface_shape_objective_contribution_vjp_enzyme
        subroutine surface_shape_objective_contribution_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="surface_shape_objective_contribution_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine surface_shape_objective_contribution_jvp_enzyme
        subroutine tensor_power_split_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="tensor_power_split_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine tensor_power_split_vjp_enzyme
        subroutine tensor_power_split_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="tensor_power_split_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine tensor_power_split_jvp_enzyme
        subroutine toroidal_poisson_products_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="toroidal_poisson_products_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine toroidal_poisson_products_vjp_enzyme
        subroutine toroidal_poisson_products_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="toroidal_poisson_products_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine toroidal_poisson_products_jvp_enzyme
        subroutine toroidal_vector_to_cartesian_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="toroidal_vector_to_cartesian_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine toroidal_vector_to_cartesian_vjp_enzyme
        subroutine toroidal_vector_to_cartesian_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="toroidal_vector_to_cartesian_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine toroidal_vector_to_cartesian_jvp_enzyme
        subroutine torus_curved_panel_vjp_enzyme(n, z, zb, y, yb) &
                bind(C, name="torus_curved_panel_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine torus_curved_panel_vjp_enzyme
        subroutine torus_curved_panel_jvp_enzyme(n, z, dz, y, dy) &
                bind(C, name="torus_curved_panel_jvp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), dz(*), y, dy
        end subroutine torus_curved_panel_jvp_enzyme
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

    integer, parameter :: NW = 42
    character(len=39), parameter :: NAMES(NW) = &
        [character(len=39) :: "block_graph_product",  &
         "cgl_pressure_divergence", "cgl_pressure_tensor",  &
         "fci_cubic_bezier_edge_area", "fci_cubic_lagrange_weights",  &
         "fci_curved_quadrilateral_cell_area",  &
         "fci_decic_bezier_edge_area", "fci_hendecic_bezier_edge_area",  &
         "fci_nonic_bezier_edge_area", "fci_octic_bezier_edge_area",  &
         "fci_parallel_diffusion", "fci_parallel_flux_power",  &
         "fci_parallel_gradient", "fci_perpendicular_power",  &
         "fci_polygon_edge_area", "fci_quadratic_bezier_edge_area",  &
         "fci_quadratic_lagrange_weights", "fci_quadrilateral_cell_area",  &
         "fci_quartic_bezier_edge_area", "fci_quartic_lagrange_weights",  &
         "fci_quintic_bezier_edge_area", "fci_quintic_lagrange_weights",  &
         "fci_septic_bezier_edge_area", "fci_sextic_bezier_edge_area",  &
         "fci_sextic_lagrange_weights", "fci_staggered_flux_box_volume",  &
         "field_aligned_flux", "field_aligned_hall",  &
         "force_balance_product", "helmholtz_single_layer_integrand",  &
         "helmholtz_single_layer_smooth_integrand",  &
         "laplace_single_layer_integrand",  &
         "laplace_singular_edge_potential", "regularized_surface_current",  &
         "sphere_curved_panel", "surface_integral_contribution",  &
         "surface_shape_objective_contribution",  &
         "surface_triangle_geometry_3d", "tensor_power_split",  &
         "toroidal_poisson_products", "toroidal_vector_to_cartesian",  &
         "torus_curved_panel"]
    integer, parameter :: ARITY(NW) = [2, 20, 5, 8, 5, 16, 22, 24, 20, 18,  &
        8, 3, 5, 3, 4, 6, 4, 8, 10, 6, 12, 7, 16, 14, 8, 4, 8, 4, 3, 10,  &
        10, 9, 9, 4, 12, 2, 3, 11, 12, 8, 6, 10]
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

        ! Differences of the primal, before the two engines are compared with
        ! each other. Cross-checking alone cannot tell which of two
        ! disagreeing engines is right, and it cannot see them being wrong the
        ! same way at all.
        call check_differences(name, N_BATCH, z, zb)
        call cross_check(name, "enzyme", zb, zb2, tol)
        call cross_check(name, "fortad-grad", zb, zb3, tol)

        call call_fortad_jvp(name, N_BATCH, z, dz, y, dy)
        call call_enzyme_jvp(name, N_BATCH, z, dz, y, dy2)
        if (abs(dy - dy2) > tol*max(1.0_dp, abs(dy))) then
            print *, "DISAGREEMENT ", trim(name), " jvp fortad vs enzyme: ", &
                dy, dy2
        end if
        ! The directional derivative is the gradient contracted with the
        ! direction. That relation needs no third reference, so it catches both
        ! engines being wrong the same way in one mode.
        if (abs(dy - dot_product(zb, dz)) > 10.0_dp*tol*max(1.0_dp, abs(dy))) then
            print *, "DISAGREEMENT ", trim(name), " jvp vs gradient: ", dy, &
                dot_product(zb, dz)
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
        case ("block_graph_product")
            call block_graph_product(n, z, y)
        case ("cgl_pressure_divergence")
            call cgl_pressure_divergence(n, z, y)
        case ("fci_cubic_bezier_edge_area")
            call fci_cubic_bezier_edge_area(n, z, y)
        case ("fci_cubic_lagrange_weights")
            call fci_cubic_lagrange_weights(n, z, y)
        case ("fci_curved_quadrilateral_cell_area")
            call fci_curved_quadrilateral_cell_area(n, z, y)
        case ("fci_decic_bezier_edge_area")
            call fci_decic_bezier_edge_area(n, z, y)
        case ("fci_nonic_bezier_edge_area")
            call fci_nonic_bezier_edge_area(n, z, y)
        case ("fci_octic_bezier_edge_area")
            call fci_octic_bezier_edge_area(n, z, y)
        case ("fci_parallel_diffusion")
            call fci_parallel_diffusion(n, z, y)
        case ("fci_parallel_flux_power")
            call fci_parallel_flux_power(n, z, y)
        case ("fci_perpendicular_power")
            call fci_perpendicular_power(n, z, y)
        case ("fci_quadratic_bezier_edge_area")
            call fci_quadratic_bezier_edge_area(n, z, y)
        case ("fci_quadratic_lagrange_weights")
            call fci_quadratic_lagrange_weights(n, z, y)
        case ("fci_quartic_lagrange_weights")
            call fci_quartic_lagrange_weights(n, z, y)
        case ("fci_quintic_bezier_edge_area")
            call fci_quintic_bezier_edge_area(n, z, y)
        case ("fci_septic_bezier_edge_area")
            call fci_septic_bezier_edge_area(n, z, y)
        case ("fci_sextic_bezier_edge_area")
            call fci_sextic_bezier_edge_area(n, z, y)
        case ("fci_sextic_lagrange_weights")
            call fci_sextic_lagrange_weights(n, z, y)
        case ("fci_staggered_flux_box_volume")
            call fci_staggered_flux_box_volume(n, z, y)
        case ("field_aligned_flux")
            call field_aligned_flux(n, z, y)
        case ("field_aligned_hall")
            call field_aligned_hall(n, z, y)
        case ("force_balance_product")
            call force_balance_product(n, z, y)
        case ("helmholtz_single_layer_integrand")
            call helmholtz_single_layer_integrand(n, z, y)
        case ("helmholtz_single_layer_smooth_integrand")
            call helmholtz_single_layer_smooth_integrand(n, z, y)
        case ("laplace_singular_edge_potential")
            call laplace_singular_edge_potential(n, z, y)
        case ("regularized_surface_current")
            call regularized_surface_current(n, z, y)
        case ("sphere_curved_panel")
            call sphere_curved_panel(n, z, y)
        case ("surface_integral_contribution")
            call surface_integral_contribution(n, z, y)
        case ("surface_shape_objective_contribution")
            call surface_shape_objective_contribution(n, z, y)
        case ("tensor_power_split")
            call tensor_power_split(n, z, y)
        case ("toroidal_poisson_products")
            call toroidal_poisson_products(n, z, y)
        case ("toroidal_vector_to_cartesian")
            call toroidal_vector_to_cartesian(n, z, y)
        case ("torus_curved_panel")
            call torus_curved_panel(n, z, y)
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
        case ("block_graph_product")
            call block_graph_product_vjp(n, z, y, yb, zb)
        case ("cgl_pressure_divergence")
            call cgl_pressure_divergence_vjp(n, z, y, yb, zb)
        case ("fci_cubic_bezier_edge_area")
            call fci_cubic_bezier_edge_area_vjp(n, z, y, yb, zb)
        case ("fci_cubic_lagrange_weights")
            call fci_cubic_lagrange_weights_vjp(n, z, y, yb, zb)
        case ("fci_curved_quadrilateral_cell_area")
            call fci_curved_quadrilateral_cell_area_vjp(n, z, y, yb, zb)
        case ("fci_decic_bezier_edge_area")
            call fci_decic_bezier_edge_area_vjp(n, z, y, yb, zb)
        case ("fci_nonic_bezier_edge_area")
            call fci_nonic_bezier_edge_area_vjp(n, z, y, yb, zb)
        case ("fci_octic_bezier_edge_area")
            call fci_octic_bezier_edge_area_vjp(n, z, y, yb, zb)
        case ("fci_parallel_diffusion")
            call fci_parallel_diffusion_vjp(n, z, y, yb, zb)
        case ("fci_parallel_flux_power")
            call fci_parallel_flux_power_vjp(n, z, y, yb, zb)
        case ("fci_perpendicular_power")
            call fci_perpendicular_power_vjp(n, z, y, yb, zb)
        case ("fci_quadratic_bezier_edge_area")
            call fci_quadratic_bezier_edge_area_vjp(n, z, y, yb, zb)
        case ("fci_quadratic_lagrange_weights")
            call fci_quadratic_lagrange_weights_vjp(n, z, y, yb, zb)
        case ("fci_quartic_lagrange_weights")
            call fci_quartic_lagrange_weights_vjp(n, z, y, yb, zb)
        case ("fci_quintic_bezier_edge_area")
            call fci_quintic_bezier_edge_area_vjp(n, z, y, yb, zb)
        case ("fci_septic_bezier_edge_area")
            call fci_septic_bezier_edge_area_vjp(n, z, y, yb, zb)
        case ("fci_sextic_bezier_edge_area")
            call fci_sextic_bezier_edge_area_vjp(n, z, y, yb, zb)
        case ("fci_sextic_lagrange_weights")
            call fci_sextic_lagrange_weights_vjp(n, z, y, yb, zb)
        case ("fci_staggered_flux_box_volume")
            call fci_staggered_flux_box_volume_vjp(n, z, y, yb, zb)
        case ("field_aligned_flux")
            call field_aligned_flux_vjp(n, z, y, yb, zb)
        case ("field_aligned_hall")
            call field_aligned_hall_vjp(n, z, y, yb, zb)
        case ("force_balance_product")
            call force_balance_product_vjp(n, z, y, yb, zb)
        case ("helmholtz_single_layer_integrand")
            call helmholtz_single_layer_integrand_vjp(n, z, y, yb, zb)
        case ("helmholtz_single_layer_smooth_integrand")
            call helmholtz_single_layer_smooth_integrand_vjp(n, z, y, yb, zb)
        case ("laplace_singular_edge_potential")
            call laplace_singular_edge_potential_vjp(n, z, y, yb, zb)
        case ("regularized_surface_current")
            call regularized_surface_current_vjp(n, z, y, yb, zb)
        case ("sphere_curved_panel")
            call sphere_curved_panel_vjp(n, z, y, yb, zb)
        case ("surface_integral_contribution")
            call surface_integral_contribution_vjp(n, z, y, yb, zb)
        case ("surface_shape_objective_contribution")
            call surface_shape_objective_contribution_vjp(n, z, y, yb, zb)
        case ("tensor_power_split")
            call tensor_power_split_vjp(n, z, y, yb, zb)
        case ("toroidal_poisson_products")
            call toroidal_poisson_products_vjp(n, z, y, yb, zb)
        case ("toroidal_vector_to_cartesian")
            call toroidal_vector_to_cartesian_vjp(n, z, y, yb, zb)
        case ("torus_curved_panel")
            call torus_curved_panel_vjp(n, z, y, yb, zb)
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
        case ("block_graph_product")
            call block_graph_product_grad(n, z, yb, zb)
        case ("cgl_pressure_divergence")
            call cgl_pressure_divergence_grad(n, z, yb, zb)
        case ("fci_cubic_bezier_edge_area")
            call fci_cubic_bezier_edge_area_grad(n, z, yb, zb)
        case ("fci_cubic_lagrange_weights")
            call fci_cubic_lagrange_weights_grad(n, z, yb, zb)
        case ("fci_curved_quadrilateral_cell_area")
            call fci_curved_quadrilateral_cell_area_grad(n, z, yb, zb)
        case ("fci_decic_bezier_edge_area")
            call fci_decic_bezier_edge_area_grad(n, z, yb, zb)
        case ("fci_nonic_bezier_edge_area")
            call fci_nonic_bezier_edge_area_grad(n, z, yb, zb)
        case ("fci_octic_bezier_edge_area")
            call fci_octic_bezier_edge_area_grad(n, z, yb, zb)
        case ("fci_parallel_diffusion")
            call fci_parallel_diffusion_grad(n, z, yb, zb)
        case ("fci_parallel_flux_power")
            call fci_parallel_flux_power_grad(n, z, yb, zb)
        case ("fci_perpendicular_power")
            call fci_perpendicular_power_grad(n, z, yb, zb)
        case ("fci_quadratic_bezier_edge_area")
            call fci_quadratic_bezier_edge_area_grad(n, z, yb, zb)
        case ("fci_quadratic_lagrange_weights")
            call fci_quadratic_lagrange_weights_grad(n, z, yb, zb)
        case ("fci_quartic_lagrange_weights")
            call fci_quartic_lagrange_weights_grad(n, z, yb, zb)
        case ("fci_quintic_bezier_edge_area")
            call fci_quintic_bezier_edge_area_grad(n, z, yb, zb)
        case ("fci_septic_bezier_edge_area")
            call fci_septic_bezier_edge_area_grad(n, z, yb, zb)
        case ("fci_sextic_bezier_edge_area")
            call fci_sextic_bezier_edge_area_grad(n, z, yb, zb)
        case ("fci_sextic_lagrange_weights")
            call fci_sextic_lagrange_weights_grad(n, z, yb, zb)
        case ("fci_staggered_flux_box_volume")
            call fci_staggered_flux_box_volume_grad(n, z, yb, zb)
        case ("field_aligned_flux")
            call field_aligned_flux_grad(n, z, yb, zb)
        case ("field_aligned_hall")
            call field_aligned_hall_grad(n, z, yb, zb)
        case ("force_balance_product")
            call force_balance_product_grad(n, z, yb, zb)
        case ("helmholtz_single_layer_integrand")
            call helmholtz_single_layer_integrand_grad(n, z, yb, zb)
        case ("helmholtz_single_layer_smooth_integrand")
            call helmholtz_single_layer_smooth_integrand_grad(n, z, yb, zb)
        case ("laplace_singular_edge_potential")
            call laplace_singular_edge_potential_grad(n, z, yb, zb)
        case ("regularized_surface_current")
            call regularized_surface_current_grad(n, z, yb, zb)
        case ("sphere_curved_panel")
            call sphere_curved_panel_grad(n, z, yb, zb)
        case ("surface_integral_contribution")
            call surface_integral_contribution_grad(n, z, yb, zb)
        case ("surface_shape_objective_contribution")
            call surface_shape_objective_contribution_grad(n, z, yb, zb)
        case ("tensor_power_split")
            call tensor_power_split_grad(n, z, yb, zb)
        case ("toroidal_poisson_products")
            call toroidal_poisson_products_grad(n, z, yb, zb)
        case ("toroidal_vector_to_cartesian")
            call toroidal_vector_to_cartesian_grad(n, z, yb, zb)
        case ("torus_curved_panel")
            call torus_curved_panel_grad(n, z, yb, zb)
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
        case ("block_graph_product")
            call block_graph_product_jvp(n, z, dz, y, dy)
        case ("cgl_pressure_divergence")
            call cgl_pressure_divergence_jvp(n, z, dz, y, dy)
        case ("fci_cubic_bezier_edge_area")
            call fci_cubic_bezier_edge_area_jvp(n, z, dz, y, dy)
        case ("fci_cubic_lagrange_weights")
            call fci_cubic_lagrange_weights_jvp(n, z, dz, y, dy)
        case ("fci_curved_quadrilateral_cell_area")
            call fci_curved_quadrilateral_cell_area_jvp(n, z, dz, y, dy)
        case ("fci_decic_bezier_edge_area")
            call fci_decic_bezier_edge_area_jvp(n, z, dz, y, dy)
        case ("fci_nonic_bezier_edge_area")
            call fci_nonic_bezier_edge_area_jvp(n, z, dz, y, dy)
        case ("fci_octic_bezier_edge_area")
            call fci_octic_bezier_edge_area_jvp(n, z, dz, y, dy)
        case ("fci_parallel_diffusion")
            call fci_parallel_diffusion_jvp(n, z, dz, y, dy)
        case ("fci_parallel_flux_power")
            call fci_parallel_flux_power_jvp(n, z, dz, y, dy)
        case ("fci_perpendicular_power")
            call fci_perpendicular_power_jvp(n, z, dz, y, dy)
        case ("fci_quadratic_bezier_edge_area")
            call fci_quadratic_bezier_edge_area_jvp(n, z, dz, y, dy)
        case ("fci_quadratic_lagrange_weights")
            call fci_quadratic_lagrange_weights_jvp(n, z, dz, y, dy)
        case ("fci_quartic_lagrange_weights")
            call fci_quartic_lagrange_weights_jvp(n, z, dz, y, dy)
        case ("fci_quintic_bezier_edge_area")
            call fci_quintic_bezier_edge_area_jvp(n, z, dz, y, dy)
        case ("fci_septic_bezier_edge_area")
            call fci_septic_bezier_edge_area_jvp(n, z, dz, y, dy)
        case ("fci_sextic_bezier_edge_area")
            call fci_sextic_bezier_edge_area_jvp(n, z, dz, y, dy)
        case ("fci_sextic_lagrange_weights")
            call fci_sextic_lagrange_weights_jvp(n, z, dz, y, dy)
        case ("fci_staggered_flux_box_volume")
            call fci_staggered_flux_box_volume_jvp(n, z, dz, y, dy)
        case ("field_aligned_flux")
            call field_aligned_flux_jvp(n, z, dz, y, dy)
        case ("field_aligned_hall")
            call field_aligned_hall_jvp(n, z, dz, y, dy)
        case ("force_balance_product")
            call force_balance_product_jvp(n, z, dz, y, dy)
        case ("helmholtz_single_layer_integrand")
            call helmholtz_single_layer_integrand_jvp(n, z, dz, y, dy)
        case ("helmholtz_single_layer_smooth_integrand")
            call helmholtz_single_layer_smooth_integrand_jvp(n, z, dz, y, dy)
        case ("laplace_singular_edge_potential")
            call laplace_singular_edge_potential_jvp(n, z, dz, y, dy)
        case ("regularized_surface_current")
            call regularized_surface_current_jvp(n, z, dz, y, dy)
        case ("sphere_curved_panel")
            call sphere_curved_panel_jvp(n, z, dz, y, dy)
        case ("surface_integral_contribution")
            call surface_integral_contribution_jvp(n, z, dz, y, dy)
        case ("surface_shape_objective_contribution")
            call surface_shape_objective_contribution_jvp(n, z, dz, y, dy)
        case ("tensor_power_split")
            call tensor_power_split_jvp(n, z, dz, y, dy)
        case ("toroidal_poisson_products")
            call toroidal_poisson_products_jvp(n, z, dz, y, dy)
        case ("toroidal_vector_to_cartesian")
            call toroidal_vector_to_cartesian_jvp(n, z, dz, y, dy)
        case ("torus_curved_panel")
            call torus_curved_panel_jvp(n, z, dz, y, dy)
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
        case ("block_graph_product")
            call block_graph_product_vjp_enzyme(n, z, zb, y, yb)
        case ("cgl_pressure_divergence")
            call cgl_pressure_divergence_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_cubic_bezier_edge_area")
            call fci_cubic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_cubic_lagrange_weights")
            call fci_cubic_lagrange_weights_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_curved_quadrilateral_cell_area")
            call fci_curved_quadrilateral_cell_area_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_decic_bezier_edge_area")
            call fci_decic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_nonic_bezier_edge_area")
            call fci_nonic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_octic_bezier_edge_area")
            call fci_octic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_parallel_diffusion")
            call fci_parallel_diffusion_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_parallel_flux_power")
            call fci_parallel_flux_power_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_perpendicular_power")
            call fci_perpendicular_power_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_quadratic_bezier_edge_area")
            call fci_quadratic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_quadratic_lagrange_weights")
            call fci_quadratic_lagrange_weights_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_quartic_lagrange_weights")
            call fci_quartic_lagrange_weights_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_quintic_bezier_edge_area")
            call fci_quintic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_septic_bezier_edge_area")
            call fci_septic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_sextic_bezier_edge_area")
            call fci_sextic_bezier_edge_area_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_sextic_lagrange_weights")
            call fci_sextic_lagrange_weights_vjp_enzyme(n, z, zb, y, yb)
        case ("fci_staggered_flux_box_volume")
            call fci_staggered_flux_box_volume_vjp_enzyme(n, z, zb, y, yb)
        case ("field_aligned_flux")
            call field_aligned_flux_vjp_enzyme(n, z, zb, y, yb)
        case ("field_aligned_hall")
            call field_aligned_hall_vjp_enzyme(n, z, zb, y, yb)
        case ("force_balance_product")
            call force_balance_product_vjp_enzyme(n, z, zb, y, yb)
        case ("helmholtz_single_layer_integrand")
            call helmholtz_single_layer_integrand_vjp_enzyme(n, z, zb, y, yb)
        case ("helmholtz_single_layer_smooth_integrand")
            call helmholtz_single_layer_smooth_integrand_vjp_enzyme(n, z, zb, y, yb)
        case ("laplace_singular_edge_potential")
            call laplace_singular_edge_potential_vjp_enzyme(n, z, zb, y, yb)
        case ("regularized_surface_current")
            call regularized_surface_current_vjp_enzyme(n, z, zb, y, yb)
        case ("sphere_curved_panel")
            call sphere_curved_panel_vjp_enzyme(n, z, zb, y, yb)
        case ("surface_integral_contribution")
            call surface_integral_contribution_vjp_enzyme(n, z, zb, y, yb)
        case ("surface_shape_objective_contribution")
            call surface_shape_objective_contribution_vjp_enzyme(n, z, zb, y, yb)
        case ("tensor_power_split")
            call tensor_power_split_vjp_enzyme(n, z, zb, y, yb)
        case ("toroidal_poisson_products")
            call toroidal_poisson_products_vjp_enzyme(n, z, zb, y, yb)
        case ("toroidal_vector_to_cartesian")
            call toroidal_vector_to_cartesian_vjp_enzyme(n, z, zb, y, yb)
        case ("torus_curved_panel")
            call torus_curved_panel_vjp_enzyme(n, z, zb, y, yb)
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
        case ("block_graph_product")
            call block_graph_product_jvp_enzyme(n, z, dz, y, dy)
        case ("cgl_pressure_divergence")
            call cgl_pressure_divergence_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_cubic_bezier_edge_area")
            call fci_cubic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_cubic_lagrange_weights")
            call fci_cubic_lagrange_weights_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_curved_quadrilateral_cell_area")
            call fci_curved_quadrilateral_cell_area_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_decic_bezier_edge_area")
            call fci_decic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_nonic_bezier_edge_area")
            call fci_nonic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_octic_bezier_edge_area")
            call fci_octic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_parallel_diffusion")
            call fci_parallel_diffusion_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_parallel_flux_power")
            call fci_parallel_flux_power_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_perpendicular_power")
            call fci_perpendicular_power_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_quadratic_bezier_edge_area")
            call fci_quadratic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_quadratic_lagrange_weights")
            call fci_quadratic_lagrange_weights_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_quartic_lagrange_weights")
            call fci_quartic_lagrange_weights_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_quintic_bezier_edge_area")
            call fci_quintic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_septic_bezier_edge_area")
            call fci_septic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_sextic_bezier_edge_area")
            call fci_sextic_bezier_edge_area_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_sextic_lagrange_weights")
            call fci_sextic_lagrange_weights_jvp_enzyme(n, z, dz, y, dy)
        case ("fci_staggered_flux_box_volume")
            call fci_staggered_flux_box_volume_jvp_enzyme(n, z, dz, y, dy)
        case ("field_aligned_flux")
            call field_aligned_flux_jvp_enzyme(n, z, dz, y, dy)
        case ("field_aligned_hall")
            call field_aligned_hall_jvp_enzyme(n, z, dz, y, dy)
        case ("force_balance_product")
            call force_balance_product_jvp_enzyme(n, z, dz, y, dy)
        case ("helmholtz_single_layer_integrand")
            call helmholtz_single_layer_integrand_jvp_enzyme(n, z, dz, y, dy)
        case ("helmholtz_single_layer_smooth_integrand")
            call helmholtz_single_layer_smooth_integrand_jvp_enzyme(n, z, dz, y, dy)
        case ("laplace_singular_edge_potential")
            call laplace_singular_edge_potential_jvp_enzyme(n, z, dz, y, dy)
        case ("regularized_surface_current")
            call regularized_surface_current_jvp_enzyme(n, z, dz, y, dy)
        case ("sphere_curved_panel")
            call sphere_curved_panel_jvp_enzyme(n, z, dz, y, dy)
        case ("surface_integral_contribution")
            call surface_integral_contribution_jvp_enzyme(n, z, dz, y, dy)
        case ("surface_shape_objective_contribution")
            call surface_shape_objective_contribution_jvp_enzyme(n, z, dz, y, dy)
        case ("tensor_power_split")
            call tensor_power_split_jvp_enzyme(n, z, dz, y, dy)
        case ("toroidal_poisson_products")
            call toroidal_poisson_products_jvp_enzyme(n, z, dz, y, dy)
        case ("toroidal_vector_to_cartesian")
            call toroidal_vector_to_cartesian_jvp_enzyme(n, z, dz, y, dy)
        case ("torus_curved_panel")
            call torus_curved_panel_jvp_enzyme(n, z, dz, y, dy)
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

    subroutine check_differences(name, n, z, g)
        !! A few entries against central differences of the primal.
        !!
        !! Loose on purpose: cancellation in the difference costs several
        !! digits, so demanding more would measure the step size. It is here to
        !! settle which engine is right when they disagree, and to catch both
        !! being wrong together - neither of which cross-checking can do.
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:), g(:)
        real(dp), allocatable :: work(:)
        real(dp) :: h, yp, ym, fd, scale
        integer :: i, k

        work = z
        scale = max(1.0_dp, maxval(abs(g)))
        do k = 1, min(12, size(z))
            i = 1 + (k - 1)*(size(z)/12)
            h = 1.0e-6_dp*max(1.0_dp, abs(z(i)))
            work(i) = z(i) + h
            call call_primal(name, n, work, yp)
            work(i) = z(i) - h
            call call_primal(name, n, work, ym)
            work(i) = z(i)
            fd = (yp - ym)/(2.0_dp*h)
            if (abs(g(i) - fd) > 1.0e-5_dp*scale) then
                print *, "DIFFERENCE MISMATCH ", name, " at ", i, ": ", g(i), fd
                error stop 1
            end if
        end do
    end subroutine check_differences

    subroutine cross_check(name, other, g1, g2, tol)
        !! Report the worst disagreement rather than stopping on it.
        !!
        !! fortad reassociates - it factors, distributes and multiplies by
        !! reciprocals, none of which a Fortran compiler may do - and that
        !! costs accuracy where the exact arithmetic cancels. On the quintic
        !! Lagrange weights, whose weights sum to one, an entry whose true
        !! derivative is exactly zero comes out as -1.5e-8: Enzyme returns zero
        !! and so do central differences of the primal. That is a real property
        !! of the emitted code and belongs in the results, not under a
        !! tolerance chosen to hide it, so the worst relative disagreement is
        !! recorded per operator and the run continues.
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
        real(dp) :: scale, worst
        integer :: i

        scale = max(1.0_dp, maxval(abs(g1)))
        worst = 0.0_dp
        do i = 1, size(g1)
            worst = max(worst, abs(g1(i) - g2(i))/scale)
        end do
        if (worst > tol) then
            print *, "DISAGREEMENT ", trim(name), " fortad vs ", trim(other), &
                ", worst relative ", worst
        end if
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
