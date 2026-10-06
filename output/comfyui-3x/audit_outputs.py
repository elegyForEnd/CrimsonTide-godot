import json, hashlib
from pathlib import Path
from PIL import Image, ImageDraw

root = Path('D:/develop/school/CrimsonTide-godot')
out = root / 'output/comfyui-3x'
records = json.loads((out / 'results.json').read_text(encoding='utf-8'))
for record in records:
    with Image.open(record['output']) as im:
        im.verify()
    assert tuple(record['size']) == tuple(x * 3 for x in record['source_size'])
    source = root / 'assets/rogue/regions' / record['texture']
    expected = next(x for x in json.loads((root / 'output/rogue-final-night/artwork-audit.json').read_text(encoding='utf-8'))['assets'] if x['texture'] == record['texture'])
    assert hashlib.sha256(source.read_bytes()).hexdigest() == expected['sha256']
for floor in range(1, 6):
    subset = [r for r in records if r['texture'].startswith(f'f{floor}-')]
    if not subset:
        continue
    sheet = Image.new('RGB', (1600, ((len(subset)+1)//2)*295), '#16191f')
    draw = ImageDraw.Draw(sheet)
    for i,record in enumerate(subset):
        x, y = (i%2)*800, (i//2)*295
        with Image.open(record['output']) as im:
            im = im.convert('RGB')
            im.thumbnail((790,260))
            sheet.paste(im,(x,y+28))
        draw.text((x+5,y+5), f"{record['texture']}  {record['size'][0]}x{record['size'][1]}",fill='white')
    sheet.save(out / f'preview-f{floor}.jpg', quality=92)
print(f'Verified {len(records)}/50: PNG validity, exact 3x size, original SHA256 unchanged.')
