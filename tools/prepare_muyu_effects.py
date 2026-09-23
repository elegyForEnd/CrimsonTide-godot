"""Cuts the ultimate's effect art out of the supplied reference sheets.

Four pieces now, two of which arrive as screenshots of a transparent canvas with
the editor's transparency grid flattened into the pixels.  The grid is always two
flat greys, so it can be measured and removed; what differs between the sheets is
which signal separates art from grid.

  flames   the five-frame underworld flame.  Every flame is strongly saturated
           purple (chroma 55 and up) while the grid is neutral (chroma under 3),
           so saturation *is* the alpha: a pixel that carries no colour is grid,
           whatever grey it happens to be.  Reachability from the border is what
           keeps a genuinely neutral part of a flame from being punched out.
  circle   the rune ring that stands in for the drawn rectangle.  It has almost
           no broad colour of its own - it is linework and glow over the grid -
           so it is read positionally instead: which of the grid's two greys a
           pixel is closest to says how much art landed on it.
  sword    the rain blade, flat white backdrop, keyed like the character art.
  (raw)    anything supplied already carrying real alpha is passed through.

Everything the game consumes is written to assets/combat/.  Nothing here touches
the drawn rectangle: the damage test, the aim test and the drawn ring all read
the same TideSession constants, so the ring covers exactly the ground that burns.

Run:  python tools/prepare_muyu_effects.py               (all pieces, writes files)
      python tools/prepare_muyu_effects.py --preview      (contact sheet only)
      python tools/prepare_muyu_effects.py flames circle  (pick pieces)
"""

from __future__ import annotations

import argparse
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REFS = os.path.abspath(os.path.join(ROOT, "..", "..", "_refs"))
RAW = os.path.join(REFS, "muyu-effects")
OUT = os.path.join(ROOT, "assets", "combat")

FLAMES_REF = os.path.join(RAW, "flames-raw.jpg")
CIRCLE_REF = os.path.join(RAW, "circle-raw.jpg")
SWORD_REF = os.path.join(RAW, "sword-raw.png")

FLAME_CELLS = 5          # the sheet paints five frames of one flame
FLAME_COLUMNS = 5        # stored as one row, so a cell is width/5
# Cell size for the strip.  Every frame is fitted into its own cell rather than
# packed edge to edge: the painted flames are wider than a fifth of the sheet,
# so tight packing lets one frame bleed into the next cell's column and the
# neighbour's edge shows up inside the animation.
FLAME_CELL = (360, 560)

# Backdrop greys.  Measured off each sheet's border rather than assumed: the
# flame sheet's grid sits at 119/161 because the painting dims it, the circle's
# at 189/254 because it does not.
FLAME_GREY_HINT = (100.0, 190.0)
CIRCLE_GREY_HINT = (170.0, 262.0)
# What counts as backdrop: neutral enough, and bright enough to be the grid
# rather than the art.  The floor is below every sheet's dark grid square and
# above the ring's linework and the flames' outlines.
GRID_GATES = (12.0, 105.0)


def read(path: str) -> np.ndarray:
    if not os.path.exists(path):
        print("missing reference: %s" % path, file=sys.stderr)
        raise SystemExit(1)
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float32)


