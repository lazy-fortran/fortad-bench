! Bounded, standard-conforming port of Tapenade nonRegressions/set01/bd05/program.f.
! The upstream case mutates A and C in place and leaves I implicit.  This
! bounded port declares I, retains HEAD's call to LEAF and both product loops,
! and exposes both mutated values as ordinary outputs.
subroutine set01_bd05(a_in, b_in, c_in, a_out, c_out)
    implicit none
    real, intent(in) :: a_in(10), b_in, c_in
    real, intent(out) :: a_out(10), c_out
    integer :: i
    real :: c_work

    a_out = a_in
    c_work = c_in
    call set01_bd05_leaf(a_out, b_in, c_work)
    c_out = c_work
    do i = 1, 10
        c_out = c_out * a_out(i)
    end do
end subroutine set01_bd05

subroutine set01_bd05_leaf(a, b, c)
    implicit none
    real, intent(inout) :: a(10), c
    real, intent(in) :: b
    integer :: i

    do i = 1, 10
        a(i) = b
        c = c * a(i)
    end do
end subroutine set01_bd05_leaf
