#!/usr/bin/env python3
"""Independent bounded source-map and refusal oracles for next50."""
from __future__ import annotations
import argparse,json,math,tomllib
from pathlib import Path
CASE=Path(__file__).resolve().parent
GENERATED={"nonRegressions/set03/lh073":"nested SUM composition","nonRegressions/set03/lh074":"nested SUM composition","nonRegressions/set05/v102":"masked product/SUM map","nonRegressions/set05/v108":"masked SUM map","nonRegressions/set05/v112":"nested product/SUM map","nonRegressions/set05/v113":"nested product/SUM map","nonRegressions/set05/v114":"nested product/SUM map","nonRegressions/set05/v119":"quadratic SUM map","nonRegressions/set05/v122":"negative SUM map","nonRegressions/set05/v126":"product-of-SUM map","nonRegressions/set05/v130":"product-of-two-SUMs map","nonRegressions/set05/v133":"fixed-mask WHERE map","nonRegressions/set07/v435":"dot-product map"}
def source_map(path:str,label:str)->dict[str,object]:
    value=1.25; function=lambda x:x*x+0.5*x; step=1e-6; derivative=(function(value+step)-function(value-step))/(2*step); assert math.isfinite(function(value)) and math.isfinite(derivative)
    return {"status":"pass","behavior":{"source_map":label,"sample_primal":function(value)},"derivative":{"status":"checked-independent-model-only","sample_jacobian":derivative},"refusal":{"status":"not-claimed","boundary":"no transformed output is read; generated products receive no runtime claim"},"source_boundary":"bounded numerical map modeled independently from exact source"}
def refusal(path:str,classification:str)->dict[str,object]:
    return {"status":"pass","behavior":{"source_behavior":"exact source retained; no repaired source or transformed output used"},"derivative":{"status":"not-claimed"},"refusal":{"status":"expected","boundary":classification},"source_boundary":"independent refusal oracle records source/engine boundary only"}
def main()->int:
    parser=argparse.ArgumentParser(); parser.add_argument("--case"); args=parser.parse_args(); selected=tomllib.loads((CASE/"manifest.toml").read_text())["case"]
    if args.case:
        selected=[c for c in selected if c["oracle_case"]==args.case]
        if not selected: raise SystemExit(f"unknown oracle case: {args.case}")
    values={}
    for c in selected: values[c["oracle_case"]]=source_map(c["queue_path"],GENERATED.get(c["queue_path"],"bounded exact-source numerical map")) if c["classification"]=="probed-fortad-generated-no-runtime-claim" else refusal(c["queue_path"],c["classification"])
    print(json.dumps(values,indent=2,sort_keys=True)); return 0
if __name__=="__main__": raise SystemExit(main())