def trim_alpha(arr: np.ndarray, floor: int = 8) -> Image.Image:
    """Crop to the art, so what the game stretches is the art and not margin."""
    a = arr[:, :, 3]
    ys, xs = np.where(a > floor)
    if not len(ys):
        return Image.fromarray(arr, "RGBA")
    return Image.fromarray(arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")


def grid_levels(mn: np.ndarray, hint: tuple[float, float], band: int = 70) -> tuple[float, float]:
    """The grid's own dark grey and the checker step, measured on the border."""
    edge = np.concatenate([mn[:band].ravel(), mn[-band:].ravel(),
                           mn[:, :band].ravel(), mn[:, -band:].ravel()])
    hist, edges = np.histogram(edge, bins=64, range=(0, 256))
    centres = (edges[:-1] + edges[1:]) * 0.5
    lo, hi = hint
    inside = (centres >= lo) & (centres <= hi) & (hist > edge.size * 0.02)
    if not inside.any():
        return lo, 60.0
    peaks = centres[inside]
    weights = hist[inside].astype(np.float64)
    dark = float(peaks[int(np.argmax(np.where(peaks <= np.average(peaks, weights=weights),
                                            weights, 0)))])
    light = float(peaks[int(np.argmax(np.where(peaks >= dark + 15.0, weights, 0)))])
    return dark, max(20.0, light - dark)


def key_grid(rgb: np.ndarray, hint: tuple[float, float]) -> tuple[np.ndarray, np.ndarray]:
    """Alpha out a transparency grid, keeping everything that is not grid.

    A grid pixel is both *neutral* and *bright*: the grid is grey, and the sheet's
    weakest glow only tints it a little, whereas the art itself is either
    strongly coloured (a flame's body) or strongly dark (the ring's linework, a
    flame's outline).  So the test is chroma against a gate plus a floor on
    brightness, and only the grid the border can reach is removed - which is what
    keeps a neutral, dark part of the art from being punched out with it.

    Both gates are deliberately loose.  Tightening them to chase the faintest
    glow would start eating the art, and a pixel that is nearly grid grey is
    nearly invisible once the effect is composited on the game's dark ground, so
    there is nothing there worth saving."""
    mn = rgb.min(2)
    chroma = rgb.max(2) - mn
    gate, floor = GRID_GATES
    grid = (chroma <= gate) & (mn >= floor)
    labels, _ = ndimage.label(grid, structure=np.ones((3, 3), int))
    touch = np.unique(np.concatenate([labels[0, :], labels[-1, :],
                                      labels[:, 0], labels[:, -1]]))
    backdrop = np.isin(labels, touch[touch != 0])
    # Grow the removed region by one pixel so the grid's own anti-aliased edge
    # goes with it, and fade what is left by how much colour it carries.
    halo = ndimage.binary_dilation(backdrop, iterations=2) & ~backdrop
    alpha = np.where(backdrop, 0.0, 1.0)
    if halo.any():
        raw_fade = np.clip((chroma[halo] - gate * 0.5) / (gate * 2.0), 0.0, 1.0)
        # Push the low end of the halo towards nothing.  A barely-there glow is
        # not worth the grid that always comes with it: at a few percent opacity
        # the sheet's grey shell is more visible on dark ground than the glow it
        # is standing in for, so the fade starts later and climbs faster.
        alpha[halo] = np.clip((raw_fade - 0.35) / 0.5, 0.0, 1.0) ** 0.8
    # The halo's own alpha carries the grid as a ripple one square wide, because
    # the two parities of square let different amounts of grid grey through.  The
    # glow it stands for is smooth, so the ripple is filtered out of the alpha -
    # not out of the colour, which would dull the art.
    if halo.any():
        alpha = np.where(halo, ndimage.median_filter(alpha, size=15), alpha)
    dark, _ = grid_levels(mn, hint)
    a = alpha[..., None]
    art = np.where(a > 0.35, (rgb - dark * (1.0 - a)) / np.maximum(a, 0.35), rgb)
    return np.clip(art, 0, 255), alpha


# --- the flames ---------------------------------------------------------------

def build_flames() -> Image.Image:
    """Five painted frames, keyed and packed into one row.

    The atlas is a strip so `necro_cell()` can address it with a column count and
    a single row, the same way the pose sheets are addressed."""
    rgb = read(FLAMES_REF)
    art, alpha = key_grid(rgb, FLAME_GREY_HINT)
    keyed = np.dstack([art, alpha * 255.0]).astype(np.uint8)

    # Split the five painted flames apart and pack each into its own cell.
    # The alpha comes out of the key with a flame's interior linework open - a
    # key cannot tell the dark inside of a flame from a hole - so the crop is
    # taken from a solid region per flame instead: the fragments are joined,
    # filled, and only then used as the frame and the stencil.  The flames'
    # wisps also reach into the neighbouring columns, so that stencil is what
    # keeps the next flame out of this cell.
    art = keyed[:, :, 3] > 24
    joined = ndimage.binary_closing(art, structure=np.ones((3, 3), bool), iterations=8)
    labels, count = ndimage.label(joined, structure=np.ones((3, 3), int))
    blobs = []
    for index in range(1, count + 1):
        mask = ndimage.binary_fill_holes(labels == index)
        size = int(mask.sum())
        if size < 20000:
            continue
        ys, xs = np.where(mask)
        blobs.append((xs.min(), size, mask, xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    if len(blobs) != FLAME_CELLS:
        print("expected %d flames on the sheet, found %d" % (FLAME_CELLS, len(blobs)),
              file=sys.stderr)
        raise SystemExit(1)
    blobs.sort(key=lambda b: b[0])

    frames = []
    for _, _, mask, x0, y0, x1, y1 in blobs:
        crop = keyed[y0:y1, x0:x1].copy()
        crop[:, :, 3] = np.where(mask[y0:y1, x0:x1], crop[:, :, 3], 0)
        cell = Image.fromarray(crop, "RGBA")
        scale = min(FLAME_CELL[0] / float(cell.width), FLAME_CELL[1] / float(cell.height))
        frames.append(cell.resize((max(1, int(round(cell.width * scale))),
                                   max(1, int(round(cell.height * scale)))), Image.LANCZOS))
    # Every frame stands on its cell's bottom edge, because `stamp` anchors a
    # flame by its base: a shorter frame then plants itself rather than floating.
    strip = Image.new("RGBA", (FLAME_CELL[0] * FLAME_CELLS, FLAME_CELL[1]), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * FLAME_CELL[0] + (FLAME_CELL[0] - frame.width) // 2,
                                      FLAME_CELL[1] - frame.height))
    return strip


# --- the ring -----------------------------------------------------------------

def build_circle() -> Image.Image:
    """The rune ring, read off the grid it was flattened onto."""
    rgb = read(CIRCLE_REF)
    art, alpha = key_grid(rgb, CIRCLE_GREY_HINT)
    return trim_alpha(np.dstack([art, alpha * 255.0]).astype(np.uint8))


# --- the blade and the pass-through -------------------------------------------

def build_sword() -> Image.Image:
    """The rune blade, keyed off its white backdrop and left on its own axes."""
    rgb = read(SWORD_REF)
    mn, mx = rgb.min(2), rgb.max(2)
    white = (mn >= 238) & ((mx - mn) <= 20)
    labels, _ = ndimage.label(white, structure=np.ones((3, 3), int))
    touch = np.unique(np.concatenate([labels[0, :], labels[-1, :],
                                      labels[:, 0], labels[:, -1]]))
    grid = np.isin(labels, touch[touch != 0])
    alpha = np.where(grid, 0.0, 1.0)
    edge = ndimage.binary_dilation(grid, iterations=1) & ~grid
    if edge.any():
        alpha[edge] = np.clip((255.0 - mn[edge]) / 26.0, 0.0, 1.0)
    a = alpha[..., None]
    art = np.where(a > 0.05, (rgb - (1.0 - a) * 255.0) / np.maximum(a, 0.05), rgb)
    return trim_alpha(np.dstack([np.clip(art, 0, 255), alpha * 255.0]).astype(np.uint8))


BUILDERS = {
    "flames": ("muyu-flames.png", build_flames),
    "circle": ("muyu-circle.png", build_circle),
    "sword": ("muyu-sword.png", build_sword),
}


def report(name: str, art: Image.Image) -> None:
    a = np.asarray(art)[:, :, 3]
    print("  %-7s %4dx%-4d  alpha>200 %7d  soft %6d  transparent %7d" % (
        name, art.width, art.height, (a > 200).sum(),
        ((a > 8) & (a <= 200)).sum(), (a <= 8).sum()))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("pieces", nargs="*", default=[], help="flames, circle, sword")
    parser.add_argument("--preview", action="store_true", help="preview instead of install")
    args = parser.parse_args(argv)

    wanted = args.pieces or list(BUILDERS)
    unknown = [p for p in wanted if p not in BUILDERS]
    if unknown:
        print("unknown piece(s): %s" % ", ".join(unknown), file=sys.stderr)
        return 2

    built = {}
    for piece in wanted:
        built[piece] = BUILDERS[piece][1]()
        report(piece, built[piece])

    if args.preview:
        sheet = os.path.join(ROOT, "output", "muyu-effects")
        os.makedirs(sheet, exist_ok=True)
        for piece, art in built.items():
            art.save(os.path.join(sheet, "preview-%s.png" % piece))
            on_dark = Image.new("RGB", art.size, (24, 14, 20))
            on_dark.paste(art, (0, 0), art)
            on_dark.save(os.path.join(sheet, "preview-%s-dark.png" % piece))
        print("previews written to %s" % sheet)
        return 0

    os.makedirs(OUT, exist_ok=True)
    for piece, art in built.items():
        art.save(os.path.join(OUT, BUILDERS[piece][0]))
    print("墓煜 ultimate effects written to %s" % OUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
