program bench_tapenade_set01_lh009
    use, intrinsic :: iso_fortran_env, only: dp => real64
    use tapenade_set01_lh009_hand, only: lh009_primal, lh009_hand_jvp, &
        lh009_hand_vjp
    implicit none

    real(dp) :: a(0:1000), ad(0:1000), b(0:1000), bd(0:1000)
    real(dp) :: ao(0:1000), bo(0:1000)
    real(dp) :: ah(0:1000), ahd(0:1000), bh(0:1000), bhd(0:1000)
    real(dp) :: a_bar(0:1000), b_bar(0:1000), a_bar_h(0:1000)
    real(dp) :: b_bar_h(0:1000), ap(0:1000), am(0:1000)
    real(dp) :: h, fd, lhs, rhs
    integer :: i, step, s
    logical :: ok

    s = 2
    ok = .true.
    do i = 0, 1000
        a(i) = 0.2_dp + 0.001_dp*real(i, dp)
        ad(i) = 0.01_dp*sin(real(i + 1, dp))
        b(i) = -0.3_dp + 0.0007_dp*real(i, dp)
        bd(i) = 0.02_dp*cos(real(i + 2, dp))
        a_bar(i) = 0.03_dp*sin(real(i + 3, dp))
        b_bar(i) = -0.04_dp*cos(real(i + 4, dp))
    end do

    call set01_lh009(a, b, s, ao, bo)
    call lh009_primal(a, b, s, ah, bh)
    call check_array("primal A", ao, ah, ok)
    call check_array("primal B", bo, bh, ok)

    call lh009_hand_jvp(a, ad, b, bd, s, ah, ahd, bh, bhd)
    ! This is the reference JVP.  The finite-difference sweep below checks it
    ! against fresh primal evaluations, independent of the algebra above.
    call check_array("hand JVP A state", ah, ao, ok)
    call check_array("hand JVP B state", bh, bo, ok)
    call lh009_hand_vjp(a, b, s, ao, bo, a_bar, b_bar, a_bar_h, b_bar_h)

    lhs = sum(a_bar*ahd) + sum(b_bar*bhd)
    rhs = sum(a_bar_h*ad) + sum(b_bar_h*bd)
    call check_close("hand adjoint identity", lhs, rhs, ok)

    do step = 2, 5
        h = 10.0_dp**(-step)
        call lh009_primal(a + h*ad, b + h*bd, s, ap, ao)
        call lh009_primal(a - h*ad, b - h*bd, s, am, bo)
        fd = sum(a_bar*(ap - am))/(2.0_dp*h) + &
            sum(b_bar*(ao - bo))/(2.0_dp*h)
        call check_close_tol("central difference", fd, rhs, 2.0e-8_dp, ok)
    end do

    if (.not. ok) error stop "Tapenade set01 lh009 oracle failed"
    print '(a)', "refusal_oracle_status: pass"

contains

    subroutine check_array(label, actual, expected, ok)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual(0:), expected(0:)
        logical, intent(inout) :: ok

        if (maxval(abs(actual - expected)) > 2.0e-12_dp) then
            print '(a,1x,es16.8)', "FAIL "//trim(label), &
                maxval(abs(actual - expected))
            ok = .false.
        end if
    end subroutine check_array

    subroutine check_close(label, actual, expected, ok)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected
        logical, intent(inout) :: ok

        if (abs(actual - expected) > 2.0e-10_dp*max(1.0_dp, abs(expected))) then
            print '(a,2(1x,es16.8))', "FAIL "//trim(label), actual, expected
            ok = .false.
        end if
    end subroutine check_close

    subroutine check_close_tol(label, actual, expected, tolerance, ok)
        character(len=*), intent(in) :: label
        real(dp), intent(in) :: actual, expected, tolerance
        logical, intent(inout) :: ok

        if (abs(actual - expected) > tolerance*max(1.0_dp, abs(expected))) then
            print '(a,2(1x,es16.8))', "FAIL "//trim(label), actual, expected
            ok = .false.
        end if
    end subroutine check_close_tol
end program bench_tapenade_set01_lh009
