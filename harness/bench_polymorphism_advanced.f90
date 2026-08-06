program bench_polymorphism_advanced
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    use class_is_models, only: response_t, scaled_leaf_t, fallback_response_t
    use class_is_default_ad, only: evaluate_hierarchy_jvp
    use class_is_default_hand, only: evaluate_hierarchy_hand_jvp
    use factory_profile_models, only: profile_t, make_profile
    use factory_allocatable_ad, only: evaluate_profile_jvp
    use factory_allocatable_hand, only: evaluate_profile_hand_jvp
    implicit none

    integer, parameter :: repetitions = 5000000
    real(dp), parameter :: tolerance = 1.0e-13_dp
    type(scaled_leaf_t) :: scaled
    type(fallback_response_t) :: fallback
    class(profile_t), allocatable :: profile
    real(dp) :: class_generated_seconds, class_hand_seconds
    real(dp) :: class_generated_sink, class_hand_sink
    real(dp) :: factory_generated_seconds, factory_hand_seconds
    real(dp) :: factory_generated_sink, factory_hand_sink

    scaled%scale = 2.75_dp
    scaled%leaf_offset = 100.0_dp
    fallback%passive_tag = 7.0_dp

    call check_hierarchy(scaled, 1.2_dp, -0.3_dp, 3.3_dp, -0.825_dp)
    call check_hierarchy(fallback, 1.2_dp, -0.3_dp, 1.19_dp, -0.72_dp)

    call make_profile(1, 1.75_dp, -0.5_dp, profile)
    call check_profile(profile, 1.4_dp, -0.25_dp, 1.95_dp, -0.4375_dp)
    call make_profile(2, -0.8_dp, 0.6_dp, profile)
    call check_profile(profile, 1.4_dp, -0.25_dp, -0.728_dp, 0.41_dp)

    call time_class_generated(scaled, fallback, class_generated_seconds, &
        class_generated_sink)
    call time_class_hand(scaled, fallback, class_hand_seconds, class_hand_sink)
    call check_close("CLASS IS timed sink", class_generated_sink, &
        class_hand_sink, &
        1.0e-11_dp*max(1.0_dp, abs(class_hand_sink)))

    call time_factory_generated(factory_generated_seconds, factory_generated_sink)
    call time_factory_hand(factory_hand_seconds, factory_hand_sink)
    call check_close("factory timed sink", factory_generated_sink, &
        factory_hand_sink, &
        1.0e-11_dp*max(1.0_dp, abs(factory_hand_sink)))

    print '(a,i0)', "class_is_dispatches_per_implementation ", 2*repetitions
    print '(a,es16.8)', "class_is_generated_seconds_per_dispatch ", &
        class_generated_seconds/real(2*repetitions, dp)
    print '(a,es16.8)', "class_is_hand_seconds_per_dispatch ", &
        class_hand_seconds/real(2*repetitions, dp)
    if (class_hand_seconds > 0.0_dp) then
        print '(a,es16.8)', "class_is_generated_over_hand_runtime ", &
            class_generated_seconds/class_hand_seconds
    end if
    print '(a,es16.8)', "class_is_generated_sink ", class_generated_sink

    print '(a,i0)', "factory_dispatches_per_implementation ", 2*repetitions
    print '(a,es16.8)', "factory_generated_seconds_per_dispatch ", &
        factory_generated_seconds/real(2*repetitions, dp)
    print '(a,es16.8)', "factory_hand_seconds_per_dispatch ", &
        factory_hand_seconds/real(2*repetitions, dp)
    if (factory_hand_seconds > 0.0_dp) then
        print '(a,es16.8)', "factory_generated_over_hand_runtime ", &
            factory_generated_seconds/factory_hand_seconds
    end if
    print '(a,es16.8)', "factory_generated_sink ", factory_generated_sink
    print '(a)', "PASS: CLASS IS/default and factory JVPs match hand derivatives"

