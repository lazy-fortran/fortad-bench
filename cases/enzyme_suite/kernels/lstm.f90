subroutine lstm(n, z, y)
    integer, intent(in) :: n
    real(8), intent(in) :: z(n)
    real(8), intent(out) :: y
    real(8) :: cell, change, forget, hidden, ingate, outgate
    integer :: i
    cell = 0.2d0
    hidden = -0.1d0
    y = 0.0d0
    do i = 1, n
        forget = 1.0d0/(1.0d0 + exp(-(0.7d0*z(i) + 0.2d0)))
        ingate = 1.0d0/(1.0d0 + exp(-(-0.4d0*hidden + 0.1d0)))
        outgate = 1.0d0/(1.0d0 + exp(-(0.5d0*z(i) - 0.3d0)))
        change = tanh(0.8d0*hidden + 0.6d0*z(i))
        cell = cell*forget + ingate*change
        hidden = outgate*tanh(cell)
        y = y + log(2.0d0 + exp(hidden)) - 0.1d0*hidden
    end do
    y = y/real(n, 8)
end subroutine lstm
