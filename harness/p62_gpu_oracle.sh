#!/usr/bin/env bash
set -euo pipefail

# Remote-only P6.2 oracle.  The caller provides either the unpacked GCC NVPTX
# packages or a user-local NVIDIA HPC SDK, so the script never installs
# anything into the host system.
: "${FORTAD_CLI:?set FORTAD_CLI to the built fortad CLI}"

toolchain=${P62_TOOLCHAIN:-gcc}

work=${P62_WORKDIR:-$(mktemp -d "${TMPDIR:-/tmp}/fortad-p62-oracle.XXXXXX")}
keep_work=${P62_KEEP_WORK:-0}
if [[ -z "${P62_WORKDIR:-}" ]]; then
    trap 'if [[ "$keep_work" != 1 ]]; then rm -rf "$work"; fi' EXIT
else
    mkdir -p "$work"
fi

if [[ "$toolchain" == nvhpc ]]; then
    : "${P62_NVHPC_PREFIX:?set P62_NVHPC_PREFIX to the user-local HPC SDK prefix}"
    nvhpc_root="$P62_NVHPC_PREFIX/Linux_x86_64/26.5"
    fc=${P62_NVFORTRAN:-$nvhpc_root/compilers/bin/nvfortran}
    export PATH="$nvhpc_root/compilers/bin:$PATH"
    export NVHPC_CUDA_HOME="$nvhpc_root/cuda/12.9"
    export LD_LIBRARY_PATH="$nvhpc_root/compilers/lib:$NVHPC_CUDA_HOME/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
else
    : "${P62_OFFLOAD_ROOT:?set P62_OFFLOAD_ROOT to the unpacked GCC offload root}"
    fc=${FC:-gfortran}
    gcc_exec_root="$P62_OFFLOAD_ROOT/usr/libexec/gcc/x86_64-linux-gnu/14"
    gcc_lib_root="$P62_OFFLOAD_ROOT/usr/lib/gcc/x86_64-linux-gnu/14"
    export PATH="$P62_OFFLOAD_ROOT/usr/bin:$P62_OFFLOAD_ROOT/usr/bin/x86_64-linux-gnu:$PATH"
    export LD_LIBRARY_PATH="$P62_OFFLOAD_ROOT/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export LIBRARY_PATH="$P62_OFFLOAD_ROOT/usr/lib/x86_64-linux-gnu${LIBRARY_PATH:+:$LIBRARY_PATH}"
fi

cat > "$work/kernel.f90" <<'EOF'
subroutine k(n, a, b, s)
    integer, intent(in) :: n
    real(8), intent(in) :: a(n)
    real(8), intent(in) :: b(n)
    real(8), intent(out) :: s
    integer :: i
    s = 0.0d0
    do i = 1, n
        s = s + a(i)*sin(b(i))
    end do
end subroutine k
EOF

if ! /usr/bin/time -f 'transform_seconds=%e' -o "$work/transform.time" \
    "$FORTAD_CLI" --mode reverse --indep a,b --dep s --name k_vjp \
    -o "$work/derivs.f90" "$work/kernel.f90" \
    2>"$work/transform.log"; then
    cat "$work/transform.log" >&2
    exit 1
fi

cat > "$work/driver_omp.f90" <<'EOF'
program driver_omp
    use omp_lib
    implicit none
    integer, parameter :: n = 100000, n_call = 8
    real(8) :: a(n), b(n), a_b(n), b_b(n), s, s_b, expected, err
    logical :: on_device
    integer :: i, call_no

    do i = 1, n
        a(i) = 0.3d0 + 0.000001d0*i
        b(i) = 0.7d0 + 0.0000007d0*i
    end do
    s_b = 1.0d0
    do call_no = 1, n_call
        call k_vjp(n, a, b, s, s_b, a_b, b_b)
    end do
    expected = sum(a*sin(b))
    err = max(abs(s-expected), &
              max(maxval(abs(a_b-s_b*sin(b))), &
                  maxval(abs(b_b-s_b*a*cos(b)))))

    on_device = .false.
!$omp target map(from:on_device)
    on_device = .not. omp_is_initial_device()
!$omp end target
    print *, "openmp", err, on_device
    if (err > 1.0d-9 .or. .not. on_device) error stop 1
end program driver_omp
EOF

cat > "$work/driver_acc.f90" <<'EOF'
program driver_acc
    use openacc
    implicit none
    integer, parameter :: n = 100000, n_call = 8
    real(8) :: a(n), b(n), a_b(n), b_b(n), s, s_b, expected, err
    logical :: on_device
    integer :: i, call_no

    do i = 1, n
        a(i) = 0.3d0 + 0.000001d0*i
        b(i) = 0.7d0 + 0.0000007d0*i
    end do
    s_b = 1.0d0
    do call_no = 1, n_call
        call k_vjp(n, a, b, s, s_b, a_b, b_b)
    end do
    expected = sum(a*sin(b))
    err = max(abs(s-expected), &
              max(maxval(abs(a_b-s_b*sin(b))), &
                  maxval(abs(b_b-s_b*a*cos(b)))))

    on_device = .false.
!$acc parallel copy(on_device)
    on_device = acc_on_device(acc_device_nvidia)
!$acc end parallel
    print *, "openacc", err, on_device
    if (err > 1.0d-9 .or. .not. on_device) error stop 2
end program driver_acc
EOF

