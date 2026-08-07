module tapenade_set01_lh033_040_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none
contains
    pure subroutine absorbN_jvp_hand(data, data_d, resu, resu_d)
        real(dp), intent(in) :: data, data_d
        real(dp), intent(out) :: resu, resu_d
        resu = 10.0_dp * data
        resu_d = 10.0_dp * data_d
    end subroutine absorbN_jvp_hand

    pure subroutine f_jvp_hand(t, t_d, value, value_d)
        real(dp), intent(in) :: t, t_d
        real(dp), intent(out) :: value, value_d
        value = exp(t * t)
        value_d = 2.0_dp * t * value * t_d
    end subroutine f_jvp_hand
end module tapenade_set01_lh033_040_hand
