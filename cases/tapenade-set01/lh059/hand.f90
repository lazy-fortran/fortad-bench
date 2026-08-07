module tapenade_set01_lh059_hand
    implicit none
contains

    subroutine hand_value(t, u, n, i)
        integer, intent(in) :: n
        integer, intent(inout) :: i
        real, intent(inout) :: t(31), u(31)
        integer :: k

        do k = 1, 5
            if (t(i) > 1.0) then
                u(i) = u(i) + log(t(i))
                t(i) = 3.0*u(i)
            else
                u(i) = u(i) + t(i-5)
                if (u(i) >= 0.0) t(i) = 3.0*u(i)
            end if
            i = i + 5
            t(i) = 2.0*t(i) + 1.0
        end do
    end subroutine hand_value

    subroutine hand_jvp(t, td, u, ud, n, i)
        integer, intent(in) :: n
        integer, intent(inout) :: i
        real, intent(inout) :: t(31), td(31), u(31), ud(31)
        integer :: k

        do k = 1, 5
            if (t(i) > 1.0) then
                ud(i) = ud(i) + td(i)/t(i)
                u(i) = u(i) + log(t(i))
                td(i) = 3.0*ud(i)
                t(i) = 3.0*u(i)
            else
                ud(i) = ud(i) + td(i-5)
                u(i) = u(i) + t(i-5)
                if (u(i) >= 0.0) then
                    td(i) = 3.0*ud(i)
                    t(i) = 3.0*u(i)
                end if
            end if
            i = i + 5
            td(i) = 2.0*td(i)
            t(i) = 2.0*t(i) + 1.0
        end do
    end subroutine hand_jvp

end module tapenade_set01_lh059_hand
