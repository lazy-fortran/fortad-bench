! Copyright (©) 1999-2021 INRIA
! Tapenade source/port; MIT license in LICENSES/Tapenade-MIT.txt.
subroutine set01_lh054(n, m, lrhs, lbn, b, bpm, pp)
    implicit none
    integer, intent(in) :: n, m, lrhs, lbn, pp
    real(8), intent(inout) :: b(:)
    real(8), intent(in) :: bpm(:, :)

    b(1) = 2.0d0 * b(1)
end subroutine set01_lh054
