! SPDX-FileCopyrightText: 2024-present Proxima Fusion GmbH
! SPDX-License-Identifier: MIT
!
! Fortran port of VMEC++'s ComputeHalfGridJacobian from upstream commit
! ccdeec53e048f086d71b2ffa35070238e3c70373.  The port keeps the full-grid
! radial dimension and poloidal dimension as ordinary Fortran arrays instead
! of exposing the upstream flat-buffer/index-offset interface.
module vmec_jacobian_kernel
  implicit none
  private

  integer, parameter, public :: dp = kind(1.0d0)

  type, public :: geometry_field
    real(dp), allocatable :: r1e(:,:), r1o(:,:), z1e(:,:), z1o(:,:)
    real(dp), allocatable :: rue(:,:), ruo(:,:), zue(:,:), zuo(:,:)
  end type geometry_field

  type, public :: jacobian_field
    real(dp), allocatable :: r12(:,:), ru12(:,:), zu12(:,:)
    real(dp), allocatable :: rs(:,:), zs(:,:), tau(:,:)
  end type jacobian_field

  public :: allocate_geometry, allocate_jacobian
  public :: compute_half_grid_jacobian
  public :: compute_half_grid_jacobian_jvp
  public :: compute_half_grid_jacobian_vjp
  public :: zero_geometry, zero_jacobian

