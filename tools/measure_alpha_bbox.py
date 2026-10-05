"""Measure the opaque-pixel bounding box of enemy-bullet source art.

The Godot draw code fits a whole PNG into a target box, so transparent padding
in the source silently shrinks the visible projectile.  This reports the real
silhouette so a scale factor can be chosen from measured pixels rather than
from the nominal target box.
"""
import sys
from PIL import Image

def report(path):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    alpha = im.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        print("%s native=%dx%d bbox=NONE (fully transparent)" % (path, w, h))
        return
    x0, y0, x1, y1 = bbox
    bw, bh = x1 - x0, y1 - y0
    # Coverage at a few alpha thresholds, because soft glow tails count in a
    # raw bbox but read as almost nothing on screen.
    hist = alpha.histogram()
    total = w * h
    solid = sum(hist[64:])
    faint = sum(hist[16:64])
    print("%s" % path)
    print("  native            %dx%d" % (w, h))
    print("  alpha bbox        x=%d y=%d w=%d h=%d" % (x0, y0, bw, bh))
    print("  bbox fraction     %.3f x %.3f of native" % (bw / w, bh / h))
    print("  opaque(a>=64)     %d px (%.2f%% of image)" % (solid, 100.0 * solid / total))
    print("  faint(16<=a<64)   %d px (%.2f%%)" % (faint, 100.0 * faint / total))
    # Solid-core bbox: only pixels with meaningful alpha, i.e. what the eye
    # reads as the projectile body rather than its halo.
    core = alpha.point(lambda v: 255 if v >= 160 else 0).getbbox()
    if core:
        cx0, cy0, cx1, cy1 = core
        print("  core bbox(a>=160) x=%d y=%d w=%d h=%d" % (cx0, cy0, cx1 - cx0, cy1 - cy0))
    else:
        print("  core bbox(a>=160) NONE")

if __name__ == "__main__":
    for p in sys.argv[1:]:
        report(p)
