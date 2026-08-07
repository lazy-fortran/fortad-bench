module tapenade_set01_lh001_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
    private
    public :: lh001_hand_jvp, lh001_hand_vjp

contains

    subroutine lh001_hand_jvp(i1, i1_d, i2, i2_d, i3, i3_d, o1, o1_d, &
            o2, o3, o3_d)
        real(dp), intent(inout) :: i1, i1_d, i2, i2_d
        real(dp), intent(in) :: i3, i3_d
        real(dp), intent(out) :: o1, o1_d, o2, o3, o3_d
        real(dp) :: l1, l1_d, l2, l2_d

        l1 = i1*i2
        l1_d = i1_d*i2 + i1*i2_d
        l2 = i1 - 3.0_dp*i2
        l2_d = i1_d - 3.0_dp*i2_d
        o1 = l1/l2
        o1_d = (l1_d*l2 - l1*l2_d)/(l2*l2)
        o2 = 35.0_dp
        i1 = 99.0_dp
        i1_d = 0.0_dp
        o3 = i3*i2
        o3_d = i3_d*i2 + i3*i2_d
        o1_d = o2*(o1_d*i2 + o1*i2_d)
        o1 = o1*o2*i2
        o3 = 2.0_dp
        o3_d = 0.0_dp
        i2 = 5.0_dp
        i2_d = 0.0_dp
    end subroutine lh001_hand_jvp

    subroutine lh001_hand_vjp(i1, i2, i3, o1, o2, o3, o1_b, i1_b, i2_b, &
            i3_b)
        real(dp), intent(in) :: i1, i2, i3, o1_b
        real(dp), intent(out) :: o1, o2, o3, i1_b, i2_b, i3_b
        real(dp) :: denominator

        denominator = i1 - 3.0_dp*i2
        o1 = 35.0_dp*i1*i2*i2/denominator
        o2 = 35.0_dp
        o3 = 2.0_dp
        i1_b = o1_b*(-105.0_dp*i2**3/denominator**2)
        i2_b = o1_b*(35.0_dp*i1*i2*(2.0_dp*i1 - 3.0_dp*i2)/ &
            denominator**2)
        i3_b = 0.0_dp
    end subroutine lh001_hand_vjp

end module tapenade_set01_lh001_hand
