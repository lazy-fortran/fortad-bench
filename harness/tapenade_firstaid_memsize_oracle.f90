program tapenade_firstaid_memsize_oracle
    use, intrinsic :: iso_fortran_env, only: int64, real32, real64
    implicit none

    integer :: integer_default
    integer(int64) :: integer_8
    real :: real_default
    real(real32) :: real_4
    real(real64) :: real_8
    double precision :: double_value
    complex :: complex_default
    complex(real32) :: complex_8
    complex(real64) :: complex_16
    logical :: logical_default
    character :: character_default

    call report("INTEGER", storage_size(integer_default))
    call report("INTEGER*8", storage_size(integer_8))
    call report("REAL", storage_size(real_default))
    call report("REAL*4", storage_size(real_4))
    call report("REAL(4)", storage_size(real_4))
    call report("REAL*8", storage_size(real_8))
    call report("REAL(8)", storage_size(real_8))
    call report("DOUBLE PRECISION", storage_size(double_value))
    call report("COMPLEX", storage_size(complex_default))
    call report("COMPLEX*8", storage_size(complex_8))
    call report("COMPLEX(8)", storage_size(complex_16))
    call report("COMPLEX*16", storage_size(complex_16))
    call report("DOUBLE COMPLEX", storage_size(complex_16))
    call report("LOGICAL", storage_size(logical_default))
    call report("CHARACTER", storage_size(character_default))

contains

    subroutine report(label, bits)
        character(len=*), intent(in) :: label
        integer, intent(in) :: bits

        if (mod(bits, 8) /= 0) error stop "non-octet intrinsic storage"
        write (*, '(a,"|",i0)') label, bits / 8
    end subroutine report

end program tapenade_firstaid_memsize_oracle
