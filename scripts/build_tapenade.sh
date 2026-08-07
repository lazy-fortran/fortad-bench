#!/usr/bin/env bash
# Generate Tapenade adjoints for the suite kernels, in a container.
#
# Tapenade is an MIT-licensed Java tool maintained by Inria. Running it from the
# official image keeps the installation outside this repository. The default
# image is pinned by registry digest.
#
# Fairness note that shapes how these are used: `tapenade -b` emits a
# gradient-only routine. fortad's and Enzyme's routines compute the primal and
# the gradient together, so timing those against Tapenade directly would
# flatter Tapenade by the cost of the primal. The harness therefore records a
# `fortad-grad` row from `fortad --no-primal`, and that is the row to compare
# against `tapenade`. The `fortad` and `enzyme` rows are the with-primal pair.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

default_image=registry.gitlab.inria.fr/tapenade/tapenade@sha256:1426f9f4fca94ccf665c96704886cf0595d806ca88e9fa63101a015dd62a46af
image=${TAPENADE_IMAGE:-$default_image}
out=build/tapenade
# The ADFirstAidKit runtime is extracted once and kept: pulling it out of the
# image on every build would make a container round trip part of the inner loop.
if [ ! -d "$out/ADFirstAidKit" ]; then
    mkdir -p "$out"
    cid=$(docker create "$image")
    docker cp "$cid:/usr/tapenade/ADFirstAidKit" "$out/ADFirstAidKit"
    docker rm "$cid" > /dev/null
fi
find "$out" -maxdepth 1 -type f -delete
mkdir -p "$out"

for k in euler rk4 lstm ba bruss; do
    cp "cases/enzyme_suite/kernels/$k.f90" "$out/"
done

for k in euler rk4 lstm ba bruss; do
    docker run --rm -v "$PWD/$out:/work" -w /work --entrypoint tapenade "$image" \
        -b -head "$k(y)/(z)" -o "${k}_tap" -O /work "$k.f90" \
        > "$out/$k.log" 2>&1 || echo "  tapenade refused $k"
done

echo "generated:"
for k in euler rk4 lstm ba bruss; do
    if [ -f "$out/${k}_tap_b.f90" ]; then
        printf '  %-8s ok  (%s lines)\n' "$k" "$(wc -l < "$out/${k}_tap_b.f90")"
    else
        printf '  %-8s FAILED\n' "$k"
    fi
done
