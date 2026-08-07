 SUBROUTINE FLX_BLK(x, y)
    IMPLICIT NONE

    REAL :: x, y
    REAL :: s, t, u, w

! On doit avoir sb = tb et non sb = sb + tb 
        s = x**2
        t = s
        u = SIGN(1.0, s)
        w = t*u
        y = w

  END SUBROUTINE FLX_BLK



    
    

