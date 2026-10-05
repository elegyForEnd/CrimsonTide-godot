"""Read-only alpha validation: never modifies the generated sprites."""
from pathlib import Path
from PIL import Image
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / 'assets/rogue/animations'
report = []
hd = '--hd' in sys.argv
spec = json.loads((DIR / ('hd-source-manifest.json' if hd else 'source-manifest.json')).read_text(encoding='utf8'))
for record in spec['assets']:
    path = DIR / record['file']
    image = Image.open(path).convert('RGBA')
    cols = record['columns']
    rows = record.get('used_rows', record['rows'])
    alpha = image.getchannel('A').point(lambda a: 255 if a >= 31 else 0)
    gutters = []
    bounds = []
    for row in range(rows):
        for col in range(cols):
            left, top = col * image.width // cols, row * image.height // rows
            right, bottom = (col + 1) * image.width // cols, (row + 1) * image.height // rows
            box = alpha.crop((left, top, right, bottom)).getbbox()
            if not box:
                raise RuntimeError(f'Empty frame: {path.name} / {row},{col}')
            gap = min(box[0], box[1], right - left - box[2], bottom - top - box[3])
            gutters.append(gap)
            bounds.append({'cell': [left, top, right-left, bottom-top], 'alpha_bounds': list(box), 'gutter': gap})
    report.append({'file': path.name, 'width': image.width, 'height': image.height, 'frames': cols*rows,
                   'min_gutter': min(gutters), 'cells': bounds})
    print(f'{path.name}: {cols*rows} frames, minimum alpha gutter {min(gutters)}px')
    if min(gutters) < 64:
        raise RuntimeError(f'Insufficient frame padding: {path.name}')
(DIR / ('hd-alpha-validation.json' if hd else 'alpha-validation.json')).write_text(json.dumps(report, indent=2), encoding='utf8')
print('Frames', sum(x['frames'] for x in report), 'sheets', len(report))
