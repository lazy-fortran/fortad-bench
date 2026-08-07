program lh069_harness
    use tapenade_set01_lh069_hand, only: set01_lh069_hand_jvp, set01_lh069_hand_vjp
    use lh069_jvp_mod, only: lh069_jvp
    use lh069_ao7_vjp_mod, only: lh069_ao7_vjp
    use lh069_bo5_vjp_mod, only: lh069_bo5_vjp
    implicit none

    integer, parameter :: n = 10
    real :: a(10), b(10), ad(10), bd(10)
    real :: ao(10), bo(10), aod(10), bod(10)
    real :: aoh(10), boh(10), aodh(10), bodh(10)
    real :: ao_seed(10), bo_seed(10), ao_seed_h(10), bo_seed_h(10)
    real :: a_bar(10), b_bar(10), a_bar_h(10), b_bar_h(10)
    real :: a7_bar(10), b5_bar(10), error, lhs, rhs
    real :: ao7_seed, bo5_seed
    integer :: i

    do i = 1, n
        a(i) = 0.2 + 0.07*i
        b(i) = -0.4 + 0.11*i
        ad(i) = 0.013 - 0.001*i
        bd(i) = -0.021 + 0.002*i
    end do
    a(2) = 0.9
    a(4) = 1.0
    a(8) = 0.0
    b(8) = 10.0

    call set01_lh069_hand_jvp(a, ad, b, bd, n, aoh, aodh, boh, bodh)
    call lh069_jvp(a(1), ad(1), a(2), ad(2), a(3), ad(3), a(4), ad(4), &
        a(5), ad(5), a(6), ad(6), a(7), ad(7), a(8), ad(8), a(9), ad(9), &
        a(10), ad(10), b(1), bd(1), b(2), bd(2), b(3), bd(3), b(4), bd(4), &
        b(5), bd(5), b(6), bd(6), b(7), bd(7), b(8), bd(8), b(9), bd(9), &
        b(10), bd(10), n, ao(1), aod(1), ao(2), aod(2), ao(3), aod(3), &
        ao(4), aod(4), ao(5), aod(5), ao(6), aod(6), ao(7), aod(7), ao(8), &
        aod(8), ao(9), aod(9), ao(10), aod(10), bo(1), bod(1), bo(2), bod(2), &
        bo(3), bod(3), bo(4), bod(4), bo(5), bod(5), bo(6), bod(6), bo(7), &
        bod(7), bo(8), bod(8), bo(9), bod(9), bo(10), bod(10))
    error = max(maxval(abs(ao - aoh)), maxval(abs(bo - boh)))
    error = max(error, maxval(abs(aod - aodh)))
    error = max(error, maxval(abs(bod - bodh)))
    call assert_close('forward/JVP', error, 0.0, 5.0e-6)

    do i = 1, n
        ao_seed(i) = 0.031 - 0.002*i
        bo_seed(i) = -0.017 + 0.003*i
    end do
    ao_seed_h = ao_seed
    bo_seed_h = bo_seed
    call set01_lh069_hand_vjp(a, b, n, ao_seed_h, bo_seed_h, a_bar_h, b_bar_h)
    lhs = sum(aod*ao_seed + bod*bo_seed)
    rhs = sum(ad*a_bar_h + bd*b_bar_h)
    call assert_close('adjoint identity', abs(lhs-rhs), 0.0, 5.0e-6)

    a7_bar = 0.0
    b5_bar = 0.0
    ao7_seed = 1.0
    bo5_seed = 1.0
    call lh069_ao7_vjp(a(1), a(2), a(3), a(4), a(5), a(6), a(7), a(8), &
        a(9), a(10), b(1), b(2), b(3), b(4), b(5), b(6), b(7), b(8), &
        b(9), b(10), n, ao(1), ao(2), ao(3), ao(4), ao(5), ao(6), ao(7), &
        ao(8), ao(9), ao(10), bo(1), bo(2), bo(3), bo(4), bo(5), bo(6), &
        bo(7), bo(8), bo(9), bo(10), ao7_seed, a7_bar(1), a7_bar(2), &
        a7_bar(3), a7_bar(4), a7_bar(5), a7_bar(6), a7_bar(7), a7_bar(8), &
        a7_bar(9), a7_bar(10), b5_bar(1), b5_bar(2), b5_bar(3), b5_bar(4), &
        b5_bar(5), b5_bar(6), b5_bar(7), b5_bar(8), b5_bar(9), b5_bar(10))
    ao_seed_h = 0.0
    bo_seed_h = 0.0
    ao_seed_h(7) = 1.0
    call set01_lh069_hand_vjp(a, b, n, ao_seed_h, bo_seed_h, a_bar_h, b_bar_h)
    error = max(maxval(abs(a7_bar-a_bar_h)), maxval(abs(b5_bar-b_bar_h)))
    call assert_close('reverse ao7', error, 0.0, 5.0e-6)

    a7_bar = 0.0
    b5_bar = 0.0
    call lh069_bo5_vjp(a(1), a(2), a(3), a(4), a(5), a(6), a(7), a(8), &
        a(9), a(10), b(1), b(2), b(3), b(4), b(5), b(6), b(7), b(8), &
        b(9), b(10), n, ao(1), ao(2), ao(3), ao(4), ao(5), ao(6), ao(7), &
        ao(8), ao(9), ao(10), bo(1), bo(2), bo(3), bo(4), bo(5), bo(6), &
        bo(7), bo(8), bo(9), bo(10), bo5_seed, a7_bar(1), a7_bar(2), &
        a7_bar(3), a7_bar(4), a7_bar(5), a7_bar(6), a7_bar(7), a7_bar(8), &
        a7_bar(9), a7_bar(10), b5_bar(1), b5_bar(2), b5_bar(3), b5_bar(4), &
        b5_bar(5), b5_bar(6), b5_bar(7), b5_bar(8), b5_bar(9), b5_bar(10))
    ao_seed_h = 0.0
    bo_seed_h = 0.0
    bo_seed_h(5) = 1.0
    call set01_lh069_hand_vjp(a, b, n, ao_seed_h, bo_seed_h, a_bar_h, b_bar_h)
    error = max(maxval(abs(a7_bar-a_bar_h)), maxval(abs(b5_bar-b_bar_h)))
    call assert_close('reverse bo5', error, 0.0, 5.0e-6)

    print '(a)', 'harness_status: pass'

contains

    subroutine assert_close(label, actual, expected, eps)
        character(len=*), intent(in) :: label
        real, intent(in) :: actual, expected, eps
        if (abs(actual - expected) > eps) then
            write(*, '(a,1x,a,1x,es16.7,1x,es16.7)') 'mismatch:', trim(label), actual, expected
            error stop 1
        end if
    end subroutine assert_close

end program lh069_harness
