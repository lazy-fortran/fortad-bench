module tapenade_set01_lh034_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: lh034_hand_jvp, lh034_hand_vjp

contains

    pure function callback(value) result(output)
        real(dp), intent(in) :: value
        real(dp) :: output

        output = value*value + 0.25_dp*value
    end function callback

    subroutine lh034_hand_jvp(a0, a0_d, b0, b0_d, x, n, root, root_d)
        real(dp), intent(in) :: a0, a0_d, b0, b0_d, x
        integer, intent(in) :: n
        real(dp), intent(out) :: root, root_d
        real(dp) :: a, a_d, b, b_d, m, m_d
        integer :: i

        a = a0
        a_d = a0_d
        b = b0
        b_d = b0_d
        do i = 1, n
            m = (a + b)/2.0_dp
            m_d = (a_d + b_d)/2.0_dp
            if ((callback(a) - x)*(callback(m) - x) <= 0.0_dp) then
                b = m
                b_d = m_d
            else
                a = m
                a_d = m_d
            end if
        end do
        root = (a + b)/2.0_dp
        root_d = (a_d + b_d)/2.0_dp
    end subroutine lh034_hand_jvp

    subroutine lh034_hand_vjp(a0, b0, x, n, root, root_b, a0_b, b0_b)
        real(dp), intent(in) :: a0, b0, x, root_b
        integer, intent(in) :: n
        real(dp), intent(out) :: root, a0_b, b0_b
        logical, allocatable :: upper_history(:)
        real(dp) :: a, b, m, a_b, b_b, m_b
        integer :: i

        allocate(upper_history(n))
        a = a0
        b = b0
        do i = 1, n
            m = (a + b)/2.0_dp
            if ((callback(a) - x)*(callback(m) - x) <= 0.0_dp) then
                upper_history(i) = .true.
                b = m
            else
                upper_history(i) = .false.
                a = m
            end if
        end do
        root = (a + b)/2.0_dp

        a_b = root_b/2.0_dp
        b_b = root_b/2.0_dp
        do i = n, 1, -1
            if (upper_history(i)) then
                m_b = b_b
                b_b = 0.0_dp
            else
                m_b = a_b
                a_b = 0.0_dp
            end if
            a_b = a_b + m_b/2.0_dp
            b_b = b_b + m_b/2.0_dp
        end do
        a0_b = a_b
        b0_b = b_b
        deallocate(upper_history)
    end subroutine lh034_hand_vjp

end module tapenade_set01_lh034_hand
