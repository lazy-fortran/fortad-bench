# Tapenade `todoF90/REFERENCES/v01`: module-state refusal boundary

`todoF90/REFERENCES/v01` is a historical failure component rather than a
complete application.  Its exact free-form source defines the module
`flincom` and the entry point `flinopen_work`.  The module has several `SAVE`
variables, including allocatable persistent arrays, and the routine calls
external NetCDF-style procedures through implicit interfaces.  The directory
also contains the stored forward reference `program_d.f90`, its diagnostic
message file, and the pinned binary `flincom.mod`; parser and reverse stored
references are absent.

The exact primal and stored tangent both pass the strict F2018 compiler gate
(with the expected implicit-interface and unused-variable warnings).  Fresh
pinned Tapenade generation succeeds for `-p`, `-d -root flinopen_work`, and
`-b -root flinopen_work`; each fresh output also passes the same strict syntax
and object-compilation gate.  This records Tapenade generation and compiler
acceptance separately from executable derivative support: the external
callbacks are only declarations here, so no link or runtime behavior is
claimed.

FortAD is run on the exact `program.f90` in all applicable modes.  The parser
round-trip request (`fortad check --proc flinopen_work`), forward request, and
reverse request all refuse before emitting a file at the module's allocatable
declaration/component on line 9.  The refusal is a FortAD capability boundary,
not an upstream compiler failure.

No bounded port is included.  Replacing the persistent allocatable state or
inventing concrete behavior for the external NetCDF callbacks would be a
specialization, not exact support for this candidate.  The independent oracle
is therefore the reproducible strict compiler result plus FortAD's diagnostic
and no-output behavior, not a fabricated derivative or runtime harness.

Run the complete pinned probe with:

```sh
FORTAD_REPO=/mnt/storage/code/lazy-fortran/fortad \
TAPENADE_REPO=/mnt/storage/code/lazy-fortran/fortad-bench/upstream/tapenade \
  cases/tapenade-set01/v01/run.sh
python3 cases/tapenade-set01/v01/test_contract.py
```

The generated compiler, Tapenade, FortAD, and source-checksum record is in
[`result.txt`](result.txt).
