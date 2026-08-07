program lh054_harness
    use lh054_port_forward_mod, only: lh054_port_forward
    implicit none

    integer :: n, m, lrhs, lbn, pp
    real(8) :: b(1), b_d(1), bpm(1, 1)

    n = 1
    m = 1
    lrhs = 0
    lbn = 0
    pp = 1
    b = 1.75d0
    b_d = 0.25d0
    bpm = 0.0d0

    call lh054_port_forward(n, m, lrhs, lbn, b, b_d, bpm, pp)
    if (abs(b(1) - 3.5d0) > 1.0d-12) error stop "primal mismatch"
    if (abs(b_d(1) - 0.5d0) > 1.0d-12) error stop "tangent mismatch"

    print '(a)', 'harness_status: pass'
    print '(a,es24.16)', 'b_1: ', b(1)
    print '(a,es24.16)', 'b_d_1: ', b_d(1)
end program lh054_harness
