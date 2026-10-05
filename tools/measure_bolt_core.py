"""Measure the solid core disc of a staged bolt from its own scan lines.

The disc is drawn as a plain filled circle in ENEMY_BOLT_TINT, so its widest row
and tallest column are exactly its diameter; the halo is far dimmer and the
sprite highlight is local, so both fall below a mid-level red threshold.  This
reports the disc's width/height in physical pixels, at the device scale printed
alongside.
"""
import sys
from PIL import Image

def extent(px, w, h, cx, cy, radius, predicate):
    best_w = best_h = 0
    for dy in range(-radius, radius + 1):
        run = 0
        for dx in range(-radius, radius + 1):
            if predicate(px[cx + dx, cy + dy]):
                run += 1
                best_w = max(best_w, run)
            else:
                run = 0
    for dx in range(-radius, radius + 1):
        run = 0
        for dy in range(-radius, radius + 1):
            if predicate(px[cx + dx, cy + dy]):
                run += 1
                best_h = max(best_h, run)
            else:
                run = 0
    return best_w, best_h


def make_disc(level):
    """Red channel above the halo's contribution, but not the white core."""
    def disc(p):
        r, g, b = p[:3]
        return r >= level and g <= r * 0.80 and b <= r * 0.85
    return disc


CENTRES = {
    "enemy-bullets-readability-dark.png": [(787, 509), (1011, 509), (1235, 509), (1459, 509)],
}
RADIUS = 90

for path in sys.argv[1:]:
    image = Image.open(path).convert("RGB")
    name = path.replace("\\", "/").split("/")[-1]
    print("%s  %dx%d" % (path, image.size[0], image.size[1]))
    for cx, cy in CENTRES.get(name, []):
        for level in (60, 90, 110, 130, 150, 170):
            bw, bh = extent(image.load(), image.size[0], image.size[1], cx, cy, RADIUS, make_disc(level))
            print("    bolt (%4d,%4d) red>=%3d : widest row=%3d px, tallest col=%3d px" % (cx, cy, level, bw, bh))
        print("")
