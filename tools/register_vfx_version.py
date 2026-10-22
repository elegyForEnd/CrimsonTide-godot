"""Register unchanged ImageGen outputs and exact gameplay-role mappings.

Only selected originals enter assets/. Density images retain their native RGB:
weapon_density.gdshader converts brightness to coverage while rendering.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/combat/imagegen-mechanics'


def register(specification):
    spec = json.loads(specification.read_text(encoding='utf-8'))
    version = spec.get('version', 'layered-v2')
    assert version in ['layered-v2', 'smoke-v3', 'blade-v4', 'weapon-v5']
    manifest_path = BASE / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    for item in spec['assets']:
        original = Path(item['original'])
        key = item['key']
        file_key = item.get('file_key', key)
        target = BASE / version / (file_key + '.png')
        target.parent.mkdir(parents=True, exist_ok=True)
        digest = hashlib.sha256(original.read_bytes()).hexdigest()
        if target.exists():
            assert hashlib.sha256(target.read_bytes()).hexdigest() == digest, target
        else:
            shutil.copyfile(original, target)
        image = Image.open(target)
        density = bool(item.get('density_mask', False))
        channel = image.convert('L') if density else image.getchannel('A')
        if not density:
            assert channel.getextrema()[0] == 0, f'{key}: missing transparency'
        ink = channel.point(lambda value: 255 if value > (4 if density else 20) else 0).getbbox()
        assert ink and image.width >= 512 and image.height >= 512, key
        prompt = BASE / 'prompts' / version / (file_key + '.txt')
        prompt.parent.mkdir(parents=True, exist_ok=True)
        prompt.write_text(item['prompt'] + '\n', encoding='utf-8')
        entry = {'file': target.relative_to(BASE).as_posix(), 'original': str(original),
                 'size': list(image.size), 'ink': list(ink), 'sha256': digest,
                 'prompt': prompt.relative_to(ROOT).as_posix(), 'density_mask': density,
                 'native_aspect': True, 'vfx_version': version,
                 'generator': 'built-in ImageGen; original pixels preserved',
                 'design': item.get('design', key)}
        if key in manifest['assets']:
            entry['prior_file'] = manifest['assets'][key].get('prior_file', manifest['assets'][key]['file'])
        entry.update(item.get('metadata', {}))
        manifest['assets'][key] = entry
        print(key, image.size, ink)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    if 'overrides' in spec:
        (BASE / 'weapon-overrides.json').write_text(json.dumps(spec['overrides'], ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('specification', type=Path)
    register(ap.parse_args().specification)
