"""Download a small, pinned CC0 material palette. No live API in the game.

Powered by Poly Haven (https://polyhaven.com). Cached files are verified before
reuse; the manifest records upstream checksums and the exact redistribution source.
"""
import hashlib
import json
import pathlib
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
TARGET = ROOT / 'assets/story/environment/pbr'
PALETTE = {
    'paving': 'cobblestone_floor_08',
    'soil': 'forest_ground_04',
    'masonry': 'old_stone_wall_02',
    'timber': 'weathered_brown_planks',
    'slate': 'roof_slates_02',
    'rock': 'rock_face_03',
    'mud': 'muddy_tracks',
    'iron': 'rusty_metal_04',
    'cloth': 'denim_fabric',
    'bark': 'bark_brown_02',
}


def request(url):
    for attempt in range(3):
        try:
            return urllib.request.urlopen(urllib.request.Request(
                url, headers={'User-Agent': 'CrimsonTideAssetPrep/1.0'}), timeout=90).read()
        except Exception:
            if attempt == 2:
                raise
            time.sleep(2)


def main():
    TARGET.mkdir(parents=True, exist_ok=True)
    assets = []
    for role, slug in PALETTE.items():
        files = json.loads(request(f'https://api.polyhaven.com/files/{slug}'))
        info = json.loads(request(f'https://api.polyhaven.com/info/{slug}'))
        maps = []
        for output, candidates in [('albedo', ['diff', 'Diffuse']),
                                   ('normal', ['nor_gl']), ('orm', ['arm'])]:
            key = next(key for key in candidates if key in files)
            formats = files[key]['2k']
            fmt = 'png' if 'png' in formats else 'jpg'
            entry = formats[fmt]
            dest = TARGET / f'{role}_{output}.{fmt}'
            if not dest.exists() or hashlib.md5(dest.read_bytes()).hexdigest() != entry['md5']:
                payload = request(entry['url'])
                assert hashlib.md5(payload).hexdigest() == entry['md5'], entry['url']
                dest.write_bytes(payload)
            maps.append({'file': dest.name, 'url': entry['url'], 'md5': entry['md5'],
                         'sha256': hashlib.sha256(dest.read_bytes()).hexdigest(),
                         'bytes': dest.stat().st_size, 'map': key})
            print(f'{role}/{output}: {dest.stat().st_size} bytes', flush=True)
        assets.append({'role': role, 'slug': slug, 'page': f'https://polyhaven.com/a/{slug}',
                       'license': 'CC0-1.0', 'resolution': '2k',
                       'authors': info.get('authors', {}), 'files': maps})
    (TARGET.parent / 'material-sources.json').write_text(json.dumps(
        {'provider': 'Poly Haven', 'license_page': 'https://polyhaven.com/license',
         'normal_convention': 'OpenGL +Y', 'orm_channels': 'R=AO, G=roughness, B=metallic',
         'assets': assets}, ensure_ascii=False, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
