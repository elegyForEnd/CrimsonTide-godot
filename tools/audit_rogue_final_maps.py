"""Check selected image provenance and create labeled contact sheets for visual review."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw
from install_rogue_final_maps import PRESERVED, PROFILES, REGIONS, ROOT

manifest = json.loads((REGIONS / 'ground-manifest.json').read_text(encoding='utf-8'))
kinds = ['a6', 'a7', 'shop', 'talent', 'treasure', 'curse', 'event', 'forge', 'gamble', 'mirror']
records = []
for floor in range(1, 6):
    for kind in kinds:
        key = f'f{floor}-{kind}'
        path = REGIONS / manifest[key]['texture']
        assert key in PROFILES, f'Missing reviewed geometry: {key}'
        assert path.exists(), f'Missing selected artwork: {key}'
        expected = '-smooth-night-v2.png' if key in PRESERVED else '-flat-night-v7.png'
        assert path.name.endswith(expected.removesuffix('.png') + '-3x.png'), f'ComfyUI 3x artwork not selected: {key}'
        with Image.open(path) as img:
            size = img.size
            assert abs(size[0] / size[1] - 3) < .06
            source = REGIONS / path.name.replace('-3x.png', '.png')
            with Image.open(source) as original:
                assert size == tuple(v * 3 for v in original.size), f'Wrong 3x dimensions: {key}'
        records.append({'key': key, 'texture': path.name, 'size': size,
                        'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    for mode in ['artwork', 'profiles']:
        sheet = Image.new('RGB', (1500, 1360), (18, 20, 28))
        draw = ImageDraw.Draw(sheet)
        for index, kind in enumerate(kinds):
            key = f'f{floor}-{kind}'
            source = (ROOT / 'build/final-map-audit' / f'profile-{key}.png'
                      if mode == 'profiles' else REGIONS / manifest[key]['texture'])
            with Image.open(source) as img:
                sheet.paste(img.resize((750, 250)), ((index % 2) * 750, (index // 2) * 272))
            draw.text(((index % 2) * 750 + 6, (index // 2) * 272 + 252), key, fill='white')
        sheet.save(ROOT / 'output/rogue-final-night' / f'{mode}-f{floor}.png')
(ROOT / 'output/comfyui-3x/game-artwork-audit.json').write_text(
    json.dumps({'selected': 50, 'preserved': len(PRESERVED), 'generated': 43,
                'assets': records}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('50 ComfyUI 3x maps selected and exact source dimensions verified')
