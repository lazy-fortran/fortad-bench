# upstream/: local study checkouts, never committed

Everything in this directory except this file is gitignored.

Populate it with:

```bash
scripts/fetch_upstreams.py            # all entries in docs/upstreams.toml
scripts/fetch_upstreams.py enzyme clad
scripts/fetch_upstreams.py --category julia
scripts/fetch_upstreams.py --corpus tapenade # pinned full checkout + corpus audit
scripts/fetch_upstreams.py --audit-corpora   # repeat corpus audit without network
scripts/fetch_upstreams.py --seed-corpus-ledger tapenade # initial status scaffold
scripts/fetch_upstreams.py --write-corpus-triage tapenade # static source hints
scripts/fetch_upstreams.py --licenses # rescan and write the licence inventory
```

These are third-party projects under their own licences. They are here to be
read. They are not vendored, not built into fortad, and not redistributed. See
[../LEGAL.md](../LEGAL.md) before copying a single line out of any of them.
For most entries the answer is that you may not.
