program bench_tapenade_first_aid_validity
    use, intrinsic :: iso_fortran_env, only: dp => real64, sp => real32, int64
    implicit none

    integer, parameter :: repetitions = 1000000
    real(sp) :: gmin, gmax
    logical :: infmin, infmax
    common /validity_test_common/ gmin, gmax, infmin, infmax
    integer :: i
    integer(int64) :: tick_start, tick_stop, tick_rate
    real(dp) :: t8, td8, checksum, elapsed, ns_per_call
    real(sp) :: t4, td4

    call reset_interval()
    t8 = 6.0_dp
    td8 = 2.0_dp
    call validity_domain_real8(t8, td8)
    call check_real(gmin, -3.0_sp, "initial lower bound")
    call check_false(infmin, "initial lower flag")

    t8 = 10.0_dp
    call validity_domain_real8(t8, td8)
    call check_real(gmin, -3.0_sp, "inactive lower candidate")
    t8 = 4.0_dp
    call validity_domain_real8(t8, td8)
    call check_real(gmin, -2.0_sp, "active lower candidate")

    t8 = -8.0_dp
    call validity_domain_real8(t8, td8)
    call check_real(gmax, 4.0_sp, "initial upper bound")
    call check_false(infmax, "initial upper flag")
    t8 = -10.0_dp
    call validity_domain_real8(t8, td8)
    call check_real(gmax, 4.0_sp, "inactive upper candidate")
    t8 = -6.0_dp
    call validity_domain_real8(t8, td8)
    call check_real(gmax, 3.0_sp, "active upper candidate")

    td8 = 0.0_dp
    call validity_domain_real8(t8, td8)
    call check_real(gmin, -2.0_sp, "zero-direction lower bound")
    call check_real(gmax, 3.0_sp, "zero-direction upper bound")

    call reset_interval()
    t4 = 9.0_sp
    td4 = -3.0_sp
    call validity_domain_real4(t4, td4)
    call check_real(gmax, 3.0_sp, "real4 upper bound")
    call check_false(infmax, "real4 upper flag")

    checksum = 0.0_dp
    t8 = 6.0_dp
    td8 = 2.0_dp
    call system_clock(tick_start, tick_rate)
    do i = 1, repetitions
        call reset_interval()
        call validity_domain_real8(t8, td8)
        checksum = checksum + real(gmin, dp)
    end do
    call system_clock(tick_stop)
    elapsed = real(tick_stop - tick_start, dp)/real(tick_rate, dp)
    ns_per_call = elapsed*1.0e9_dp/real(repetitions, dp)

    write (*, '(a)') "oracle_status: pass"
    write (*, '(a,i0)') "state_transitions_checked: ", 8
    write (*, '(a,es24.16)') "checksum: ", checksum
    write (*, '(a,es24.16)') "primal_ns_per_call: ", ns_per_call
contains
    subroutine reset_interval()
        gmin = -999.99_sp
        gmax = 999.99_sp
        infmin = .true.
        infmax = .true.
    end subroutine reset_interval

    subroutine check_real(actual, expected, label)
        real(sp), intent(in) :: actual, expected
        character(len=*), intent(in) :: label

        if (abs(actual - expected) > 4.0_sp*epsilon(expected)) then
            write (*, '(a,2(1x,es14.6))') trim(label), actual, expected
            error stop "validity interval state mismatch"
        end if
    end subroutine check_real

    subroutine check_false(actual, label)
        logical, intent(in) :: actual
        character(len=*), intent(in) :: label

        if (actual) then
            write (*, '(a)') trim(label)
            error stop "validity interval flag mismatch"
        end if
    end subroutine check_false
end program bench_tapenade_first_aid_validity
