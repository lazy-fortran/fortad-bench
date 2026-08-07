C Check the possibilities of better adjoint using CHECKPOINT-START/END
      SUBROUTINE test(x,y,pkz)

      INTEGER i,j,k,n1,n2,n3
      REAL pkz(400,400,400),x,y

      n1 = 100
      n2 = 200
      n3 = 300

      y = pkz(1,1,1) * pkz(2,3,4)
C $AD CHECKPOINT-START
      DO k=1,n3
         DO j=1,n2
            DO i=1,n1
               pkz(i, j, k) = x * pkz(i, j, k)
            END DO
         END DO
      END DO
C $AD CHECKPOINT-END
      x = x*y*pkz(4,5,6)
      END
