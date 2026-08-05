! Plain-array form of VMEC++'s ComputeHalfGridJacobian arithmetic.
! It is the same half-grid kernel as kernel.f90, without the derived-type
! allocation wrapper, so fortad can inspect the arithmetic itself.
subroutine vmec_half_grid_plain(nhalf, nznT, r1e, r1o, z1e, z1o, rue, ruo, &
                                zue, zuo, sqrtsh, deltaS, dSHalfDsInterp, loss)
  integer, intent(in) :: nhalf, nznT
  real(8), intent(in) :: r1e(nhalf+1,nznT), r1o(nhalf+1,nznT)
  real(8), intent(in) :: z1e(nhalf+1,nznT), z1o(nhalf+1,nznT)
  real(8), intent(in) :: rue(nhalf+1,nznT), ruo(nhalf+1,nznT)
  real(8), intent(in) :: zue(nhalf+1,nznT), zuo(nhalf+1,nznT)
  real(8), intent(in) :: sqrtsh(nhalf), deltaS, dSHalfDsInterp
  real(8), intent(out) :: loss
  integer :: ih, kl, i_in, i_out
  real(8) :: sH
  real(8) :: r1e_i, r1e_o, r1o_i, r1o_o
  real(8) :: z1e_i, z1e_o, z1o_i, z1o_o
  real(8) :: rue_i, rue_o, ruo_i, ruo_o
  real(8) :: zue_i, zue_o, zuo_i, zuo_o
  real(8) :: r12, ru12, zu12, rs, zs, tau1, tau2, tau

  loss = 0.0d0
  do ih = 1, nhalf
    sH = sqrtsh(ih)
    i_in = ih
    i_out = ih + 1
    do kl = 1, nznT
      r1e_i = r1e(i_in,kl); r1e_o = r1e(i_out,kl)
      r1o_i = r1o(i_in,kl); r1o_o = r1o(i_out,kl)
      z1e_i = z1e(i_in,kl); z1e_o = z1e(i_out,kl)
      z1o_i = z1o(i_in,kl); z1o_o = z1o(i_out,kl)
      rue_i = rue(i_in,kl); rue_o = rue(i_out,kl)
      ruo_i = ruo(i_in,kl); ruo_o = ruo(i_out,kl)
      zue_i = zue(i_in,kl); zue_o = zue(i_out,kl)
      zuo_i = zuo(i_in,kl); zuo_o = zuo(i_out,kl)

      r12 = 0.5d0 * ((r1e_i+r1e_o) + sH*(r1o_i+r1o_o))
      ru12 = 0.5d0 * ((rue_i+rue_o) + sH*(ruo_i+ruo_o))
      zu12 = 0.5d0 * ((zue_i+zue_o) + sH*(zuo_i+zuo_o))
      rs = ((r1e_o-r1e_i) + sH*(r1o_o-r1o_i)) / deltaS
      zs = ((z1e_o-z1e_i) + sH*(z1o_o-z1o_i)) / deltaS
      tau1 = ru12*zs - rs*zu12
      tau2 = ruo_o*z1o_o + ruo_i*z1o_i - zuo_o*r1o_o - zuo_i*r1o_i &
           + (rue_o*z1o_o + rue_i*z1o_i - zue_o*r1o_o - zue_i*r1o_i) / sH
      tau = tau1 + dSHalfDsInterp*tau2
      loss = loss + tau
    end do
  end do
end subroutine vmec_half_grid_plain
