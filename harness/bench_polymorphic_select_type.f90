program bench_polymorphic_select_type
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use polymorphic_field_models, only: field_model_t, linear_field_t, &
        quadratic_field_t
    use polymorphic_field_kernel, only: field_response
    use polymorphic_select_type_ad, only: field_response_jvp
    use polymorphic_select_type_hand, only: field_response_hand_jvp
    use polymorphic_select_type_reverse_ad, only: field_response_vjp
    use polymorphic_select_type_hand_reverse, only: field_response_hand_vjp
    implicit none

    integer, parameter :: repetitions = 5000000
    real(dp), parameter :: tolerance = 1.0e-13_dp
    type(linear_field_t) :: linear
    type(quadratic_field_t) :: quadratic
    real(dp) :: generated_jvp_seconds, hand_jvp_seconds
    real(dp) :: generated_vjp_seconds, hand_vjp_seconds
    real(dp) :: generated_jvp_sink, hand_jvp_sink
    real(dp) :: generated_vjp_sink, hand_vjp_sink

    linear%scale = 2.5_dp
    linear%offset = -0.75_dp
    quadratic%curvature = -1.2_dp
    quadratic%tilt = 0.8_dp

    call check_case(linear, 1.25_dp, -0.4_dp, 1.7_dp, 2.375_dp, -1.0_dp, &
        4.25_dp)
    call check_case(quadratic, 1.25_dp, -0.4_dp, 1.7_dp, -0.875_dp, &
        0.88_dp, -3.74_dp)

    call time_generated_jvp(linear, quadratic, generated_jvp_seconds, &
        generated_jvp_sink)
    call time_hand_jvp(linear, quadratic, hand_jvp_seconds, hand_jvp_sink)
    call time_generated_vjp(linear, quadratic, generated_vjp_seconds, &
        generated_vjp_sink)
    call time_hand_vjp(linear, quadratic, hand_vjp_seconds, hand_vjp_sink)
    call check_close("timed JVP sink", generated_jvp_sink, hand_jvp_sink, &
        1.0e-11_dp*max(1.0_dp, abs(hand_jvp_sink)))
    call check_close("timed VJP sink", generated_vjp_sink, hand_vjp_sink, &
        1.0e-11_dp*max(1.0_dp, abs(hand_vjp_sink)))

    print '(a,i0)', "dispatches_per_implementation ", 2*repetitions
    print '(a,es16.8)', "generated_jvp_seconds_per_dispatch ", &
        generated_jvp_seconds/real(2*repetitions, dp)
    print '(a,es16.8)', "hand_jvp_seconds_per_dispatch ", &
        hand_jvp_seconds/real(2*repetitions, dp)
    if (hand_jvp_seconds > 0.0_dp) then
        print '(a,es16.8)', "generated_over_hand_jvp_runtime ", &
            generated_jvp_seconds/hand_jvp_seconds
    end if
    print '(a,es16.8)', "generated_vjp_seconds_per_dispatch ", &
        generated_vjp_seconds/real(2*repetitions, dp)
    print '(a,es16.8)', "hand_vjp_seconds_per_dispatch ", &
        hand_vjp_seconds/real(2*repetitions, dp)
    if (hand_vjp_seconds > 0.0_dp) then
        print '(a,es16.8)', "generated_over_hand_vjp_runtime ", &
            generated_vjp_seconds/hand_vjp_seconds
    end if
    print '(a,es16.8)', "generated_jvp_sink ", generated_jvp_sink
    print '(a,es16.8)', "generated_vjp_sink ", generated_vjp_sink
    print '(a)', "PASS: both runtime children pass JVP, VJP, FD, and adjoint checks"

