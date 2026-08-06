# Complex arithmetic JVP

The kernel deliberately mixes holomorphic and non-holomorphic operations:

```text
y = z² + conjg(z) + i Im(z)
```

For real-coordinate directions `(zr_d, zi_d)`, with `z_d = zr_d + i zi_d`,
the complex output contract is

```text
y_d = 2 z z_d + conjg(z_d) + i Im(z_d)
```

That contract covers `conjg`, complex multiplication, `cmplx`, and `aimag`.
The JVP is defined in real coordinates. No holomorphic derivative is assumed.
The harness checks the generated and hand JVPs against a central real finite
difference in both coordinate directions. This is the positive B10 intrinsic
slice. Real-valued non-holomorphic objectives remain a separate boundary.
