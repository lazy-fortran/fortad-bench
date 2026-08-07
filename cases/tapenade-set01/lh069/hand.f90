! Independent JVP and VJP for the bounded one-iteration lh069 path.
module tapenade_set01_lh069_hand
    implicit none
    private
    public :: set01_lh069_hand_jvp, set01_lh069_hand_vjp

contains

    subroutine set01_lh069_hand_jvp(a, ad, b, bd, n, ao, aod, bo, bod)
        integer, intent(in) :: n
        real, intent(in) :: a(10), ad(10), b(10), bd(10)
        real, intent(out) :: ao(10), aod(10), bo(10), bod(10)
        integer :: i

        ao = a
        aod = ad
        bo = b
        bod = bd
        aod(1) = 2.0*aod(2)
        ao(1) = 2.0*ao(2)
        aod(3) = 4.0*aod(4)
        ao(3) = 4.0*ao(4)
        if (ao(3) > ao(8)) then
            aod(5) = 6.0*aod(6)
            ao(5) = 6.0*ao(6)
            do i = 5, n
                aod(i) = bod(i)
                ao(i) = bo(i)
            end do
        end if
        aod(7) = 8.0*aod(8)
        ao(7) = 8.0*ao(8)
    end subroutine set01_lh069_hand_jvp

    subroutine set01_lh069_hand_vjp(a, b, n, ao_bar, bo_bar, a_bar, b_bar)
        integer, intent(in) :: n
        real, intent(in) :: a(10), b(10)
        real, intent(inout) :: ao_bar(10), bo_bar(10)
        real, intent(out) :: a_bar(10), b_bar(10)
        integer :: i

        a_bar = 0.0
        b_bar = bo_bar
        a_bar(2) = a_bar(2) + ao_bar(2)
        a_bar(4) = a_bar(4) + ao_bar(4)
        b_bar(8) = b_bar(8) + 8.0*ao_bar(7)
        ao_bar(7) = 0.0
        do i = n, 5, -1
            b_bar(i) = b_bar(i) + ao_bar(i)
            ao_bar(i) = 0.0
        end do
        a_bar(6) = a_bar(6) + 6.0*ao_bar(5)
        ao_bar(5) = 0.0
        a_bar(4) = a_bar(4) + 4.0*ao_bar(3)
        ao_bar(3) = 0.0
        a_bar(2) = a_bar(2) + 2.0*ao_bar(1)
        ao_bar(1) = 0.0
    end subroutine set01_lh069_hand_vjp

end module tapenade_set01_lh069_hand