contains

    subroutine check_hierarchy(model, x, x_d, expected_y, expected_y_d)
        class(response_t), intent(in) :: model
        real(dp), intent(in) :: x, x_d, expected_y, expected_y_d
        real(dp) :: generated_y, generated_y_d, hand_y, hand_y_d

        call evaluate_hierarchy_jvp(model, x, x_d, generated_y, generated_y_d)
        call evaluate_hierarchy_hand_jvp(model, x, x_d, hand_y, hand_y_d)
        call check_close("CLASS IS generated primal", generated_y, &
            expected_y, tolerance)
        call check_close("CLASS IS generated JVP", generated_y_d, &
            expected_y_d, tolerance)
        call check_close("CLASS IS hand primal", hand_y, expected_y, tolerance)
        call check_close("CLASS IS hand JVP", hand_y_d, expected_y_d, tolerance)
    end subroutine check_hierarchy

    subroutine check_profile(model, x, x_d, expected_y, expected_y_d)
        class(profile_t), intent(in) :: model
        real(dp), intent(in) :: x, x_d, expected_y, expected_y_d
        real(dp) :: generated_y, generated_y_d, hand_y, hand_y_d

        call evaluate_profile_jvp(model, x, x_d, generated_y, generated_y_d)
        call evaluate_profile_hand_jvp(model, x, x_d, hand_y, hand_y_d)
        call check_close("factory generated primal", generated_y, &
            expected_y, tolerance)
        call check_close("factory generated JVP", generated_y_d, &
            expected_y_d, tolerance)
        call check_close("factory hand primal", hand_y, expected_y, tolerance)
        call check_close("factory hand JVP", hand_y_d, expected_y_d, tolerance)
    end subroutine check_profile

    subroutine check_close(label, actual, expected, allowed)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected, allowed

        if (abs(actual - expected) > allowed) then
            print '(3a,3(1x,es24.16))', "FAIL: ", trim(label), &
                " actual expected tolerance", actual, expected, allowed
            error stop 1
        end if
    end subroutine check_close

    subroutine time_class_generated(scaled_model, fallback_model, seconds, sink)
        type(scaled_leaf_t), intent(in) :: scaled_model
        type(fallback_response_t), intent(in) :: fallback_model
        real(dp), intent(out) :: seconds, sink
        class(response_t), allocatable :: model
        integer :: i
        integer(int64) :: count_rate, count_start, count_stop
        real(dp) :: x, y, y_d

        sink = 0.0_dp
        call system_clock(count_rate=count_rate)
        call system_clock(count_start)
        allocate (model, source=scaled_model)
        do i = 1, repetitions
            x = 0.65_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call evaluate_hierarchy_jvp(model, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
        end do
        deallocate (model)
        allocate (model, source=fallback_model)
        do i = 1, repetitions
            x = 0.65_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call evaluate_hierarchy_jvp(model, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
        end do
        call system_clock(count_stop)
        seconds = real(count_stop - count_start, dp)/real(count_rate, dp)
    end subroutine time_class_generated

    subroutine time_class_hand(scaled_model, fallback_model, seconds, sink)
        type(scaled_leaf_t), intent(in) :: scaled_model
        type(fallback_response_t), intent(in) :: fallback_model
        real(dp), intent(out) :: seconds, sink
        class(response_t), allocatable :: model
        integer :: i
        integer(int64) :: count_rate, count_start, count_stop
        real(dp) :: x, y, y_d

        sink = 0.0_dp
        call system_clock(count_rate=count_rate)
        call system_clock(count_start)
        allocate (model, source=scaled_model)
        do i = 1, repetitions
            x = 0.65_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call evaluate_hierarchy_hand_jvp(model, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
        end do
        deallocate (model)
        allocate (model, source=fallback_model)
        do i = 1, repetitions
            x = 0.65_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call evaluate_hierarchy_hand_jvp(model, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
        end do
        call system_clock(count_stop)
        seconds = real(count_stop - count_start, dp)/real(count_rate, dp)
    end subroutine time_class_hand

    subroutine time_factory_generated(seconds, sink)
        real(dp), intent(out) :: seconds, sink
        class(profile_t), allocatable :: model
        integer :: i
        integer(int64) :: count_rate, count_start, count_stop
        real(dp) :: x, y, y_d

        sink = 0.0_dp
        call system_clock(count_rate=count_rate)
        call system_clock(count_start)
        call make_profile(1, 1.75_dp, -0.5_dp, model)
        do i = 1, repetitions
            x = 0.85_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call evaluate_profile_jvp(model, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
        end do
        call make_profile(2, -0.8_dp, 0.6_dp, model)
        do i = 1, repetitions
            x = 0.85_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call evaluate_profile_jvp(model, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
        end do
        call system_clock(count_stop)
        seconds = real(count_stop - count_start, dp)/real(count_rate, dp)
    end subroutine time_factory_generated

    subroutine time_factory_hand(seconds, sink)
        real(dp), intent(out) :: seconds, sink
        class(profile_t), allocatable :: model
        integer :: i
        integer(int64) :: count_rate, count_start, count_stop
        real(dp) :: x, y, y_d

        sink = 0.0_dp
        call system_clock(count_rate=count_rate)
        call system_clock(count_start)
        call make_profile(1, 1.75_dp, -0.5_dp, model)
        do i = 1, repetitions
            x = 0.85_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call evaluate_profile_hand_jvp(model, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
        end do
        call make_profile(2, -0.8_dp, 0.6_dp, model)
        do i = 1, repetitions
            x = 0.85_dp + 1.0e-6_dp*real(mod(i, 97), dp)
            call evaluate_profile_hand_jvp(model, x, 0.125_dp, y, y_d)
            sink = sink + y + y_d
        end do
        call system_clock(count_stop)
        seconds = real(count_stop - count_start, dp)/real(count_rate, dp)
    end subroutine time_factory_hand
end program bench_polymorphism_advanced
