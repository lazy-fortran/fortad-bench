! Hand-derived JVP. This is the ceiling, not a competitor: no AD tool should
! beat a correct hand-written tangent, and any tool that loses badly to it is
! leaving performance on the table.
subroutine dot_sin_jvp_analytical(n, a, a_d, b, b_d, s, s_d)
    implicit none
    integer, intent(in) :: n
    real(8), intent(in) :: a(n), a_d(n), b(n), b_d(n)
    real(8), intent(out) :: s, s_d
    integer :: i
    real(8) :: sb, cb

    s = 0.0d0
    s_d = 0.0d0
    do i = 1, n
        sb = sin(b(i))
        cb = cos(b(i))
        s = s + a(i)*sb
        s_d = s_d + a_d(i)*sb + a(i)*cb*b_d(i)
    end do
end subroutine dot_sin_jvp_analytical
