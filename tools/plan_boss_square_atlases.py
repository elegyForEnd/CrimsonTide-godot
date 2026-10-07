import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT/'assets/bosses/imagegen/actions'
old = json.loads((BASE/'catalog-v3.json').read_text(encoding='utf-8'))['assets']
groups=[]
for key in dict.fromkeys(s['key'] for s in old):
    motifs=[s.copy() for s in old if s['key']==key]
    instructions=[]
    for i, s in enumerate(motifs):
        quadrant=['TOP LEFT','TOP RIGHT','BOTTOM LEFT','BOTTOM RIGHT'][i]
        instructions.append(f"{quadrant} 3x3 block, animation '{s['role']}': {s['subject']}. "
            + ('Face RIGHT; fixed origin at x=16%, y=55% of each little cell.' if s['style'] in ['flow','field','directional','projectile','blade'] else 'Upright; fixed grounded contact at x=50%, y=82% of each little cell.'))
    prompt=(f"Use case: stylized-concept. Production SQUARE transparent RGBA VFX sprite atlas for the 2D gothic fantasy boss '{key}'. "
        f"Palette: {motifs[0]['palette']}. Rework and animate the four effects in the reference; preserve their painted material and identity, remove the reference labels/background. "
        "The output MUST be a 1:1 SQUARE canvas. Exactly SIX equal columns by SIX equal rows, 36 small square cells. "
        "The square is divided into FOUR 3x3 animation blocks. Never use a wide banner. Each block has NINE different sequential animation poses of ONE effect, in row-major order within that block. "
        "Block-local frames 0-1: quiet preparation; 2-3: emission/real contact and peak attack; 4-5-6: three different active/sustained material poses; 7: collapse; 8: faint fragments. "
        "Show actual shape changes, deformation and emitted material across frames, NOT nine identical pictures. "
        + ' '.join(instructions) +
        " Every motif stays ONLY in its assigned block. Each tiny square cell has minimum 15% empty transparent margin; isolate every pose completely, NEVER touch cell boundaries or enter adjacent cells. "
        "Keep every origin/contact pivot and apparent scale consistent across its nine frames. Attacks are elegant, sharply painted and readable at 150 pixels, no noisy giant halos. "
        "Flowing effects must be narrow flowing filaments with no energy bubble; ground and falling entities retain upright silhouettes; wind/water remain flowing broken ribbons. "
        "No solid circles, sectors, warning polygons, circular badges, character bodies, scenery, text, numbers, drawn grid lines or checkerboard artwork. True transparent background. "
        "No opaque background copied from reference. High quality square atlas with generous alpha gutters.")
    groups.append({'key':key,'file':key+'-states-square-v4.png','columns':6,'rows':6,'motifs':motifs,'prompt':prompt})
(BASE/'catalog-square-v4.json').write_text(json.dumps({'generator':'built-in image_gen','date':'2026-10-06','assets':groups},indent=2)+'\n',encoding='utf-8')
print('17 square atlases, 68 motif animations, 612 frames planned')
