"""One independently generated 3x3 square per effect; no crowded multi-effect sheet."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/bosses/imagegen/actions'
old=json.loads((BASE/'catalog-v3.json').read_text(encoding='utf-8'))['assets']
assets=[]
for spec in old:
    horizontal=spec['style'] in ['flow','field','directional','projectile','blade']
    pivot='LEFT source/grip at 16% width and 55% height of each cell, pointed RIGHT' if horizontal else 'grounded contact at 50% width and 82% height of each cell, upright side view'
    prompt=(f"Use case: stylized-concept. Final production 2D dark gothic fantasy game VFX animation atlas: {spec['key']} / {spec['role']}. "
        "Create ONE effect on its OWN large SQUARE 1:1 transparent RGBA canvas, native high detail; EXACTLY THREE equal columns by THREE equal rows, exactly NINE separate square animation frames. "
        "Do NOT make a 6x6, 4x4, wide banner, or combine multiple different effects. This whole image is exclusively one continuous animation of ONE subject. "
        f"Subject: {spec['subject']}. Painted materials/palette: {spec['palette']}. The attached reference contains the old boss motifs for stylistic guidance ONLY; focus exclusively on this specified subject. "
        "Read left-to-right top row then middle row then bottom row. Frame 0 tiny dormant/anticipation hint, frame 1 stronger preparation, frame 2 initial release/contact, frame 3 strongest attack/follow-through, "
        "frames 4,5,6 three visibly different sustained active/flowing poses, frame 7 collapse, frame 8 faint debris/mist/embers. "
        "Actual deformation and material motion between frames, not nine duplicates or nine scaling variants. For grounded objects show real emergence and destruction; "
        "for falling objects show actual dropping/contact and fragments; for projectiles show distinct flying/wing/electric/liquid poses; for slashes show stroke growth and broken afterimages. "
        f"Registration: fixed {pivot}; constant apparent scale and source anchor across all nine frames. "
        "Subject maximum extent stays within 70% width and 70% height of each cell. Minimum 15% genuinely EMPTY transparent margin all sides. No neighbouring-frame overlap. "
        "Beautiful sharp elegant painted fantasy art readable in-game, restrained bloom, distinct silhouettes. Horizontal attacks must use narrow filaments and source-to-tip trails, not a surrounding energy bubble. "
        "No characters, scenery, opaque floor background, text, numbers, labels, drawn grid lines, checkerboard artwork, watermark, circular badges, generic circle/sector warning shapes. "
        "True alpha background with empty gutters. Do not copy the reference background or its labels. High quality, crisp native detail in all nine large cells.")
    assets.append({**spec,'file':spec['key']+'-'+spec['role']+'-3x3-v5.png','columns':3,'rows':3,'prompt':prompt})
(BASE/'catalog-3x3-v5.json').write_text(json.dumps({'date':'2026-10-06','generator':'built-in image_gen','format':'one effect per native square 3x3 atlas','assets':assets},indent=2)+'\n',encoding='utf-8')
print('68 independent 3x3 square atlases planned, 612 frames')
