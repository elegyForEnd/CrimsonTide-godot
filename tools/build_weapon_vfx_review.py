"""Make labelled QA contact sheets of original textures without modifying them."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/combat/imagegen-square'
MECH = ROOT / 'assets/combat/imagegen-mechanics'
OUT = ROOT / 'build/lol-vfx-study'
manifest = json.loads((MECH / 'manifest.json').read_text(encoding='utf-8'))['assets']
rows = json.loads((ROOT / 'build/weapon-asset-inventory.json').read_text(encoding='utf-8'))
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 14)


def path(source):
    if source in manifest:
        return MECH / manifest[source]['file']
    return (BASE if source.startswith('weapon_') else MECH) / (source + '.png')


def sheet(key, selected):
    w, h, cols = 224, 232, 6
    canvas = Image.new('RGB', (cols*w, ((len(selected)+cols-1)//cols)*h), '#15212c')
    draw = ImageDraw.Draw(canvas)
    for i, row in enumerate(selected):
        x, y = (i % cols)*w, (i//cols)*h
        original = path(row[key])
        if original.exists():
            image = Image.open(original).convert('RGBA')
            image.thumbnail((204, 185))
            canvas.paste(image, (x+(w-image.width)//2, y+(187-image.height)//2), image)
        draw.text((x+6, y+188), f"{row['id']} {row['name']}", font=font, fill='#edf1f4')
        draw.text((x+6, y+210), row[key], font=font, fill='#99b6ca')
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / f'weapons-{key}.jpg'
    canvas.save(target, quality=92)
    print(target)


if __name__ == '__main__':
    sheet('normal_source', rows)
    sheet('projectile_source', [r for r in rows if r['family'] in [0,3]])
    sheet('art_source', rows)
