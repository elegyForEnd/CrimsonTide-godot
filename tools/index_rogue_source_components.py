"""Read-only source indexing, records disconnected sprite bounds and labels.

Does not modify images. Godot assembles the actual final atlas.
"""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / 'assets/rogue/animations'
hd = '--hd' in sys.argv
spec = json.loads((DIR / ('hd-source-manifest.json' if hd else 'source-manifest.json')).read_text(encoding='utf8'))
records = []
cache = ROOT / 'build/rogue-source-index'
cache.mkdir(parents=True, exist_ok=True)
for record in spec['assets']:
    path = DIR / ('hd-sources' if hd else 'sources') / record.get('source_file',record['file'])
    alpha = np.asarray(Image.open(path).convert('RGBA'))[:, :, 3]
    labels, count = ndimage.label(alpha >= 31)
    sizes = np.bincount(labels.ravel())
    major = [i for i in range(1, count+1) if sizes[i] > 800]
    boxes = ndimage.find_objects(labels)
    print(record['file'], 'major components', len(major), 'expected', record['rows']*record['columns'])
    centers = np.array(ndimage.center_of_mass(alpha >= 31, labels, range(1, count+1)))
    rows, cols = record['rows'], record['columns']
    height, width = alpha.shape
    primary = {}
    for i in major:
        y, x = centers[i-1]
        cell = min(rows-1, int(y*rows/height))*cols + min(cols-1, int(x*cols/width))
        if cell not in primary or sizes[i] > sizes[primary[cell]]:
            primary[cell] = i
    used = record.get('used_rows', rows)*cols
    if any(cell not in primary for cell in range(used)):
        print('REJECT merged or missing pose', record['file'])
        continue
    # Main sprites establish ownership; detached motes/staff jewels follow the
    # closest main sprite. Curved transparent gaps are allowed, so a long weapon
    # in one pose never forces a straight rectangular cut through its neighbor.
    keys = sorted(primary)
    primary_centers = centers[np.array([primary[k] for k in keys])-1]
    weights = np.array([height/rows, width/cols])
    component_owner = np.zeros(count+1, dtype=np.uint8)
    for i in range(1, count+1):
        distances = np.sum(((primary_centers-centers[i-1])/weights)**2, axis=1)
        component_owner[i] = keys[int(np.argmin(distances))]+1
    for cell, label in primary.items():
        component_owner[label] = cell+1
    # Map antialiased edge pixels to the nearest opaque component. This index
    # stores ownership metadata only; Godot copies the original RGBA unchanged.
    nearest = ndimage.distance_transform_edt(labels == 0, return_distances=False, return_indices=True)
    ownership = component_owner[labels[nearest[0], nearest[1]]]
    ownership[alpha == 0] = 0
    (cache / (record['file']+'.owners')).write_bytes(ownership.tobytes())
    frame_records = []
    for frame in range(used):
        ys, xs = np.where((ownership == frame+1) & (alpha >= 31))
        # Faint distant alpha dust must not determine the actor's scale or feet.
        # Keep eight pixels around visible art for smooth antialiased edges.
        left, top = max(0,int(xs.min())-8), max(0,int(ys.min())-8)
        right, bottom = min(width,int(xs.max())+9), min(height,int(ys.max())+9)
        frame_records.append({'bounds':[left, top, right-left, bottom-top]})
    records.append({'file': record['file'], 'width':width, 'height':height,
                    'ownership':'res://build/rogue-source-index/'+record['file']+'.owners', 'frames':frame_records})
(DIR / ('hd-source-components.json' if hd else 'source-components.json')).write_text(json.dumps(records, indent=2), encoding='utf8')
