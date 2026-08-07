! Copyright (c) 1999-2021 INRIA
! SPDX-License-Identifier: MIT
!
! Independent numerical oracle for the bounded lh026 port.  The reference
! primal uses structured DO WHILE/EXIT control flow; the hand JVP and VJP
! propagate the fixed trace without using generated derivative code.
module tapenade_set01_lh026_hand
    use, intrinsic :: iso_fortran_env, only: dp => real64
    implicit none

    integer, parameter :: max_events = 10000

contains

    subroutine reference_lh026(a, b)
        real(dp), intent(inout) :: a(100), b(100)
        integer :: i
        logical :: restart

        restart = .true.
        do while (restart)
            restart = .false.
            do i = 1, 100
                if (a(i) > 0.0_dp) then
                    a(i) = a(i)*b(i)
                    if (b(i) > 0.0_dp) then
                        b(i) = b(i) + 1.0_dp
                    else
                        b(i) = b(i) + 2.0_dp
                        restart = .true.
                        exit
                    end if
                end if
            end do
        end do
    end subroutine reference_lh026

    subroutine lh026_jvp_hand(a, a_d, b, b_d)
        real(dp), intent(inout) :: a(100), a_d(100)
        real(dp), intent(inout) :: b(100), b_d(100)
        integer :: i, restart_count
        logical :: restart, running

        running = .true.
        do restart_count = 1, 100
            if (running) then
                restart = .false.
                do i = 1, 100
                    if (.not. restart) then
                        if (a(i) > 0.0_dp) then
                            a_d(i) = b(i)*a_d(i) + a(i)*b_d(i)
                            a(i) = a(i)*b(i)
                            if (b(i) > 0.0_dp) then
                                b(i) = b(i) + 1.0_dp
                            else
                                b(i) = b(i) + 2.0_dp
                                restart = .true.
                            end if
                        end if
                    end if
                end do
                running = restart
            end if
        end do
    end subroutine lh026_jvp_hand

    subroutine lh026_vjp_hand(a, b, a_seed, b_seed, a_bar, b_bar)
        real(dp), intent(in) :: a(100), b(100)
        real(dp), intent(in) :: a_seed(100), b_seed(100)
        real(dp), intent(out) :: a_bar(100), b_bar(100)
        real(dp) :: a_work(100), b_work(100)
        real(dp) :: old_a(max_events), old_b(max_events)
        real(dp) :: current_a_bar
        integer :: event_i(max_events), event_count, i

        a_work = a
        b_work = b
        call record_trace(a_work, b_work, event_count, event_i, old_a, old_b)

        a_bar = a_seed
        b_bar = b_seed
        do i = event_count, 1, -1
            current_a_bar = a_bar(event_i(i))
            b_bar(event_i(i)) = b_bar(event_i(i)) + &
                old_a(i)*current_a_bar
            a_bar(event_i(i)) = old_b(i)*current_a_bar
        end do
    end subroutine lh026_vjp_hand

    subroutine primal_lh026(a, b)
        real(dp), intent(inout) :: a(100), b(100)
        real(dp) :: old_a(max_events), old_b(max_events)
        integer :: event_i(max_events), event_count

        call record_trace(a, b, event_count, event_i, old_a, old_b)
    end subroutine primal_lh026

    subroutine record_trace(a, b, event_count, event_i, old_a, old_b)
        real(dp), intent(inout) :: a(100), b(100)
        integer, intent(out) :: event_count
        integer, intent(out) :: event_i(max_events)
        real(dp), intent(out) :: old_a(max_events), old_b(max_events)
        integer :: i, restart_count
        logical :: restart, running

        event_count = 0
        running = .true.
        do restart_count = 1, 100
            if (running) then
                restart = .false.
                do i = 1, 100
                    if (.not. restart) then
                        if (a(i) > 0.0_dp) then
                            if (event_count >= max_events) then
                                error stop "lh026 oracle trace is full"
                            end if
                            event_count = event_count + 1
                            event_i(event_count) = i
                            old_a(event_count) = a(i)
                            old_b(event_count) = b(i)
                            a(i) = a(i)*b(i)
                            if (b(i) > 0.0_dp) then
                                b(i) = b(i) + 1.0_dp
                            else
                                b(i) = b(i) + 2.0_dp
                                restart = .true.
                            end if
                        end if
                    end if
                end do
                running = restart
            end if
        end do
    end subroutine record_trace

end module tapenade_set01_lh026_hand
