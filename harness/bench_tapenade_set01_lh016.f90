program bench_tapenade_set01_lh016
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use, intrinsic :: iso_fortran_env, only: int64, real64
    use lh016_forward_ad, only: lh016_jvp
    use tapenade_set01_lh016, only: set01_lh016
    use tapenade_set01_lh016_hand, only: lh016_hand_jvp, lh016_hand_vjp
    implicit none

    interface
        subroutine ctest(input, output)
            complex, intent(in) :: input(2)
            complex, intent(out) :: output(2)
        end subroutine ctest

        subroutine ctest_d(input, input_d, output, output_d)
            complex, intent(in) :: input(2), input_d(2)
            complex, intent(out) :: output(2), output_d(2)
        end subroutine ctest_d

        subroutine ctest_b(input, input_b, output, output_b)
            complex, intent(in) :: input(2), output(2)
            complex, intent(inout) :: input_b(2), output_b(2)
        end subroutine ctest_b
    end interface

    logical :: passed

    passed = .true.
    call check_case(passed)
    call benchmark_forward()
    if (.not. passed) error stop "Tapenade set01 tranche J oracle failed"
    print '(a)', "refusal_oracle_status: pass"

contains

    subroutine check_case(ok)
        logical, intent(inout) :: ok
        real, parameter :: h(4) = [0.1, 0.05, 0.025, 0.0125]
        complex, parameter :: input(2) = [cmplx(0.8, -0.3), cmplx(-1.2, 0.4)]
        complex, parameter :: direction(2) = [cmplx(0.2, -0.7), cmplx(0.9, 0.1)]
        complex, parameter :: seed(2) = [cmplx(-0.5, 0.9), cmplx(0.6, -0.2)]
        complex :: output(2), output_d(2), hand_output(2), hand_output_d(2)
        complex :: upstream_output(2), tapenade_output(2), tapenade_output_d(2)
        complex :: input_b(2), hand_input_b(2), output_b(2)
        complex :: plus_output(2), minus_output(2)
        real :: errors(4), lhs, rhs
        integer :: index

        call lh016_jvp(input, direction, output, output_d)
        call lh016_hand_jvp(input, direction, hand_output, hand_output_d)
        call ctest(input, upstream_output)
        call ctest_d(input, direction, tapenade_output, tapenade_output_d)
        call check_vector("primal", output, hand_output, ok)
        call check_vector("exact upstream", upstream_output, hand_output, ok)
        call check_vector("Tapenade primal", tapenade_output, hand_output, ok)
        call check_vector("JVP", output_d, hand_output_d, ok)
        call check_vector("Tapenade JVP", tapenade_output_d, hand_output_d, ok)

        call lh016_hand_vjp(seed, hand_input_b)
        input_b = cmplx(0.0, 0.0)
        output_b = seed
        call ctest_b(input, input_b, output, output_b)
        call check_vector("Tapenade VJP", input_b, hand_input_b, ok)
        lhs = real(sum(conjg(seed) * output_d))
        rhs = real(sum(conjg(hand_input_b) * direction))
        call check_real("real-coordinate adjoint identity", lhs, rhs, ok)

        do index = 1, size(h)
            call set01_lh016(input + h(index) * direction, plus_output)
            call set01_lh016(input - h(index) * direction, minus_output)
            errors(index) = maxval(abs((plus_output - minus_output) / &
                (2.0 * h(index)) - output_d))
        end do
        if (.not. all(ieee_is_finite(errors)) .or. any(errors > 2.0e-5)) then
            print '(a,4(es12.4,1x))', "FAIL: FD errors ", errors
            ok = .false.
        else
            print '(a,4(es12.4,1x))', "fd_errors: ", errors
        end if
    end subroutine check_case

    subroutine check_vector(name, got, expected, ok)
        character(len=*), intent(in) :: name
        complex, intent(in) :: got(:), expected(:)
        logical, intent(inout) :: ok

        if (maxval(abs(got - expected)) > 2.0e-6) then
            print '(a,es12.4)', "FAIL: " // name // " max error ", &
                maxval(abs(got - expected))
            ok = .false.
        end if
    end subroutine check_vector

    subroutine check_real(name, got, expected, ok)
        character(len=*), intent(in) :: name
        real, intent(in) :: got, expected
        logical, intent(inout) :: ok

        if (.not. ieee_is_finite(got) .or. abs(got - expected) > 2.0e-6) then
            print '(a,2(es12.4,1x))', "FAIL: " // name // " ", got, expected
            ok = .false.
        end if
    end subroutine check_real

    subroutine benchmark_forward()
        integer, parameter :: repetitions = 1000000
        integer(int64) :: clock_start, clock_stop, clock_rate
        integer :: index
        complex :: input(2), direction(2), output(2), output_d(2), sink
        real(real64) :: elapsed

        direction = [cmplx(0.2, -0.7), cmplx(0.9, 0.1)]
        sink = cmplx(0.0, 0.0)
        call system_clock(clock_start, clock_rate)
        do index = 1, repetitions
            input = [cmplx(0.8 + real(mod(index, 97)) * 1.0e-5, -0.3), &
                cmplx(-1.2, 0.4)]
            call lh016_jvp(input, direction, output, output_d)
            sink = sink + 1.0e-12 * (sum(output) + sum(output_d))
        end do
        call system_clock(clock_stop)
        elapsed = real(clock_stop - clock_start, real64) / &
            real(clock_rate, real64)
        print '(a,i0)', "forward_calls: ", repetitions
        print '(a,es16.8)', "forward_runtime_seconds: ", elapsed
        print '(a,es16.8)', "ns_per_forward_call: ", &
            elapsed * 1.0e9_real64 / real(repetitions, real64)
        print '(a,2(es16.8,1x))', "runtime_sink_real_imag: ", &
            real(sink), aimag(sink)
    end subroutine benchmark_forward

end program bench_tapenade_set01_lh016
