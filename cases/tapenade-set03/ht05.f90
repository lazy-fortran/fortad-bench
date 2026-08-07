subroutine toto(m, x, y)

real x, y
integer m
integer n
real, DIMENSION(:), ALLOCATABLE :: v
n = m
allocate(v(n))
IF (any (v(1:n) .ne. 0.0) ) y = x**2
deallocate(v)

end subroutine toto
