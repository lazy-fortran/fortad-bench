# Tapenade `nonRegressions/set02/v065`

## Static triage

The pinned checkout contains exactly three tracked files for v065:

- `program.f` is a fixed-form `BLOCKDATA` unit. It initializes `COMMON /axes/`
  with `ii=1`, `jj=2`, and `kk=3`, but declares no `PROGRAM`, `FUNCTION`, or
  `SUBROUTINE`.
- `program_p.f` is Tapenade's stored parser copy of that same `BLOCKDATA` unit.
- `program_p.msg` is empty. There are no stored tangent or reverse sources or
  messages.

This is not an extractor miss: there is no callable procedure in the primal.
It is also not a standalone `PROGRAM`; `BLOCKDATA` has no executable entry
point. The stored parser copy is reference-only evidence.

## Probe boundary

The runner compiles the exact primal and stored parser artifact with strict
F2018 diagnostics, using fixed-form input for the tracked `.f` files. The
requested semantic flags are retained; the source-form switch is the only
difference between the primal/reference compiler invocations and the free-form
flag spelling used for generated-source checks elsewhere in the bench.

Fresh Tapenade `-p`, `-d`, and `-b` probes are run without a root. The parser
probe emits `v065_p.f`; tangent and reverse emit only `v065_d.msg` and
`v065_b.msg`, respectively, and report `No root unit to differentiate`.

FortAD is asked for its exact parser check and exact forward/reverse modes
without a procedure request. Each refuses with `fortad: no function or
subroutine found in source`, returns status 1, and writes no generated file.

The independent oracle models the only defined numerical state: the COMMON
initialization `(1, 2, 3)`, with sum `6`, product `6`, and weighted checksum
`14`. These checks document the source semantics without pretending that a
derivative interface exists.

No bounded port, support claim, or replacement procedure is provided.
