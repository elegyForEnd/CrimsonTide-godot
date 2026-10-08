"""Register approved source selections without modifying any image pixels.

Gutters become AtlasTexture regions; one ground plane and body scale per row
preserve authored bob/airborne poses. Packing problems are recorded for repair.
"""
import hashlib
import json
import re
import statistics
from pathlib import Path

import numpy as np
from PIL import Image
from install_weapon_atlas import boundaries

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/combat/weapon-atlases'
RAW = BASE / 'raw'
STATES = ['idle', 'walk', 'run', 'dodge', 'attack', 'art']
CATEGORIES = {624: 'rifle', 625: 'bow', 626: 'crossbow', 627: 'pistol',
              628: 'bow', 629: 'rifle', 630: 'rifle', 631: 'dual-pistols',
              632: 'bow', 633: 'rifle', 634: 'crossbow', 635: 'pistol'}
CATEGORIES.update({i: 'staff' for i in range(636, 648)})


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def integrate():
    manifest = json.loads((BASE / 'manifest.json').read_text(encoding='utf-8'))
    old = manifest['atlases']
    atlases = {}
    issues = []
    pages = []
    for index in ['generation-status.json', 'other-heroes-generation-status.json']:
        pages.extend(json.loads((RAW / index).read_text(encoding='utf-8'))['completed_character_files'])

    def splits(counts, n, filename, axis):
        try:
            return boundaries(counts.tolist(), n)
        except AssertionError:
            # A low-alpha fringe may bridge a gutter. Do not alter the original.
            cuts = [0]
            for i in range(1, n):
                expected = round(len(counts) * i / n)
                span = round(len(counts) / n * .18)
                lo, hi = expected - span, expected + span
                candidates = np.flatnonzero(counts[lo:hi] == counts[lo:hi].min()) + lo
                cuts.append(int(min(candidates, key=lambda x: abs(x - expected))))
            issues.append({'file': filename, 'issue': 'No fully clear gutter', 'axis': axis})
            return cuts + [len(counts)]

    for filename in pages:
        match = re.fullmatch(r'hero-(\d)-weapons-(\d+)-(\d+)-(\w+)-v\d+\.png', filename)
        if match:
            hero, first, last = map(int, match.group(1, 2, 3))
            rows = [(weapon, match[4]) for weapon in range(first, last + 1)]
        else:
            match = re.fullmatch(r'hero-(\d)-weapon-(\d+)-locomotion-v\d+\.png', filename)
            if match:
                hero, weapon = map(int, match.group(1, 2))
                rows = [(weapon, state) for state in STATES[:3]]
            else:
                match = re.fullmatch(r'hero-(\d)-ranged-(.+)-(locomotion|combat)-v\d+\.png', filename)
                assert match, filename
                hero = int(match[1])
                weapons = [i for i, category in CATEGORIES.items() if category == match[2]]
                rows = [(weapons, state) for state in (STATES[:3] if match[3] == 'locomotion' else STATES[3:])]
        source = RAW / filename
        rgba = np.asarray(Image.open(source).convert('RGBA'))
        h, w = rgba.shape[:2]
        mask = rgba[:, :, 3] > 96
        ys = splits(mask.sum(axis=1), 3, filename, 'rows')
        provenance = {'source': 'raw/' + filename, 'sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'size': [w, h]}
        for row, (weapons, state) in enumerate(rows):
            top, bottom = ys[row:row + 2]
            xs = splits(mask[top:bottom].sum(axis=0), 4, filename, 'columns-%d' % row)
            frames, heights, grounds = [], [], []
            for col in range(4):
                left, right = xs[col:col + 2]
                cell = mask[top:bottom, left:right]
                yy, xx = np.nonzero(cell)
                assert len(xx), (filename, row, col)
                ink = [int(xx.min()), int(yy.min()), int(xx.max()) + 1, int(yy.max()) + 1]
                cw, ch = right - left, bottom - top
                # Central torso/boots exclude most extended blades and polearms.
                strip = cell[:, int(cw * .32):int(cw * .65)]
                occupied = np.flatnonzero(strip.sum(axis=1) >= max(3, cw * .025))
                assert len(occupied), filename
                # Boots can extend outside the torso strip while running.
                solid_rows = np.flatnonzero(cell.sum(axis=1) >= max(4, cw * .025))
                ground = int(solid_rows[-1])
                heights.append(ground - int(occupied[0]) + 1)
                grounds.append(ground)
                tip_x = ink[2] - 1
                tip_y = float(np.median(np.flatnonzero(cell[:, tip_x])))
                frames.append({'region': [left, top, cw, ch], 'ink': ink,
                               'pivot': [cw * .5, 0], 'socket': [tip_x, tip_y],
                               'file': 'raw/' + filename})
                if min(ink[0], ink[1], cw - ink[2], ch - ink[3]) < 2:
                    issues.append({'file': filename, 'row': row, 'frame': col, 'issue': 'Source touches frame edge'})
            # A shared baseline keeps running lift and dodge height in the art.
            for frame in frames:
                frame['pivot'][1] = max(grounds)
            height = statistics.median(heights)
            for weapon in weapons if isinstance(weapons, list) else [weapons]:
                key = f'{hero}/{weapon}'
                atlas = atlases.setdefault(key, {'enabled': True, 'states': {}, 'page_heights': {}, 'sources': {},
                                                'fps': {'idle': 3, 'walk': 7, 'run': 11.5}, 'contact_frames': {'attack': 2, 'art': 2}})
                atlas['states'][state] = frames
                atlas['page_heights']['raw/' + filename] = height
                atlas.setdefault('body_measurements', {})[state] = {'height': height}
                atlas['sources']['raw/' + filename] = provenance
                atlas.setdefault('standing_height', height)
                atlas.setdefault('file', 'raw/' + filename)
                if isinstance(weapons, list):
                    atlas['animation_category'] = CATEGORIES[weapon]
        del rgba, mask
    # Three-state pages share the standing row's scale, rather than fitting
    # a crouched dodge or running stride independently to standing height.
    for atlas in atlases.values():
        atlas['clip_heights'] = {}
        for state, measurement in atlas['body_measurements'].items():
            source = atlas['states'][state][0]['file']
            shared = [s for s, frames in atlas['states'].items() if frames[0]['file'] == source]
            standing = 'idle' if 'idle' in shared else 'attack' if 'attack' in shared else state
            atlas['clip_heights'][state] = atlas['body_measurements'][standing]['height']
    # Retain manually reviewed first-three attack anchors rather than regress them.
    for weapon in range(600, 603):
        key = f'0/{weapon}'
        previous = old[key]
        atlases[key]['states']['attack'] = previous['states']['attack']
        atlases[key]['page_heights'].update(previous['page_heights'])
        atlases[key]['sources'].update(previous['sources'])
        atlases[key]['anchor_review'] = previous['anchor_review']
        atlases[key]['clip_heights']['attack'] = previous['page_heights'][previous['states']['attack'][0]['file']]
    assert len(atlases) == 192
    for key, atlas in atlases.items():
        assert set(atlas['states']) == set(STATES), key
        assert all(len(frames) == 4 for frames in atlas['states'].values()), key
    manifest['atlases'] = atlases
    manifest['layout'] = 'Original RGBA; transparent gutters; four keys per state; fixed ground plane per clip'
    write(BASE / 'manifest.json', manifest)
    # Register distal blade/shaft landmarks used by both combat renderers.
    from register_weapon_mounts import register
    register()

    effects_base = ROOT / 'assets/combat/imagegen-mechanics'
    effects = json.loads((effects_base / 'manifest.json').read_text(encoding='utf-8'))
    for source in sorted((effects_base / 'raw').glob('weapon-*.png')):
        weapon, payload = re.fullmatch(r'weapon-(\d+)-(\w+)-v\d+\.png', source.name).groups()
        role = f'authored_{weapon}_{payload}'
        with Image.open(source) as image:
            ink = image.getchannel('A').point(lambda v: 255 if v > 20 else 0).getbbox()
            assert ink
            effects['assets'][role] = {'file': 'raw/' + source.name, 'ink': list(ink), 'size': list(image.size),
                                      'sha256': hashlib.sha256(source.read_bytes()).hexdigest()}
    write(effects_base / 'manifest.json', effects)
    from register_weapon_effect_contacts import register as register_contacts
    register_contacts()
    write(BASE / 'integration-report.json', {'characters': 4, 'weapons_per_character': 48, 'states': STATES,
        'clips': 1152, 'keys': 4608, 'original_pages': len(pages), 'extra_effects': 44,
        'packing_issues': issues, 'note': 'Original artwork unchanged; source quality repairs remain separate from runtime integration.'})
    print(f'Registered {len(atlases)} equipped atlases / 1152 clips; {len(issues)} source packing notices; 44 effects')


if __name__ == '__main__':
    integrate()
