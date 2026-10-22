"""Read-only provenance and useful silhouette measurements of actual attack art."""
import hashlib
import json
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/combat/imagegen-mechanics'
j = json.loads((BASE / 'manifest.json').read_text(encoding='utf-8'))
errors = []
legacy_without_prompt = 0
for role, entry in j['assets'].items():
    path = BASE / entry['file']
    if hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']: errors.append(role+': original pixels changed')
    if entry.get('prompt'):
        if not (ROOT / entry['prompt']).is_file(): errors.append(role+': prompt missing')
    elif entry.get('vfx_version') in ['layered-v2', 'smoke-v3', 'blade-v4', 'weapon-v5']:
        errors.append(role+': new asset prompt missing')
    else:
        legacy_without_prompt += 1
    with Image.open(path) as im:
        density = entry.get('density_mask', False)
        # Modern originals include native portrait chops and landscape beams.
        # Verify their declared size rather than forcing a square and stretching ink.
        if not density and 'A' not in im.getbands(): errors.append(role+': source alpha contract')
        if list(im.size) != entry.get('size', list(im.size)): errors.append(role+': source dimensions changed')
        alpha=im.convert('L') if density else im.getchannel('A')
        if alpha.getextrema()[0]!=0: errors.append(role+': missing zero-density background' if density else role+': opaque background')
        ink=alpha.point(lambda v:255 if v>20 else 0).getbbox()
        width,height=ink[2]-ink[0],ink[3]-ink[1]
        if role in ['projectile_arrow','projectile_bullet','projectile_needle','motion_thrust'] and width/height<8: errors.append(role+': narrow attack has a broad silhouette')
        if role in ['motion_spin','motion_heavy_spin'] and alpha.getpixel((im.width//2,im.height//2))>32: errors.append(role+': swing circle has a filled center')
        if role in ['projectile_arrow_v2','projectile_bullet_v2','projectile_needle_v2','motion_thrust_v2'] and width/height<3: errors.append(role+': redrawn directional stroke lost its long silhouette')
        if role in ['motion_spin_v2','motion_heavy_spin_v2','motion_quake_v2'] and alpha.getpixel((im.width//2,im.height//2))>32: errors.append(role+': redrawn swing lost its transparent center')
        if role == 'motion_heavy_slash_v3' and alpha.getpixel((im.width//2,im.height//2))>32: errors.append(role+': heavy cut covers its hollow interior')
        print(f'{role}: ink aspect {width/height:.2f}')
print(f'WEAPON MECHANIC ART {len(j["assets"])} originals, {len(errors)} failures')
print(f'Legacy entries without prompt metadata: {legacy_without_prompt}; new version entries require prompts')
for error in errors: print(error)
raise SystemExit(1 if errors else 0)
