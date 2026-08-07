program lh060_harness
    use tapenade_set01_lh060_case, only: set01_lh060
    use tapenade_set01_lh060_hand, only: set01_lh060_hand
    use lh060_jvp_mod, only: lh060_jvp
    use lh060_y_out_vjp_mod, only: lh060_y_out_vjp
    use lh060_savf_out_vjp_mod, only: lh060_savf_out_vjp
    use lh060_tn_out_vjp_mod, only: lh060_tn_out_vjp
    implicit none

    integer :: neq
    real :: y, savf, tn, c3, c4
    real :: yd, savfd, tnd, c3d, c4d
    real :: y_out, savf_out, tn_out
    real :: y_j, savf_j, tn_j, yd_j, savfd_j, tnd_j
    real :: yd_h, savfd_h, tnd_h
    real :: by, bs, bt, bc3, bc4
    real :: by_i, bs_i, bt_i, bc3_i, bc4_i
    real :: seed_y, seed_s, seed_t, lhs, rhs

    neq = 2
    y = 0.7
    savf = -0.4
    tn = 0.25
    c3 = 1.3
    c4 = -0.6
    yd = 0.11
    savfd = -0.07
    tnd = 0.05
    c3d = 0.0
    c4d = 0.0

    call set01_lh060(neq, y, savf, tn, c3, c4, y_out, savf_out, tn_out)
    call lh060_jvp(neq, y, yd, savf, savfd, tn, tnd, c3, c3d, c4, c4d, &
                   y_j, yd_j, savf_j, savfd_j, tn_j, tnd_j)
    call set01_lh060_hand(neq, y, savf, tn, c3, c4, yd, savfd, tnd, &
                          yd_h, savfd_h, tnd_h)
    call assert_close('jvp primal y', y_j, y_out)
    call assert_close('jvp primal savf', savf_j, savf_out)
    call assert_close('jvp primal tn', tn_j, tn_out)
    call assert_close('hand/JVP y', yd_j, yd_h)
    call assert_close('hand/JVP savf', savfd_j, savfd_h)
    call assert_close('hand/JVP tn', tnd_j, tnd_h)

    seed_y = 0.4
    seed_s = -0.8
    seed_t = 0.6
    by = 0.0
    bs = 0.0
    bt = 0.0
    bc3 = 0.0
    bc4 = 0.0

    call lh060_y_out_vjp(neq, y, savf, tn, c3, c4, y_out, savf_out, tn_out, &
                         seed_y, by_i, bs_i, bt_i, bc3_i, bc4_i)
    by = by + by_i
    bs = bs + bs_i
    bt = bt + bt_i
    bc3 = bc3 + bc3_i
    bc4 = bc4 + bc4_i
    call lh060_savf_out_vjp(neq, y, savf, tn, c3, c4, y_out, savf_out, tn_out, &
                            seed_s, by_i, bs_i, bt_i, bc3_i, bc4_i)
    by = by + by_i
    bs = bs + bs_i
    bt = bt + bt_i
    bc3 = bc3 + bc3_i
    bc4 = bc4 + bc4_i
    call lh060_tn_out_vjp(neq, y, savf, tn, c3, c4, y_out, savf_out, tn_out, &
                          seed_t, by_i, bs_i, bt_i, bc3_i, bc4_i)
    by = by + by_i
    bs = bs + bs_i
    bt = bt + bt_i
    bc3 = bc3 + bc3_i
    bc4 = bc4 + bc4_i

    lhs = seed_y*yd_j + seed_s*savfd_j + seed_t*tnd_j
    rhs = by*yd + bs*savfd + bt*tnd + bc3*c3d + bc4*c4d
    call assert_close('adjoint identity', lhs, rhs)
    print '(a)', 'harness_status: pass'

contains
    subroutine assert_close(label, got, want)
        character(*), intent(in) :: label
        real, intent(in) :: got, want
        if (abs(got - want) > 3.0e-5) then
            print '(a,2(es16.7,1x))', 'FAIL '//label//' got/want=', got, want
            error stop 1
        end if
    end subroutine assert_close
end program lh060_harness
