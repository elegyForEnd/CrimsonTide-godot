"""Export any of the 120 registered body/expression combinations as a 4K PNG."""
from pathlib import Path
import argparse
import json
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--hero",choices=["feiyue","xueli","yayu"],required=True)
    parser.add_argument("--expression",default="neutral")
    parser.add_argument("--costume",default="regular")
    parser.add_argument("--out",type=Path,required=True)
    args=parser.parse_args()
    manifest=json.loads((ROOT/"assets/story/portraits/manifest.json").read_text(encoding="utf-8"))
    if args.expression not in manifest["expressions"] or args.costume not in manifest["costumes"]: raise ValueError("Unknown variant")
    entry=manifest["heroes"][args.hero]
    if not entry["ready"]:raise ValueError("Hero production incomplete")
    body=Image.open(ROOT/entry["bodies"][args.costume].removeprefix("res://")).convert("RGBA")
    if args.expression!="neutral":
        face=Image.open(ROOT/entry["faces"][args.expression].removeprefix("res://")).convert("RGBA")
        body.alpha_composite(face,tuple(entry["face_rect"][:2]))
    if args.out.exists():raise FileExistsError(args.out)
    args.out.parent.mkdir(parents=True,exist_ok=True);body.save(args.out,compress_level=6)
    print(str(args.out),body.size)

if __name__=="__main__":main()
