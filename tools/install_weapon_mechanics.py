"""Copy built-in ImageGen originals unchanged and record semantic role/provenance."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/combat/imagegen-mechanics'

def install(source, role):
    source = Path(source)
    prompt = BASE / 'prompts' / (role + '.txt')
    assert prompt.is_file(), f'Missing original generation prompt: {role}'
    with Image.open(source) as im:
        assert im.width == im.height and 'A' in im.getbands(), 'Expected original transparent square'
        alpha = im.getchannel('A')
        assert alpha.getextrema()[0] == 0, 'Missing alpha negative space'
        bounds = alpha.point(lambda v: 255 if v > 20 else 0).getbbox()
        assert bounds, 'Empty effect'
        size = list(im.size)
    target = BASE / (role + '.png')
    assert not target.exists(), f'Use a new versioned role rather than overwrite {role}'
    shutil.copy2(source, target)
    path = BASE / 'manifest.json'
    manifest = json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'generator': 'built-in ImageGen', 'original_rgba': True, 'assets': {}}
    manifest['assets'][role] = {'file': target.name, 'original': str(source), 'size': size, 'ink': list(bounds), 'sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'prompt': str(prompt.relative_to(ROOT)).replace('\\', '/')}
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'Installed original {role}: {size}, ink={bounds}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source')
    parser.add_argument('role')
    args = parser.parse_args()
    install(args.source, args.role)
