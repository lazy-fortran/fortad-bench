# Polymorphic ownership boundary

`holder_t` owns an allocatable `class(node_t)` component. `replace_holder`
allocates a different child, initializes it through `SELECT TYPE`, transfers
ownership with `move_alloc`, and increments a generation counter. The holder
has a finalizer and `clear_holder` exercises destruction before replacement.
The primal therefore covers allocation, replacement, assignment of dynamic
type, nested component access, and lifetime, not just a read-only factory.

The harness checks linear and quadratic values and central finite differences
for the active scalar. FortAD is expected to refuse the dynamic
`holder%node%value(x)` call rather than emit a derivative that loses ownership
or dynamic-type information. This is the P8.5/B3/B4/B6 boundary. The existing
factory-positive case remains the smaller supported `SELECT TYPE` slice.
The validation record
([`itpplasma_oo_boundaries_validation.txt`](../../../results/itpplasma_oo_boundaries_validation.txt))
records the allocation-lifetime refusal diagnostic. The harness captures
stderr during the check and verifies that no derivative file is produced.

Run the primal and refusal check from the fortad-bench repository root with
`../fortad` pointing to the FortAD checkout:

```sh
FORTAD_REPO=../fortad scripts/bench_itpplasma_oo_boundaries.sh
```
