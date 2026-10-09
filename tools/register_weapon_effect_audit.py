import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/combat/imagegen-mechanics'
SOURCE = Path('C:/Users/wangk/.codex/generated_images/01a11517-33ed-7641-b95f-4d40ef475dbd')
ORIGINALS = {
    'identity_610_cut_v2': 'exec-99c50925-5355-453d-af78-8dd5558d4459.png',
    'identity_612_cut_v2': 'exec-282fe3f5-1a95-424e-8767-9c3cc5826408.png',
    'identity_618_cut_v2': 'exec-573cf8a8-6eee-4f2f-a7eb-7a527b1dd914.png',
    'identity_623_cut_v2': 'exec-a03a105d-b8f4-48b6-8293-fb78670c5416.png',
    'audit_637_burst_v2': 'exec-3e834830-282f-4185-b6ac-2cd01ab4ae22.png',
    'audit_639_burst_v2': 'exec-4f040709-1cf2-4629-9d11-1d40b687fd24.png',
}

def register():
    path = BASE / 'manifest.json'
    manifest = json.loads(path.read_text(encoding='utf-8-sig'))
    for name, filename in ORIGINALS.items():
        original = SOURCE / filename
        target = BASE / (name + '.png')
        if not target.exists():
            shutil.copyfile(original, target)
        image = Image.open(target)
        assert image.mode == 'RGBA', name
        alpha = image.getchannel('A')
        assert alpha.getextrema()[0] == 0, name
        ink = alpha.point(lambda value: 255 if value > 32 else 0).getbbox()
        manifest['assets'][name] = {
            'file': target.name, 'original': str(original),
            'size': list(image.size), 'ink': list(ink),
            'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
            'use': 'area burst' if 'burst' in name else 'mouse-aimed blade cut; right-facing original',
            'generator': 'built-in ImageGen; unchanged original RGBA',
        }
        print(name, image.size, ink)
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

if __name__ == '__main__':
    register()
