"""Save a built-in imagegen result and per-job provenance without concurrent ledger writes."""
from pathlib import Path
import argparse,hashlib,json,shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/"art/vn-full-v3"
def main():
    parser=argparse.ArgumentParser();parser.add_argument("--job",required=True);parser.add_argument("--source",type=Path,required=True)
    args=parser.parse_args();jobs=json.loads((ART/"jobs.json").read_text(encoding="utf-8"))["jobs"]
    job=next(j for j in jobs if j["id"]==args.job)
    target=ROOT/job["output"]
    if target.exists():raise FileExistsError(target)
    with Image.open(args.source) as image:
        if image.mode!="RGBA" or image.getchannel("A").getextrema()[0]!=0:raise ValueError("Expected real transparent RGBA")
        resolution=list(image.size)
    target.parent.mkdir(exist_ok=True,parents=True)
    temporary=target.with_suffix(".part.png");shutil.copy2(args.source,temporary);temporary.replace(target)
    record={"id":job["id"],"generator":"built-in imagegen","whole_portrait":True,"facial_compositing":False,
            "resolution":resolution,"native_4k":resolution==[2160,3840],"source":str(args.source),
            "output":job["output"],"sha256":hashlib.sha256(target.read_bytes()).hexdigest(),
            "prompt_sha256":hashlib.sha256(job["prompt"].encode()).hexdigest(),"prompt":job["prompt"],"visual_review":"pending"}
    temporary=target.with_suffix(".part.json")
    temporary.write_text(json.dumps(record,indent=2,ensure_ascii=False),encoding="utf-8")
    temporary.replace(target.with_suffix(".json"))
    print(job["id"],resolution)
if __name__=="__main__":main()
