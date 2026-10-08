"""Locate colored metal assemblies in original sprite cells; write landmarks only."""
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

BASE = Path(__file__).resolve().parents[1] / 'assets/combat/weapon-atlases'

def locate(rgba, contact=False, bow=False, raised_pistol=False, anticipation=''):
    rgb = rgba[:, :, :3].astype(float) / 255
    h, w = rgba.shape[:2]
    yy, xx = np.indices((h, w))
    hi, lo = rgb.max(2), rgb.min(2)
    saturation = (hi-lo) / np.maximum(hi, .001)
    opaque = rgba[:, :, 3] > 120
    colored = opaque & (saturation > .27) & (hi > .25)
    r, g, b = rgb.transpose(2, 0, 1)
    gold = opaque & (r > .38) & (g > .24) & (b < g*.83) & (r > g*.85) & (r < g*2.25)
    if contact or anticipation:
        # Authored contact keys extend the business end to screen-right.
        # Silver/black blades are frequently disconnected from gold hilts;
        # use the opaque distal silhouette rather than a hair ribbon's gold.
        sy, sx = np.nonzero(opaque)
        edge = int(sx.max())
        rows = np.flatnonzero(opaque[:, edge])
        tip_y = float(rows[np.argmin(abs(rows-np.median(rows)))])
        if bow:
            # Arrow release occurs at the middle of the bow, not at a limb tip.
            right = opaque[:, int(w*.65):]
            ys = np.flatnonzero(right.sum(1)>2)
            if len(ys):
                middle=float((ys[0]+ys[-1])*.5)
                by,bx=np.nonzero(opaque & (xx>w*.62) & (abs(yy-middle)<h*.08))
                if len(bx):
                    edge=int(bx.max())
                    near=bx==edge
                    candidates=by[near]
                    tip_y=float(candidates[np.argmin(abs(candidates-middle))])
        tip = [edge, tip_y]
        if anticipation in ['top','upper-left']:
            allowed=opaque & ((xx<w*.42) | (xx>w*.65))
            if anticipation=='upper-left': allowed &= yy<h*.55
            py,px=np.nonzero(allowed)
            if len(px):
                chosen=int(np.argmin(px)) if anticipation=='upper-left' else int(np.argmin(py))
                tip=[int(px[chosen]),int(py[chosen])]
                edge,tip_y=tip
        if raised_pistol:
            py, px = np.nonzero(gold & (xx>w*.54) & (yy<h*.55))
            if len(px)>4:
                edge=int(px.max())
                near=px==edge
                candidates=py[near]
                tip=[edge,float(candidates[np.argmin(abs(candidates-np.median(candidates)))])]
                tip_y=tip[1]
        # Fit the visible distal edge to infer the shaft/blade direction.
        length = max(12,int(h*.14))
        patch = opaque[:, max(0,edge-length):edge+1]
        py, px = np.nonzero(patch)
        px = px+max(0,edge-length)
        near = abs(py-tip_y)<h*.13
        if near.sum()>8:
            px, py = px[near], py[near]
            cov = np.cov(np.stack((px,py)))
            _, vectors = np.linalg.eigh(cov)
            axis = vectors[:,-1]
            if axis[0]<0: axis=-axis
            # A broad hammer/bow head is not the shaft: use its torso-facing axis.
            if axis[0]<.45 or bow: axis=np.array([1.,0.])
            grip = np.array(tip)-axis*h*.25
        else:
            grip = np.array([w*.55,tip_y])
        if contact:
            assembly=locate(rgba)
            if assembly is not None and np.linalg.norm(np.array(assembly[1])-np.array(tip))<h*.18:
                grip=np.array(assembly[2],dtype=float)
        return (1.,tip,grip.tolist())
    # Pale hair and dark clothing cannot bridge the weapon's colored assembly.
    connected = ndimage.binary_closing(colored, iterations=2)
    labels, total = ndimage.label(connected)
    best = None
    for label in range(1, total+1):
        selected = (labels == label) & opaque
        sy, sx = np.nonzero(selected)
        if len(sx) < 18 or (gold & selected).sum() < 4:
            continue
        outside = ((sx < w*.32) | (sx > w*.68) | (sy < h*.25)).mean()
        if outside < .08:
            continue
        span = np.hypot(np.ptp(sx), np.ptp(sy))
        distance = np.hypot((sx-w*.50), (sy-h*.50))
        score = span * (.2+outside) * np.sqrt(min(len(sx), 1800))
        if best is None or score > best[0]:
            tip_index = int(np.argmax(distance))
            # Grip is the assembly's closest point to the torso/hand zone.
            grip_index = int(np.argmin((sx-w*.50)**2+(sy-h*.52)**2))
            best = (score, [int(sx[tip_index]), int(sy[tip_index])],
                    [int(sx[grip_index]), int(sy[grip_index])])
    return best

def register(contact_only=False, charge_only=False):
    path = BASE / 'manifest.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    cache = {}
    files = {}
    found = 0
    missing = []
    for key, atlas in data['atlases'].items():
        for state, frames in atlas['states'].items():
            for index, frame in enumerate(frames):
                name = frame.get('file', atlas.get('file'))
                region = frame['region']
                identity = int(key.split('/')[1])
                bow = identity in [625,628,632]
                contact = state in ['attack','art'] and index==2
                if contact_only and not contact: continue
                anticipation=''
                if state in ['attack','art'] and index==1:
                    anticipation = 'right' if identity in [601,605,609,617,642] or identity in range(624,636) else 'upper-left' if identity in [600,603] else 'top'
                if charge_only and not anticipation: continue
                raised_pistol = key.startswith('3/') and identity in [627,635]
                cell_key = (name, *region, contact, bow, raised_pistol,anticipation)
                if cell_key not in cache:
                    if name not in files:
                        files[name] = np.asarray(Image.open(BASE/name).convert('RGBA'))
                    x, y, w, h = map(int, region)
                    cache[cell_key] = locate(files[name][y:y+h, x:x+w],contact,bow,raised_pistol,anticipation)
                result = cache[cell_key]
                if result:
                    _, tip, grip = result
                    # Retain the original hand-reviewed attack tip for hero 0's first three.
                    if not (key in ['0/600','0/601','0/602'] and state == 'attack' and index==2):
                        frame['socket'] = tip
                    frame['grip'] = grip
                    frame['mount_method'] = 'distal contact silhouette' if contact else 'anticipation weapon extremity' if anticipation else 'colored metal assembly; automatic'
                    found += 1
                else:
                    missing.append({'atlas':key,'state':state,'frame':index})
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    report = {'registered':found,'fallback':missing,'note':'Automatic landmarks require visual review; no raster pixels changed.'}
    if not contact_only and not charge_only: (BASE/'mount-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Metal assemblies: {found}/{384 if contact_only or charge_only else 4608}; {len(missing)} retained fallback mounts')

if __name__ == '__main__':
    register('--contact-only' in sys.argv,'--charge-only' in sys.argv)
