module enzyme_study_kernels
    use, intrinsic :: iso_c_binding, only: c_double, c_int
    implicit none

contains

    function sigmoid(a) result(y) bind(C)
        real(c_double), value, intent(in) :: a
        real(c_double) :: y

        y = 1.0_c_double/(1.0_c_double + exp(-a))
    end function sigmoid

    function lstm_objective(m, z) result(y) bind(C)
        integer(c_int), value, intent(in) :: m
        real(c_double), intent(in) :: z(*)
        real(c_double) :: cell, change, forget, hidden, ingate, outgate, y
        integer :: i

        cell = 0.2_c_double
        hidden = -0.1_c_double
        y = 0.0_c_double
        do i = 1, m
            forget = sigmoid(0.7_c_double*z(i) + 0.2_c_double)
            ingate = sigmoid(-0.4_c_double*hidden + 0.1_c_double)
            outgate = sigmoid(0.5_c_double*z(i) - 0.3_c_double)
            change = tanh(0.8_c_double*hidden + 0.6_c_double*z(i))
            cell = cell*forget + ingate*change
            hidden = outgate*tanh(cell)
            y = y + log(2.0_c_double + exp(hidden)) - 0.1_c_double*hidden
        end do
        y = y/real(m, c_double)
    end function lstm_objective

    function ba_objective(m, z) result(y) bind(C)
        integer(c_int), value, intent(in) :: m
        real(c_double), intent(in) :: z(*)
        real(c_double) :: costheta, cross1, cross2, cross3, distortion
        real(c_double) :: px, py, pz, qx, qy, qz, radius2, sintheta
        real(c_double) :: theta, wx, wy, wz, y
        integer :: i, j

        wx = 0.03_c_double
        wy = -0.04_c_double
        wz = 0.02_c_double
        theta = sqrt(wx*wx + wy*wy + wz*wz)
        costheta = cos(theta)
        sintheta = sin(theta)
        wx = wx/theta
        wy = wy/theta
        wz = wz/theta
        y = 0.0_c_double
        do i = 1, m
            j = 3*(i - 1)
            px = z(j + 1) - 0.1_c_double
            py = z(j + 2) + 0.2_c_double
            pz = z(j + 3) + 3.0_c_double
            cross1 = wy*pz - wz*py
            cross2 = wz*px - wx*pz
            cross3 = wx*py - wy*px
            qx = px*costheta + cross1*sintheta &
                + wx*(wx*px + wy*py + wz*pz)*(1.0_c_double - costheta)
            qy = py*costheta + cross2*sintheta &
                + wy*(wx*px + wy*py + wz*pz)*(1.0_c_double - costheta)
            qz = pz*costheta + cross3*sintheta &
                + wz*(wx*px + wy*py + wz*pz)*(1.0_c_double - costheta)
            qx = qx/qz
            qy = qy/qz
            radius2 = qx*qx + qy*qy
            distortion = 1.0_c_double + 0.01_c_double*radius2 &
                - 0.001_c_double*radius2*radius2
            qx = 800.0_c_double*qx*distortion + 320.0_c_double
            qy = 800.0_c_double*qy*distortion + 240.0_c_double
            y = y + (qx - 321.0_c_double)**2 + (qy - 239.0_c_double)**2
        end do
        y = y/real(m, c_double)
    end function ba_objective

    function gmm_objective(m, z) result(y) bind(C)
        integer(c_int), value, intent(in) :: m
        real(c_double), intent(in) :: z(*)
        real(c_double) :: centered, component, maximum, total, y
        real(c_double) :: terms(4)
        integer :: d, i, j, k

        d = 4
        y = 0.0_c_double
        do i = 1, m
            do k = 1, 4
                total = 0.0_c_double
                do j = 1, d
                    centered = z((i - 1)*d + j) &
                        - 0.15_c_double*real(k - 2, c_double)*real(j, c_double)
                    total = total + exp(0.02_c_double*real(j*k, c_double)) &
                        *centered*centered
                end do
                terms(k) = 0.1_c_double*real(k - 2, c_double) - 0.5_c_double*total
            end do
            maximum = max(terms(1), max(terms(2), max(terms(3), terms(4))))
            component = 0.0_c_double
            do k = 1, 4
                component = component + exp(terms(k) - maximum)
            end do
            y = y + log(component) + maximum
        end do
        y = -y/real(m, c_double)
    end function gmm_objective

    function euler_objective(m, z) result(y) bind(C)
        integer(c_int), value, intent(in) :: m
        real(c_double), intent(in) :: z(*)
        real(c_double) :: dt, state, y
        integer :: i

        dt = 2.1_c_double/real(m, c_double)
        state = 1.0_c_double
        do i = 1, m
            state = state + dt*(-1.2_c_double*state + 0.05_c_double*z(i))
        end do
        y = state
    end function euler_objective

    function rk4_objective(m, z) result(y) bind(C)
        integer(c_int), value, intent(in) :: m
        real(c_double), intent(in) :: z(*)
        real(c_double) :: dt, k1, k2, k3, k4, state, y
        integer :: i

        dt = 2.1_c_double/real(m, c_double)
        state = 1.0_c_double
        do i = 1, m
            k1 = -1.2_c_double*state + 0.05_c_double*z(i)
            k2 = -1.2_c_double*(state + 0.5_c_double*dt*k1) &
                + 0.05_c_double*z(i)
            k3 = -1.2_c_double*(state + 0.5_c_double*dt*k2) &
                + 0.05_c_double*z(i)
            k4 = -1.2_c_double*(state + dt*k3) + 0.05_c_double*z(i)
            state = state + dt*(k1 + 2.0_c_double*k2 &
                + 2.0_c_double*k3 + k4)/6.0_c_double
        end do
        y = state
    end function rk4_objective

    function fft_objective(m, z) result(y) bind(C)
        integer(c_int), value, intent(in) :: m
        real(c_double), intent(inout) :: z(*)
        real(c_double) :: angle, ai, ar, bi, br, ti, tr, y
        integer :: half, i, j, span

        span = 2
        do while (span <= m)
            half = span/2
            do i = 1, m, span
                do j = 0, half - 1
                    angle = -2.0_c_double*acos(-1.0_c_double) &
                        *real(j, c_double)/real(span, c_double)
                    ar = z(i + j)
                    ai = z(m + i + j)
                    br = z(i + j + half)
                    bi = z(m + i + j + half)
                    tr = cos(angle)*br - sin(angle)*bi
                    ti = sin(angle)*br + cos(angle)*bi
                    z(i + j) = ar + tr
                    z(m + i + j) = ai + ti
                    z(i + j + half) = ar - tr
                    z(m + i + j + half) = ai - ti
                end do
            end do
            span = 2*span
        end do
        y = 0.0_c_double
        do i = 1, m
            y = y + log(1.0_c_double + z(i)*z(i) + z(m + i)*z(m + i))
        end do
        y = y/real(m, c_double)

        span = m
        do while (span >= 2)
            half = span/2
            do i = 1, m, span
                do j = 0, half - 1
                    angle = 2.0_c_double*acos(-1.0_c_double) &
                        *real(j, c_double)/real(span, c_double)
                    ar = z(i + j)
                    ai = z(m + i + j)
                    br = z(i + j + half)
                    bi = z(m + i + j + half)
                    tr = 0.5_c_double*(ar + br)
                    ti = 0.5_c_double*(ai + bi)
                    br = 0.5_c_double*(ar - br)
                    bi = 0.5_c_double*(ai - bi)
                    z(i + j) = tr
                    z(m + i + j) = ti
                    z(i + j + half) = cos(angle)*br - sin(angle)*bi
                    z(m + i + j + half) = sin(angle)*br + cos(angle)*bi
                end do
            end do
            span = span/2
        end do
    end function fft_objective

    function brusselator_objective(m, z) result(y) bind(C)
        integer(c_int), value, intent(in) :: m
        real(c_double), intent(in) :: z(*)
        real(c_double) :: alpha, du, dv, u, u2v, v, y
        integer :: i, im, ip, j, jm, jp, p

        alpha = 0.01_c_double*real((m - 1)*(m - 1), c_double)
        y = 0.0_c_double
        do i = 1, m
            im = max(1, i - 1)
            ip = min(m, i + 1)
            do j = 1, m
                jm = max(1, j - 1)
                jp = min(m, j + 1)
                p = (i - 1)*m + j
                u = z(p)
                v = z(m*m + p)
                u2v = u*u*v
                du = alpha*(z((im - 1)*m + j) + z((ip - 1)*m + j) &
                    + z((i - 1)*m + jm) + z((i - 1)*m + jp) &
                    - 4.0_c_double*u) + 1.0_c_double + u2v - 4.4_c_double*u
                dv = alpha*(z(m*m + (im - 1)*m + j) &
                    + z(m*m + (ip - 1)*m + j) &
                    + z(m*m + (i - 1)*m + jm) &
                    + z(m*m + (i - 1)*m + jp) - 4.0_c_double*v) &
                    + 3.4_c_double*u - u2v
                y = y + du*du + dv*dv
            end do
        end do
        y = y/real(m*m, c_double)
    end function brusselator_objective

end module enzyme_study_kernels

subroutine enzyme_study_objective(workload, n, length, x, value) bind(C)
    use, intrinsic :: iso_c_binding, only: c_double, c_int
    use enzyme_study_kernels, only: ba_objective, brusselator_objective, &
        euler_objective, fft_objective, gmm_objective, lstm_objective, &
        rk4_objective
    implicit none

    integer(c_int), value, intent(in) :: workload, n, length
    real(c_double), intent(inout) :: x(length)
    real(c_double), intent(out) :: value

    select case (workload)
    case (1)
        value = lstm_objective(n, x)
    case (2)
        value = ba_objective(n, x)
    case (3)
        value = gmm_objective(n, x)
    case (4)
        value = euler_objective(n, x)
    case (5)
        value = rk4_objective(n, x)
    case (6)
        value = fft_objective(n, x)
    case (7)
        value = brusselator_objective(n, x)
    case default
        value = 0.0_c_double
    end select
end subroutine enzyme_study_objective
