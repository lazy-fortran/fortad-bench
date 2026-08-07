! Independent hand derivative for the bounded lh060 callback specialization.
module tapenade_set01_lh060_hand
    implicit none
contains
    subroutine set01_lh060_hand(neq, y, savf, tn, c3, c4, yd, savfd, tnd, &
                                yd_out, savfd_out, tnd_out)
        integer, intent(in) :: neq
        real, intent(in) :: y, savf, tn, c3, c4
        real, intent(in) :: yd, savfd, tnd
        real, intent(out) :: yd_out, savfd_out, tnd_out
        real :: y1, s1, t1, y1d, s1d, t1d

        s1 = savf + c3*tn + 0.5d0*y + real(neq, kind=8)
        s1d = savfd + c3*tnd + 0.5d0*yd
        t1 = tn + 0.1d0*c3*y
        t1d = tnd + 0.1d0*c3*yd

        y1 = y + c4*s1 + t1 + 0.25d0*c3
        y1d = yd + c4*s1d + t1d
        t1d = t1d + 0.05d0*c4*s1d
        t1 = t1 + 0.05d0*c4*s1

        savfd_out = s1d + c3*t1d + 0.5d0*y1d
        s1 = s1 + c3*t1 + 0.5d0*y1 + real(neq, kind=8)
        tnd_out = t1d + 0.1d0*c3*y1d
        yd_out = y1d
    end subroutine set01_lh060_hand
end module tapenade_set01_lh060_hand
