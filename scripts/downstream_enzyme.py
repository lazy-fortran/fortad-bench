"""Build one Enzyme reverse product with the suite's C-bound primal."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import shlex
from typing import Callable


def build_derivative(args: argparse.Namespace, suite: str, name: str,
                     source: Path, work: Path, log: Path,
                     run: Callable) -> list[str]:
    if suite not in ("fortnum", "fortfem") or not re.fullmatch(r"[a-z][a-z0-9_]*", name):
        raise ValueError("invalid downstream kernel identity")
    plugin = Path(args.enzyme_plugin).resolve()
    if not plugin.is_file():
        raise FileNotFoundError(f"missing Enzyme plugin: {plugin}")
    original = Path(args.root).resolve() / "cases" / suite / "kernels" / f"{name}_c.f90"
    c_source = work / f"{name}_c.f90"
    c_source.write_bytes(original.read_bytes())
    wrapper = work / "enzyme_wrapper.c"
    wrapper.write_text(f"""extern int enzyme_dup;
extern int enzyme_const;
extern void __enzyme_autodiff(void *, ...);
extern void {name}(int, const double *, double *);
void {name}_vjp_enzyme(int n, const double *z, double *g, double *y, double *seed) {{
    __enzyme_autodiff((void *){name}, enzyme_const, n, enzyme_dup, z, g,
                      enzyme_dup, y, seed);
}}
""")
    primal_ir = work / "primal.ll"
    wrapper_ir = work / "wrapper.ll"
    linked_ir = work / "linked.ll"
    derivative_ir = work / "enzyme.ll"
    optimized_ir = work / "enzyme_optimized.ll"
    obj = work / "enzyme.o"
    commands = [
        [*shlex.split(args.compiler), *shlex.split(args.flags), "-fPIC", "-S", "-emit-llvm",
         str(c_source), "-module-dir", str(work), "-o", str(primal_ir)],
        [*shlex.split(args.clang), *shlex.split(args.cflags), "-fPIC", "-S", "-emit-llvm",
         str(wrapper), "-o", str(wrapper_ir)],
        [*shlex.split(args.llvm_link), "-S", str(primal_ir), str(wrapper_ir), "-o", str(linked_ir)],
        [*shlex.split(args.opt), f"-load-pass-plugin={plugin}", "-passes=enzyme",
         str(linked_ir), "-S", "-o", str(derivative_ir)],
        [*shlex.split(args.opt), "-O3", str(derivative_ir), "-S", "-o", str(optimized_ir)],
        [*shlex.split(args.clang), *shlex.split(args.cflags), "-fPIC", "-c",
         str(optimized_ir), "-o", str(obj)],
    ]
    for command in commands:
        run(command, work, log, args.timeout)
    return [str(obj)]
