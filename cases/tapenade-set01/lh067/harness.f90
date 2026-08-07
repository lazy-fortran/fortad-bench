program tapenade_set01_lh067_harness
    use tapenade_set01_lh067_hand, only: hand_value, hand_jvp
    use lh067_forward_mod, only: lh067_forward
    use lh067_reverse_mod, only: lh067_reverse
    implicit none

    real :: z, zd, read7, read7d, read7_b, z_b
    real :: expected, expected_d, expected_b
    real :: error

    z = 1.7
    zd = -0.35
    call hand_value(z, expected)
    call hand_jvp(z, zd, read7, read7d)
    call lh067_forward(z, zd, read7, read7d)
    expected_d = 11.0 * zd
    error = max(abs(read7 - expected), abs(read7d - expected_d))
    if (error > 2.0e-5) error stop "bounded JVP mismatch"

    read7_b = 0.8
    call lh067_reverse(z, read7, read7_b, z_b)
    expected_b = 11.0 * read7_b
    error = max(error, abs(read7 - expected))
    error = max(error, abs(z_b - expected_b))
    if (error > 2.0e-5) error stop "bounded VJP mismatch"

    write (*, '(a,es12.4)') 'harness_status: pass max_error=', error
end program tapenade_set01_lh067_harness
