program lh064_harness
  use iso_fortran_env, only: real64
  use lh064_forward_mod, only: lh064_forward
  use lh064_hand_mod, only: set01_lh064_hand
  implicit none

  interface
    subroutine set01_lh064(t, n)
      use iso_fortran_env, only: real64
      real(real64), intent(inout) :: t(0:1000)
      integer, intent(in) :: n
    end subroutine set01_lh064
  end interface

  real(real64) :: t0(0:1000), d0(0:1000)
  real(real64) :: port_t(0:1000), hand_t(0:1000)
  real(real64) :: fortad_t(0:1000), fortad_td(0:1000)
  real(real64) :: hand_td(0:1000)
  integer :: n

  n = 5
  t0 = 0.0_real64
  d0 = 0.0_real64
  t0(1:n) = [-0.5_real64, -0.25_real64, 0.0_real64, 0.25_real64, 1.0_real64]
  d0(1:n) = [0.3_real64, -0.4_real64, 0.5_real64, -0.6_real64, 0.7_real64]

  port_t = t0
  call set01_lh064(port_t, n)

  hand_t = t0
  hand_td = d0
  call set01_lh064_hand(hand_t, hand_td, n)

  fortad_t = t0
  fortad_td = d0
  call lh064_forward(fortad_t, fortad_td, n)

  if (maxval(abs(port_t - hand_t)) > 1.0e-12_real64) then
    error stop "bounded primal mismatch"
  end if
  if (maxval(abs(fortad_t - hand_t)) > 1.0e-12_real64) then
    error stop "FortAD primal mismatch"
  end if
  if (maxval(abs(fortad_td - hand_td)) > 1.0e-12_real64) then
    error stop "FortAD JVP mismatch"
  end if

  print '(a)', 'harness_status: pass'
  print '(a,es24.16)', 'primal_norm: ', maxval(abs(port_t - hand_t))
  print '(a,es24.16)', 'jvp_norm: ', maxval(abs(fortad_td - hand_td))
end program lh064_harness
