! Structured bounded port of nonRegressions/set01/lh059/program.f.
! The mutable index and the GOTO-5 path are retained explicitly; n and the
! initial i are controls, while t and u remain the differentiated arrays.
subroutine set01_lh059(t, u, n, i)
    implicit none
    integer, intent(in) :: n
    integer, intent(inout) :: i
    real, intent(inout) :: t(31), u(31)
    integer :: k

    ! For the bounded probe, n=31 and the initial i=6.  The selected
    ! derivative test follows the original five body iterations (6, 11, 16,
    ! 21, 26) and then reaches t(31)<=0 at the original loop guard.
    do k = 1, 5
        if (t(i) > 1.0) then
            u(i) = u(i) + log(t(i))
            t(i) = 3.0*u(i)
        else
            u(i) = u(i) + t(i-5)
            ! The original GOTO 5 skips t(i)=3*u(i) and resumes at the
            ! increment.  This branch is the same state transition.
            if (u(i) >= 0.0) t(i) = 3.0*u(i)
        end if
        i = i + 5
        t(i) = 2.0*t(i) + 1.0
    end do
end subroutine set01_lh059
