"""Install generated attacks with a stable support foot and uniform action scale."""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'output/attack-animation'
DEST = ROOT / 'assets/combat/generated-attacks'


def support(image, floating=False):
    alpha = np.asarray(image.getchannel('A'))
    ys, xs = np.where(alpha > 128)
    bottom = int(ys.max()) + 1
    # Use the sole band, not the whole silhouette (weapons, hair and skirts).
    band = alpha[max(0, bottom - 32):bottom] > 128
    occupied = np.flatnonzero(band.sum(axis=0) >= 3)
    splits = np.split(occupied, np.where(np.diff(occupied) > 14)[0] + 1)
    parts = [p for p in splits if len(p) >= 12]
    if not parts:
        parts = [occupied]
    # Rear support foot for humanoids; floating creatures use their lower center.
    chosen = occupied if floating else parts[0]
    return [int(round((int(chosen.min()) + int(chosen.max())) / 2)), bottom]


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = {}
    galleries = {'heroes': [], 'bosses': []}
    floating = {'earthsplitter', 'moon-leviathan', 'storm-roc-v2', 'mirror-weaver', 'ashen-vesper', 'nameless-moon'}
    landmarks = json.loads((ROOT/'tools/attack-foot-landmarks.json').read_text(encoding='utf-8'))
    for meta_path in sorted(SOURCE.glob('*/*/*/animation.json')):
        relative = meta_path.parent.relative_to(SOURCE)
        category, name, action = relative.parts
        images = [Image.open(meta_path.parent / f'{i:03}.png').convert('RGBA') for i in range(8)]
        anchors = [support(im, category == 'bosses' and name in floating) for im in images]
        key = relative.as_posix()
        if key in landmarks['anchors']:
            anchors = [[x*4,y*4] for x,y in landmarks['anchors'][key]]
        support_anchors = [a[:] for a in anchors]
        center_offset = landmarks['center_offsets'].get(key,0)*4
        anchors = [[x+center_offset,y] for x,y in anchors]
        boxes = [im.getbbox() for im in images]
        left = min(b[0]-a[0] for b,a in zip(boxes,anchors))-24
        top = min(b[1]-a[1] for b,a in zip(boxes,anchors))-24
        right = max(b[2]-a[0] for b,a in zip(boxes,anchors))+24
        bottom = max(b[3]-a[1] for b,a in zip(boxes,anchors))+24
        size = (right-left, bottom-top)
        # One scale for all 8 frames; never scale each pose by its changing bounds.
        texture_size = (round(size[0]/2), round(size[1]/2))
        pivot = [-left/2, -top/2]
        directory = DEST / relative
        directory.mkdir(parents=True, exist_ok=True)
        for i, (im, anchor) in enumerate(zip(images, anchors)):
            canvas = Image.new('RGBA', size)
            canvas.alpha_composite(im, (-anchor[0]-left, -anchor[1]-top))
            canvas.resize(texture_size, Image.Resampling.LANCZOS).save(directory / f'{i:03}.png')
        first_box = boxes[0]
        # Heroes use one anatomical scale across weapon actions. Bosses retain
        # their existing world height, measured from opening to ground.
        world_height = 100.0 if category == 'heroes' else {
            'bell-hierophant':185,'thorn-huntsman':185,'blood-queen':215,
            'mirror-weaver':185,'ashen-vesper':185,'nameless-moon':245,
            'earthsplitter':210,'storm-roc-v2':210,'moon-leviathan':275,'frostbone-dragon':240,
        }[name]
        scale = world_height / (anchors[0][1]-first_box[1]) * 2
        if category == 'heroes':
            # Opening crown-to-sole height excludes raised weapons and halos.
            # Keep this scale throughout the action, including crouched poses.
            scale = 90.0 / (anchors[0][1]-landmarks['opening_crowns'][key]*4) * 2
        offset = [0,16] if category == 'heroes' else [0,0]
        key = relative.as_posix()
        manifest[key] = {'path':'res://assets/combat/generated-attacks/'+key,
                         'frame_count':8, 'source_anchors':anchors, 'support_anchors':support_anchors,
                         'facing':-1 if name == 'earthsplitter' else 1, 'pivot':pivot,
                         'standing_height':90.0 if category == 'heroes' else world_height,
                         'rect': [offset[0]-pivot[0]*scale,offset[1]-pivot[1]*scale,
                                  texture_size[0]*scale,texture_size[1]*scale]}
        gallery = Image.new('RGB', (160*8, 190), '#282c36')
        draw = ImageDraw.Draw(gallery)
        for i, (im, anchor) in enumerate(zip(images, support_anchors)):
            tile = Image.new('RGBA', (160,160), '#282c36')
            tile.alpha_composite(im.resize((160,160)))
            gallery.paste(tile.convert('RGB'), (i*160, 20))
            x,y = i*160+anchor[0]*160/1536,20+anchor[1]*160/1536
            draw.line((x-6,y,x+6,y),fill='#00ffff',width=2)
            draw.line((x,y-6,x,y+6),fill='#00ffff',width=2)
        draw.text((4,2),key,fill='white')
        galleries[category].append(gallery)
    (DEST/'manifest.json').write_text(json.dumps(manifest, indent=2),encoding='utf-8')
    for category, rows in galleries.items():
        sheet=Image.new('RGB',(1280,190*len(rows)))
        for i,row in enumerate(rows): sheet.paste(row,(0,i*190))
        sheet.save(SOURCE/f'{category}-foot-review.jpg')
    print(f'Installed {len(manifest)} attacks / {len(manifest)*8} frames')


if __name__ == '__main__':
    main()
