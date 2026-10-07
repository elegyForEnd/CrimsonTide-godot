"""Read-only provenance and useful silhouette measurements of actual attack art."""
import hashlib
import json
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/combat/imagegen-mechanics'
j = json.loads((BASE / 'manifest.json').read_text(encoding='utf-8'))
errors = []
for role, entry in j['assets'].items():
    path = BASE / entry['file']
    if hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']: errors.append(role+': original pixels changed')
    if not (ROOT / entry['prompt']).is_file(): errors.append(role+': prompt missing')
    with Image.open(path) as im:
        if im.width != im.height or 'A' not in im.getbands(): errors.append(role+': square alpha contract')
        alpha=im.getchannel('A')
        if alpha.getextrema()[0]!=0: errors.append(role+': opaque background')
        ink=alpha.point(lambda v:255 if v>20 else 0).getbbox()
        width,height=ink[2]-ink[0],ink[3]-ink[1]
        if role in ['projectile_arrow','projectile_bullet','projectile_needle','motion_thrust'] and width/height<8: errors.append(role+': narrow attack has a broad silhouette')
        if role in ['motion_spin','motion_heavy_spin'] and alpha.getpixel((im.width//2,im.height//2))>32: errors.append(role+': swing circle has a filled center')
        print(f'{role}: ink aspect {width/height:.2f}')
print(f'WEAPON MECHANIC ART {len(j["assets"])} originals, {len(errors)} failures')
for error in errors: print(error)
raise SystemExit(1 if errors else 0)
