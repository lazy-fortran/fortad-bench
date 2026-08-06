module factory_allocatable_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use factory_profile_models, only: profile_t, linear_profile_t, &
        quadratic_profile_t
    implicit none
    private

    public :: evaluate_profile_hand_jvp

contains

    pure subroutine evaluate_profile_hand_jvp(profile, x, x_d, y, y_d)
        class(profile_t), intent(in) :: profile
        real(dp), intent(in) :: x, x_d
        real(dp), intent(out) :: y, y_d

        select type (profile)
            type is (linear_profile_t)
            y = profile%coefficients%leading*x + &
                profile%coefficients%trailing
            y_d = profile%coefficients%leading*x_d
            type is (quadratic_profile_t)
            y = profile%coefficients%leading*x*x + &
                profile%coefficients%trailing*x
            y_d = (2.0_dp*profile%coefficients%leading*x + &
                profile%coefficients%trailing)*x_d
        class default
            y = 0.0_dp
            y_d = 0.0_dp
        end select
    end subroutine evaluate_profile_hand_jvp
end module factory_allocatable_hand
