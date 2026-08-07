program bench_tapenade_set03_ht09
  use, intrinsic :: iso_fortran_env, only : real32
  use fofo_jvp_mod, only : ht09_jvp
  use fofo_vjp_mod, only : ht09_vjp
  use tapenade_set03_ht09_hand, only : primal_ht09, jvp_ht09, vjp_ht09
  implicit none

  real(real32) :: x(10), xd(10), y(10), yd(10), yd_hand(10)
  real(real32) :: yb(10), xb(10), xb_hand(10), xplus(10), xminus(10)
  real(real32) :: yplus(10), yminus(10), fd(10), h, err
  integer :: i

  do i = 1, 10
    x(i) = 0.25_real32 * real(i, real32) + 0.125_real32
    xd(i) = (-1.0_real32)**i * (0.1_real32 + 0.03_real32 * real(i, real32))
    yb(i) = 0.2_real32 - 0.01_real32 * real(i, real32)
  end do

  call jvp_ht09(x, xd, yd_hand)
  y = 0.0_real32
  call ht09_jvp(x, xd, y, yd)
  err = maxval(abs(yd - yd_hand))
  if (err > 2.0e-6_real32) error stop "JVP disagrees with hand derivative"

  call vjp_ht09(x, yb, xb_hand)
  y = 0.0_real32
  call ht09_vjp(x, y, yb, xb)
  err = maxval(abs(xb - xb_hand))
  if (err > 2.0e-6_real32) error stop "VJP disagrees with hand derivative"

  err = abs(sum(yd * yb) - sum(xd * xb_hand))
  if (err > 2.0e-6_real32) error stop "adjoint identity failed"

  do i = 2, 5
    h = 10.0_real32**(-i)
    xplus = x + h * xd
    xminus = x - h * xd
    call primal_ht09(xplus, yplus)
    call primal_ht09(xminus, yminus)
    fd = (yplus - yminus) / (2.0_real32 * h)
    err = maxval(abs(fd - yd_hand))
    if (err > 6.0e-3_real32) error stop "central difference disagrees"
  end do

  write (*, '(a)') 'oracle_status: pass'
end program bench_tapenade_set03_ht09
