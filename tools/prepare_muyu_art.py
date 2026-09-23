"""Cuts the 墓煜 (Muyu) art set out of the two supplied reference sheets.

The source sheets are painted on a near black, slightly blue studio backdrop with
a soft purple rim glow around every sprite. There is no alpha channel to key
against, so the backdrop is removed by colour distance to a per cut sample of
the sheet border, with a hue guard: saturated crimson / violet costume pixels
survive even where they are as dark as the backdrop, while the desaturated
backdrop itself falls away.

The reference sheet packs its poses almost edge to edge - hair of one pose
overlaps the book of the next. Cropping on a rectangle therefore drags a
detached neighbour fragment into the cut, so every pose is cut in three steps:

  1. a hand measured x-window per pose that stops short of the neighbour,
  2. connected component labelling of the keyed alpha, keeping only the
     silhouette that owns the window (and thin parts that genuinely touch it),
  3. a hard mask of everything outside that silhouette, so nothing else can be
     composited into the frame.

Everything the game consumes is written here:

  assets/combat/attack-clean-3.png   1448x1086, 4 columns x 3 rows, one row per
                                     weapon family, same layout as heroes 0..2
  assets/combat/movement-3.png       1448x1086, 4 columns x 3 rows = walk / run
                                     / dodge, weapons stowed
  assets/portrait-3.png              camp + result screen bust
  assets/muyu-idle.png               single standing pose
  assets/muyu-down.png               single fallen pose
  assets/muyu/ultimate-cg.png        three row cut-in for the Q cinematic
  assets/muyu/rune-rain.png          rune sword rain atlas (8 cells, 4x2)
  assets/muyu/hellfire.png           underworld fire sheet (6 cells, 3x2)
  assets/muyu/hex-ring.png           curse circle for the ultimate telegraph
  assets/muyu/soul-scythe.png        initial weapon: the rune cross blade
  assets/muyu/grimoire.png           the floating grimoire the hero carries
  assets/muyu/amulet.png             knight's amulet loot icon (1x1, red)
  assets/muyu/hidden-boss.png        portrait for the hidden final encounter

The effects come from assets/muyu/raw/, four hand cropped pieces of the same
reference sheet: the curse sigil, the rune cross, the rune lance and the
grimoire. Drop a replacement in that folder under the same name and every effect
built from it follows. The only drawn effect is the underworld fire, which the
reference sheet does not contain; _flame() is the one place to replace.

Run:  python tools/prepare_muyu_art.py
      python tools/preview_muyu_art.py   (contact sheets in output/muyu-preview)
"""

from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REFS = os.path.abspath(os.path.join(ROOT, "..", "..", "_refs"))
ASSETS = os.path.join(ROOT, "assets")
OUT = os.path.join(ASSETS, "muyu")

SHEET1 = os.path.join(REFS, "ref1-battle.png")   # 1448 x 1086 key art + demo
SHEET2 = os.path.join(REFS, "ref2-sprite.png")   # 2048 x 1152 full sprite sheet

# Hand cropped effect art, lifted from the same reference sheet at full
# resolution: the curse sigil, the rune cross blade, the rune lance and the
# floating grimoire. Everything the hero's effects are built from lives here, so
# replacing one of these files replaces that effect everywhere.
RAW_DIR = os.path.join(ASSETS, "muyu", "raw")
RAW_FILES = {
    "hex-ring": "hex-ring-raw.png",
    "rune-cross": "rune-cross-raw.png",
    "rune-lance": "rune-lance-raw.png",
    "grimoire": "grimoire-raw.png",
}

HOUSE_SIZE = (1448, 1086)
HOUSE_CELL = (362, 362)
HOUSE_FOOT_Y = 361.0        # rows 0 and 1 sit their feet on this line
HOUSE_FOOT_Y2 = 361.0       # the dodge row keeps the same floor line

# Hero 0 is the house style: its walk row stands 296..303 px inside a 362 px
# cell with the feet on y=361. Every Muyu pose is scaled to that height so all
# four heroes share one on-screen scale and one head size.
HOUSE_STAND_H = 299.0
SAFE_TOP = 3                # no sprite may touch the top edge of its cell
SAFE_SIDE = 10              # or the left / right edges


# --- backdrop removal --------------------------------------------------------

