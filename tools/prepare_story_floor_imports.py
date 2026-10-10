"""Pin new PBR maps to mipmapped VRAM formats; normal/ORM remain data maps."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
import argparse
parser=argparse.ArgumentParser(); parser.add_argument('--roles'); args=parser.parse_args()
for role in (args.roles.split(',') if args.roles else ['interior_stone','crypt_slab','ceremonial_tile']):
    for channel in ['albedo','normal','orm']:
        p=ROOT/'assets/story/environment/pbr'/f'{role}_{channel}.png.import'
        text=p.read_text(encoding='utf-8')
        import re
        text=re.sub(r'^compress/mode=\d+', 'compress/mode=2',text,flags=re.M)
        text=re.sub(r'^compress/normal_map=\d+', 'compress/normal_map='+('1' if channel=='normal' else '0'),text,flags=re.M)
        text=text.replace('mipmaps/generate=false','mipmaps/generate=true')
        text=re.sub(r'^detect_3d/compress_to=\d+','detect_3d/compress_to=0',text,flags=re.M)
        p.write_text(text,encoding='utf-8')
