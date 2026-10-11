"""Embed the small bootstrap PCK in an official matching Godot release template."""
from pathlib import Path
import argparse,struct
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser();parser.add_argument('template',type=Path)
    parser.add_argument('--pack',default='CrimsonTide-Inventory-Launcher.pck')
    parser.add_argument('--output',default='CrimsonTide-ForwardPlus-v10.exe')
    args=parser.parse_args()
    assert Path(args.pack).name==args.pack and Path(args.output).name==args.output, 'Expected dist filenames'
    pack=(ROOT/'dist'/args.pack).read_bytes()
    assert pack[:4]==b'GDPC', 'Expected a Godot pack'
    runtime=args.template.read_bytes();assert runtime[:2]==b'MZ', 'Expected Windows release template'
    # Embedded packs end with pack size and Godot magic; the untouched template
    # stays reusable, and v9 remains only the asset/base pack mounted at startup.
    target=ROOT/'dist'/args.output
    target.write_bytes(runtime+pack+struct.pack('<Q',len(pack))+b'GDPC')
    print(target.name,target.stat().st_size)
if __name__=='__main__':main()