contains

    subroutine check_case(model, x, x_d, y_b, expected_y, expected_y_d, &
            expected_x_b)
        class(field_model_t), intent(in) :: model
        real(dp), intent(in) :: x, x_d, y_b
        real(dp), intent(in) :: expected_y, expected_y_d, expected_x_b
        real(dp) :: generated_y, generated_y_d, hand_y, hand_y_d
        real(dp) :: generated_vjp_y, generated_x_b, hand_vjp_y, hand_x_b
        real(dp) :: fd_derivative, h, y_minus, y_plus

        call field_response_jvp(model, x, x_d, generated_y, generated_y_d)
        call field_response_hand_jvp(model, x, x_d, hand_y, hand_y_d)
        call field_response_vjp(model, x, generated_vjp_y, y_b, generated_x_b)
        call field_response_hand_vjp(model, x, hand_vjp_y, y_b, hand_x_b)

        h = 1.0e-6_dp
        y_minus = field_response(model, x - h)
        y_plus = field_response(model, x + h)
        fd_derivative = (y_plus - y_minus)/(2.0_dp*h)

        call check_close("generated primal", generated_y, expected_y, tolerance)
        call check_close("generated JVP", generated_y_d, expected_y_d, tolerance)
        call check_close("hand primal", hand_y, expected_y, tolerance)
        call check_close("hand JVP", hand_y_d, expected_y_d, tolerance)
        call check_close("generated VJP primal", generated_vjp_y, expected_y, &
            tolerance)
        call check_close("generated VJP", generated_x_b, expected_x_b, tolerance)
        call check_close("hand VJP primal", hand_vjp_y, expected_y, tolerance)
        call check_close("hand VJP", hand_x_b, expected_x_b, tolerance)
        call check_close("VJP finite difference", generated_x_b, &
            y_b*fd_derivative, 1.0e-9_dp)
        call check_close("adjoint identity", y_b*generated_y_d, &
            x_d*generated_x_b, tolerance)
    end subroutine check_case

    subroutine check_close(label, actual, expected, allowed)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected, allowed

        if (.not. ieee_is_finite(actual) .or. &
            .not. ieee_is_finite(expected)) then
            print '(3a,2(1x,es24.16))', "FAIL: ", trim(label), &
                " non-finite actual or expected", actual, expected
            error stop 1
        end if
        if (abs(actual - expected) > allowed) then
            print '(3a,3(1x,es24.16))', "FAIL: ", trim(label), &
                " actual expected tolerance", actual, expected, allowed
            error stop 1
        end if
    end subroutine check_close

    subroutine time_generated_jvp(linear_model, quadratic_model, seconds, sink)
        type(linear_field_t), intent(in) :: linear_model
        type(quadratic_field_t), intent(in) :: quadratic_model
        real(dp), intent(out) :: seconds, sink
        class(field_model_t), allocatable :: model
        integer :: i
        integer(int64) :: count_rate, count_start, count_stop
        real(dp) :: x, y, y_d

        sink = 0.0_dp
        call system_clock(count_rate=count_rate)
        call system_clock(count_start)
        allocate (model, source=linear_model)
        do i = 1, repetitions
            x = 0.75_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call field_response_jvp(model, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
        end do
        deallocate (model)
        allocate (model, source=quadratic_model)
        do i = 1, repetitions
            x = 0.75_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call field_response_jvp(model, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
        end do
        call system_clock(count_stop)
        seconds = real(count_stop - count_start, dp)/real(count_rate, dp)
    end subroutine time_generated_jvp

    subroutine time_hand_jvp(linear_model, quadratic_model, seconds, sink)
        type(linear_field_t), intent(in) :: linear_model
        type(quadratic_field_t), intent(in) :: quadratic_model
        real(dp), intent(out) :: seconds, sink
        class(field_model_t), allocatable :: model
        integer :: i
        integer(int64) :: count_rate, count_start, count_stop
        real(dp) :: x, y, y_d

        sink = 0.0_dp
        call system_clock(count_rate=count_rate)
        call system_clock(count_start)
        allocate (model, source=linear_model)
        do i = 1, repetitions
            x = 0.75_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call field_response_hand_jvp(model, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
        end do
        deallocate (model)
        allocate (model, source=quadratic_model)
        do i = 1, repetitions
            x = 0.75_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call field_response_hand_jvp(model, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
        end do
        call system_clock(count_stop)
        seconds = real(count_stop - count_start, dp)/real(count_rate, dp)
    end subroutine time_hand_jvp

    subroutine time_generated_vjp(linear_model, quadratic_model, seconds, sink)
        type(linear_field_t), intent(in) :: linear_model
        type(quadratic_field_t), intent(in) :: quadratic_model
        real(dp), intent(out) :: seconds, sink
        class(field_model_t), allocatable :: model
        integer :: i
        integer(int64) :: count_rate, count_start, count_stop
        real(dp) :: x, x_b, y

        sink = 0.0_dp
        call system_clock(count_rate=count_rate)
        call system_clock(count_start)
        allocate (model, source=linear_model)
        do i = 1, repetitions
            x = 0.75_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call field_response_vjp(model, x, y, 0.125_dp, x_b)
            sink = sink + y + x_b
        end do
        deallocate (model)
        allocate (model, source=quadratic_model)
        do i = 1, repetitions
            x = 0.75_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call field_response_vjp(model, x, y, 0.125_dp, x_b)
            sink = sink + y + x_b
        end do
        call system_clock(count_stop)
        seconds = real(count_stop - count_start, dp)/real(count_rate, dp)
    end subroutine time_generated_vjp

    subroutine time_hand_vjp(linear_model, quadratic_model, seconds, sink)
        type(linear_field_t), intent(in) :: linear_model
        type(quadratic_field_t), intent(in) :: quadratic_model
        real(dp), intent(out) :: seconds, sink
        class(field_model_t), allocatable :: model
        integer :: i
        integer(int64) :: count_rate, count_start, count_stop
        real(dp) :: x, x_b, y

        sink = 0.0_dp
        call system_clock(count_rate=count_rate)
        call system_clock(count_start)
        allocate (model, source=linear_model)
        do i = 1, repetitions
            x = 0.75_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call field_response_hand_vjp(model, x, y, 0.125_dp, x_b)
            sink = sink + y + x_b
        end do
        deallocate (model)
        allocate (model, source=quadratic_model)
        do i = 1, repetitions
            x = 0.75_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call field_response_hand_vjp(model, x, y, 0.125_dp, x_b)
            sink = sink + y + x_b
        end do
        call system_clock(count_stop)
        seconds = real(count_stop - count_start, dp)/real(count_rate, dp)
    end subroutine time_hand_vjp
end program bench_polymorphic_select_type
