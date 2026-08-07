! SPDX-License-Identifier: MIT
! Exact bounded source from Tapenade nonRegressions/set02/lh163.
      subroutine test(v,p,q,s)
      real v,p,q,s
      s = q*v
      v = p*p
      q = 3.0*v
      end
