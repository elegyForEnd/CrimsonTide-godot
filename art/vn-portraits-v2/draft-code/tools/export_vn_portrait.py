"""Export a blank base or any layered pose/costume/expression combination, no API calls."""
import argparse
import json
from pathlib import Path
from build_vn_portraits import ROOT, ASSETS, HEROES, COSTUMES, POSES, EXPRESSIONS, compose

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--hero",choices=HEROES,required=True)
    parser.add_argument("--costume",choices=COSTUMES,default="regular")
    parser.add_argument("--pose",choices=POSES,default="relaxed")
    parser.add_argument("--expression",choices=EXPRESSIONS,default="neutral")
    parser.add_argument("--blank",action="store_true")
    parser.add_argument("--no-blush",action="store_true")
    parser.add_argument("--out",type=Path,required=True)
    args=parser.parse_args()
    if args.out.exists():raise FileExistsError(args.out)
    manifest=json.loads((ASSETS/"manifest.json").read_text())
    if not manifest["heroes"][args.hero]["ready"]:raise ValueError("Production incomplete")
    image=compose(manifest,args.hero,args.costume,args.pose,args.expression,args.blank,not args.no_blush)
    args.out.parent.mkdir(parents=True,exist_ok=True);image.save(args.out,compress_level=6)
    print(args.out,image.size,"native_4k=False")

if __name__=="__main__":main()
