#!/usr/bin/env python3
"""Measure matched reverse products on the downstream operator suites."""

from __future__ import annotations

import argparse
import array
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import random
import re
import shlex
import signal
import socket
import subprocess
import sys
import time


ENGINES = ("fortad-grad", "tapenade", "fortad-vjp", "enzyme")
FIELDS = ("suite", "operator", "engine", "sample", "batch", "arity", "repetitions",
          "seconds", "ns_per_input", "checksum", "fd_error", "fd_scale")


def stop_group(pid: int) -> None:
    try:
        os.killpg(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def inventory(root: Path, suites: list[str]) -> list[tuple[str, str, int]]:
    cases = []
    for suite in suites:
        text = (root / "harness" / f"bench_{suite}_suite.f90").read_text()
        names_match = re.search(r"NAMES\(NW\)\s*=\s*&\s*\[character\(len=\d+\)\s*::(.*?)\]", text, re.S)
        arities_match = re.search(r"ARITY\(NW\)\s*=\s*\[([\d\s,&]+)\]", text, re.S)
        count = int(re.search(r"parameter\s*::\s*NW\s*=\s*(\d+)", text, re.I)[1])
        if names_match is None or arities_match is None:
            raise ValueError(f"cannot read {suite} inventory")
        names = re.findall(r'"([a-z][a-z0-9_]*)"', names_match[1])
        arities = [int(value) for value in re.findall(r"\d+", arities_match[1])]
        if len(names) != count or len(arities) != count or len(set(names)) != count:
            raise ValueError(f"inconsistent {suite} inventory")
        for name, arity in zip(names, arities):
            if not (root / "cases" / suite / "kernels" / f"{name}.f90").is_file():
                raise ValueError(f"missing {suite}/{name} source")
            cases.append((suite, name, arity))
    return cases


def run(command: list[str], cwd: Path, log: Path, timeout: float) -> str:
    with log.open("a") as stream:
        stream.write("$ " + shlex.join(command) + "\n")
        stream.flush()
        proc = subprocess.Popen(command, cwd=cwd, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, start_new_session=True)
        try:
            output, _ = proc.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            stop_group(proc.pid)
            output, _ = proc.communicate()
            stream.write(output)
            raise RuntimeError(f"command timed out after {timeout:g}s") from None
        finally:
            stop_group(proc.pid)
        stream.write(output)
        if proc.returncode:
            raise RuntimeError(f"command exited {proc.returncode}")
        return output


def driver(name: str, arity: int, suite: str, engine: str) -> str:
    offset = "0.4" if suite == "fortnum" else "0.6"
    if engine == "tapenade":
        derivative = f"call {name}_b(n, z, g, y, seed)"
    elif engine == "fortad-vjp":
        derivative = f"call {name}_vjp(n, z, y, seed, g)"
    elif engine == "enzyme":
        derivative = f"call {name}_vjp_enzyme(n, z, g, y, seed)"
    else:
        derivative = f"call {name}_grad(n, z, seed, g)"
    interface = ""
    if engine == "enzyme":
        interface = f"""interface
    subroutine {name}_vjp_enzyme(n, z, g, y, seed) bind(C)
      import :: c_int, c_double
      integer(c_int), value :: n
      real(c_double) :: z(*), g(*), y, seed
    end subroutine
  end interface"""
    primal_check = ""
    if engine in ("fortad-vjp", "enzyme"):
        primal_check = f"""if (present(verify_primal)) then
      if (verify_primal) then
        call {name}(n, z, expected)
        if (.not. ieee_is_finite(y) .or. .not. ieee_is_finite(expected)) error stop 'nonfinite primal'
        if (abs(y-expected) > 1.0e-8_dp*max(1.0_dp, abs(expected))) error stop 'primal mismatch'
      end if
    end if"""
    return f"""program measure
  use, intrinsic :: iso_fortran_env, only: dp => real64, int64
  use, intrinsic :: iso_c_binding, only: c_int, c_double
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  integer, parameter :: arity = {arity}, nc = 3*arity
  real(dp) :: zc(nc), gc(nc), work(nc), yp, ym, h, fd, err, best
  real(dp) :: fd_error, fd_scale, check_scale, seconds, target, checksum
  real(dp), allocatable :: z(:), g(:)
  integer :: i, j, phase, batch, reps, r, unit
  integer(int64) :: start, finish, rate
  character(len=64) :: arg
  {interface}
  call get_command_argument(1, arg)
  read(arg, *) batch
  call get_command_argument(2, arg)
  read(arg, *) target
  fd_error = 0.0_dp
  fd_scale = 1.0_dp
  do phase = 0, 1
    do i = 1, nc
      zc(i) = {offset}_dp + 0.3_dp*sin(0.31_dp*i + 0.13_dp*phase)
    end do
    call gradient(3, zc, gc, .true.)
    if (.not. all(ieee_is_finite(gc))) error stop 'nonfinite derivative'
    check_scale = max(1.0_dp, maxval(abs(gc)))
    fd_scale = max(fd_scale, check_scale)
    do i = 1, nc
      best = huge(1.0_dp)
      do j = 4, 6
        h = 10.0_dp**(-j)*max(1.0_dp, abs(zc(i)))
        work = zc
        work(i) = zc(i) + h
        call {name}(3, work, yp)
        work(i) = zc(i) - h
        call {name}(3, work, ym)
        fd = (yp - ym)/(2.0_dp*h)
        if (.not. ieee_is_finite(fd)) error stop 'nonfinite finite difference'
        err = abs(gc(i)-fd)
        best = min(best, err)
      end do
      fd_error = max(fd_error, best)
      if (best > 1.0e-5_dp*check_scale) then
        print *, 'FD_FAILURE', phase, i, gc(i), best, check_scale
        error stop 'finite difference mismatch'
      end if
    end do
  end do
  allocate(z(arity*batch), g(arity*batch))
  do i = 1, size(z)
    z(i) = {offset}_dp + 0.3_dp*sin(0.31_dp*i)
  end do
  call gradient(batch, z, g, .true.)
  if (.not. all(ieee_is_finite(g))) error stop 'nonfinite full-batch derivative'
  open(newunit=unit, file='gradient.bin', access='stream', form='unformatted', status='replace')
  write(unit) g
  close(unit)
  call get_command_argument(3, arg)
  if (trim(arg) == 'check') stop
  call gradient(batch, z, g)
  call system_clock(count_rate=rate)
  if (rate <= 0) error stop 'clock unavailable'
  reps = 1
  do
    call system_clock(start)
    do r = 1, reps
      call gradient(batch, z, g)
    end do
    call system_clock(finish)
    seconds = real(finish-start, dp)/real(rate, dp)
    if (seconds >= target) exit
    if (reps > huge(reps)/2) error stop 'timer calibration overflow'
    reps = reps*2
  end do
  if (.not. all(ieee_is_finite(g))) error stop 'nonfinite timed derivative'
  checksum = sum(g)
  print '(a,1x,es25.16,1x,i0,3(1x,es25.16))', 'RESULT', seconds, reps, checksum, fd_error, fd_scale
contains
  subroutine gradient(n, z, g, verify_primal)
    integer, intent(in) :: n
    real(dp), intent(in) :: z(arity*n)
    real(dp), intent(out) :: g(arity*n)
    logical, intent(in), optional :: verify_primal
    real(dp) :: seed, y, expected
    g = 0.0_dp
    y = 0.0_dp
    seed = 1.0_dp
    {derivative}
    {primal_check}
  end subroutine gradient
end program measure
"""


def parse_result(output: str, minimum: float) -> dict:
    rows = [line.split() for line in output.splitlines() if line.startswith("RESULT ")]
    if len(rows) != 1 or len(rows[0]) != 6:
        raise ValueError("missing unique complete RESULT record")
    _, seconds, reps, checksum, error, scale = rows[0]
    values = dict(seconds=float(seconds), repetitions=int(reps), checksum=float(checksum),
                  fd_error=float(error), fd_scale=float(scale))
    if any(not math.isfinite(value) for value in values.values()):
        raise ValueError("nonfinite result record")
    if values["seconds"] < minimum or values["repetitions"] < 1 or values["fd_scale"] < 1:
        raise ValueError("incomplete timed result")
    if values["fd_error"] < 0 or values["fd_error"] > 1e-5*values["fd_scale"]:
        raise ValueError("failed finite difference result")
    return values


def version(command: list[str]) -> str:
    try:
        proc = subprocess.Popen(command, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, start_new_session=True)
        try:
            output, _ = proc.communicate(timeout=30)
        except subprocess.TimeoutExpired:
            stop_group(proc.pid)
            output, _ = proc.communicate()
            return output.strip() + "\nversion command timed out"
        finally:
            stop_group(proc.pid)
        return output.strip()
    except (OSError, subprocess.TimeoutExpired) as exc:
        return str(exc)


def compare_gradients(suite: str, name: str, gradients: dict) -> tuple[float, float]:
    reference = next(iter(gradients.values()))
    if suite == "fortnum":
        worst = max(abs(a-b)/max(1.0, abs(a))
                    for values in gradients.values() for a, b in zip(reference, values))
        return worst, 1e-12
    scale = max(1.0, max(abs(value) for value in reference))
    worst = max(abs(a-b)/scale for values in gradients.values() for a, b in zip(reference, values))
    tolerance = 1e-6 if name in ("fci_hendecic_bezier_edge_area", "fci_decic_bezier_edge_area") else 1e-8
    return worst, tolerance


def build(args: argparse.Namespace, case: tuple[str, str, int], engine: str,
          root: Path, output: Path) -> tuple[Path, Path]:
    suite, name, arity = case
    work = output / "build" / suite / name / engine
    work.mkdir(parents=True)
    log = work / "build.log"
    original = root / "cases" / suite / "kernels" / f"{name}.f90"
    source = work / f"{name}.f90"
    source.write_bytes(original.read_bytes())
    harness = work / "measure.f90"
    harness.write_text(driver(name, arity, suite, engine))
    derivative = work / f"{name}_grad.f90"
    extra = []
    if engine.startswith("fortad-"):
        suffix = "grad" if engine == "fortad-grad" else "vjp"
        derivative = work / f"{name}_{suffix}.f90"
        command = [args.fortad_bin, "--mode", "reverse", "--indep", "z"]
        if engine == "fortad-grad":
            command.append("--no-primal")
        run([*command, "--name", f"{name}_{suffix}", "-o", str(derivative), str(source)], work, log, args.timeout)
    elif engine == "enzyme":
        if not args.enzyme_plugin:
            raise FileNotFoundError("Enzyme plugin is not configured")
        from downstream_enzyme import build_derivative
        extra = build_derivative(args, suite, name, source, work, log, run)
        derivative = None
    else:
        run([args.tapenade_bin, "-b", "-head", f"{name}(y)/(z)", "-o", f"{name}_tap",
             "-O", str(work), str(source)], work, log, args.timeout)
        derivative = work / f"{name}_tap_b.f90"
        if args.runtime_dir:
            runtime = Path(args.runtime_dir).resolve()
            obj = work / "adStack.o"
            run([*shlex.split(args.cc), *shlex.split(args.cflags), "-I", str(runtime),
                 "-c", str(runtime / "adStack.c"), "-o", str(obj)], work, log, args.timeout)
            extra = [str(obj)]
    executable = work / "measure"
    derivative_sources = [str(derivative)] if derivative else []
    run([*shlex.split(args.compiler), *shlex.split(args.flags), str(source), *derivative_sources,
         str(harness), *extra, "-o", str(executable)], work, log, args.timeout)
    return executable, work


def execute(args: argparse.Namespace) -> int:
    root, output = Path(args.root).resolve(), Path(args.output).resolve()
    if output.exists():
        raise ValueError("output already exists; use a new run directory")
    cases = inventory(root, args.suite or ["fortnum", "fortfem"])
    engines = args.engine or list(ENGINES)
    if len(set(engines)) != len(engines) or len(set(args.suite or [])) != len(args.suite or []):
        raise ValueError("duplicate engine or suite")
    if args.workload:
        selected = set(args.workload)
        if selected - {name for _, name, _ in cases}:
            raise ValueError("unknown selected workload")
        cases = [case for case in cases if case[1] in selected]
    if not args.smoke and (args.samples < 7 or args.min_seconds < 0.05):
        raise ValueError("measurements require >=7 process samples and >=0.05s trials")
    if args.samples < 1 or args.batch < 1 or not math.isfinite(args.min_seconds) or args.min_seconds <= 0 or not math.isfinite(args.timeout) or args.timeout <= 0:
        raise ValueError("invalid positive measurement parameter")
    if not args.smoke:
        revisions = {"fortad-grad": args.fortad_revision, "fortad-vjp": args.fortad_revision,
                     "tapenade": args.tapenade_revision, "enzyme": args.enzyme_revision}
        if any(not re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", revisions[engine]) for engine in engines):
            raise ValueError("measurements require an exact source commit or archive SHA256 for each selected engine")
    output.mkdir(parents=True)
    metadata = dict(schema=1, status="running", mode="smoke" if args.smoke else "measurement",
                    created_utc=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                    inventory=[dict(suite=suite, operator=name, arity=arity) for suite, name, arity in cases],
                    benchmark_commit=version(["git", "-C", str(root), "rev-parse", "HEAD"]),
                    source_sha256={f"{s}/{n}": hashlib.sha256(
                        (root / "cases" / s / "kernels" / f"{n}.f90").read_bytes()).hexdigest()
                        for s, n, _ in cases},
                    source_c_sha256={f"{s}/{n}": hashlib.sha256(
                        (root / "cases" / s / "kernels" / f"{n}_c.f90").read_bytes()).hexdigest()
                        for s, n, _ in cases},
                    host=socket.gethostname(), platform=platform.platform(),
                    byte_order=sys.byteorder,
                    affinity=sorted(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else None,
                    slurm_job=os.environ.get("SLURM_JOB_ID"), protocol=vars(args),
                    allocation={key: os.environ.get(key) for key in
                                ("SLURM_JOB_ID", "SLURM_JOB_NODELIST", "SLURM_JOB_CPUS_PER_NODE",
                                 "SLURM_CPUS_PER_TASK", "SLURM_MEM_PER_NODE", "SLURM_MEM_PER_CPU")},
                    compiler=version([*shlex.split(args.compiler), "--version"]),
                    cc=version([*shlex.split(args.cc), "--version"]),
                    clang=version([*shlex.split(args.clang), "--version"]),
                    fortad=version([args.fortad_bin, "--version"]),
                    tapenade=version([args.tapenade_bin, "-version"]),
                    opt=version([*shlex.split(args.opt), "--version"]),
                    llvm_link=version([*shlex.split(args.llvm_link), "--version"]),
                    enzyme_plugin_sha256=hashlib.sha256(Path(args.enzyme_plugin).read_bytes()).hexdigest()
                    if args.enzyme_plugin and Path(args.enzyme_plugin).is_file() else None,
                    engine_revisions=dict(fortad=args.fortad_revision, tapenade=args.tapenade_revision,
                                          enzyme=args.enzyme_revision),
                    oracle="All coordinates in two three-element batches; central differences at three steps, best error <=1e-5 times gradient scale",
                    timing="Independent processes; two warm-ups then doubling repetitions until minimum wall-clock duration; all final trials retained; each call includes zeroing the output gradient and resetting the scalar seed",
                    contracts={"fortad-grad": "gradient-only", "tapenade": "gradient-only",
                               "fortad-vjp": "primal-and-gradient", "enzyme": "primal-and-gradient"},
                    full_batch_comparison="FortNum: component error <=1e-12*max(1,abs(reference component)); FortFEM: vector-scale error <=1e-8, or1e-6 for decic/hendecic edge areas, as in the existing suite")
    cpu_info = Path("/proc/cpuinfo")
    metadata["cpu_model"] = next((line.split(":", 1)[1].strip() for line in cpu_info.read_text().splitlines()
                                    if line.startswith("model name")), "unavailable") if cpu_info.is_file() else version(["sysctl", "-n", "machdep.cpu.brand_string"])
    metadata["libc"] = platform.libc_ver()
    metadata["runtime_sha256"] = {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                                  for path in (Path("/lib64/ld-linux-x86-64.so.2"), Path("/lib/x86_64-linux-gnu/libc.so.6"))
                                  if path.is_file()}
    meta_path = output / "metadata.json"
    meta_path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n")
    gaps = []
    runnable = {}
    for case in cases:
        for engine in engines:
            suite, name, _ = case
            try:
                runnable[(suite, name, engine)] = build(args, case, engine, root, output)
            except (OSError, RuntimeError, ValueError) as exc:
                gaps.append(dict(suite=suite, operator=name, engine=engine, sample="", stage="build",
                                 reason=str(exc), log=str(output / "build" / suite / name / engine / "build.log")))
    for suite, name, arity in cases:
        gradients = {}
        for engine in engines:
            key = (suite, name, engine)
            if key not in runnable:
                continue
            executable, work = runnable[key]
            log = work / "validation.log"
            try:
                run([str(executable), str(args.batch), str(args.min_seconds), "check"], work, log, args.timeout)
                values = array.array("d")
                with (work / "gradient.bin").open("rb") as stream:
                    values.fromfile(stream, args.batch*arity)
                    if stream.read(1):
                        raise ValueError("oversized gradient record")
                if not all(math.isfinite(value) for value in values):
                    raise ValueError("nonfinite gradient record")
                gradients[engine] = values
            except (OSError, RuntimeError, ValueError, EOFError) as exc:
                del runnable[key]
                gaps.append(dict(suite=suite, operator=name, engine=engine, sample="", stage="validation",
                                 reason=str(exc), log=str(log)))
        if len(gradients) > 1:
            worst, tolerance = compare_gradients(suite, name, gradients)
            if worst > tolerance:
                log = output / "build" / suite / name / "gradient-comparison.json"
                log.write_text(json.dumps(dict(worst_relative_error=worst, tolerance=tolerance,
                                                engines=list(gradients)), indent=2) + "\n")
                for engine in gradients:
                    del runnable[(suite, name, engine)]
                    gaps.append(dict(suite=suite, operator=name, engine=engine, sample="", stage="gradient-comparison",
                                     reason=f"full-batch engines disagree ({worst:g} > {tolerance:g})", log=str(log)))
    rng = random.Random(args.seed)
    with (output / "trials.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, FIELDS)
        writer.writeheader()
        for sample in range(args.samples):
            order = [(case, engine) for case in cases for engine in engines
                     if (*case[:2], engine) in runnable]
            rng.shuffle(order)
            for (suite, name, arity), engine in order:
                executable, work = runnable[(suite, name, engine)]
                log = work / f"sample-{sample}.log"
                try:
                    text = run([str(executable), str(args.batch), str(args.min_seconds)], work, log, args.timeout)
                    values = parse_result(text, args.min_seconds)
                    writer.writerow(dict(suite=suite, operator=name, engine=engine, sample=sample,
                                         batch=args.batch, arity=arity,
                                         ns_per_input=1e9*values["seconds"]/(args.batch*arity*values["repetitions"]),
                                         **values))
                    stream.flush()
                except (OSError, RuntimeError, ValueError) as exc:
                    gaps.append(dict(suite=suite, operator=name, engine=engine, sample=sample, stage="runtime",
                                     reason=str(exc), log=str(log)))
    with (output / "gaps.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, ("suite", "operator", "engine", "sample", "stage", "reason", "log"))
        writer.writeheader()
        writer.writerows(gaps)
    metadata["status"] = "complete-with-gaps" if gaps else "complete"
    metadata["gap_count"] = len(gaps)
    meta_path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n")
    print(f"{metadata['status']}: {output}")
    return int(bool(gaps))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    parser.add_argument("--output", required=True)
    parser.add_argument("--fortad-bin", required=True)
    parser.add_argument("--tapenade-bin", required=True)
    parser.add_argument("--runtime-dir", help="Tapenade ADFirstAidKit directory containing adStack.c")
    parser.add_argument("--compiler", default="flang")
    parser.add_argument("--flags", default="-O3")
    parser.add_argument("--cc", default="clang")
    parser.add_argument("--cflags", default="-O3")
    parser.add_argument("--engine", action="append", choices=ENGINES)
    parser.add_argument("--clang", default="clang")
    parser.add_argument("--opt", default="opt")
    parser.add_argument("--llvm-link", default="llvm-link")
    parser.add_argument("--enzyme-plugin")
    parser.add_argument("--fortad-revision", default="unrecorded")
    parser.add_argument("--tapenade-revision", default="unrecorded")
    parser.add_argument("--enzyme-revision", default="unrecorded")
    parser.add_argument("--suite", action="append", choices=("fortnum", "fortfem"))
    parser.add_argument("--workload", action="append")
    parser.add_argument("--batch", type=int, default=20000)
    parser.add_argument("--samples", type=int, default=7)
    parser.add_argument("--min-seconds", type=float, default=0.05)
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--seed", type=int, default=20261113)
    parser.add_argument("--smoke", action="store_true", help="Allow a short protocol check; never publication evidence")
    args = parser.parse_args(argv)
    try:
        return execute(args)
    except (ValueError, OSError) as exc:
        parser.error(str(exc))


if __name__ == "__main__":
    sys.exit(main())
