"""Create inspection-only references from unchanged original production art."""
import json
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
assets = json.loads((ROOT / 'assets/bosses/imagegen/actions/catalog-v3.json').read_text(encoding='utf-8'))['assets']
dest = ROOT / 'build/boss-square-refs'
dest.mkdir(parents=True, exist_ok=True)
for key in dict.fromkeys(a['key'] for a in assets):
    sheet = Image.new('RGB', (1024, 1024), '#18202c')
    draw = ImageDraw.Draw(sheet)
    for i, spec in enumerate(a for a in assets if a['key']==key):
        path = ROOT / ('assets/bosses/imagegen/'+key+'_'+spec['role']+'.png')
        if not path.exists() and key=='storm': path = ROOT / 'assets/bosses/imagegen/storm_lightning_sweep.png'
        art = Image.open(path).convert('RGBA'); art.thumbnail((450,450))
        x, y = i%2*512, i//2*512
        sheet.paste(art, (x+(512-art.width)//2,y+45+(450-art.height)//2), art)
        draw.text((x+24,y+14), spec['role'], fill='white')
    sheet.save(dest / (key+'.png'))
print('17 original-art square reference sheets prepared')
