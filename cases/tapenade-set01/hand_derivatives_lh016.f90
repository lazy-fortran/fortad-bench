module tapenade_set01_lh016_hand
    implicit none
    private
    public :: lh016_hand_jvp, lh016_hand_vjp

contains

    subroutine lh016_hand_jvp(input, input_d, output, output_d)
        complex, intent(in) :: input(2), input_d(2)
        complex, intent(out) :: output(2), output_d(2)

        output(1) = cmplx(1.0, 2.0) * input(1)
        output(2) = cmplx(2.0, 2.0) * input(1)
        output_d(1) = cmplx(1.0, 2.0) * input_d(1)
        output_d(2) = cmplx(2.0, 2.0) * input_d(1)
    end subroutine lh016_hand_jvp

    subroutine lh016_hand_vjp(output_b, input_b)
        complex, intent(in) :: output_b(2)
        complex, intent(out) :: input_b(2)

        input_b(1) = conjg(cmplx(1.0, 2.0)) * output_b(1) + &
            conjg(cmplx(2.0, 2.0)) * output_b(2)
        input_b(2) = cmplx(0.0, 0.0)
    end subroutine lh016_hand_vjp

end module tapenade_set01_lh016_hand
