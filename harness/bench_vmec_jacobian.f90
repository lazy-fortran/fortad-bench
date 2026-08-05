program bench_vmec_jacobian
  use vmec_jacobian_kernel
  implicit none

  integer, parameter :: nznT = 32, nhalf = 12, nfull = nhalf + 1
  integer, parameter :: reps = 2000
  real(dp), parameter :: deltaS = 0.1_dp, dSHalfDsInterp = 0.25_dp
  type(geometry_field) :: g, dg, gp, gm, gbar
  type(jacobian_field) :: y, dy, yp, ym, ybar, yloss
  real(dp) :: sqrtsh(nhalf), h, fd, jvp_loss, vjp_loss
  real(dp) :: lhs, rhs, fd_phi, phi_p, phi_m, scale
  real(dp) :: min_fd_err, min_fd_phi_err, err
  real(dp) :: t_primal, t_jvp, t_vjp, sink
  integer :: j, count0, count1, rate, r
  logical :: ok

  call allocate_geometry(g, nfull, nznT)
  call allocate_geometry(dg, nfull, nznT)
  call allocate_geometry(gp, nfull, nznT)
  call allocate_geometry(gm, nfull, nznT)
  call allocate_geometry(gbar, nfull, nznT)
  call allocate_jacobian(y, nhalf, nznT)
  call allocate_jacobian(dy, nhalf, nznT)
  call allocate_jacobian(yp, nhalf, nznT)
  call allocate_jacobian(ym, nhalf, nznT)
  call allocate_jacobian(ybar, nhalf, nznT)
  call allocate_jacobian(yloss, nhalf, nznT)
  call fill_inputs(g, dg, sqrtsh)
  call fill_output_cotangent(ybar)

  call compute_half_grid_jacobian_jvp(g, dg, sqrtsh, deltaS, &
                                      dSHalfDsInterp, y, dy)
  jvp_loss = output_dot(y, dy)
  yloss = y
  call compute_half_grid_jacobian_vjp(g, yloss, sqrtsh, deltaS, &
                                      dSHalfDsInterp, y, gbar)
  vjp_loss = geometry_dot(gbar, dg)

  print '(a,es24.16)', 'jvp_loss ', jvp_loss
  print '(a,es24.16)', 'vjp_loss ', vjp_loss
  print '(a,es12.4)', 'jvp_vjp_relative_error ', &
       abs(jvp_loss-vjp_loss)/(abs(jvp_loss)+1.0e-300_dp)

  call compute_half_grid_jacobian_jvp(g, dg, sqrtsh, deltaS, &
                                      dSHalfDsInterp, y, dy)
  call compute_half_grid_jacobian_vjp(g, ybar, sqrtsh, deltaS, &
                                      dSHalfDsInterp, y, gbar)
  lhs = output_dot(ybar, dy)
  rhs = geometry_dot(gbar, dg)

  min_fd_err = huge(1.0_dp)
  min_fd_phi_err = huge(1.0_dp)
  print '(a)', 'finite_difference_step relative_jvp_error relative_vjp_error'
  do j = 2, 7
    h = 10.0_dp**(-j)
    call perturb(gp, g, dg, h)
    call perturb(gm, g, dg, -h)
    fd = (loss_value(gp, yp, sqrtsh) - loss_value(gm, ym, sqrtsh))/(2.0_dp*h)
    scale = abs(fd) + 1.0e-300_dp
    err = abs(jvp_loss-fd)/scale
    min_fd_err = min(min_fd_err, err)
    phi_p = output_value(gp, yp, ybar, sqrtsh)
    phi_m = output_value(gm, ym, ybar, sqrtsh)
    fd_phi = (phi_p-phi_m)/(2.0_dp*h)
    err = abs(rhs-fd_phi)/(abs(fd_phi)+1.0e-300_dp)
    min_fd_phi_err = min(min_fd_phi_err, err)
    print '(es12.4,1x,es12.4,1x,es12.4)', h, &
         abs(jvp_loss-fd)/scale, abs(rhs-fd_phi)/(abs(fd_phi)+1.0e-300_dp)
  end do

  call compute_half_grid_jacobian_jvp(g, dg, sqrtsh, deltaS, &
                                      dSHalfDsInterp, y, dy)
  call compute_half_grid_jacobian_vjp(g, ybar, sqrtsh, deltaS, &
                                      dSHalfDsInterp, y, gbar)
  lhs = output_dot(ybar, dy)
  rhs = geometry_dot(gbar, dg)
  print '(a,es24.16)', 'adjoint_lhs ', lhs
  print '(a,es24.16)', 'adjoint_rhs ', rhs
  print '(a,es12.4)', 'adjoint_relative_error ', &
       abs(lhs-rhs)/(abs(lhs)+1.0e-300_dp)

  call system_clock(count_rate=rate)
  call system_clock(count0)
  sink = 0.0_dp
  do r = 1, reps
    call compute_half_grid_jacobian(g, sqrtsh, deltaS, dSHalfDsInterp, y)
    sink = sink + y%tau(1,1)
  end do
  call system_clock(count1)
  t_primal = real(count1-count0,dp)/real(rate,dp)/real(reps,dp)

  call system_clock(count0)
  do r = 1, reps
    call compute_half_grid_jacobian_jvp(g, dg, sqrtsh, deltaS, &
                                        dSHalfDsInterp, y, dy)
    sink = sink + output_dot(y,dy)
  end do
  call system_clock(count1)
  t_jvp = real(count1-count0,dp)/real(rate,dp)/real(reps,dp)

  call system_clock(count0)
  do r = 1, reps
    call compute_half_grid_jacobian_vjp(g, yloss, sqrtsh, deltaS, &
                                        dSHalfDsInterp, y, gbar)
    sink = sink + geometry_dot(gbar,dg)
  end do
  call system_clock(count1)
  t_vjp = real(count1-count0,dp)/real(rate,dp)/real(reps,dp)

  print '(a,es16.8)', 'primal_seconds_per_pass ', t_primal
  print '(a,es16.8)', 'hand_jvp_seconds_per_pass ', t_jvp
  print '(a,es16.8)', 'hand_vjp_seconds_per_pass ', t_vjp
  print '(a,es16.8)', 'sink ', sink

  ok = min_fd_err < 1.0e-8_dp .and. min_fd_phi_err < 1.0e-8_dp &
       .and. abs(lhs-rhs)/(abs(lhs)+1.0e-300_dp) < 1.0e-11_dp &
       .and. abs(jvp_loss-vjp_loss)/(abs(jvp_loss)+1.0e-300_dp) < 1.0e-11_dp
  if (ok) then
    print '(a)', 'PASS'
  else
    print '(a)', 'FAIL'
    error stop 1
  end if

