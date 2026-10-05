"""Install the selected existing PNG poses for an in-game animation review."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/combat/hero-animation-preview'
# Audited rear shoe sole centers. Both soles can have different image-space
# heights, so the global lowest-alpha band must never choose the support foot.
SWORD_REAR_SOLES = [[477.5, 1155], [467, 1149], [421, 1163], [449, 1127],
                    [204, 1040], [197, 1046], [528, 1115], [477, 1157]]


def foot(image):
    alpha = np.asarray(image.getchannel('A'))
    bottom = int(np.where(alpha > 128)[0].max()) + 1
    columns = np.flatnonzero((alpha[bottom-24:bottom] > 128).sum(axis=0) >= 3)
    return [float((columns.min() + columns.max()) / 2), float(bottom)]


def main():
    manifest = {}
    groups = [(0, 'sword', 'v3', 8), (0, 'walk', 'v4', 8),
              (1, 'walk', 'v3', 4), (2, 'walk', 'v3', 4)]
    # Opening anatomical crown excludes the curl, cap and weapon.
    crowns = {(0, 'sword'): 348, (0, 'walk'): 242,
              (1, 'walk'): 230, (2, 'walk'): 245}
    for hero, action, version, count in groups:
        key = f'heroes/hero-{hero}/{action}'
        source = ROOT / f'output/hero-animation-{version}/hero-{hero}/{action}'
        images = [Image.open(source / f'{n:03}.png').convert('RGBA') for n in range(count)]
        anchors = [foot(im) for im in images]
        first_bottom = anchors[0][1]
        height = first_bottom - crowns[(hero, action)]
        scales = [1.0] * count
        if hero in (1, 2):
            # Earlier walking drafts have canvas/scale drift. Normalize the
            # entire figure uniformly to their original first-frame scale.
            first_bbox = images[0].getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()
            target = first_bbox[3] - first_bbox[1]
            scales = []
            for im in images:
                box = im.getchannel('A').point(lambda a: 255 if a > 128 else 0).getbbox()
                scales.append(target / (box[3] - box[1]))
        if hero == 0 and action == 'walk':
            # v4 was authored on a locked canvas. Register its torso, not
            # whichever foot happens to occupy the lowest alpha band.
            anchors = [[735.0, 1166.0] for _ in images]
        elif action == 'walk':
            # Align the earlier size-varying drafts by the face/torso center.
            # Skin in this upper band excludes hands and purple/blue hair.
            for n, im in enumerate(images):
                rgb = np.asarray(im).astype(float)
                band = rgb[int(im.height*0.18):int(im.height*0.48)]
                skin = ((band[:,:,0] > band[:,:,1]*1.08)
                        & (band[:,:,1] > band[:,:,2]*0.98)
                        & (band[:,:,0] > 180) & (band[:,:,3] > 128))
                xs = np.where(skin)[1]
                if len(xs) > 100:
                    anchors[n][0] = float(np.median(xs)) - 40.0/scales[n]
        # Center the torso between the feet for locomotion; use the rear
        # supporting foot for the short sword to retain a stable attack origin.
        if action == 'sword':
            anchors = [list(point) for point in SWORD_REAR_SOLES]
        height = anchors[0][1] - crowns[(hero, action)]
        boxes = [im.getchannel('A').getbbox() for im in images]
        left = min((box[0]-anchor[0])*s for box, anchor, s in zip(boxes, anchors, scales))
        right = max((box[2]-anchor[0])*s for box, anchor, s in zip(boxes, anchors, scales))
        top = min((box[1]-anchor[1])*s for box, anchor, s in zip(boxes, anchors, scales))
        bottom = max((box[3]-anchor[1])*s for box, anchor, s in zip(boxes, anchors, scales))
        padding = 24
        size = (int(np.ceil(right-left))+padding*2, int(np.ceil(bottom-top))+padding*2)
        pivot = [-left+padding, -top+padding]
        directory = DEST / key
        directory.mkdir(parents=True, exist_ok=True)
        # Downsample once for game texture memory; original drawings remain intact.
        down = min(1.0, 900.0 / max(size))
        texture_size = tuple(int(round(v*down)) for v in size)
        for n, (im, anchor, s) in enumerate(zip(images, anchors, scales)):
            scaled = im.resize((round(im.width*s), round(im.height*s)), Image.Resampling.LANCZOS)
            canvas = Image.new('RGBA', size)
            canvas.alpha_composite(scaled, (round(pivot[0]-anchor[0]*s), round(pivot[1]-anchor[1]*s)))
            canvas.resize(texture_size, Image.Resampling.LANCZOS).save(directory / f'{n:03}.png')
        # Exact dimensions can round independently by <1 pixel. Use a single
        # scalar for layout and landmark, so rendered sprites remain uniform.
        pivot = [v*down for v in pivot]
        scale = 90.0 / (height*down)
        manifest[key] = {'path': 'res://assets/combat/hero-animation-preview/' + key,
                         'frame_count': count, 'pivot': pivot, 'facing': 1,
                         'standing_height': 90.0,
                         'rect': [-pivot[0]*scale, 16-pivot[1]*scale,
                                  texture_size[0]*scale, texture_size[1]*scale],
                         'source': str(source.relative_to(ROOT)).replace('\\', '/'),
                         'source_anchors': anchors, 'source_scales': scales,
                         'review_only': hero != 0}
    (DEST / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'Installed {sum(v["frame_count"] for v in manifest.values())} frames in {len(manifest)} actions')


if __name__ == '__main__':
    main()
