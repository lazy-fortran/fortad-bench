program bench_enzyme_suite
    !! The Enzyme README workloads, gradient timings for fortad and Enzyme.
    !!
    !! These are the workloads the Enzyme paper reports: LSTM, bundle
    !! adjustment, Euler, RK4 and a Brusselator, taken from the same numerical
    !! contract used in `differentiable-fortran/studies/enzyme-readme`. Both
    !! engines differentiate the same Fortran kernel and both are compiled by
    !! the same flang, so the comparison is of derivative code rather than of
    !! two compilers.
    !!
    !! Every gradient is checked against central finite differences along a
    !! random direction before any timing is kept. A directional check tests the
    !! whole gradient at once, where checking entries one at a time would cost
    !! `n` extra runs per workload and still miss cross terms.
    use, intrinsic :: iso_c_binding, only: c_int, c_double
    use, intrinsic :: iso_fortran_env, only: dp => real64, int64
    implicit none

    interface
        subroutine euler(n, z, y) bind(C, name="euler")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine euler
        subroutine rk4(n, z, y) bind(C, name="rk4")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine rk4
        subroutine lstm(n, z, y) bind(C, name="lstm")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine lstm
        subroutine ba(n, z, y) bind(C, name="ba")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine ba
        subroutine bruss(n, z, y) bind(C, name="bruss")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), y
        end subroutine bruss

        subroutine euler_vjp_enzyme(n, z, zb, y, yb) bind(C, name="euler_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine euler_vjp_enzyme
        subroutine rk4_vjp_enzyme(n, z, zb, y, yb) bind(C, name="rk4_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine rk4_vjp_enzyme
        subroutine lstm_vjp_enzyme(n, z, zb, y, yb) bind(C, name="lstm_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine lstm_vjp_enzyme
        subroutine ba_vjp_enzyme(n, z, zb, y, yb) bind(C, name="ba_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine ba_vjp_enzyme
        subroutine bruss_vjp_enzyme(n, z, zb, y, yb) bind(C, name="bruss_vjp_enzyme")
            import :: c_int, c_double
            integer(c_int), value :: n
            real(c_double) :: z(*), zb(*), y, yb
        end subroutine bruss_vjp_enzyme

        pure subroutine euler_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(n)
        end subroutine euler_vjp
        pure subroutine rk4_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(n)
        end subroutine rk4_vjp
        pure subroutine lstm_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(n)
        end subroutine lstm_vjp
        pure subroutine ba_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(3*n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(3*n)
        end subroutine ba_vjp
        pure subroutine bruss_vjp(n, z, y, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(n)
            real(dp), intent(out) :: y
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(n)
        end subroutine bruss_vjp
        subroutine euler_b(n, z, zb, y, yb)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(*)
            real(dp) :: zb(*), y, yb
        end subroutine euler_b
        subroutine rk4_b(n, z, zb, y, yb)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(*)
            real(dp) :: zb(*), y, yb
        end subroutine rk4_b
        subroutine lstm_b(n, z, zb, y, yb)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(*)
            real(dp) :: zb(*), y, yb
        end subroutine lstm_b
        subroutine ba_b(n, z, zb, y, yb)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(*)
            real(dp) :: zb(*), y, yb
        end subroutine ba_b
        subroutine bruss_b(n, z, zb, y, yb)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(*)
            real(dp) :: zb(*), y, yb
        end subroutine bruss_b

        ! fortad's gradient-only contract: no primal value returned, matching
        ! what Tapenade's reverse routine produces. Enzyme cannot express this -
        ! its seed rides on a duplicated output - so it appears once only.
        pure subroutine euler_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(n)
        end subroutine euler_grad
        pure subroutine rk4_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(n)
        end subroutine rk4_grad
        pure subroutine lstm_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(n)
        end subroutine lstm_grad
        pure subroutine ba_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(n)
        end subroutine ba_grad
        pure subroutine bruss_grad(n, z, y_b, z_b)
            import :: dp
            integer, intent(in) :: n
            real(dp), intent(in) :: z(n)
            real(dp), intent(in) :: y_b
            real(dp), intent(out) :: z_b(n)
        end subroutine bruss_grad
    end interface

    integer, parameter :: NW = 5
    integer, parameter :: MAX_SIZES = 16
    character(len=8), parameter :: NAMES(NW) = &
        [character(len=8) :: "euler", "rk4", "lstm", "ba", "bruss"]
    integer :: unit, w, size_index, n_sizes, n_trials, repetition_override
    integer :: sizes(MAX_SIZES), status
    character(len=4096) :: sizes_text
    character(len=512) :: output_path, run_id, provenance_file

    call get_environment_variable("FORTAD_SWEEP_NS", sizes_text, status=status)
    if (status /= 0) sizes_text = "100,1000,10000,100000,1000000"
    call parse_sizes(trim(sizes_text), sizes, n_sizes)
    n_trials = environment_integer("FORTAD_SWEEP_TRIALS", 7)
    repetition_override = environment_integer("FORTAD_SWEEP_REPS", 0)
    if (n_trials <= 0) error stop "FORTAD_SWEEP_TRIALS must be positive"
    if (repetition_override < 0) error stop "FORTAD_SWEEP_REPS must be non-negative"

    call get_environment_variable("FORTAD_SWEEP_OUTPUT", output_path, status=status)
    if (status /= 0 .or. len_trim(output_path) == 0) &
        output_path = "results/enzyme_suite_sweep.csv"
    call get_environment_variable("FORTAD_SWEEP_RUN_ID", run_id, status=status)
    if (status /= 0 .or. len_trim(run_id) == 0) run_id = "direct"
    call get_environment_variable("FORTAD_SWEEP_METADATA", provenance_file, status=status)
    if (status /= 0) provenance_file = ""

    open (newunit=unit, file=trim(output_path), status="replace", &
        action="write")
    write (unit, '(a)') "workload,engine,problem_size,input_count,n,repetitions,trials," // &
        "seconds_median,seconds_min,seconds_max,ns_per_input_median," // &
        "ns_per_input_min,ns_per_input_max,timing_clock,run_id,provenance_file"

    do w = 1, NW
        do size_index = 1, n_sizes
            call run_workload(trim(NAMES(w)), sizes(size_index), n_trials, &
                repetition_override, unit, trim(run_id), &
                trim(provenance_file))
        end do
    end do

    close (unit)
    print *, "wrote ", trim(output_path)

contains

    subroutine run_workload(name, n_elem, n_trials, repetition_override, unit, &
            run_id, provenance_file)
        !! Check one size, then retain every interleaved wall-clock sample.
        character(len=*), intent(in) :: name, run_id, provenance_file
        integer, intent(in) :: n_elem, n_trials, repetition_override, unit
        integer :: n_in, reps, r, i, trial
        real(dp), allocatable :: z(:), zb(:), zb2(:), zb3(:), zb4(:), dir(:)
        real(dp), allocatable :: samples_f(:), samples_e(:), samples_t(:)
        real(dp), allocatable :: samples_g(:), samples_p(:)
        integer(int64) :: start_count, end_count, clock_rate
        real(dp) :: y, yb

        n_in = n_elem
        if (name == "ba") n_in = 3*n_elem

        allocate (z(n_in), zb(n_in), zb2(n_in), zb3(n_in), zb4(n_in), dir(n_in))
        allocate (samples_f(n_trials), samples_e(n_trials), samples_t(n_trials))
        allocate (samples_g(n_trials), samples_p(n_trials))
        do i = 1, n_in
            z(i) = 0.4_dp + 0.3_dp*sin(0.31_dp*i)
            dir(i) = cos(0.77_dp*i)
        end do
        if (repetition_override > 0) then
            reps = repetition_override
        else
            reps = max(3, 4000000/n_in)
        end if

        yb = 1.0_dp
        call call_fortad(name, n_elem, z, y, yb, zb)
        zb2 = 0.0_dp
        yb = 1.0_dp
        call call_enzyme(name, n_elem, z, zb2, y, yb)

        ! Cross-engine agreement is corroboration. The directional finite
        ! difference below remains the independent behavioral oracle.
        zb3 = 0.0_dp
        yb = 1.0_dp
        call call_tapenade(name, n_elem, z, zb3, y, yb)
        zb4 = 0.0_dp
        yb = 1.0_dp
        call call_fortad_grad(name, n_elem, z, yb, zb4)

        call cross_check(name, "enzyme", zb, zb2)
        call cross_check(name, "fortad-grad", zb, zb4)
        call cross_check(name, "tapenade", zb, zb3)
        call check(name, "fortad", n_elem, z, dir, zb)

        ! Interleave the engines and retain all samples. The summary reports
        ! median, minimum, and maximum rather than selecting a favorable run.
        do trial = 1, n_trials
            call system_clock(start_count, clock_rate)
            do r = 1, reps
                call primal(name, n_elem, z, y)
            end do
            call system_clock(end_count)
            samples_p(trial) = elapsed_seconds(start_count, end_count, clock_rate)

            call system_clock(start_count, clock_rate)
            do r = 1, reps
                yb = 1.0_dp
                call call_fortad_grad(name, n_elem, z, yb, zb4)
            end do
            call system_clock(end_count)
            samples_g(trial) = elapsed_seconds(start_count, end_count, clock_rate)

            call system_clock(start_count, clock_rate)
            do r = 1, reps
                yb = 1.0_dp
                call call_fortad(name, n_elem, z, y, yb, zb)
            end do
            call system_clock(end_count)
            samples_f(trial) = elapsed_seconds(start_count, end_count, clock_rate)

            call system_clock(start_count, clock_rate)
            do r = 1, reps
                zb2 = 0.0_dp
                yb = 1.0_dp
                call call_enzyme(name, n_elem, z, zb2, y, yb)
            end do
            call system_clock(end_count)
            samples_e(trial) = elapsed_seconds(start_count, end_count, clock_rate)

            call system_clock(start_count, clock_rate)
            do r = 1, reps
                zb3 = 0.0_dp
                yb = 1.0_dp
                call call_tapenade(name, n_elem, z, zb3, y, yb)
            end do
            call system_clock(end_count)
            samples_t(trial) = elapsed_seconds(start_count, end_count, clock_rate)
        end do

        call row(unit, name, "fortad", n_elem, n_in, samples_f, reps, run_id, provenance_file)
        call row(unit, name, "enzyme", n_elem, n_in, samples_e, reps, run_id, provenance_file)
        call row(unit, name, "tapenade", n_elem, n_in, samples_t, reps, run_id, provenance_file)
        call row(unit, name, "fortad-grad", n_elem, n_in, samples_g, reps, run_id, provenance_file)
        call row(unit, name, "primal", n_elem, n_in, samples_p, reps, run_id, provenance_file)

        deallocate (z, zb, zb2, zb3, zb4, dir, samples_f, samples_e, samples_t, samples_g, samples_p)
    end subroutine run_workload

    subroutine call_fortad(name, n, z, y, yb, zb)
        !! Dispatch to the fortad-generated adjoint.
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:)
        real(dp), intent(out) :: y
        real(dp), intent(in) :: yb
        real(dp), intent(out) :: zb(:)

        select case (name)
        case ("euler")
            call euler_vjp(n, z, y, yb, zb)
        case ("rk4")
            call rk4_vjp(n, z, y, yb, zb)
        case ("lstm")
            call lstm_vjp(n, z, y, yb, zb)
        case ("ba")
            call ba_vjp(n, z, y, yb, zb)
        case ("bruss")
            call bruss_vjp(n, z, y, yb, zb)
        end select
    end subroutine call_fortad

    subroutine call_fortad_grad(name, n, z, yb, zb)
        !! Dispatch to the fortad-generated gradient-only adjoint.
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:)
        real(dp), intent(in) :: yb
        real(dp), intent(out) :: zb(:)

        select case (name)
        case ("euler")
            call euler_grad(n, z, yb, zb)
        case ("rk4")
            call rk4_grad(n, z, yb, zb)
        case ("lstm")
            call lstm_grad(n, z, yb, zb)
        case ("ba")
            call ba_grad(n, z, yb, zb)
        case ("bruss")
            call bruss_grad(n, z, yb, zb)
        end select
    end subroutine call_fortad_grad

    subroutine call_enzyme(name, n, z, zb, y, yb)
        !! Dispatch to the Enzyme-generated adjoint.
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(inout) :: z(:), zb(:)
        real(dp), intent(inout) :: y, yb

        select case (name)
        case ("euler")
            call euler_vjp_enzyme(n, z, zb, y, yb)
        case ("rk4")
            call rk4_vjp_enzyme(n, z, zb, y, yb)
        case ("lstm")
            call lstm_vjp_enzyme(n, z, zb, y, yb)
        case ("ba")
            call ba_vjp_enzyme(n, z, zb, y, yb)
        case ("bruss")
            call bruss_vjp_enzyme(n, z, zb, y, yb)
        end select
    end subroutine call_enzyme

    subroutine call_tapenade(name, n, z, zb, y, yb)
        !! Dispatch to the Tapenade-generated adjoint.
        !!
        !! Tapenade's routine recomputes the primal internally for its tape but
        !! does not hand back the value. That is one scalar store less than the
        !! other two engines do, which is below the resolution of this
        !! measurement and is noted rather than corrected for.
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(inout) :: z(:), zb(:)
        real(dp), intent(inout) :: y, yb

        select case (name)
        case ("euler")
            call euler_b(n, z, zb, y, yb)
        case ("rk4")
            call rk4_b(n, z, zb, y, yb)
        case ("lstm")
            call lstm_b(n, z, zb, y, yb)
        case ("ba")
            call ba_b(n, z, zb, y, yb)
        case ("bruss")
            call bruss_b(n, z, zb, y, yb)
        end select
    end subroutine call_tapenade

    subroutine primal(name, n, z, y)
        !! The undifferentiated kernel, for the finite-difference check.
        character(len=*), intent(in) :: name
        integer, intent(in) :: n
        real(dp), intent(inout) :: z(:)
        real(dp), intent(out) :: y

        select case (name)
        case ("euler")
            call euler(n, z, y)
        case ("rk4")
            call rk4(n, z, y)
        case ("lstm")
            call lstm(n, z, y)
        case ("ba")
            call ba(n, z, y)
        case ("bruss")
            call bruss(n, z, y)
        end select
    end subroutine primal

    subroutine cross_check(name, other, g1, g2)
        !! fortad against another engine, entry by entry.
        character(len=*), intent(in) :: name, other
        real(dp), intent(in) :: g1(:), g2(:)
        real(dp) :: err, scale

        scale = max(1.0_dp, maxval(abs(g2)))
        err = maxval(abs(g1 - g2))/scale
        if (err > 1.0e-12_dp) then
            print *, "workload "//name//": fortad and "//other// &
                " gradients differ, relative", err
            error stop 1
        end if
    end subroutine cross_check

    subroutine check(name, engine, n, z, dir, g)
        !! Directional finite-difference check of a whole gradient.
        character(len=*), intent(in) :: name, engine
        integer, intent(in) :: n
        real(dp), intent(in) :: z(:), dir(:), g(:)
        real(dp), allocatable :: zp(:), zm(:)
        real(dp) :: sp, sm, fd, ad, h

        allocate (zp(size(z)), zm(size(z)))
        h = 1.0e-7_dp
        zp = z + h*dir
        zm = z - h*dir
        call primal(name, n, zp, sp)
        call primal(name, n, zm, sm)
        fd = (sp - sm)/(2.0_dp*h)
        ad = sum(g*dir)

        ! Loose on purpose: a central difference of a quantity this large
        ! keeps only about half its digits, so a tight bound here would reject
        ! correct gradients rather than catch wrong ones.
        if (abs(fd - ad) > 1.0e-3_dp*max(1.0_dp, abs(ad))) then
            print *, "workload "//name//", engine "//engine// &
                ": gradient disagrees with finite differences"
            print *, "  ad =", ad, " fd =", fd
            error stop 1
        end if
    end subroutine check

    real(dp) function elapsed_seconds(start_count, end_count, clock_rate) result(seconds)
        integer(int64), intent(in) :: start_count, end_count, clock_rate

        if (clock_rate <= 0_int64) error stop "system_clock returned no rate"
        seconds = real(end_count - start_count, dp)/real(clock_rate, dp)
        if (seconds < 0.0_dp) error stop "system_clock moved backwards"
    end function elapsed_seconds

    subroutine row(unit, name, engine, problem_size, input_count, samples, reps, &
            run_id, provenance_file)
        !! One summary record. Normalised per input so workloads are comparable.
        integer, intent(in) :: unit, problem_size, input_count, reps
        character(len=*), intent(in) :: name, engine, run_id, provenance_file
        real(dp), intent(in) :: samples(:)
        real(dp), allocatable :: sorted(:)
        real(dp) :: median_seconds, min_seconds, max_seconds
        real(dp) :: median_rate, min_rate, max_rate

        allocate (sorted(size(samples)))
        sorted = samples
        call sort_samples(sorted)
        min_seconds = sorted(1)
        max_seconds = sorted(size(sorted))
        if (mod(size(sorted), 2) == 1) then
            median_seconds = sorted((size(sorted) + 1)/2)
        else
            median_seconds = 0.5_dp*(sorted(size(sorted)/2) + &
                sorted(size(sorted)/2 + 1))
        end if
        min_rate = min_seconds*1.0e9_dp/(real(reps, dp)*real(input_count, dp))
        median_rate = median_seconds*1.0e9_dp/(real(reps, dp)*real(input_count, dp))
        max_rate = max_seconds*1.0e9_dp/(real(reps, dp)*real(input_count, dp))

        write (unit, '(a,",",a,",",i0,",",i0,",",i0,",",i0,",",i0,",", &
            es14.6,",",es14.6,",",es14.6,",",es14.6,",",es14.6,",", &
            es14.6,",",a,",",a,",",a)') name, engine, problem_size, &
            input_count, input_count, reps, size(samples), median_seconds, &
            min_seconds, max_seconds, median_rate, min_rate, max_rate, &
            "system_clock_wall", run_id, provenance_file
        deallocate (sorted)
    end subroutine row

    subroutine sort_samples(values)
        real(dp), intent(inout) :: values(:)
        integer :: i, j
        real(dp) :: value

        do i = 2, size(values)
            value = values(i)
            j = i - 1
            do while (j >= 1)
                if (values(j) <= value) exit
                values(j + 1) = values(j)
                j = j - 1
            end do
            values(j + 1) = value
        end do
    end subroutine sort_samples

    integer function environment_integer(name, default_value) result(value)
        character(len=*), intent(in) :: name
        integer, intent(in) :: default_value
        character(len=64) :: text
        integer :: status, ios

        value = default_value
        call get_environment_variable(name, text, status=status)
        if (status == 0 .and. len_trim(text) > 0) then
            read (text, *, iostat=ios) value
            if (ios /= 0) error stop "invalid integer environment value"
        end if
    end function environment_integer

    subroutine parse_sizes(text, values, count)
        character(len=*), intent(in) :: text
        integer, intent(out) :: values(:), count
        integer :: begin_at, end_at, comma, ios, size_value
        character(len=64) :: token

        count = 0
        begin_at = 1
        do
            if (begin_at > len_trim(text)) exit
            comma = index(text(begin_at:), ",")
            if (comma == 0) then
                end_at = len_trim(text)
            else
                end_at = begin_at + comma - 2
            end if
            token = ""
            if (end_at >= begin_at) token = adjustl(text(begin_at:end_at))
            read (token, *, iostat=ios) size_value
            if (ios /= 0) error stop "FORTAD_SWEEP_NS contains an invalid size"
            if (size_value <= 0) &
                error stop "FORTAD_SWEEP_NS contains an invalid size"
            if (count >= size(values)) error stop "too many sweep sizes"
            count = count + 1
            values(count) = size_value
            if (comma == 0) exit
            begin_at = begin_at + comma
        end do
        if (count == 0) error stop "FORTAD_SWEEP_NS is empty"
    end subroutine parse_sizes

end program bench_enzyme_suite
