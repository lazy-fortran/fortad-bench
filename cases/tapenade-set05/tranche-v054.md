# Tapenade set05 `v054`

This case promotes the `f_vector(x)` entry point from the pinned
`nonRegressions/set05/v054/program.f90` source. The upstream module is
standards-valid and exercises a pure assumed-shape array function, generic
resolution, an elemental companion, and masked `WHERE` driver calls.

The stored FortAD input is the module entry-point body extracted from the
upstream file; the upstream program driver is retained in the exact-source
compile and fresh Tapenade gates. The elemental companion is intentionally not
the promoted path: fresh Tapenade tangent output for that companion fails the
strict purity contract and remains visible as evidence rather than being
silently repaired.

The runner records exact upstream and stored-port hashes, fresh pinned
Tapenade parser/tangent/reverse generation with strict compilation, FortAD
JVP/VJP transformation and compilation, and an independent hand, central
difference, and adjoint-identity oracle.