if [[ "$toolchain" == nvhpc ]]; then
    omp_flags=(-O2 -mp=gpu -gpu=cc75 -Minfo=accel)
    acc_flags=(-O2 -acc=gpu -gpu=cc75 -Minfo=accel)
else
    omp_flags=("-B$gcc_exec_root/" "-B$gcc_lib_root/" -O2 -fopenmp \
               -foffload=nvptx-none \
               -foffload-options=nvptx-none=-misa=sm_53 \
               "-fopt-info-vec-optimized=$work/openmp.vec")
    acc_flags=("-B$gcc_exec_root/" "-B$gcc_lib_root/" -O2 -fopenacc \
               -foffload=nvptx-none \
               -foffload-options=nvptx-none=-misa=sm_53 \
               "-fopt-info-vec-optimized=$work/openacc.vec")
fi

/usr/bin/time -f 'compile_seconds=%e' -o "$work/omp_compile.time" \
    "$fc" "${omp_flags[@]}" "$work/derivs.f90" "$work/driver_omp.f90" \
    -o "$work/run_omp" >"$work/build_omp.log" 2>&1
/usr/bin/time -f 'compile_seconds=%e' -o "$work/acc_compile.time" \
    "$fc" "${acc_flags[@]}" "$work/derivs.f90" "$work/driver_acc.f90" \
    -o "$work/run_acc" >"$work/build_acc.log" 2>&1

run_with_gpu_memory_sample() {
    local label=$1
    local binary=$2
    local output=$3
    local timing=$4
    local sample="$work/${label}.gpu_memory"

    : >"$sample"
    if command -v nvidia-smi >/dev/null 2>&1; then
        /usr/bin/time -f 'elapsed_seconds=%e max_rss_kb=%M' "$binary" \
            >"$output" 2>"$timing" &
        local run_pid=$!
        while kill -0 "$run_pid" 2>/dev/null; do
            nvidia-smi --query-gpu=memory.used \
                --format=csv,noheader,nounits 2>/dev/null |
                awk '{print $1}' >>"$sample" || true
            sleep 0.05
        done
        wait "$run_pid"
    else
        /usr/bin/time -f 'elapsed_seconds=%e max_rss_kb=%M' "$binary" \
            >"$output" 2>"$timing"
    fi
}

gpu_memory_summary() {
    local sample=$1
    if [[ -s "$sample" ]]; then
        awk 'NR == 1 { min = $1 } {
            if ($1 < min) min = $1
            if ($1 > max) max = $1
        } END { printf "samples=%d min_mb=%d peak_mb=%d", NR, min, max }' \
            "$sample"
    else
        printf '%s' 'unavailable'
    fi
}

OMP_TARGET_OFFLOAD=MANDATORY run_with_gpu_memory_sample omp \
    "$work/run_omp" "$work/run_omp.out" "$work/run_omp.time"
ACC_DEVICE_TYPE=nvidia run_with_gpu_memory_sample acc \
    "$work/run_acc" "$work/run_acc.out" "$work/run_acc.time"

printf '%s\n' 'case=P6.2 GPU emitted derivative oracle'
printf 'toolchain=%s\n' "$toolchain"
printf 'compiler=%s\n' "$fc"
"$fc" --version | head -1
printf 'openmp_flags='; printf '%q ' "${omp_flags[@]}"; printf '\n'
printf 'openacc_flags='; printf '%q ' "${acc_flags[@]}"; printf '\n'
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
fi
printf 'generated_source_bytes=%s\n' "$(wc -c <"$work/derivs.f90")"
printf 'openmp_object_bytes=%s\n' "$(stat -c %s "$work/run_omp")"
printf 'openacc_object_bytes=%s\n' "$(stat -c %s "$work/run_acc")"
printf 'transform_seconds=%s\n' "$(sed 's/^[^=]*=//' "$work/transform.time")"
printf 'openmp_compile_seconds=%s\n' "$(sed 's/^[^=]*=//' "$work/omp_compile.time")"
printf 'openacc_compile_seconds=%s\n' "$(sed 's/^[^=]*=//' "$work/acc_compile.time")"
printf 'openmp_gpu_memory=%s\n' "$(gpu_memory_summary "$work/omp.gpu_memory")"
printf 'openacc_gpu_memory=%s\n' "$(gpu_memory_summary "$work/acc.gpu_memory")"
printf '%s\n' '--- OpenMP oracle ---'
cat "$work/run_omp.out" "$work/run_omp.time"
printf '%s\n' '--- OpenACC oracle ---'
cat "$work/run_acc.out" "$work/run_acc.time"
printf '%s\n' '--- compiler reports ---'
if [[ "$toolchain" == nvhpc ]]; then
    for label_log in "openmp:$work/build_omp.log" "openacc:$work/build_acc.log"; do
        label=${label_log%%:*}
        report=${label_log#*:}
        printf '%s\n' "[$label]"
        grep -En 'Accelerator|Generating|Loop|OpenMP|CC75|CUDA' "$report" || cat "$report"
    done
else
  for label_report in "openmp:$work/openmp.vec" "openacc:$work/openacc.vec"; do
    label=${label_report%%:*}
    report=${label_report#*:}
    printf '%s\n' "[$label]"
    if [[ -s "$report" ]]; then cat "$report"; else echo "(empty: compiler emitted no vectorisation remarks)"; fi
  done
fi