contains

  subroutine allocate_geometry(g, nfull, nznT)
    type(geometry_field), intent(inout) :: g
    integer, intent(in) :: nfull, nznT
    call deallocate_geometry(g)
    allocate(g%r1e(nfull,nznT), g%r1o(nfull,nznT), &
             g%z1e(nfull,nznT), g%z1o(nfull,nznT), &
             g%rue(nfull,nznT), g%ruo(nfull,nznT), &
             g%zue(nfull,nznT), g%zuo(nfull,nznT))
  end subroutine allocate_geometry

  subroutine allocate_jacobian(y, nhalf, nznT)
    type(jacobian_field), intent(inout) :: y
    integer, intent(in) :: nhalf, nznT
    call deallocate_jacobian(y)
    allocate(y%r12(nhalf,nznT), y%ru12(nhalf,nznT), &
             y%zu12(nhalf,nznT), y%rs(nhalf,nznT), &
             y%zs(nhalf,nznT), y%tau(nhalf,nznT))
  end subroutine allocate_jacobian

  subroutine deallocate_geometry(g)
    type(geometry_field), intent(inout) :: g
    if (allocated(g%r1e)) deallocate(g%r1e)
    if (allocated(g%r1o)) deallocate(g%r1o)
    if (allocated(g%z1e)) deallocate(g%z1e)
    if (allocated(g%z1o)) deallocate(g%z1o)
    if (allocated(g%rue)) deallocate(g%rue)
    if (allocated(g%ruo)) deallocate(g%ruo)
    if (allocated(g%zue)) deallocate(g%zue)
    if (allocated(g%zuo)) deallocate(g%zuo)
  end subroutine deallocate_geometry

  subroutine deallocate_jacobian(y)
    type(jacobian_field), intent(inout) :: y
    if (allocated(y%r12)) deallocate(y%r12)
    if (allocated(y%ru12)) deallocate(y%ru12)
    if (allocated(y%zu12)) deallocate(y%zu12)
    if (allocated(y%rs)) deallocate(y%rs)
    if (allocated(y%zs)) deallocate(y%zs)
    if (allocated(y%tau)) deallocate(y%tau)
  end subroutine deallocate_jacobian

  subroutine zero_geometry(g)
    type(geometry_field), intent(inout) :: g
    g%r1e = 0.0_dp
    g%r1o = 0.0_dp
    g%z1e = 0.0_dp
    g%z1o = 0.0_dp
    g%rue = 0.0_dp
    g%ruo = 0.0_dp
    g%zue = 0.0_dp
    g%zuo = 0.0_dp
  end subroutine zero_geometry

  subroutine zero_jacobian(y)
    type(jacobian_field), intent(inout) :: y
    y%r12 = 0.0_dp
    y%ru12 = 0.0_dp
    y%zu12 = 0.0_dp
    y%rs = 0.0_dp
    y%zs = 0.0_dp
    y%tau = 0.0_dp
  end subroutine zero_jacobian

  subroutine compute_half_grid_jacobian(g, sqrtsh, deltaS, dSHalfDsInterp, y)
    type(geometry_field), intent(in) :: g
    real(dp), intent(in) :: sqrtsh(:), deltaS, dSHalfDsInterp
    type(jacobian_field), intent(inout) :: y
    integer :: ih, kl, i_in, i_out
    real(dp) :: sH
    real(dp) :: r1e_i, r1e_o, r1o_i, r1o_o
    real(dp) :: z1e_i, z1e_o, z1o_i, z1o_o
    real(dp) :: rue_i, rue_o, ruo_i, ruo_o
    real(dp) :: zue_i, zue_o, zuo_i, zuo_o
    real(dp) :: tau1, tau2

    do ih = 1, size(y%r12,1)
      sH = sqrtsh(ih)
      i_in = ih
      i_out = ih + 1
      do kl = 1, size(y%r12,2)
        r1e_i = g%r1e(i_in,kl); r1e_o = g%r1e(i_out,kl)
        r1o_i = g%r1o(i_in,kl); r1o_o = g%r1o(i_out,kl)
        z1e_i = g%z1e(i_in,kl); z1e_o = g%z1e(i_out,kl)
        z1o_i = g%z1o(i_in,kl); z1o_o = g%z1o(i_out,kl)
        rue_i = g%rue(i_in,kl); rue_o = g%rue(i_out,kl)
        ruo_i = g%ruo(i_in,kl); ruo_o = g%ruo(i_out,kl)
        zue_i = g%zue(i_in,kl); zue_o = g%zue(i_out,kl)
        zuo_i = g%zuo(i_in,kl); zuo_o = g%zuo(i_out,kl)

        y%r12(ih,kl) = 0.5_dp * ((r1e_i+r1e_o) + sH*(r1o_i+r1o_o))
        y%ru12(ih,kl) = 0.5_dp * ((rue_i+rue_o) + sH*(ruo_i+ruo_o))
        y%zu12(ih,kl) = 0.5_dp * ((zue_i+zue_o) + sH*(zuo_i+zuo_o))
        y%rs(ih,kl) = ((r1e_o-r1e_i) + sH*(r1o_o-r1o_i)) / deltaS
        y%zs(ih,kl) = ((z1e_o-z1e_i) + sH*(z1o_o-z1o_i)) / deltaS

        tau1 = y%ru12(ih,kl)*y%zs(ih,kl) - y%rs(ih,kl)*y%zu12(ih,kl)
        tau2 = ruo_o*z1o_o + ruo_i*z1o_i - zuo_o*r1o_o - zuo_i*r1o_i &
             + (rue_o*z1o_o + rue_i*z1o_i - zue_o*r1o_o - zue_i*r1o_i) / sH
        y%tau(ih,kl) = tau1 + dSHalfDsInterp*tau2
      end do
    end do
  end subroutine compute_half_grid_jacobian

  ! Hand-written JVP with respect to the eight geometry fields. sqrtsh,
  ! deltaS and dSHalfDsInterp are fixed interpolation data, as in the
  ! upstream Enzyme comparison.
  subroutine compute_half_grid_jacobian_jvp(g, dg, sqrtsh, deltaS, &
                                            dSHalfDsInterp, y, dy)
    type(geometry_field), intent(in) :: g, dg
    real(dp), intent(in) :: sqrtsh(:), deltaS, dSHalfDsInterp
    type(jacobian_field), intent(inout) :: y, dy
    integer :: ih, kl, i_in, i_out
    real(dp) :: sH
    real(dp) :: r1e_i,r1e_o,r1o_i,r1o_o,z1e_i,z1e_o,z1o_i,z1o_o
    real(dp) :: rue_i,rue_o,ruo_i,ruo_o,zue_i,zue_o,zuo_i,zuo_o
    real(dp) :: dr1e_i,dr1e_o,dr1o_i,dr1o_o,dz1e_i,dz1e_o,dz1o_i,dz1o_o
    real(dp) :: drue_i,drue_o,druo_i,druo_o,dzue_i,dzue_o,dzuo_i,dzuo_o
    real(dp) :: dr12,dru12,dzu12,drs,dzs,dtau1,dtau2,tau1,tau2
    real(dp) :: r12,ru12,zu12,rs,zs

    do ih = 1, size(dy%r12,1)
      sH = sqrtsh(ih)
      i_in = ih
      i_out = ih + 1
      do kl = 1, size(dy%r12,2)
        r1e_i = g%r1e(i_in,kl); r1e_o = g%r1e(i_out,kl)
        r1o_i = g%r1o(i_in,kl); r1o_o = g%r1o(i_out,kl)
        z1e_i = g%z1e(i_in,kl); z1e_o = g%z1e(i_out,kl)
        z1o_i = g%z1o(i_in,kl); z1o_o = g%z1o(i_out,kl)
        rue_i = g%rue(i_in,kl); rue_o = g%rue(i_out,kl)
        ruo_i = g%ruo(i_in,kl); ruo_o = g%ruo(i_out,kl)
        zue_i = g%zue(i_in,kl); zue_o = g%zue(i_out,kl)
        zuo_i = g%zuo(i_in,kl); zuo_o = g%zuo(i_out,kl)
        dr1e_i = dg%r1e(i_in,kl); dr1e_o = dg%r1e(i_out,kl)
        dr1o_i = dg%r1o(i_in,kl); dr1o_o = dg%r1o(i_out,kl)
        dz1e_i = dg%z1e(i_in,kl); dz1e_o = dg%z1e(i_out,kl)
        dz1o_i = dg%z1o(i_in,kl); dz1o_o = dg%z1o(i_out,kl)
        drue_i = dg%rue(i_in,kl); drue_o = dg%rue(i_out,kl)
        druo_i = dg%ruo(i_in,kl); druo_o = dg%ruo(i_out,kl)
        dzue_i = dg%zue(i_in,kl); dzue_o = dg%zue(i_out,kl)
        dzuo_i = dg%zuo(i_in,kl); dzuo_o = dg%zuo(i_out,kl)

        r12 = 0.5_dp*((r1e_i+r1e_o) + sH*(r1o_i+r1o_o))
        ru12 = 0.5_dp*((rue_i+rue_o) + sH*(ruo_i+ruo_o))
        zu12 = 0.5_dp*((zue_i+zue_o) + sH*(zuo_i+zuo_o))
        rs = ((r1e_o-r1e_i) + sH*(r1o_o-r1o_i))/deltaS
        zs = ((z1e_o-z1e_i) + sH*(z1o_o-z1o_i))/deltaS
        dr12 = 0.5_dp*((dr1e_i+dr1e_o) + sH*(dr1o_i+dr1o_o))
        dru12 = 0.5_dp*((drue_i+drue_o) + sH*(druo_i+druo_o))
        dzu12 = 0.5_dp*((dzue_i+dzue_o) + sH*(dzuo_i+dzuo_o))
        drs = ((dr1e_o-dr1e_i) + sH*(dr1o_o-dr1o_i))/deltaS
        dzs = ((dz1e_o-dz1e_i) + sH*(dz1o_o-dz1o_i))/deltaS
        tau1 = ru12*zs - rs*zu12
        tau2 = ruo_o*z1o_o + ruo_i*z1o_i - zuo_o*r1o_o - zuo_i*r1o_i &
             + (rue_o*z1o_o + rue_i*z1o_i - zue_o*r1o_o - zue_i*r1o_i) / sH
        dtau2 = druo_o*z1o_o + ruo_o*dz1o_o + druo_i*z1o_i + ruo_i*dz1o_i &
               - dzuo_o*r1o_o - zuo_o*dr1o_o - dzuo_i*r1o_i - zuo_i*dr1o_i &
               + (drue_o*z1o_o + rue_o*dz1o_o + drue_i*z1o_i + rue_i*dz1o_i &
                  - dzue_o*r1o_o - zue_o*dr1o_o - dzue_i*r1o_i &
                  - zue_i*dr1o_i) / sH
        dtau1 = dru12*zs + ru12*dzs - drs*zu12 - rs*dzu12
        y%r12(ih,kl) = r12
        y%ru12(ih,kl) = ru12
        y%zu12(ih,kl) = zu12
        y%rs(ih,kl) = rs
        y%zs(ih,kl) = zs
        y%tau(ih,kl) = tau1 + dSHalfDsInterp*tau2
        dy%r12(ih,kl) = dr12
        dy%ru12(ih,kl) = dru12
        dy%zu12(ih,kl) = dzu12
        dy%rs(ih,kl) = drs
        dy%zs(ih,kl) = dzs
        dy%tau(ih,kl) = dtau1 + dSHalfDsInterp*dtau2
      end do
    end do
  end subroutine compute_half_grid_jacobian_jvp

  ! Hand-written VJP with respect to the eight geometry fields. The output
  ! cotangent is accumulated into the two full-grid surfaces touched by each
  ! half-grid point.
  subroutine compute_half_grid_jacobian_vjp(g, ybar, sqrtsh, deltaS, &
                                            dSHalfDsInterp, y, gbar)
    type(geometry_field), intent(in) :: g
    type(jacobian_field), intent(in) :: ybar
    real(dp), intent(in) :: sqrtsh(:), deltaS, dSHalfDsInterp
    type(jacobian_field), intent(inout) :: y
    type(geometry_field), intent(inout) :: gbar
    integer :: ih, kl, i_in, i_out
    real(dp) :: sH, bt1, bt2, bru, bzu, brs, bzs
    real(dp) :: r1e_i,r1e_o,r1o_i,r1o_o,z1e_i,z1e_o,z1o_i,z1o_o
    real(dp) :: rue_i,rue_o,ruo_i,ruo_o,zue_i,zue_o,zuo_i,zuo_o
    real(dp) :: r12,ru12,zu12,rs,zs,tau1,tau2

    call zero_geometry(gbar)
    do ih = 1, size(ybar%r12,1)
      sH = sqrtsh(ih)
      i_in = ih
      i_out = ih + 1
      do kl = 1, size(ybar%r12,2)
        r1e_i = g%r1e(i_in,kl); r1e_o = g%r1e(i_out,kl)
        r1o_i = g%r1o(i_in,kl); r1o_o = g%r1o(i_out,kl)
        z1e_i = g%z1e(i_in,kl); z1e_o = g%z1e(i_out,kl)
        z1o_i = g%z1o(i_in,kl); z1o_o = g%z1o(i_out,kl)
        rue_i = g%rue(i_in,kl); rue_o = g%rue(i_out,kl)
        ruo_i = g%ruo(i_in,kl); ruo_o = g%ruo(i_out,kl)
        zue_i = g%zue(i_in,kl); zue_o = g%zue(i_out,kl)
        zuo_i = g%zuo(i_in,kl); zuo_o = g%zuo(i_out,kl)
        ru12 = 0.5_dp*((rue_i+rue_o) + sH*(ruo_i+ruo_o))
        zu12 = 0.5_dp*((zue_i+zue_o) + sH*(zuo_i+zuo_o))
        r12 = 0.5_dp*((r1e_i+r1e_o) + sH*(r1o_i+r1o_o))
        rs = ((r1e_o-r1e_i) + sH*(r1o_o-r1o_i))/deltaS
        zs = ((z1e_o-z1e_i) + sH*(z1o_o-z1o_i))/deltaS
        tau1 = ru12*zs - rs*zu12
        tau2 = ruo_o*z1o_o + ruo_i*z1o_i - zuo_o*r1o_o - zuo_i*r1o_i &
             + (rue_o*z1o_o + rue_i*z1o_i - zue_o*r1o_o - zue_i*r1o_i) / sH
        y%r12(ih,kl) = r12
        y%ru12(ih,kl) = ru12
        y%zu12(ih,kl) = zu12
        y%rs(ih,kl) = rs
        y%zs(ih,kl) = zs
        y%tau(ih,kl) = tau1 + dSHalfDsInterp*tau2
        bt1 = ybar%tau(ih,kl)
        bt2 = dSHalfDsInterp*bt1
        bru = ybar%ru12(ih,kl) + bt1*zs
        bzu = ybar%zu12(ih,kl) - bt1*rs
        brs = ybar%rs(ih,kl) - bt1*zu12
        bzs = ybar%zs(ih,kl) + bt1*ru12

        gbar%r1e(i_in,kl) = gbar%r1e(i_in,kl) + 0.5_dp*ybar%r12(ih,kl) - brs/deltaS
        gbar%r1e(i_out,kl) = gbar%r1e(i_out,kl) + 0.5_dp*ybar%r12(ih,kl) + brs/deltaS
        gbar%r1o(i_in,kl) = gbar%r1o(i_in,kl) + 0.5_dp*sH*ybar%r12(ih,kl) - sH*brs/deltaS
        gbar%r1o(i_out,kl) = gbar%r1o(i_out,kl) + 0.5_dp*sH*ybar%r12(ih,kl) + sH*brs/deltaS
        gbar%z1e(i_in,kl) = gbar%z1e(i_in,kl) - bzs/deltaS
        gbar%z1e(i_out,kl) = gbar%z1e(i_out,kl) + bzs/deltaS
        gbar%z1o(i_in,kl) = gbar%z1o(i_in,kl) - sH*bzs/deltaS
        gbar%z1o(i_out,kl) = gbar%z1o(i_out,kl) + sH*bzs/deltaS

        gbar%rue(i_in,kl) = gbar%rue(i_in,kl) + 0.5_dp*bru
        gbar%rue(i_out,kl) = gbar%rue(i_out,kl) + 0.5_dp*bru
        gbar%ruo(i_in,kl) = gbar%ruo(i_in,kl) + 0.5_dp*sH*bru
        gbar%ruo(i_out,kl) = gbar%ruo(i_out,kl) + 0.5_dp*sH*bru
        gbar%zue(i_in,kl) = gbar%zue(i_in,kl) + 0.5_dp*bzu
        gbar%zue(i_out,kl) = gbar%zue(i_out,kl) + 0.5_dp*bzu
        gbar%zuo(i_in,kl) = gbar%zuo(i_in,kl) + 0.5_dp*sH*bzu
        gbar%zuo(i_out,kl) = gbar%zuo(i_out,kl) + 0.5_dp*sH*bzu

        gbar%ruo(i_out,kl) = gbar%ruo(i_out,kl) + bt2*z1o_o
        gbar%z1o(i_out,kl) = gbar%z1o(i_out,kl) + bt2*ruo_o
        gbar%ruo(i_in,kl) = gbar%ruo(i_in,kl) + bt2*z1o_i
        gbar%z1o(i_in,kl) = gbar%z1o(i_in,kl) + bt2*ruo_i
        gbar%zuo(i_out,kl) = gbar%zuo(i_out,kl) - bt2*r1o_o
        gbar%r1o(i_out,kl) = gbar%r1o(i_out,kl) - bt2*zuo_o
        gbar%zuo(i_in,kl) = gbar%zuo(i_in,kl) - bt2*r1o_i
        gbar%r1o(i_in,kl) = gbar%r1o(i_in,kl) - bt2*zuo_i
        gbar%rue(i_out,kl) = gbar%rue(i_out,kl) + bt2*z1o_o/sH
        gbar%z1o(i_out,kl) = gbar%z1o(i_out,kl) + bt2*rue_o/sH
        gbar%rue(i_in,kl) = gbar%rue(i_in,kl) + bt2*z1o_i/sH
        gbar%z1o(i_in,kl) = gbar%z1o(i_in,kl) + bt2*rue_i/sH
        gbar%zue(i_out,kl) = gbar%zue(i_out,kl) - bt2*r1o_o/sH
        gbar%r1o(i_out,kl) = gbar%r1o(i_out,kl) - bt2*zue_o/sH
        gbar%zue(i_in,kl) = gbar%zue(i_in,kl) - bt2*r1o_i/sH
        gbar%r1o(i_in,kl) = gbar%r1o(i_in,kl) - bt2*zue_i/sH
      end do
    end do
  end subroutine compute_half_grid_jacobian_vjp

end module vmec_jacobian_kernel
