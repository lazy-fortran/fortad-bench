      subroutine top(x,y)
      real x,y,z,t
      x = x*y
      call foo(x,y,z)
      z = 2.5
      call foo(x,z,t)
      y = y*t
      end

      subroutine foo(a,b,c)
      real a,b,c
      a = a*a
      c = 2.0*b
      end
