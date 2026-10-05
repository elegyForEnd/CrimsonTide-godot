"""Measure the staged enemy projectiles in a capture, per bolt and per layer.

The capture is a 2x window, so every pixel figure below is physical; divide by
the device scale printed with it to read logical game pixels.

Masks, because the two pipelines differ in colour:
  * ordinary bolts - ENEMY_BOLT_TINT ff3350 over a hot core, i.e. red-dominant;
  * boss projectiles - a cyan-white additive shell in the boss's own tone.
"Solid" counts the near-white heart of a bolt, which is the part a player reads
as the projectile's body rather than its glow.
"""
import sys
from PIL import Image


def blobs(image, predicate, solid_test, min_pixels, region=None):
    w, h = image.size
    px = image.load()
    seen = bytearray(w * h)
    found = []
    x_lo, y_lo, x_hi, y_hi = region if region else (0, 0, w, h)
    for y in range(y_lo, y_hi):
        for x in range(x_lo, x_hi):
            i = y * w + x
            if seen[i] or not predicate(px[x, y]):
                continue
            stack = [(x, y)]
            seen[i] = 1
            n = solid = 0
            x0 = x1 = x
            y0 = y1 = y
            while stack:
                cx, cy = stack.pop()
                n += 1
                if solid_test(px[cx, cy]):
                    solid += 1
                x0 = min(x0, cx); x1 = max(x1, cx)
                y0 = min(y0, cy); y1 = max(y1, cy)
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not seen[j] and predicate(px[nx, ny]):
                            seen[j] = 1
                            stack.append((nx, ny))
            if n >= min_pixels:
                found.append((n, solid, x0, y0, x1 - x0 + 1, y1 - y0 + 1))
    return sorted(found, reverse=True)


def red_bolt(p):
    r, g, b = p[:3]
    return r > 150 and r - g > 60 and r - b > 30


def red_solid(p):
    r, g, b = p[:3]
    return r > 225 and g > 130 and b > 140


def boss_ink(p):
    """The boss bolt's whole envelope: the sprite plus its cyan additive shell."""
    r, g, b = p[:3]
    return b > 110 and (b - r) > 8 and (g - r) > 3


def near_white(p):
    r, g, b = p[:3]
    return r > 215 and g > 215 and b > 205


REGIONS = {
    "enemy-bullets-readability.png": {
        "boss@left": (500, 430, 800, 640),
        "bolt@x1460": (1390, 450, 1540, 610),
    },
    "enemy-bullets-readability-dark.png": {
        "boss@left": (520, 560, 800, 760),
    },
}


for path in sys.argv[1:]:
    image = Image.open(path).convert("RGB")
    name = path.replace("\\", "/").split("/")[-1]
    print("%s  %dx%d" % (path, image.size[0], image.size[1]))
    for label, region in REGIONS.get(name, {}).items():
        for kind, pred in (("ink", boss_ink), ("white", near_white)):
            found = blobs(image, pred, near_white, 60, region)
            print("  %s / %s blobs in %s: %d" % (label, kind, region, len(found)))
            for n, solid, x, y, bw, bh in found[:4]:
                print("    blob %6d px (%5d solid) at (%4d,%4d) bbox %4dx%4d" % (n, solid, x, y, bw, bh))
    reds = blobs(image, red_bolt, red_solid, 400)
    print("  ordinary bolt blobs: %d" % len(reds))
    for n, solid, x, y, bw, bh in reds[:6]:
        print("    blob %6d px (%5d solid) at (%4d,%4d) bbox %4dx%4d" % (n, solid, x, y, bw, bh))
