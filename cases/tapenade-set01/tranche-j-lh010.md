# Tranche J: lh010 sum plus product

The upstream function returns

```text
sum(x) + 10*product(x),  size(x)=100
```

The port only makes the result argument and `real64` kind explicit. Its oracle
uses the independent closed form
`d/dx(i) = 1 + 10*product(x)/x(i)`, then checks both generated modes, a
four-step central-difference sweep, and the adjoint identity. The nonzero test
domain keeps that formula away from its removable zero-coordinate singularity.