def backdrop_refs(rgb: np.ndarray) -> np.ndarray:
    """Reference backdrop colours, sampled once from the whole sheet border.

    Keying must use one reference for the whole sheet: a per cut sample lets two
    windows disagree about the same pixel, which is how a faint studio glow ends
    up as a grey haze inside one frame and not the next. The border pixels give
    a handful of colours and the darkest third is kept, because the vignette
    only ever makes the backdrop darker and a border that clips the art would
    push the reference the wrong way."""
    h, w, _ = rgb.shape
    picks = []
    for y in range(0, h, max(1, h // 64)):
        picks.append(rgb[y, 0]); picks.append(rgb[y, 1]); picks.append(rgb[y, 2])
        picks.append(rgb[y, w - 1]); picks.append(rgb[y, w - 2]); picks.append(rgb[y, w - 3])
    for x in range(0, w, max(1, w // 64)):
        picks.append(rgb[0, x]); picks.append(rgb[1, x]); picks.append(rgb[2, x])
        picks.append(rgb[h - 1, x]); picks.append(rgb[h - 2, x]); picks.append(rgb[h - 3, x])
    picks = np.asarray(picks, dtype=np.float32)
    order = np.argsort(picks.mean(axis=1))
    return picks[order[: max(2, len(order) // 4)]]


def key_background(img: Image.Image) -> Image.Image:
    """Alpha out the studio backdrop.

    Distance to the sheet's own backdrop colours is the whole key. A pixel the
    same colour as the studio floor becomes transparent, a pixel far from it
    becomes solid, and the narrow ramp between the two keeps the painted edge
    soft. Sheet 2 sits on pure black and sheet 1 on a dark violet panel, and
    measuring the ramp from the measured backdrop rather than from black is what
    lets both go through the same code."""
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    refs = backdrop_refs(rgb)
    dist = np.min(np.linalg.norm(rgb[:, :, None, :] - refs[None, None, :, :], axis=3), axis=2)
    alpha = np.clip((dist - 13.0) / 17.0, 0.0, 1.0)
    out = np.dstack([rgb, alpha * 255.0]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def strongest(img: Image.Image, keep: int = 1, floor: int = 400) -> Image.Image:
    """Keeps the biggest opaque silhouette and the substantial pieces near it.

    The hand cropped effect art was cut straight out of the sprite sheet, so a
    crop can carry the row caption and a spark of the neighbouring effect. The
    piece being kept is always much larger than that debris, so a component that
    is both small and detached is cleared rather than trimmed."""
    data = np.asarray(img).copy()
    alpha = data[:, :, 3] > 30
    labels, count = ndimage.label(alpha, structure=np.ones((3, 3), dtype=int))
    if count <= keep:
        return img
    sizes = ndimage.sum(alpha, labels, range(1, count + 1))
    order = np.argsort(sizes)[::-1]
    keep_ids = set(int(order[i]) + 1 for i in range(keep))
    out = np.zeros_like(alpha)
    for index in range(count):
        if index + 1 in keep_ids or sizes[index] >= floor:
            out |= labels == index + 1
    data[:, :, 3] = np.where(out, data[:, :, 3], 0)
    return Image.fromarray(data, "RGBA")


_RAW_CACHE: dict[str, Image.Image] = {}


def raw(name: str) -> Image.Image:
    """One hand cropped effect from the reference sheet, keyed and trimmed.

    These are painted on pure black with a soft magenta glow, which is exactly
    what key_background() expects, so the same key serves the effects and the
    character poses."""
    if name in _RAW_CACHE:
        return _RAW_CACHE[name]
    path = os.path.join(RAW_DIR, RAW_FILES[name])
    if not os.path.exists(path):
        raise SystemExit("missing effect art: %s" % path)
    art = trim(strongest(key_background(Image.open(path).convert("RGB"))))
    _RAW_CACHE[name] = art
    return art


def trim(img: Image.Image, pad: int = 3) -> Image.Image:
    box = img.getbbox()
    if box is None:
        return img
    if pad:
        box = (max(0, box[0] - pad), max(0, box[1] - pad),
               min(img.width, box[2] + pad), min(img.height, box[3] + pad))
    return img.crop(box)


def silhouette(img: Image.Image, inside: np.ndarray | None = None, seed: float = 0.5,
               grow: float = 0.12, gap: int = 16, min_px: int = 40) -> Image.Image:
    """Keeps the one figure that owns the picture, glow and all, and drops the rest.

    Every pose on the sheet is painted with a soft purple rim glow which is
    dimmer than the figure but far brighter than the backdrop, so a plain
    threshold either keeps a grey haze in the gaps or eats the painted edge.
    Regions are therefore taken whole: the alpha is cut at `grow` into connected
    regions, and a region is kept only when it contains a confident pixel above
    `seed`. The figure and the glow touching it stay; a halo that only ever
    drifts off a neighbouring pose never qualifies.

    What survives that is more than one region, because a pose wears its own
    detached art: the grimoire it holds out at arm's length, the rune bolts
    around its blade, the pages that fell with it. The largest region is the
    character, and a smaller one is kept when it is both close to the character
    and level with it. A lock of the neighbour's hair floating in the gap
    between two poses fails one test or the other, and a piece that runs out of
    `inside`, the rectangle the pose was measured in, was cut off by that
    rectangle and belongs to whoever stands there. Nothing detached is ever
    composited, so no frame can show a floating fragment."""
    data = np.asarray(img).copy()
    alpha = data[:, :, 3].astype(np.float32) / 255.0
    low = alpha > grow
    labels, count = ndimage.label(low, structure=np.ones((3, 3), dtype=int))
    if count == 0:
        data[:, :, 3] = 0
        return Image.fromarray(data, "RGBA")
    peak = ndimage.maximum(alpha, labels, range(1, count + 1))
    keep = np.isin(labels, [i + 1 for i in range(count) if peak[i] >= seed])
    solid, grown_count = ndimage.label(keep, structure=np.ones((3, 3), dtype=int))
    grown = np.asarray(solid, dtype=np.int32)
    if grown_count == 0:
        data[:, :, 3] = 0
        return Image.fromarray(data, "RGBA")
    if grown.ndim != 2:                     # a single region degenerates to a scalar
        grown = np.where(keep, 1, 0).astype(np.int32)
        grown_count = 1
    sizes = ndimage.sum(keep, grown, range(1, grown_count + 1))
    main = int(np.argmax(sizes)) + 1
    boxes = _boxes(grown, grown_count)
    my0, my1, mx0, mx1 = boxes[main - 1]
    drop = np.zeros_like(keep)
    for index in range(1, grown_count + 1):
        if index == main:
            continue
        y0, y1, x0, x1 = boxes[index - 1]
        if sizes[index - 1] < min_px:
            drop |= grown == index
            continue
        dx = max(mx0 - x1, x0 - mx1, 0)
        dy = max(my0 - y1, y0 - my1, 0)
        held = max(dx, dy) <= gap or sizes[index - 1] >= 500
        level = min(y1, my1) - max(y0, my0) > 0
        if not (held and level):
            drop |= grown == index
            continue
        if inside is not None and not inside[grown == index].all():
            drop |= grown == index       # cut off by the measured rectangle
            continue
    data[:, :, 3] = np.where(drop, 0, data[:, :, 3])
    return Image.fromarray(data, "RGBA")


def _boxes(labels: np.ndarray, count: int) -> list[tuple[int, int, int, int]]:
    """Inclusive (top, bottom, left, right) of every label, 1..count."""
    flat = np.ravel_multi_index(np.nonzero(labels), labels.shape)
    ids = labels[np.nonzero(labels)]
    order = np.argsort(ids, kind="stable")
    flat, ids = flat[order], ids[order]
    edges = np.searchsorted(ids, np.arange(1, count + 2))
    height, width = labels.shape
    out = []
    for index in range(count):
        chunk = flat[edges[index]:edges[index + 1]]
        rows, cols = np.divmod(chunk, width)
        out.append((int(rows.min()), int(rows.max()), int(cols.min()), int(cols.max())))
    return out


def frame(sprite: Image.Image, pad: int = 2) -> Image.Image:
    """Tight crop to the visible silhouette plus a hair of transparent margin."""
    box = sprite.getbbox()
    if box is None:
        return sprite
    box = (max(0, box[0] - pad), max(0, box[1] - pad),
           min(sprite.width, box[2] + pad), min(sprite.height, box[3] + pad))
    return sprite.crop(box)


def despeckle(sprite: Image.Image, min_px: int = 32) -> Image.Image:
    """Clears specks too small to be art, so no frame shows a stray dot."""
    data = np.asarray(sprite).copy()
    solid = data[:, :, 3] > 30
    labels, count = ndimage.label(solid, structure=np.ones((3, 3), dtype=int))
    if count == 0:
        return sprite
    sizes = ndimage.sum(solid, labels, range(1, count + 1))
    drop = np.isin(labels, [i + 1 for i in range(count) if sizes[i] < min_px])
    data[:, :, 3] = np.where(drop, 0, data[:, :, 3])
    return Image.fromarray(data, "RGBA")


# --- source geometry ---------------------------------------------------------
# Every rectangle below was measured off the two reference sheets with a
# coordinate grid, and is stored here rather than recomputed, so a rerun always
# cuts exactly the same pixels. x-windows deliberately stop short of the pose
# next door: sheet 2 packs its columns almost edge to edge.

# Sheet 1, bottom "精灵图 / Sprite" band: four battle ready poses plus props.
# These are the small key-art sprites and carry their own captions underneath
# (待机 / 施法 / 咒术刻印 / 远程攻击), which sit clear of the art.
S1 = {
    "idle":    (48, 858, 300, 1030),
    "cast":    (300, 858, 570, 1032),
    "hex":     (516, 852, 770, 1032),
    "bolt":    (770, 848, 1060, 1034),
    "book":    (742, 878, 828, 958),
    "bolt_fx": (1032, 872, 1440, 1010),
}
S1_KEYART = (0, 0, 250, 760)

# Sheet 2. The sheet leaves almost no gutter between its rows: the walk boots
# hang below the row its caption implies and the attack boots below theirs, and
# the robes above the 受击 row cross into it. Each window below was measured
# from the sheet, because one that stops a row short guillotines a boot.
S2 = {
    # 待机 - four standing poses
    "idle_a": (30, 14, 250, 264), "idle_b": (262, 14, 486, 264),
    "idle_c": (500, 14, 722, 264), "idle_d": (730, 14, 948, 264),
    # 行走 - four travelling poses
    "walk_a": (1026, 14, 1244, 264), "walk_b": (1206, 14, 1412, 264),
    "walk_c": (1386, 14, 1604, 264), "walk_d": (1598, 14, 1808, 266),
    # 普通攻击 - seven pointing / blade poses, then a spell-only cell
    "atk_a": (36, 262, 302, 534), "atk_b": (300, 262, 566, 534),
    "atk_c": (566, 262, 848, 534), "atk_d": (828, 262, 1092, 534),
    "atk_e": (1050, 262, 1314, 534), "atk_f": (1296, 262, 1560, 534),
    "atk_g": (1540, 262, 1780, 534), "atk_spell": (1776, 262, 2048, 534),
    # 技能 / 咒术 - five casting poses, then the rune burst
    "skill_a": (30, 500, 300, 790), "skill_b": (286, 500, 650, 790),
    "skill_c": (634, 500, 900, 790), "skill_d": (866, 500, 1116, 790),
    "skill_e": (1102, 500, 1396, 790),
    "skill_fx": (1386, 500, 2048, 790),
    # 受击 / 死亡 - four standing reels and two lying poses
    "hit_a": (40, 768, 258, 980), "hit_b": (258, 768, 440, 980),
    "hit_c": (444, 768, 630, 980), "hit_d": (620, 768, 796, 980),
    "down_a": (1230, 768, 1524, 985), "down_b": (1600, 768, 2048, 985),
    # 其他 - three extra standing poses
    "other_a": (48, 955, 266, 1142), "other_b": (268, 955, 514, 1142),
    "other_c": (504, 955, 726, 1142),
    # 特效素材 - effect strip. The measured bounds of each painted effect.
    "fx_ring": (826, 952, 986, 1092), "fx_arc": (1002, 950, 1152, 1162),
    "fx_cross": (1186, 952, 1248, 1170), "fx_blade": (1268, 950, 1458, 1180),
    "fx_pages": (1494, 950, 1730, 1140), "fx_book": (1644, 948, 1900, 1150),
    "fx_dagger": (1836, 950, 1898, 1160), "fx_sword": (1916, 950, 1966, 1150),
    "fx_nail": (2000, 950, 2048, 1150),
}

# The sheet captions every row, painting the label plus a one pixel rule under
# it. Both have to go before anything else, otherwise a rule line or a stray
# glyph is trimmed into the sprite beside it and reads as a floating fragment.
# The boxes below are the measured glyph boxes, as (left, top, right, bottom);
# they stop short of the nearest pose, which is why the 待机 box ends at x=62
# rather than continuing over the hero's hair. 死亡 and 咒术 are the two
# captions that are not in the top left corner.
S2_LABELS = [
    (16, 17, 46, 90),       # 待机
    (1078, 17, 1162, 70),   # 行走
    (260, 15, 292, 46),     # 普通攻击
    (500, 16, 530, 46),     # 技能
    (686, 500, 738, 532),   # 咒术  (second caption of the 技能 / 咒术 row)
    (778, 17, 838, 52),     # 受击
    (1242, 16, 1356, 52),   # 死亡
    (959, 17, 1018, 50),    # 其他
    (1054, 16, 1112, 50),   # 特效素材
]

# Poses that ship to the game, by role. Sheet 2 only offers seven pointing /
# blade poses for three weapon families, so families 1 and 2 reorder the same
# clean silhouettes rather than inventing a new one. The walk and run rows step
# through the travelling poses in different orders, so no frame of the run is
# the frame of the walk beside it, and the dodge row starts from the recoiling
# idle pose and lands on the plain stride.
MOVEMENT_ROWS = [
    ["walk_d", "walk_a", "walk_b", "walk_c"],
    ["walk_c", "walk_d", "walk_a", "walk_b"],
    ["idle_b", "walk_c", "walk_a", "walk_b"],
]
ATTACK_ROWS = [
    ["atk_b", "atk_d", "atk_c", "atk_f"],
    ["atk_a", "atk_e", "atk_g", "atk_d"],
    ["atk_c", "atk_e", "atk_f", "atk_b"],
]
ATTACK_GRIMOIRE = [[0, 1], [2], [0, 1, 2, 3]]   # poses that keep the book

# One exact rectangle per shipped pose: the bounding box of that pose's own
# silhouette on the sheet, measured from the labelled components rather than
# guessed. Several of them are deliberately tight, because the sheet packs its
# poses so closely that a loose rectangle catches the neighbour - the walk
# poses in particular run their hair into the next pose's book.
S2_WINDOW = {
    "idle_a": (47, 13, 242, 255), "idle_b": (269, 14, 479, 255),
    "idle_c": (507, 15, 714, 256), "idle_d": (738, 13, 940, 254),
    "walk_a": (1035, 37, 1213, 258), "walk_b": (1220, 50, 1398, 257),
    "walk_c": (1404, 28, 1588, 259), "walk_d": (1606, 26, 1808, 260),
    "atk_a": (42, 290, 242, 501), "atk_b": (322, 286, 552, 508),
    "atk_c": (573, 284, 826, 500), "atk_d": (834, 280, 1070, 507),
    "atk_e": (1057, 286, 1268, 516), "atk_f": (1302, 279, 1522, 513),
    "atk_g": (1547, 304, 1750, 508),
    # 受击: the 死亡 row lies across the lower half, and the pose's own rune
    # burst sits to its right, so the window stops before the neighbour's book.
    "hit_b": (258, 767, 430, 946),
    "atk_spell": (1717, 277, 2010, 367),
    "skill_fx": (1387, 468, 2033, 792),
}
# Windows that need the component split before it is safe to use, because the
# rectangle above also contains the neighbour that touches this pose.
S2_SPLIT = {
    # The hair of the pose at x1405 runs into this one, and the boots at
    # x1470..1510 and x1715..1755 hang below the row the caption implies.
    "walk_a": (1035, 26, 1256, 268),
    "walk_d": (1594, 26, 1808, 268),
}

_CACHE: dict[str, Image.Image] = {}
CUT_PAD = 14           # transparent growth around a pose window, see cut2


def sheet1() -> Image.Image:
    if "s1" not in _CACHE:
        _CACHE["s1"] = Image.open(SHEET1).convert("RGB")
    return _CACHE["s1"]


def sheet2() -> Image.Image:
    """The full sprite sheet with its row captions painted out."""
    if "s2" in _CACHE:
        return _CACHE["s2"]
    pixels = np.asarray(Image.open(SHEET2).convert("RGB")).copy()
    corners = np.ix_([0, 1, 2, 1149, 1150, 1151], [0, 1, 2, 2045, 2046, 2047])
    backdrop = np.median(pixels[corners].reshape(-1, 3), axis=0)
    for x0, y0, x1, y1 in S2_LABELS:
        pixels[y0:y1, x0:x1] = backdrop
    _CACHE["s2"] = Image.fromarray(pixels, "RGB")
    return _CACHE["s2"]


def keyed1() -> Image.Image:
    if "k1" not in _CACHE:
        _CACHE["k1"] = key_background(sheet1())
    return _CACHE["k1"]


def keyed2() -> Image.Image:
    if "k2" not in _CACHE:
        _CACHE["k2"] = key_background(sheet2())
    return _CACHE["k2"]


def cut1(key: str) -> Image.Image:
    return keyed1().crop(S1[key])


def cut2(key: str) -> Image.Image:
    """One clean pose out of sheet 2.

    The window is grown by CUT_PAD on every side before the alpha is separated,
    and the grown rectangle is then cut down to the silhouettes that own the
    stored window. The growth is what makes that reliable: a neighbour's hair
    that overlaps the window is a whole region with its own outline instead of a
    shape flush against the border, so it can be told apart and dropped. The
    margin is masked off again afterwards, which is why a window can be as tight
    as the pose without guillotining it."""
    wx0, wy0, wx1, wy1 = S2_WINDOW.get(key, S2[key])
    x0, y0, x1, y1 = S2_SPLIT.get(key, (wx0, wy0, wx1, wy1))
    w, h = keyed2().size
    gx0, gy0 = max(0, x0 - CUT_PAD), max(0, y0 - CUT_PAD)
    gx1, gy1 = min(w, x1 + CUT_PAD), min(h, y1 + CUT_PAD)
    crop = keyed2().crop((gx0, gy0, gx1, gy1))
    data = np.asarray(crop).copy()
    inner = np.zeros(data.shape[:2], dtype=bool)
    inner[y0 - gy0:y1 - gy0, x0 - gx0:x1 - gx0] = True
    data[:, :, 3] = np.where(inner, data[:, :, 3], 0)
    pose = silhouette(Image.fromarray(data, "RGBA"), inside=inner)
    # Keep only what the measured pose box actually covers.
    keep = np.zeros(data.shape[:2], dtype=bool)
    keep[wy0 - gy0:wy1 - gy0, wx0 - gx0:wx1 - gx0] = True
    out = np.asarray(pose).copy()
    out[:, :, 3] = np.where(keep, out[:, :, 3], 0)
    return despeckle(frame(Image.fromarray(out, "RGBA")))


def cut2_raw(key: str) -> Image.Image:
    """The whole painted content of a window, for effect art."""
    x0, y0, x1, y1 = S2_WINDOW.get(key, S2[key])
    return frame(keyed2().crop((x0, y0, x1, y1)))


# --- placement ---------------------------------------------------------------

def body_box(sprite: Image.Image, share: float = 0.035) -> tuple[int, int]:
    """Rows spanned by the standing body, from crown to sole.

    Effects - a rune ring, a thrown blade - hang off the silhouette and would
    otherwise stretch it, so a row only counts as body when it carries a real
    slice of the figure."""
    alpha = np.asarray(sprite)[:, :, 3] > 40
    density = alpha.sum(axis=1)
    rows = np.nonzero(density >= max(3.0, sprite.width * share))[0]
    if not len(rows):
        return 0, sprite.height - 1
    return int(rows.min()), int(rows.max())


def ground_of(sprite: Image.Image, share: float = 0.10) -> int:
    """Lowest row that still carries a real slice of the silhouette."""
    alpha = np.asarray(sprite)[:, :, 3] > 40
    density = alpha.sum(axis=1)
    rows = np.nonzero(density >= max(6.0, sprite.width * share))[0]
    return int(rows.max()) if len(rows) else sprite.height - 1


def fit(sprite: Image.Image, height: float = HOUSE_STAND_H,
        width_limit: float = HOUSE_CELL[0] - 2 * SAFE_SIDE) -> Image.Image:
    """Uniformly scales a pose so its standing body is `height` px tall.

    The standing body is what gets measured, so a rune ring or a thrown blade
    hanging off the silhouette cannot shrink the character. Every shipped pose
    goes through this one scale, which is what keeps the head size and the limbs
    identical from cell to cell. A pose dressed with more painted glow than
    fits a cell is scaled down as a whole rather than cropped, because a sprite
    that crosses its cell boundary would be drawn over its neighbour and would
    also hide the empty gutter character_frames.gd looks for."""
    top, foot = body_box(sprite)
    factor = height / max(1, foot - top + 1)
    if sprite.width * factor > width_limit:
        factor = width_limit / sprite.width
    return sprite.resize((max(1, int(round(sprite.width * factor))),
                          max(1, int(round(sprite.height * factor)))), Image.LANCZOS)


# How far the sole of each pose sits above the bottom of its measured box. The
# sheet hangs a soft hem, a shadow or a loose page under the furthest boot, so
# the bottom row of a cut is always one or two rows past the sole. Hero 0, the
# house style, also stands its boots on the very last row of its cell, so the
# shipped sheets put the sole of every pose on y=361 and this table states how
# far the drawn sole sits above that.
SOLE = {
    "idle_a": 1, "idle_b": 1, "idle_c": 1, "idle_d": 1,
    "walk_a": 1, "walk_b": 1, "walk_c": 1, "walk_d": 1,
    "atk_a": 1, "atk_b": 1, "atk_c": 1, "atk_d": 1,
    "atk_e": 1, "atk_f": 1, "atk_g": 1,
    "hit_b": 1,
}


def place(canvas: Image.Image, art: Image.Image, key: str, column: int, row: int) -> None:
    """Centres a pose in its cell and stands its soles on the row's floor line.

    The floor is one fixed line per row and the sole offset is a fixed property
    of the pose, so no frame can jump against its neighbours. A frame that would
    touch a cell border is nudged inward rather than shrunk, so every frame in a
    row keeps one scale: character_frames.gd finds its crop gutters by looking
    for empty rows and columns."""
    left = column * HOUSE_CELL[0]
    top = row * HOUSE_CELL[1]
    y = int(round(top + HOUSE_FOOT_Y - SOLE[key] - (art.height - 1)))
    x = int(round(left + (HOUSE_CELL[0] - art.width) / 2.0))
    y = max(top + SAFE_TOP, min(y, top + HOUSE_CELL[1] - 1 - art.height))
    x = max(left, min(x, left + HOUSE_CELL[0] - art.width))
    canvas.alpha_composite(art, (x, y))


def with_grimoire(sprite: Image.Image, scale: float = 0.66, side: float = 0.60) -> Image.Image:
    """Hangs the floating grimoire beside a pose that does not already hold it."""
    out = sprite.copy()
    book = trim(cut1("book"))
    book = book.resize((max(16, int(book.width * scale)), max(16, int(book.height * scale))),
                       Image.LANCZOS)
    top, foot = body_box(out)
    out.alpha_composite(book, (int(out.width * side) - book.width // 2,
                               max(0, int(top + (foot - top) * 0.34) - book.height // 2)))
    return out


def build_attack() -> Image.Image:
    """4 columns x 3 rows: one row per weapon family, matching heroes 0..2."""
    canvas = Image.new("RGBA", HOUSE_SIZE, (0, 0, 0, 0))
    for row, keys in enumerate(ATTACK_ROWS):
        for column, key in enumerate(keys):
            art = fit(cut2(key))
            if column in ATTACK_GRIMOIRE[row]:
                art = with_grimoire(art)
            place(canvas, art, key, column, row)
    return canvas


def build_movement() -> Image.Image:
    """4 columns x 3 rows: walk / run / dodge, hands empty."""
    canvas = Image.new("RGBA", HOUSE_SIZE, (0, 0, 0, 0))
    for row, keys in enumerate(MOVEMENT_ROWS):
        for column, key in enumerate(keys):
            place(canvas, fit(cut2(key)), key, column, row)
    return canvas


# --- effects, props and portraits -------------------------------------------

def build_ultimate_cg() -> Image.Image:
    """Three stacked cut-in rows, the shape assets/combat/ultimate-cg.png uses."""
    row_h = 320
    canvas = Image.new("RGBA", (1440, row_h * 3), (0, 0, 0, 0))
    key = key_background(sheet1().crop(S1_KEYART))
    panels = [trim(cut1("cast")), trim(cut1("hex")), trim(cut1("bolt"))]
    key_scale = (row_h * 0.94) / key.height
    key_small = key.resize((max(1, int(key.width * key_scale)), int(row_h * 0.94)), Image.LANCZOS)
    for index, panel in enumerate(panels):
        scale = (row_h * 0.94) / panel.height
        big = panel.resize((max(1, int(panel.width * scale)), int(row_h * 0.94)), Image.LANCZOS)
        canvas.alpha_composite(big, (60, index * row_h + 10))
        canvas.alpha_composite(key_small, (1440 - key_small.width - 24, index * row_h + 10))
    return canvas


def build_rune_rain() -> Image.Image:
    """Eight cells of rune swords, used by the ultimate's rectangle strike.

    Every cell is a hero effect taken from the reference art: the four rune
    blades and the curse sigil the caster throws. They are laid out largest
    first so a rectangle of rain reads as a wall of blades rather than a
    repeating stamp."""
    cell = 256
    canvas = Image.new("RGBA", (cell * 4, cell * 2), (0, 0, 0, 0))
    lance = raw("rune-lance")
    cross = raw("rune-cross")
    ring = raw("hex-ring")
    pieces = [
        lance, cross, lance.transpose(Image.FLIP_LEFT_RIGHT), cross,
        lance.rotate(-24.0, resample=Image.BICUBIC, expand=True),
        cross.rotate(18.0, resample=Image.BICUBIC, expand=True),
        ring, cross.rotate(-12.0, resample=Image.BICUBIC, expand=True),
    ]
    for index, piece in enumerate(pieces):
        fit = (cell * 0.94) / max(piece.width, piece.height)
        art = piece.resize((max(1, int(piece.width * fit)), max(1, int(piece.height * fit))),
                           Image.LANCZOS)
        canvas.alpha_composite(art, ((index % 4) * cell + (cell - art.width) // 2,
                                     (index // 4) * cell + (cell - art.height) // 2))
    return canvas


def build_hellfire() -> Image.Image:
    """Six cells of the underworld fire that lingers on the ground.

    The reference art has no flame, so these are drawn: a dark violet core, a
    magenta body and a pale licking tip, cycling through six shapes so the
    patch flickers instead of pulsing as one flat tile. Replace this function
    with real flame art later."""
    cell = 256
    canvas = Image.new("RGBA", (cell * 3, cell * 2), (0, 0, 0, 0))
    rng = np.random.default_rng(20250924)
    for index in range(6):
        art = _flame(192, 232, index, rng)
        canvas.alpha_composite(art, ((index % 3) * cell + (cell - art.width) // 2,
                                     (index // 3) * cell + (cell - art.height) // 2))
    return canvas


def _flame(width: int, height: int, seed_index: int, rng) -> Image.Image:
    """One painted flame tongue.

    Built as a height field rather than as a solid cone: a wandering top edge is
    sampled across the width, and every column is filled from the ground up to
    it. That gives an irregular, licking silhouette with no straight sides;
    colour runs from a deep violet root through magenta to a near white core,
    and the tip and edges are eaten away so the flame frays instead of ending on
    a line."""
    ys, xs = np.mgrid[0:height, 0:width]
    base = 0.90                                       # where the flame meets the ground
    nx = (xs - width / 2.0) / (width / 2.0)           # same shape as ys
    ny = np.clip((base - ys / float(height - 1)) / base, 0.0, 1.0)
    edge_x = nx[0]                                    # one row: the top edge's profile

    # The top edge: a few sine terms that make separate licks across the width,
    # plus a per cell lean so the six cells are visibly different shapes.
    edge = (0.46
            + 0.20 * np.sin(edge_x * 3.1 + seed_index * 1.9)
            + 0.14 * np.sin(edge_x * 6.7 - seed_index * 2.6 + 0.8)
            + 0.09 * np.sin(edge_x * 12.3 + seed_index * 0.7)
            + 0.10 * np.sin(edge_x * 1.7 + seed_index * 1.1))
    edge += 0.16 * (seed_index - 2.5) / 2.5
    reach = np.clip(edge, 0.18, 0.98)[None, :]        # broadcast down the columns
    # Below the edge the body is solid; above it fades out over a soft shoulder.
    body = np.clip((reach - ny) / 0.20, 0.0, 1.0)
    # Thin the flame towards the outside of its footprint so it has no flat
    # sides either: the taper reaches all the way to zero at the rim, and the
    # root is narrower than the crown so the flame has a base rather than a
    # rectangle sitting on the ground.
    rim = 0.94 - 0.30 * np.power(1.0 - ny, 1.6)
    taper = np.clip((rim - np.abs(nx)) / 0.34, 0.0, 1.0) ** 1.15
    body = np.clip(body * taper, 0.0, 1.0)
    # Muzzle noise: erode the tip and the edges into embers.
    bite = 0.06 + 0.70 * np.power(ny, 1.4) + 0.22 * np.abs(nx)
    body = np.where(rng.random((height, width)) < bite * 0.42, body * 0.10, body)
    body = np.clip(body * (0.92 + 0.16 * rng.random((height, width))), 0.0, 1.0)
    # Fade the bottom row out so the flame sits in the ground instead of on it.
    body *= np.clip((base - ys / float(height - 1)) / 0.10, 0.0, 1.0) * 0.72 + 0.28
    core = np.clip(body * 1.60 - 0.44, 0.0, 1.0)
    hot = np.clip(body * 2.30 - 1.34, 0.0, 1.0)
    deep = np.array([0.14, 0.02, 0.28])               # deep violet, at the root
    mid = np.array([0.70, 0.24, 0.90])                # the body
    pale = np.array([1.00, 0.84, 1.00])               # the hot centre
    rgb = deep[None, None, :] * (1.0 - core)[:, :, None] \
        + mid[None, None, :] * core[:, :, None] * (1.0 - hot)[:, :, None] \
        + pale[None, None, :] * hot[:, :, None]
    alpha = np.clip(body * 1.20, 0.0, 1.0) ** 0.78
    out = np.dstack([np.clip(rgb, 0, 1) * 255.0, alpha * 255.0]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def build_gear() -> None:
    """Portrait, standing and fallen poses, the weapon, and the loot icon."""
    trim(cut2("idle_a")).save(os.path.join(ASSETS, "muyu-idle.png"))

    # Down = the second fallen pose: she is on her back with the hair fanned
    # out, which reads as knocked down rather than as a death sprawl, and the
    # loose pages that fell with her come along as their own silhouettes.
    down = cut2("down_b")
    pages = np.asarray(down)[:, :, 3] > 30
    labels, count = ndimage.label(pages, structure=np.ones((3, 3), dtype=int))
    sizes = ndimage.sum(pages, labels, range(1, count + 1))
    keep = np.zeros_like(pages)
    for index in range(count):
        if sizes[index] >= 150:
            keep |= labels == index + 1
    out = np.asarray(down).copy()
    out[:, :, 3] = np.where(keep, out[:, :, 3], 0)
    trim(Image.fromarray(out, "RGBA")).save(os.path.join(ASSETS, "muyu-down.png"))

    # The portrait is a bust, so it is cropped to the head and shoulders of the
    # standing pose rather than shrunk whole: at 900 px tall a full body would
    # put the face well under a fifth of the frame.
    standing = cut2("idle_a")
    box = standing.getbbox()
    bust = standing.crop((box[0], box[1], box[2], box[1] + int((box[3] - box[1]) * 0.46)))
    bust = trim(bust)
    bust.resize((max(1, int(bust.width * (900.0 / bust.height))), 900), Image.LANCZOS).save(
        os.path.join(ASSETS, "portrait-3.png"))

    # --- the props and effects, all from the reference art -----------------
    raw("grimoire").save(os.path.join(OUT, "grimoire.png"))
    raw("hex-ring").save(os.path.join(OUT, "hex-ring.png"))
    raw("rune-cross").save(os.path.join(OUT, "soul-scythe.png"))
    raw("rune-lance").save(os.path.join(OUT, "rune-burst.png"))
    raw("rune-cross").rotate(-90.0, resample=Image.BICUBIC, expand=True).save(
        os.path.join(OUT, "rune-bolt.png"))
    # A second curse sigil with the blades fanned behind it, for the cut-in.
    raw("hex-ring").save(os.path.join(OUT, "hex-ring-large.png"))

    boss = trim(cut1("hex"))
    boss.resize((max(1, int(boss.width * (860.0 / boss.height))), 860), Image.LANCZOS).save(
        os.path.join(OUT, "hidden-boss.png"))

    # The loot icon is the curse sigil, which is what the amulet's art is.
    amulet = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    amulet.alpha_composite(raw("hex-ring").resize((58, 58), Image.LANCZOS), (3, 3))
    amulet.save(os.path.join(OUT, "amulet.png"))


def main() -> int:
    for path in (SHEET1, SHEET2):
        if not os.path.exists(path):
            print("missing reference: %s" % path, file=sys.stderr)
            return 1
    for name in RAW_FILES:
        path = os.path.join(RAW_DIR, RAW_FILES[name])
        if not os.path.exists(path):
            print("missing effect art: %s" % path, file=sys.stderr)
            return 1
    os.makedirs(OUT, exist_ok=True)

    build_attack().save(os.path.join(ASSETS, "combat", "attack-clean-3.png"))
    build_movement().save(os.path.join(ASSETS, "combat", "movement-3.png"))
    build_ultimate_cg().save(os.path.join(OUT, "ultimate-cg.png"))
    build_rune_rain().save(os.path.join(OUT, "rune-rain.png"))
    build_hellfire().save(os.path.join(OUT, "hellfire.png"))
    build_gear()
    print("墓煜 art written to assets/ and %s" % OUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