contains

  subroutine fill_inputs(g, dg, sqrtsh)
    type(geometry_field), intent(inout) :: g, dg
    real(dp), intent(out) :: sqrtsh(:)
    integer :: i, k
    real(dp) :: x
    do i = 1, nfull
      do k = 1, nznT
        x = real(17*i+3*k,dp)
        g%r1e(i,k) = 0.5_dp + 0.001_dp*x
        g%r1o(i,k) = 0.6_dp + 0.0013_dp*x
        g%z1e(i,k) = 0.7_dp + 0.0017_dp*x
        g%z1o(i,k) = 0.8_dp + 0.0021_dp*x
        g%rue(i,k) = 0.9_dp + 0.0023_dp*x
        g%ruo(i,k) = 1.0_dp + 0.0027_dp*x
        g%zue(i,k) = 1.1_dp + 0.0031_dp*x
        g%zuo(i,k) = 1.2_dp + 0.0035_dp*x
        dg%r1e(i,k) = sin(0.07_dp*x)
        dg%r1o(i,k) = cos(0.11_dp*x)
        dg%z1e(i,k) = sin(0.13_dp*x)
        dg%z1o(i,k) = cos(0.17_dp*x)
        dg%rue(i,k) = sin(0.19_dp*x)
        dg%ruo(i,k) = cos(0.23_dp*x)
        dg%zue(i,k) = sin(0.29_dp*x)
        dg%zuo(i,k) = cos(0.31_dp*x)
      end do
    end do
    do i = 1, nhalf
      sqrtsh(i) = sqrt(0.05_dp + 0.9_dp*real(i-1,dp)/real(nhalf,dp))
    end do
  end subroutine fill_inputs

  subroutine fill_output_cotangent(ybar)
    type(jacobian_field), intent(inout) :: ybar
    integer :: i, k
    real(dp) :: x
    do i = 1, nhalf
      do k = 1, nznT
        x = real(5*i+2*k,dp)
        ybar%r12(i,k) = sin(0.03_dp*x)
        ybar%ru12(i,k) = cos(0.05_dp*x)
        ybar%zu12(i,k) = sin(0.07_dp*x)
        ybar%rs(i,k) = cos(0.09_dp*x)
        ybar%zs(i,k) = sin(0.11_dp*x)
        ybar%tau(i,k) = cos(0.13_dp*x)
      end do
    end do
  end subroutine fill_output_cotangent

  subroutine perturb(out, base, direction, scale)
    type(geometry_field), intent(inout) :: out
    type(geometry_field), intent(in) :: base, direction
    real(dp), intent(in) :: scale
    out%r1e = base%r1e + scale*direction%r1e
    out%r1o = base%r1o + scale*direction%r1o
    out%z1e = base%z1e + scale*direction%z1e
    out%z1o = base%z1o + scale*direction%z1o
    out%rue = base%rue + scale*direction%rue
    out%ruo = base%ruo + scale*direction%ruo
    out%zue = base%zue + scale*direction%zue
    out%zuo = base%zuo + scale*direction%zuo
  end subroutine perturb

  real(dp) function loss_value(g, y, sqrtsh)
    type(geometry_field), intent(in) :: g
    type(jacobian_field), intent(inout) :: y
    real(dp), intent(in) :: sqrtsh(:)
    call compute_half_grid_jacobian(g, sqrtsh, deltaS, dSHalfDsInterp, y)
    loss_value = 0.5_dp*(sum(y%r12*y%r12) + sum(y%ru12*y%ru12) &
                 + sum(y%zu12*y%zu12) + sum(y%rs*y%rs) &
                 + sum(y%zs*y%zs) + sum(y%tau*y%tau))
  end function loss_value

  real(dp) function output_value(g, y, ybar, sqrtsh)
    type(geometry_field), intent(in) :: g
    type(jacobian_field), intent(inout) :: y
    type(jacobian_field), intent(in) :: ybar
    real(dp), intent(in) :: sqrtsh(:)
    call compute_half_grid_jacobian(g, sqrtsh, deltaS, dSHalfDsInterp, y)
    output_value = output_dot(ybar, y)
  end function output_value

  real(dp) function output_dot(a, b)
    type(jacobian_field), intent(in) :: a, b
    output_dot = sum(a%r12*b%r12) + sum(a%ru12*b%ru12) &
               + sum(a%zu12*b%zu12) + sum(a%rs*b%rs) &
               + sum(a%zs*b%zs) + sum(a%tau*b%tau)
  end function output_dot

  real(dp) function geometry_dot(a, b)
    type(geometry_field), intent(in) :: a, b
    geometry_dot = sum(a%r1e*b%r1e) + sum(a%r1o*b%r1o) &
                 + sum(a%z1e*b%z1e) + sum(a%z1o*b%z1o) &
                 + sum(a%rue*b%rue) + sum(a%ruo*b%ruo) &
                 + sum(a%zue*b%zue) + sum(a%zuo*b%zuo)
  end function geometry_dot

end program bench_vmec_jacobian
