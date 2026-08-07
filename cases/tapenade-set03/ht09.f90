MODULE M
  PUBLIC fofo
CONTAINS
  SUBROUTINE fofo(x, y)
    IMPLICIT NONE
    real, dimension(10) :: x, y
    y = sqrt(abs(x))
  END SUBROUTINE fofo
END MODULE M
