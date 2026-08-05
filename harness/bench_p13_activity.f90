program bench_p13_activity
  use vmec_ad, only: vmec_vjp
  implicit none

  integer, parameter :: nhalf = 12, nznT = 32, reps = 2000
  real(8), parameter :: h = 1.0d-6
  real(8) :: r1e(nhalf+1,nznT), r1o(nhalf+1,nznT)
  real(8) :: z1e(nhalf+1,nznT), z1o(nhalf+1,nznT)
  real(8) :: rue(nhalf+1,nznT), ruo(nhalf+1,nznT)
  real(8) :: zue(nhalf+1,nznT), zuo(nhalf+1,nznT)
  real(8) :: dr1e(nhalf+1,nznT), dr1o(nhalf+1,nznT)
  real(8) :: dz1e(nhalf+1,nznT), dz1o(nhalf+1,nznT)
  real(8) :: drue(nhalf+1,nznT), druo(nhalf+1,nznT)
  real(8) :: dzue(nhalf+1,nznT), dzuo(nhalf+1,nznT)
  real(8) :: sqrtsh(nhalf), deltaS, dSHalfDsInterp
  real(8) :: loss, lossp, lossm, fd, vjp, rel, sink
  real(8) :: r1e_b(nhalf+1,nznT), r1o_b(nhalf+1,nznT)
  real(8) :: z1e_b(nhalf+1,nznT), z1o_b(nhalf+1,nznT)
  real(8) :: rue_b(nhalf+1,nznT), ruo_b(nhalf+1,nznT)
  real(8) :: zue_b(nhalf+1,nznT), zuo_b(nhalf+1,nznT)
  integer :: i, k, count0, count1, rate, r

  call fill_inputs()
  call vmec_half_grid_plain(nhalf, nznT, r1e, r1o, z1e, z1o, rue, ruo, &
                            zue, zuo, sqrtsh, deltaS, dSHalfDsInterp, loss)
  call vmec_vjp(nhalf, nznT, r1e, r1o, z1e, z1o, rue, ruo, zue, zuo, &
                sqrtsh, deltaS, dSHalfDsInterp, loss, 1.0d0, r1e_b, r1o_b, &
                z1e_b, z1o_b, rue_b, ruo_b, zue_b, zuo_b)
  vjp = sum(r1e_b*dr1e) + sum(r1o_b*dr1o) + sum(z1e_b*dz1e) + &
        sum(z1o_b*dz1o) + sum(rue_b*drue) + sum(ruo_b*druo) + &
        sum(zue_b*dzue) + sum(zuo_b*dzuo)

  call vmec_half_grid_plain(nhalf, nznT, r1e+h*dr1e, r1o+h*dr1o, &
                            z1e+h*dz1e, z1o+h*dz1o, rue+h*drue, ruo+h*druo, &
                            zue+h*dzue, zuo+h*dzuo, sqrtsh, deltaS, &
                            dSHalfDsInterp, lossp)
  call vmec_half_grid_plain(nhalf, nznT, r1e-h*dr1e, r1o-h*dr1o, &
                            z1e-h*dz1e, z1o-h*dz1o, rue-h*drue, ruo-h*druo, &
                            zue-h*dzue, zuo-h*dzuo, sqrtsh, deltaS, &
                            dSHalfDsInterp, lossm)
  fd = (lossp-lossm)/(2.0d0*h)
  rel = abs(vjp-fd)/(abs(fd)+1.0d-300)
  print '(a,es16.8)', 'directional_vjp ', vjp
  print '(a,es16.8)', 'directional_fd ', fd
  print '(a,es12.4)', 'directional_relative_error ', rel

  call system_clock(count_rate=rate)
  call system_clock(count0)
  sink = 0.0d0
  do r = 1, reps
    call vmec_vjp(nhalf, nznT, r1e, r1o, z1e, z1o, rue, ruo, zue, zuo, &
                  sqrtsh, deltaS, dSHalfDsInterp, loss, 1.0d0, r1e_b, r1o_b, &
                  z1e_b, z1o_b, rue_b, ruo_b, zue_b, zuo_b)
    sink = sink + sum(r1e_b)
  end do
  call system_clock(count1)
  print '(a,es16.8)', 'vjp_seconds_per_pass ', &
       real(count1-count0,8)/real(rate,8)/real(reps,8)
  print '(a,es16.8)', 'sink ', sink

  if (rel < 1.0d-8) then
    print '(a)', 'PASS'
  else
    print '(a)', 'FAIL'
    error stop 1
  end if

contains

  subroutine fill_inputs()
    real(8) :: x
    do i = 1, nhalf+1
      do k = 1, nznT
        x = real(17*i+3*k,8)
        r1e(i,k) = 0.5d0 + 0.001d0*x
        r1o(i,k) = 0.6d0 + 0.0013d0*x
        z1e(i,k) = 0.7d0 + 0.0017d0*x
        z1o(i,k) = 0.8d0 + 0.0021d0*x
        rue(i,k) = 0.9d0 + 0.0023d0*x
        ruo(i,k) = 1.0d0 + 0.0027d0*x
        zue(i,k) = 1.1d0 + 0.0031d0*x
        zuo(i,k) = 1.2d0 + 0.0035d0*x
        dr1e(i,k) = sin(0.07d0*x)
        dr1o(i,k) = cos(0.11d0*x)
        dz1e(i,k) = sin(0.13d0*x)
        dz1o(i,k) = cos(0.17d0*x)
        drue(i,k) = sin(0.19d0*x)
        druo(i,k) = cos(0.23d0*x)
        dzue(i,k) = sin(0.29d0*x)
        dzuo(i,k) = cos(0.31d0*x)
      end do
    end do
    do i = 1, nhalf
      sqrtsh(i) = sqrt(0.05d0 + 0.9d0*real(i-1,8)/real(nhalf,8))
    end do
    deltaS = 0.1d0
    dSHalfDsInterp = 0.25d0
  end subroutine fill_inputs

end program bench_p13_activity
