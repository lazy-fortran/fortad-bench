! Bounded scalar specialization of nonRegressions/set01/lh069/program.f.
! The upstream source has an uninitialized local N.  This port exposes N as
! an integer control and is used only with n=10, 4*a4>a8, and 4*a4<=b8.
! Scalarizing the ten array elements makes that fixed one-iteration path
! explicit without changing its arithmetic or copy order.
subroutine set01_lh069(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, &
    b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, n, &
    ao1, ao2, ao3, ao4, ao5, ao6, ao7, ao8, ao9, ao10, &
    bo1, bo2, bo3, bo4, bo5, bo6, bo7, bo8, bo9, bo10)
    implicit none
    integer, intent(in) :: n
    real, intent(in) :: a1, a2, a3, a4, a5, a6, a7, a8, a9, a10
    real, intent(in) :: b1, b2, b3, b4, b5, b6, b7, b8, b9, b10
    real, intent(out) :: ao1, ao2, ao3, ao4, ao5, ao6, ao7, ao8, ao9, ao10
    real, intent(out) :: bo1, bo2, bo3, bo4, bo5, bo6, bo7, bo8, bo9, bo10

    ao1 = a1
    ao2 = a2
    ao3 = a3
    ao4 = a4
    ao5 = a5
    ao6 = a6
    ao7 = a7
    ao8 = a8
    ao9 = a9
    ao10 = a10
    bo1 = b1
    bo2 = b2
    bo3 = b3
    bo4 = b4
    bo5 = b5
    bo6 = b6
    bo7 = b7
    bo8 = b8
    bo9 = b9
    bo10 = b10

    ao1 = 2.0*ao2
    ao3 = 4.0*ao4
    if (ao3 > ao8) then
        ao5 = 6.0*ao6
        ao5 = bo5
        ao6 = bo6
        ao7 = bo7
        ao8 = bo8
        ao9 = bo9
        ao10 = bo10
    end if
    ao7 = 8.0*ao8
end subroutine set01_lh069
