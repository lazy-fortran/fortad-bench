program tapenade_set01_lh037_harness
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use tapenade_set01_lh037_hand, only: lh037_hand_jvp, lh037_hand_vjp
    use lh037_forward_ad, only: set01_lh037_d => lh037_forward
    use lh037_reverse_a_ad, only: set01_lh037_b_a => lh037_reverse_a
    use lh037_reverse_b_ad, only: set01_lh037_b_b => lh037_reverse_b
    use lh037_reverse_c_ad, only: set01_lh037_b_c => lh037_reverse_c
    implicit none

    real(dp) :: a, b, c, ad, bd, cd
    real(dp) :: a0, b0, c0, a0_d, b0_d, c0_d
    real(dp) :: a_bar, b_bar, c_bar, a0_bar, b0_bar, c0_bar
    real(dp) :: a_hand, b_hand, c_hand
    real(dp) :: a_hand_d, b_hand_d, c_hand_d
    real(dp) :: a_hand_v, b_hand_v, c_hand_v
    real(dp) :: tolerance

    a0 = 1.25_dp
    b0 = 10.75_dp
    c0 = 1.5_dp
    a0_d = -0.3_dp
    b0_d = 0.2_dp
    c0_d = 0.4_dp
    a_bar = 0.7_dp
    b_bar = -0.2_dp
    c_bar = 0.5_dp
    tolerance = 5.0e-12_dp

    call lh037_hand_jvp(a0, a0_d, b0, b0_d, c0, c0_d, &
        a_hand, a_hand_d, b_hand, b_hand_d, c_hand, c_hand_d)
    call lh037_hand_vjp(a0, b0, c0, a_bar, b_bar, c_bar, &
        a_hand_v, b_hand_v, c_hand_v, a0_bar, b0_bar, c0_bar)

    call set01_lh037_d(a0, a0_d, b0, b0_d, c0, c0_d, a, ad, b, bd, c, cd)
    call assert_close('forward a', a, a_hand, tolerance)
    call assert_close('forward b', b, b_hand, tolerance)
    call assert_close('forward c', c, c_hand, tolerance)
    call assert_close('forward ad', ad, a_hand_d, tolerance)
    call assert_close('forward bd', bd, b_hand_d, tolerance)
    call assert_close('forward cd', cd, c_hand_d, tolerance)

    call set01_lh037_b_a(a0, b0, c0, a, b, c, a_bar, ad, bd, cd)
    call assert_close('reverse-a a', a, a_hand_v, tolerance)
    call assert_close('reverse-a a0_bar', ad, 8.0_dp*a_bar, tolerance)
    call assert_close('reverse-a b0_bar', bd, 8.0_dp*a_bar + 0.0_dp, tolerance)
    call assert_close('reverse-a c0_bar', cd, 0.0_dp, tolerance)

    call set01_lh037_b_b(a0, b0, c0, a, b, c, b_bar, ad, bd, cd)
    call assert_close('reverse-b b', b, b_hand_v, tolerance)
    call assert_close('reverse-b a0_bar', ad, 0.0_dp, tolerance)
    call assert_close('reverse-b b0_bar', bd, b_bar, tolerance)
    call assert_close('reverse-b c0_bar', cd, -b_bar, tolerance)

    call set01_lh037_b_c(a0, b0, c0, a, b, c, c_bar, ad, bd, cd)
    call assert_close('reverse-c c', c, c_hand_v, tolerance)
    call assert_close('reverse-c a0_bar', ad, 2.0_dp*(b0-c0)*c_bar, tolerance)
    call assert_close('reverse-c b0_bar', bd, 2.0_dp*((b0-c0) + (a0+b0+25.5_dp))*c_bar, tolerance)
    call assert_close('reverse-c c0_bar', cd, -2.0_dp*(a0+b0+25.5_dp)*c_bar, tolerance)

    print '(a)', 'oracle_status: pass'

contains

    subroutine assert_close(label, actual, expected, eps)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected, eps
        if (abs(actual - expected) > eps) then
            write(*, '(a,1x,a,1x,es24.16,1x,es24.16)') 'mismatch:', trim(label), actual, expected
            error stop 1
        end if
    end subroutine assert_close

end program tapenade_set01_lh037_harness
