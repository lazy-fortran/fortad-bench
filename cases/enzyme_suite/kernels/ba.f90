subroutine ba(n, z, y)
    integer, intent(in) :: n
    real(8), intent(in) :: z(3*n)
    real(8), intent(out) :: y
    real(8) :: costheta, cross1, cross2, cross3, distortion
    real(8) :: px, py, pz, qx, qy, qz, radius2, sintheta
    real(8) :: theta, wx, wy, wz, dot
    integer :: i, j
    wx = 0.03d0
    wy = -0.04d0
    wz = 0.02d0
    theta = sqrt(wx*wx + wy*wy + wz*wz)
    costheta = cos(theta)
    sintheta = sin(theta)
    wx = wx/theta
    wy = wy/theta
    wz = wz/theta
    y = 0.0d0
    do i = 1, n
        j = 3*(i - 1)
        px = z(j + 1) - 0.1d0
        py = z(j + 2) + 0.2d0
        pz = z(j + 3) + 3.0d0
        cross1 = wy*pz - wz*py
        cross2 = wz*px - wx*pz
        cross3 = wx*py - wy*px
        dot = wx*px + wy*py + wz*pz
        qx = px*costheta + cross1*sintheta + wx*dot*(1.0d0 - costheta)
        qy = py*costheta + cross2*sintheta + wy*dot*(1.0d0 - costheta)
        qz = pz*costheta + cross3*sintheta + wz*dot*(1.0d0 - costheta)
        qx = qx/qz
        qy = qy/qz
        radius2 = qx*qx + qy*qy
        distortion = 1.0d0 + 0.01d0*radius2 - 0.001d0*radius2*radius2
        qx = 800.0d0*qx*distortion + 320.0d0
        qy = 800.0d0*qy*distortion + 240.0d0
        y = y + (qx - 321.0d0)**2 + (qy - 239.0d0)**2
    end do
    y = y/real(n, 8)
end subroutine ba
