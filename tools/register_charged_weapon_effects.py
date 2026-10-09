"""Register unchanged ImageGen RGBA originals; never edit generated pixels."""
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/combat/imagegen-mechanics'

def register():
    entries = json.loads((BASE / 'charged-originals.json').read_text(encoding='utf-8-sig'))
    by_id = {entry['id']: entry for entry in entries}
    for record in sorted((BASE / 'charged-records').glob('*.json')):
        entry = json.loads(record.read_text(encoding='utf-8-sig'))
        if entry.get('style') or not by_id.get(entry['id'], {}).get('style'):
            by_id[entry['id']] = entry
    entries = [by_id[key] for key in sorted(by_id)]
    (BASE / 'charged-originals.json').write_text(json.dumps(entries, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    manifest_path = BASE / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8-sig'))
    for entry in entries:
        key = f"charged_{entry['id']}_v1"
        original = Path(entry['original'])
        target = BASE / (f'{key}_clean.png' if entry.get('style') else f'{key}.png')
        original_hash = hashlib.sha256(original.read_bytes()).hexdigest()
        if target.exists():
            assert hashlib.sha256(target.read_bytes()).hexdigest() == original_hash, key
        else:
            shutil.copyfile(original, target)
        with Image.open(target) as image:
            assert image.mode == 'RGBA', key
            alpha = image.getchannel('A')
            assert alpha.getextrema()[0] == 0, f'{key}: missing transparency'
            ink = alpha.point(lambda a: 255 if a > 32 else 0).getbbox()
            assert ink and ink[2] > ink[0] and ink[3] > ink[1], key
            size = list(image.size)
            alpha_hash = hashlib.sha256(alpha.tobytes()).hexdigest()
        manifest['assets'][key] = {
            'file': target.name, 'original': str(original), 'size': size, 'ink': list(ink),
            'sha256': original_hash, 'payload': entry['payload'], 'plane': entry['plane'],
            'alpha_sha256': alpha_hash,
            'design': entry['shape'], 'palette': entry['palette'],
            'style': entry.get('style', 'independent decorated original'),
            'generator': 'built-in ImageGen; unchanged original transparent RGBA',
        }
        print(key, size, ink)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

if __name__ == '__main__':
    register()
