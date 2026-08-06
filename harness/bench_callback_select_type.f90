program bench_callback_select_type
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    use callback_select_type_models, only: callback_model_t, &
        linear_callback_t, quadratic_callback_t
    use callback_select_type_ad, only: evaluate_callback_jvp
    use callback_select_type_hand, only: evaluate_callback_hand_jvp
    implicit none

    integer, parameter :: repetitions = 5000000
    real(dp), parameter :: tolerance = 1.0e-13_dp
    type(linear_callback_t) :: linear
    type(quadratic_callback_t) :: quadratic
    real(dp) :: generated_seconds, hand_seconds
    real(dp) :: generated_sink, hand_sink

    linear%scale = 2.5_dp
    linear%shift = -0.75_dp
    quadratic%curvature = -1.2_dp
    quadratic%tilt = 0.8_dp

    call check_case(linear, 1.25_dp, -0.4_dp, 2.375_dp, -1.0_dp)
    call check_case(quadratic, 1.25_dp, -0.4_dp, -0.875_dp, 0.88_dp)

    call time_generated(linear, quadratic, generated_seconds, generated_sink)
    call time_hand(linear, quadratic, hand_seconds, hand_sink)
    call check_close("timed sink", generated_sink, hand_sink, &
        1.0e-11_dp*max(1.0_dp, abs(hand_sink)))

    print '(a,i0)', "dispatches_per_implementation ", 2*repetitions
    print '(a,es16.8)', "generated_seconds_per_dispatch ", &
        generated_seconds/real(2*repetitions, dp)
    print '(a,es16.8)', "hand_seconds_per_dispatch ", &
        hand_seconds/real(2*repetitions, dp)
    if (hand_seconds > 0.0_dp) then
        print '(a,es16.8)', "generated_over_hand_runtime ", &
            generated_seconds/hand_seconds
    end if
    print '(a,es16.8)', "generated_sink ", generated_sink
    print '(a)', &
        "PASS: explicit SELECT TYPE callback JVPs match hand derivatives"

contains

    subroutine check_case(callback, x, x_d, expected_y, expected_y_d)
        class(callback_model_t), intent(in) :: callback
        real(dp), intent(in) :: x, x_d, expected_y, expected_y_d
        real(dp) :: generated_y, generated_y_d, hand_y, hand_y_d

        call evaluate_callback_jvp(callback, x, x_d, generated_y, generated_y_d)
        call evaluate_callback_hand_jvp(callback, x, x_d, hand_y, hand_y_d)
        call check_close("generated primal", generated_y, expected_y, tolerance)
        call check_close("generated JVP", generated_y_d, expected_y_d, tolerance)
        call check_close("hand primal", hand_y, expected_y, tolerance)
        call check_close("hand JVP", hand_y_d, expected_y_d, tolerance)
    end subroutine check_case

    subroutine check_close(label, actual, expected, allowed)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected, allowed

        if (abs(actual - expected) > allowed) then
            print '(3a,3(1x,es24.16))', "FAIL: ", trim(label), &
                " actual expected tolerance", actual, expected, allowed
            error stop 1
        end if
    end subroutine check_close

    subroutine time_generated(linear_callback, quadratic_callback, seconds, sink)
        type(linear_callback_t), intent(in) :: linear_callback
        type(quadratic_callback_t), intent(in) :: quadratic_callback
        real(dp), intent(out) :: seconds, sink
        integer :: i
        integer(int64) :: count_rate, count_start, count_stop
        real(dp) :: x, y, y_d

        sink = 0.0_dp
        call system_clock(count_rate=count_rate)
        call system_clock(count_start)
        do i = 1, repetitions
            x = 0.75_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call evaluate_callback_jvp(linear_callback, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
            call evaluate_callback_jvp(quadratic_callback, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
        end do
        call system_clock(count_stop)
        seconds = real(count_stop - count_start, dp)/real(count_rate, dp)
    end subroutine time_generated

    subroutine time_hand(linear_callback, quadratic_callback, seconds, sink)
        type(linear_callback_t), intent(in) :: linear_callback
        type(quadratic_callback_t), intent(in) :: quadratic_callback
        real(dp), intent(out) :: seconds, sink
        integer :: i
        integer(int64) :: count_rate, count_start, count_stop
        real(dp) :: x, y, y_d

        sink = 0.0_dp
        call system_clock(count_rate=count_rate)
        call system_clock(count_start)
        do i = 1, repetitions
            x = 0.75_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call evaluate_callback_hand_jvp(linear_callback, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
            call evaluate_callback_hand_jvp(quadratic_callback, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
        end do
        call system_clock(count_stop)
        seconds = real(count_stop - count_start, dp)/real(count_rate, dp)
    end subroutine time_hand
end program bench_callback_select_type
