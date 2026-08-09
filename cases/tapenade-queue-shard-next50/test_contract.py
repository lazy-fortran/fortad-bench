"""Contract and independent-oracle checks for next50."""
from __future__ import annotations
import csv,hashlib,json,subprocess,tomllib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; CASE=Path(__file__).resolve().parent
def sha256(path:Path)->str:
    digest=hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda:stream.read(1024*1024),b""): digest.update(block)
    return digest.hexdigest()
def prior_cases()->set[tuple[str,str]]:
    keys=set()
    for path in ROOT.glob("cases/tapenade-queue-shard-*/manifest.toml"):
        if path!=CASE/"manifest.toml": keys.update((c["component"],c["queue_path"]) for c in tomllib.loads(path.read_text()).get("case",[]))
    return keys
def test_contract()->None:
    manifest=tomllib.loads((CASE/"manifest.toml").read_text()); result=json.loads((CASE/"result.json").read_text())
    with (ROOT/"docs/corpora/tapenade-status.csv").open(newline="",encoding="utf-8") as stream: ledger={(r["component"],r["path"]):r for r in csv.DictReader(stream)}
    assert result["shard_id"]==manifest["shard_id"]
    for key in ("upstream_revision","fortad_revision","fortfront_revision","selection_queue_sha256","selection_batch_sha256"): assert result[key]==manifest[key]
    assert result["current_queue_sha256"]==manifest["current_queue_sha256"]==sha256(ROOT/manifest["queue_file"])
    assert result["current_batch_sha256"]==manifest["current_batch_sha256"]==sha256(ROOT/manifest["batch_file"])
    assert len(manifest["case"])==len(result["cases"])==48
    observed={(c["component"],c["queue_path"]) for c in result["cases"]}; assert len(observed)==48 and observed.isdisjoint(prior_cases())
    for selected,case in zip(manifest["case"],result["cases"]):
        assert (selected["component"],selected["queue_path"])==(case["component"],case["queue_path"]); assert case["selection"]=="modern-feature-score-then-queue-order" and case["compiler_status"]=="compiler-clean"
        assert case["compiler_missing_source_files"]==[] and case["compiler_extra_source_files"]==[] and case["dependency_risk"] is False and case["independent_oracle"]["status"]=="pass"
        row=ledger[(case["component"],case["queue_path"])]
        assert row["status"]==case["classification"] and row["entry_point"]==case["entry_point"] and row["modes"]=="parser|forward|reverse" and "independent" in row["oracle"]
        for source in [case["source"],*case["references"]]: assert case["source_reference_sha256"][source]==sha256(ROOT/"upstream/tapenade"/source)
        for mode in ("parser","forward","reverse"):
            assert case["modes"][mode]["tapenade"]["status"]=="pass"
            if case["classification"]=="probed-fortad-generated-no-runtime-claim": assert case["modes"][mode]["fortad"]["status"]=="pass"
            else: assert case["modes"][mode]["fortad"]["status"] in {"pass","refused"} and (case["modes"][mode]["fortad"]["status"]=="refused" or case["modes"][mode]["fortad"]["generated"])
def test_independent_oracle()->None:
    process=subprocess.run(["python3",str(CASE/"oracle.py")],capture_output=True,text=True,check=False); assert process.returncode==0,process.stderr
    values=json.loads(process.stdout); manifest=tomllib.loads((CASE/"manifest.toml").read_text()); assert set(values)=={c["oracle_case"] for c in manifest["case"]} and all(v["status"]=="pass" for v in values.values())
if __name__=="__main__": test_contract(); test_independent_oracle()
