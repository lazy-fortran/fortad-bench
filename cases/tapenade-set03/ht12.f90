subroutine toto(n, a)
  
   integer n
   real a(n)
   
   a(4)=3.5

 end subroutine toto

! pour tester que Adj liveness rend n=5

 subroutine top(a)

   real a(10)
   integer n

   n = 5
   call toto(n,a)
   a(2)=a(1)*a(3)

 end subroutine top
