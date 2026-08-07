program tapenade_set01_v526_stored_modules_probe
    use fox_dom_types
    use fox_sax
    use m_precision
    use m_rezomat_t
    use m_sing3_i
    use m_singularite_rezo_i
    use m_singularite_t
    implicit none

    integer :: kind_sum
    kind_sum = DOUBLE + SIMPLE
    if (kind_sum <= 0) error stop 1
end program tapenade_set01_v526_stored_modules_probe
