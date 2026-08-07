program bench_tapenade_set01_lh041
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use tapenade_set01_lh041_case, only: set01_lh041
    use lh041_forward_mod, only: generated_jvp => lh041_forward
    implicit none

    real(dp), parameter :: a = 0.7_dp, b = -0.2_dp, q = 0.6_dp
    real(dp), parameter :: ad = -0.04_dp, bd = 0.03_dp, qd = 0.02_dp
    real(dp), parameter :: h = 1.0e-5_dp
    real(dp) :: value, value_d, value_hand, value_p, value_m, fd

    call set01_lh041(a, b, q, value_hand)
    call generated_jvp(a, ad, b, bd, q, qd, value, value_d)
    call set01_lh041(a + h*ad, b + h*bd, q + h*qd, value_p)
    call set01_lh041(a - h*ad, b - h*bd, q - h*qd, value_m)
    fd = (value_p - value_m)/(2.0_dp*h)

    call check_close("generated primal", value, value_hand, 1.0e-12_dp)
    call check_close("generated jvp vs finite difference", value_d, fd, 2.0e-8_dp)
    write (*, '(a)') "oracle_status: pass"
    write (*, '(a,es24.16)') "primal: ", value
    write (*, '(a,es24.16)') "jvp: ", value_d
    write (*, '(a,es24.16)') "fd_error: ", abs(value_d - fd)

contains
    subroutine check_close(label, actual, expected, tolerance)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected, tolerance
        if (abs(actual - expected) > tolerance) then
            write (*, '(a,2(1x,es24.16))') trim(label), actual, expected
            error stop "lh041 numerical contract failed"
        end if
    end subroutine check_close
end program bench_tapenade_set01_lh041
