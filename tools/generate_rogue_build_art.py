"""Generate every rogue-build art asset that `assets/rogue/build/` is expected to hold.

Deterministic and idempotent: re-running always produces byte-identical output, so a
fresh clone (or a `git clean -fdx`) can be repaired with one command:

    F:\\python\\python.exe tools/generate_rogue_build_art.py

What it writes (all inside assets/rogue/build/):
  * 13 RGBA atlases holding the 252 build IDs from resources/rogue_build_content.json
    (4 weapons x12, 3 gear x24, 4 talents x24, 1 engravings x24, 1 cores x12)
  * generation-record.json   - the plan each atlas was painted from (read by tools/index_rogue_build_art.py)
  * hero-{0..3}-jump-v1.png  - 3x2 jump sheets, 6 poses per hero
  * jump-generation-record.json
  * blood-flask-v1.png       - the flask icon that scripts/rogue_art.gd preloads at compile time

Afterwards it runs the two upstream indexers so the runtime manifests match the PNGs:
    tools/index_rogue_build_art.py  -> atlas-manifest.json
    tools/index_rogue_jump_art.py   -> jump-manifest.json

Schema of the runtime manifests (reverse engineered from the consumers):
  atlas-manifest.json  {"version":1,"regions":{<id>:{"file":"res://...","region":[x,y,w,h],"cell":[x,y,cw,ch]}}}
      consumed by scripts/rogue_build_art.gd:3,9-19 (Art.icon) and asserted by
      tests/rogue_build_rules.gd:45-52 (non-null, >4px, distinct resource_path+region)
  jump-manifest.json   {"<hero>":{"file":"res://...","standing_height":int,"frames":[{"cell":[l,t,w,h],"pivot":[cx,cy],"body_height":int}]}}
      consumed by scripts/rogue_jump_frames.gd:3,8-17 via scripts/character_frames.gd:14,216-217
"""
import hashlib
import json
import random
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "rogue" / "build"

CELL = 160          # atlas cell edge in output pixels
SS = 4              # supersample factor while painting (downsampled with LANCZOS)
JUMP_CELL = 128     # hero jump sheet cell edge
FLOOR = 0.94        # feet sit at 94% of the cell height (see tools/index_rogue_jump_art.py:21)

INK = (10, 8, 12, 255)
STEEL = (198, 208, 220, 255)
DARKSTEEL = (86, 96, 112, 255)
CRIMSON = (176, 22, 46, 255)
GOLD = (222, 158, 56, 255)
EMBER = (228, 112, 38, 255)
FROST = (108, 198, 226, 255)
BOLT = (96, 148, 240, 255)
VIOLET = (166, 100, 216, 255)
TEAL = (86, 200, 178, 255)
BONE = (232, 226, 208, 255)
IRON = (62, 68, 80, 255)
WIND = (150, 214, 156, 255)
DAWN = (244, 214, 138, 255)

SCHOOL_COLOR = [CRIMSON, EMBER, STEEL, EMBER, FROST, BOLT, TEAL, (128, 158, 232, 255),
                IRON, WIND, VIOLET, DAWN]
HERO_COLOR = [CRIMSON, FROST, GOLD, VIOLET]
# Twelve clearly separated accents: every id inside one atlas gets its own hue slot.
RING = [CRIMSON, EMBER, GOLD, DAWN, WIND, TEAL, FROST, BOLT,
        (118, 116, 240, 255), VIOLET, (226, 110, 196, 255), (214, 74, 96, 255)]


def fnv(text: str) -> int:
    h = 2166136261
    for byte in text.encode("utf-8"):
        h = ((h ^ byte) * 16777619) & 0xFFFFFFFF
    return h


def shade(color, factor):
    return (max(0, min(255, int(color[0] * factor))),
            max(0, min(255, int(color[1] * factor))),
            max(0, min(255, int(color[2] * factor))),
            color[3])


def ease(color, other, amount):
    return tuple(int(round(color[i] + (other[i] - color[i]) * amount)) for i in range(4))


class Canvas:
    """One icon painted on its own supersampled square, then downsampled into a cell."""

    def __init__(self, edge: int = CELL):
        self.edge = edge
        self.size = edge * SS
        self.image = Image.new("RGBA", (self.size, self.size), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)

    def point(self, x, y):
        return (x * self.size, y * self.size)

    def poly(self, points, fill, outline=INK, width=0.035):
        pts = [self.point(x, y) for x, y in points]
        self.draw.polygon(pts, fill=fill)
        if outline and width:
            self.draw.line(pts + [pts[0]], fill=outline, width=max(1, int(width * self.size)),
                           joint="curve")

    def stroke(self, points, color, width=0.03, closed=False):
        pts = [self.point(x, y) for x, y in points]
        if closed:
            pts = pts + [pts[0]]
        self.draw.line(pts, fill=color, width=max(1, int(width * self.size)), joint="curve")

    def disc(self, cx, cy, r, fill, outline=INK, width=0.03):
        box = [self.point(cx - r, cy - r), self.point(cx + r, cy + r)]
        self.draw.ellipse(box, fill=fill, outline=outline if width else None,
                          width=max(1, int(width * self.size)) if outline and width else 1)

    def ring(self, cx, cy, r, color, width=0.025):
        box = [self.point(cx - r, cy - r), self.point(cx + r, cy + r)]
        self.draw.ellipse(box, outline=color, width=max(1, int(width * self.size)))

    def arc(self, cx, cy, r, start, end, color, width=0.025):
        box = [self.point(cx - r, cy - r), self.point(cx + r, cy + r)]
        self.draw.arc(box, start, end, fill=color, width=max(1, int(width * self.size)))

    def rect(self, x0, y0, x1, y1, fill, outline=INK, width=0.03, radius=0.0):
        if radius <= 0:
            self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], fill, outline, width)
            return
        box = [self.point(x0, y0), self.point(x1, y1)]
        self.draw.rounded_rectangle(box, radius=radius * self.size, fill=fill,
                                    outline=outline if width else None,
                                    width=max(1, int(width * self.size)) if outline and width else 1)

    def rotate_about(self, cx, cy, angle, fn):
        """Run `fn` with a rotation applied around (cx,cy) in normalized space."""
        cos_a, sin_a = _cos(angle), _sin(angle)

        class Rot:
            def __init__(self, canvas):
                self.parent = canvas

            def point(self, x, y):
                dx, dy = x - cx, y - cy
                return self.parent.point(cx + dx * cos_a - dy * sin_a, cy + dx * sin_a + dy * cos_a)

        rot = Rot(self)
        saved = self.point

        def point(x, y):
            return rot.point(x, y)

        self.point = point
        try:
            fn(self)
        finally:
            self.point = saved

    def icon(self, edge: int = CELL) -> Image.Image:
        return self.image.resize((edge, edge), Image.LANCZOS)


def _cos(angle):
    import math
    return math.cos(angle)


def _sin(angle):
    import math
    return math.sin(angle)


# --------------------------------------------------------------------------- weapons

def _spine(grip, tip, bend, samples=9):
    """Quadratic spine from grip to tip, bowed sideways by `bend` units."""
    import math
    dx, dy = tip[0] - grip[0], tip[1] - grip[1]
    length = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / length, dx / length
    mid = ((grip[0] + tip[0]) * 0.5 + nx * bend, (grip[1] + tip[1]) * 0.5 + ny * bend)
    points = []
    for step in range(samples + 1):
        t = step / samples
        points.append(((1 - t) ** 2 * grip[0] + 2 * (1 - t) * t * mid[0] + t * t * tip[0],
                       (1 - t) ** 2 * grip[1] + 2 * (1 - t) * t * mid[1] + t * t * tip[1]))
    return points, (nx, ny)


def _blade(c, grip, tip, root, point, bend=0.0, color=STEEL, edge=None, samples=9):
    """Tapered blade: a bowed spine extruded by a shrinking half-width."""
    points, (nx, ny) = _spine(grip, tip, bend, samples)
    upper, lower = [], []
    for i, (x, y) in enumerate(points):
        t = i / (len(points) - 1)
        half = root + (point - root) * t
        upper.append((x + nx * half, y + ny * half))
        lower.append((x - nx * half, y - ny * half))
    c.poly(upper + lower[::-1], color, INK, 0.020)
    if edge:
        c.stroke(points, edge, 0.008)
    return points


def _trim(c, index, accent, at=(0.5, 0.72)):
    """One of four ornament shapes so every id inside an atlas stays distinguishable."""
    kind = (index // 4) % 4
    x, y = at
    if kind == 0:
        c.rect(x - 0.09, y - 0.022, x + 0.09, y + 0.022, accent, INK, 0.016, 0.01)
    elif kind == 1:
        c.disc(x, y, 0.036, accent, INK, 0.014)
        c.disc(x - 0.07, y, 0.024, ease(accent, BONE, 0.35), INK, 0.010)
        c.disc(x + 0.07, y, 0.024, ease(accent, BONE, 0.35), INK, 0.010)
    elif kind == 2:
        c.poly([(x, y - 0.045), (x + 0.05, y), (x, y + 0.045), (x - 0.05, y)], accent, INK, 0.014)
    else:
        c.stroke([(x - 0.06, y - 0.03), (x, y + 0.03), (x + 0.06, y - 0.03)], accent, 0.018)


def paint_weapon(c: Canvas, group: str, index: int, defn: dict):
    accent = RING[index % len(RING)]
    steel = ease(STEEL, accent, 0.30)
    bright = ease(steel, (255, 255, 255, 255), 0.45)
    variant = index % 4
    grip, tip = (0.20, 0.80), (0.86, 0.20)
    if group == "light":
        if variant == 0:
            _blade(c, grip, tip, 0.050, 0.010, 0.0, steel, bright)
            c.stroke([(0.10, 0.86), (0.30, 0.74)], GOLD, 0.028)
        elif variant == 1:
            _blade(c, grip, tip, 0.055, 0.010, 0.13, steel, bright)
            c.arc(0.22, 0.78, 0.10, 90, 270, GOLD, 0.024)
        elif variant == 2:
            _blade(c, (0.30, 0.72), (0.60, 0.38), 0.050, 0.012, 0.04, steel, bright, 6)
            _blade(c, (0.44, 0.86), (0.80, 0.50), 0.050, 0.012, 0.04, ease(steel, BONE, 0.3), bright, 6)
        else:
            _blade(c, (0.24, 0.82), (0.90, 0.16), 0.022, 0.006, 0.0, bright, None)
            c.arc(0.28, 0.78, 0.13, 210, 330, GOLD, 0.022)
            c.arc(0.28, 0.78, 0.13, 30, 150, GOLD, 0.022)
        c.disc(0.20, 0.82, 0.036, GOLD, INK, 0.020)
    elif group == "heavy":
        if variant == 0:
            _blade(c, (0.14, 0.86), (0.84, 0.22), 0.135, 0.055, 0.05, ease(DARKSTEEL, accent, 0.35), bright, 7)
            c.stroke([(0.18, 0.90), (0.34, 0.72)], GOLD, 0.040)
        elif variant == 1:
            c.stroke([(0.24, 0.84), (0.74, 0.32)], ease(IRON, GOLD, 0.35), 0.042)
            c.rect(0.60, 0.14, 0.86, 0.36, ease(STEEL, accent, 0.35), INK, 0.026, 0.02)
            c.stroke([(0.60, 0.25), (0.86, 0.25)], accent, 0.016)
        elif variant == 2:
            c.stroke([(0.22, 0.84), (0.72, 0.34)], ease(IRON, GOLD, 0.35), 0.040)
            c.poly([(0.62, 0.14), (0.88, 0.24), (0.84, 0.44), (0.58, 0.34)], ease(STEEL, accent, 0.3), INK, 0.026)
            c.poly([(0.62, 0.14), (0.88, 0.24), (0.74, 0.22)], ease(accent, BONE, 0.2), INK, 0.014)
        else:
            _blade(c, (0.14, 0.88), (0.86, 0.26), 0.150, 0.090, 0.0, ease(DARKSTEEL, accent, 0.30), bright, 5)
            c.poly([(0.62, 0.36), (0.72, 0.40), (0.68, 0.50)], (0, 0, 0, 0), INK, 0.016)
        c.disc(0.14, 0.90, 0.042, GOLD, INK, 0.024)
    elif group == "ranged":
        if variant == 0:
            c.poly([(0.14, 0.62), (0.80, 0.34), (0.82, 0.41), (0.18, 0.68)], ease(DARKSTEEL, accent, 0.35), INK, 0.028)
            c.poly([(0.16, 0.66), (0.32, 0.58), (0.28, 0.82), (0.14, 0.84)], ease(GOLD, accent, 0.25), INK, 0.024)
            c.rect(0.42, 0.36, 0.60, 0.46, IRON, INK, 0.022, 0.01)
            c.stroke([(0.72, 0.38), (0.86, 0.32)], bright, 0.016)
        elif variant == 1:
            c.arc(0.54, 0.50, 0.32, 190, 350, ease(GOLD, accent, 0.35), 0.034)
            c.stroke([(0.44, 0.22), (0.44, 0.78)], BONE, 0.012)
            c.stroke([(0.44, 0.50), (0.86, 0.44)], ease(STEEL, accent, 0.4), 0.018)
            c.poly([(0.86, 0.44), (0.78, 0.40), (0.78, 0.48)], bright, INK, 0.012)
        elif variant == 2:
            c.rect(0.26, 0.40, 0.66, 0.54, ease(DARKSTEEL, accent, 0.35), INK, 0.026, 0.02)
            c.poly([(0.66, 0.44), (0.82, 0.40), (0.82, 0.48), (0.66, 0.52)], bright, INK, 0.018)
            c.poly([(0.30, 0.54), (0.44, 0.54), (0.40, 0.80), (0.28, 0.80)], ease(GOLD, accent, 0.25), INK, 0.022)
        else:
            c.rect(0.18, 0.54, 0.74, 0.66, ease(DARKSTEEL, accent, 0.30), INK, 0.026, 0.02)
            c.arc(0.46, 0.44, 0.24, 190, 350, ease(GOLD, accent, 0.35), 0.026)
            c.stroke([(0.46, 0.24), (0.46, 0.60)], BONE, 0.012)
            c.stroke([(0.28, 0.62), (0.60, 0.40)], bright, 0.016)
    else:                                             # staves, wands, scepters
        if variant == 0:
            c.stroke([(0.20, 0.84), (0.66, 0.36)], ease(IRON, GOLD, 0.35), 0.036)
            c.disc(0.70, 0.30, 0.085, accent, INK, 0.022)
            c.disc(0.70, 0.30, 0.038, bright, None, 0)
            c.ring(0.70, 0.30, 0.125, GOLD, 0.018)
        elif variant == 1:
            c.stroke([(0.26, 0.80), (0.52, 0.54)], ease(IRON, GOLD, 0.35), 0.034)
            c.poly([(0.58, 0.22), (0.76, 0.44), (0.58, 0.66), (0.40, 0.44)], ease(accent, FROST, 0.35), INK, 0.024)
            c.stroke([(0.58, 0.28), (0.58, 0.60)], bright, 0.012)
        elif variant == 2:
            c.stroke([(0.22, 0.84), (0.62, 0.42)], ease(IRON, GOLD, 0.35), 0.034)
            _blade(c, (0.62, 0.42), (0.86, 0.18), 0.030, 0.006, 0.0, ease(STEEL, accent, 0.45), bright, 5)
            c.stroke([(0.58, 0.44), (0.68, 0.36)], GOLD, 0.020)
        else:
            c.stroke([(0.22, 0.86), (0.60, 0.46)], ease(IRON, GOLD, 0.35), 0.036)
            c.arc(0.70, 0.36, 0.12, 120, 420, GOLD, 0.020)
            c.disc(0.70, 0.36, 0.055, accent, INK, 0.018)
            c.stroke([(0.70, 0.24), (0.70, 0.14)], ease(GOLD, BONE, 0.4), 0.014)
    _trim(c, index, accent, (0.50, 0.90) if group in ("heavy", "light") else (0.56, 0.86))


# ------------------------------------------------------------------------------ gear

def paint_gear(c: Canvas, slot: int, index: int, template: str, defn: dict):
    family = int(template[1]) if len(template) > 1 and template[1].isdigit() else 1
    accent = RING[(index * 5) % len(RING)]
    body = ease(DARKSTEEL, accent, 0.22 + 0.07 * (index % 3))
    trim = ease(accent, BONE, 0.25)
    if slot == 0:                                     # chest armor
        if family == 1:
            c.poly([(0.30, 0.30), (0.70, 0.30), (0.74, 0.62), (0.5, 0.80), (0.26, 0.62)], body, INK, 0.030)
            c.stroke([(0.5, 0.32), (0.5, 0.78)], ease(body, (255, 255, 255, 255), 0.35), 0.016)
        elif family == 2:
            c.poly([(0.28, 0.30), (0.72, 0.30), (0.68, 0.52), (0.5, 0.82), (0.32, 0.52)], body, INK, 0.028)
            c.poly([(0.34, 0.36), (0.66, 0.36), (0.5, 0.50)], ease(accent, (255, 255, 255, 255), 0.25), INK, 0.018)
        elif family == 3:
            c.poly([(0.32, 0.26), (0.68, 0.26), (0.72, 0.56), (0.5, 0.84), (0.28, 0.56)], body, INK, 0.030)
            for k in range(3):
                c.disc(0.38 + 0.12 * k, 0.40, 0.026, accent, INK, 0.014)
        else:
            c.poly([(0.32, 0.28), (0.68, 0.28), (0.74, 0.50), (0.5, 0.82), (0.26, 0.50)], body, INK, 0.030)
            c.poly([(0.20, 0.36), (0.30, 0.32), (0.32, 0.52), (0.22, 0.56)], ease(body, (0, 0, 0, 255), 0.2), INK, 0.022)
            c.poly([(0.70, 0.32), (0.80, 0.36), (0.78, 0.56), (0.68, 0.52)], ease(body, (0, 0, 0, 255), 0.2), INK, 0.022)
    elif slot == 1:                                   # focus: amulet / prism / sight / seal
        if family == 1:
            c.ring(0.5, 0.54, 0.20, GOLD, 0.026)
            c.disc(0.5, 0.54, 0.13, ease(accent, (255, 255, 255, 255), 0.15), INK, 0.022)
            c.disc(0.5, 0.54, 0.05, (255, 255, 255, 230), None, 0)
            c.stroke([(0.36, 0.28), (0.5, 0.34)], GOLD, 0.016)
            c.stroke([(0.64, 0.28), (0.5, 0.34)], GOLD, 0.016)
        elif family == 2:
            c.poly([(0.5, 0.22), (0.72, 0.50), (0.5, 0.82), (0.28, 0.50)], ease(accent, STEEL, 0.35), INK, 0.026)
            c.stroke([(0.5, 0.26), (0.5, 0.78)], (255, 255, 255, 180), 0.014)
        elif family == 3:
            c.rect(0.26, 0.38, 0.74, 0.58, ease(IRON, accent, 0.25), INK, 0.026, 0.03)
            c.disc(0.5, 0.48, 0.10, ease(FROST, accent, 0.3), INK, 0.018)
            c.disc(0.5, 0.48, 0.04, (255, 255, 255, 235), None, 0)
            c.stroke([(0.30, 0.62), (0.70, 0.62)], GOLD, 0.018)
        else:
            c.poly([(0.5, 0.24), (0.74, 0.48), (0.5, 0.80), (0.26, 0.48)], ease(body, GOLD, 0.3), INK, 0.028)
            c.stroke([(0.36, 0.48), (0.64, 0.48)], GOLD, 0.020)
            c.stroke([(0.5, 0.32), (0.5, 0.68)], GOLD, 0.020)
    else:                                             # boots
        if family == 1:
            c.poly([(0.36, 0.24), (0.58, 0.24), (0.60, 0.62), (0.78, 0.66), (0.78, 0.78), (0.34, 0.78)], body, INK, 0.028)
            c.stroke([(0.36, 0.34), (0.58, 0.34)], accent, 0.022)
        elif family == 2:
            c.poly([(0.38, 0.36), (0.58, 0.36), (0.60, 0.66), (0.76, 0.70), (0.76, 0.80), (0.36, 0.80)], body, INK, 0.028)
            c.disc(0.48, 0.44, 0.030, accent, INK, 0.016)
        elif family == 3:
            for dx in (-0.10, 0.10):
                c.poly([(0.50 + dx - 0.08, 0.32), (0.50 + dx + 0.02, 0.32),
                        (0.50 + dx + 0.03, 0.66), (0.50 + dx + 0.14, 0.70),
                        (0.50 + dx + 0.14, 0.80), (0.50 + dx - 0.09, 0.80)], body, INK, 0.024)
            c.stroke([(0.42, 0.42), (0.58, 0.42)], accent, 0.020)
        else:
            c.poly([(0.36, 0.26), (0.58, 0.26), (0.60, 0.64), (0.78, 0.68), (0.78, 0.80), (0.34, 0.80)], body, INK, 0.028)
            c.poly([(0.62, 0.30), (0.82, 0.22), (0.72, 0.42)], ease(accent, (255, 255, 255, 255), 0.3), INK, 0.018)
    _trim(c, index, trim, (0.5, 0.90))


# --------------------------------------------------------------------------- talents

def paint_talent(c: Canvas, school: int, index: int, defn: dict):
    color = SCHOOL_COLOR[school % len(SCHOOL_COLOR)]
    base = ease(IRON, color, 0.16)
    c.disc(0.5, 0.5, 0.36, ease(base, (0, 0, 0, 255), 0.25), INK, 0.028)
    c.ring(0.5, 0.5, 0.34, ease(color, GOLD, 0.35), 0.022)
    if index % 8 in (0, 5):
        c.ring(0.5, 0.5, 0.27, ease(color, (255, 255, 255, 255), 0.25), 0.012)
    glyph = school % 12
    steps = 3 + index % 4
    if glyph == 0:                                    # blood: droplets + needle
        for k in range(steps):
            ang = -1.9 + k * 0.55
            x, y = 0.5 + _cos(ang) * 0.16, 0.5 + _sin(ang) * 0.16
            c.disc(x, y, 0.035, color, INK, 0.014)
        c.stroke([(0.32, 0.66), (0.68, 0.34)], BONE, 0.012)
    elif glyph == 1:                                  # forge: hammer
        c.stroke([(0.34, 0.68), (0.62, 0.40)], IRON, 0.036)
        c.rect(0.52, 0.22, 0.76, 0.40, ease(STEEL, color, 0.3), INK, 0.022, 0.02)
    elif glyph == 2:                                  # watch: crosshair + feather
        c.ring(0.5, 0.5, 0.18, color, 0.020)
        c.stroke([(0.5, 0.24), (0.5, 0.76)], color, 0.014)
        c.stroke([(0.24, 0.5), (0.76, 0.5)], color, 0.014)
        c.disc(0.5, 0.5, 0.045, (255, 255, 255, 235), None, 0)
    elif glyph == 3:                                  # ember: flame
        c.poly([(0.5, 0.24), (0.66, 0.52), (0.60, 0.74), (0.40, 0.74), (0.34, 0.52)], EMBER, INK, 0.022)
        c.poly([(0.5, 0.40), (0.58, 0.56), (0.54, 0.70), (0.46, 0.70), (0.42, 0.56)], DAWN, INK, 0.012)
    elif glyph == 4:                                  # frost: snowflake
        for k in range(6):
            ang = k * 3.14159265 / 3
            c.stroke([(0.5, 0.5), (0.5 + _cos(ang) * 0.26, 0.5 + _sin(ang) * 0.26)], color, 0.016)
        c.disc(0.5, 0.5, 0.05, (255, 255, 255, 235), None, 0)
    elif glyph == 5:                                  # lightning
        c.poly([(0.56, 0.22), (0.36, 0.54), (0.50, 0.54), (0.42, 0.80), (0.66, 0.46), (0.52, 0.46)], color, INK, 0.018)
    elif glyph == 6:                                  # spring: concentric arcs
        for k in range(3):
            c.arc(0.5, 0.58, 0.14 + 0.07 * k, 200, 340, ease(color, (255, 255, 255, 255), 0.2 * k), 0.018)
        c.disc(0.5, 0.36, 0.06, color, INK, 0.016)
    elif glyph == 7:                                  # echo: tuning fork + note
        c.stroke([(0.44, 0.28), (0.44, 0.62)], color, 0.026)
        c.stroke([(0.56, 0.28), (0.56, 0.62)], color, 0.026)
        c.stroke([(0.44, 0.62), (0.50, 0.72), (0.56, 0.62)], color, 0.020)
        c.stroke([(0.30, 0.34), (0.30, 0.66)], ease(color, (255, 255, 255, 255), 0.3), 0.012)
    elif glyph == 8:                                  # bastion: shield + bar
        c.poly([(0.5, 0.24), (0.72, 0.34), (0.68, 0.62), (0.5, 0.78), (0.32, 0.62), (0.28, 0.34)], IRON, INK, 0.024)
        for k in range(steps):
            c.stroke([(0.34, 0.40 + 0.08 * k), (0.66, 0.40 + 0.08 * k)], ease(GOLD, BONE, 0.4), 0.012)
    elif glyph == 9:                                  # wind: wing + dashes
        c.poly([(0.30, 0.56), (0.58, 0.30), (0.68, 0.44), (0.44, 0.66)], ease(color, BONE, 0.2), INK, 0.020)
        for k in range(steps):
            c.stroke([(0.26 + 0.06 * k, 0.72), (0.44 + 0.06 * k, 0.72)], color, 0.012)
    elif glyph == 10:                                 # spectral: bell + wisp
        c.poly([(0.5, 0.26), (0.66, 0.58), (0.34, 0.58)], ease(color, BONE, 0.2), INK, 0.024)
        c.rect(0.40, 0.58, 0.60, 0.66, GOLD, INK, 0.018)
        c.disc(0.5, 0.72, 0.04, ease(VIOLET, (255, 255, 255, 255), 0.4), INK, 0.012)
    else:                                             # dawn: clasped rings + bell
        c.ring(0.42, 0.52, 0.13, color, 0.020)
        c.ring(0.58, 0.52, 0.13, ease(color, GOLD, 0.4), 0.020)
        for k in range(steps):
            c.stroke([(0.34 + 0.10 * k, 0.30), (0.34 + 0.10 * k, 0.40)], DAWN, 0.010)


def paint_engraving(c: Canvas, index: int, defn: dict):
    color = [CRIMSON, GOLD, FROST, BOLT, VIOLET, WIND][index % 6]
    c.disc(0.5, 0.5, 0.34, ease(IRON, GOLD, 0.28), INK, 0.030)
    c.ring(0.5, 0.5, 0.30, ease(GOLD, BONE, 0.25), 0.016)
    c.ring(0.5, 0.5, 0.26, ease(IRON, (0, 0, 0, 255), 0.3), 0.010)
    kind = index % 8
    if kind == 0:
        c.stroke([(0.34, 0.62), (0.66, 0.38)], color, 0.018)
        c.stroke([(0.34, 0.38), (0.66, 0.62)], color, 0.018)
    elif kind == 1:
        c.poly([(0.5, 0.30), (0.68, 0.50), (0.5, 0.70), (0.32, 0.50)], color, INK, 0.016)
    elif kind == 2:
        for k in range(3):
            c.ring(0.5, 0.5, 0.09 + 0.06 * k, color, 0.014)
    elif kind == 3:
        c.stroke([(0.5, 0.30), (0.5, 0.70)], color, 0.020)
        c.stroke([(0.36, 0.42), (0.5, 0.30), (0.64, 0.42)], color, 0.018)
    elif kind == 4:
        c.poly([(0.5, 0.28), (0.62, 0.50), (0.5, 0.72), (0.38, 0.50)], None, color, 0.020)
    elif kind == 5:
        for k in range(4):
            c.stroke([(0.34, 0.36 + 0.09 * k), (0.66 - 0.07 * (k % 2), 0.36 + 0.09 * k)], color, 0.012)
    elif kind == 6:
        c.arc(0.5, 0.54, 0.16, 200, 340, color, 0.016)
        c.disc(0.5, 0.36, 0.05, color, INK, 0.012)
    else:
        c.stroke([(0.34, 0.34), (0.66, 0.34)], color, 0.014)
        c.stroke([(0.34, 0.66), (0.66, 0.66)], color, 0.014)
        c.stroke([(0.5, 0.30), (0.5, 0.70)], ease(BONE, color, 0.4), 0.012)


def paint_core(c: Canvas, family: int, index: int, defn: dict):
    color = [CRIMSON, GOLD, FROST, VIOLET][family % 4]
    c.disc(0.5, 0.5, 0.35, ease(IRON, color, 0.14), INK, 0.030)
    c.ring(0.5, 0.5, 0.32, ease(color, GOLD, 0.4), 0.018)
    c.disc(0.5, 0.5, 0.22, ease((20, 18, 24, 255), color, 0.18), INK, 0.016)
    if family == 1:
        c.stroke([(0.36, 0.64), (0.64, 0.36)], ease(color, BONE, 0.3), 0.030)
        c.stroke([(0.38, 0.44), (0.56, 0.62)], ease(color, BONE, 0.3), 0.016)
    elif family == 2:
        c.rect(0.34, 0.42, 0.66, 0.58, ease(STEEL, color, 0.35), INK, 0.018, 0.02)
        c.stroke([(0.66, 0.46), (0.74, 0.40)], BONE, 0.014)
    elif family == 0:
        c.rect(0.30, 0.50, 0.74, 0.60, ease(DARKSTEEL, color, 0.3), INK, 0.018, 0.02)
        c.disc(0.38, 0.55, 0.05, color, INK, 0.012)
    else:
        c.stroke([(0.36, 0.66), (0.58, 0.42)], ease(IRON, GOLD, 0.35), 0.028)
        c.disc(0.62, 0.38, 0.06, color, INK, 0.014)
    for k in range(1 + index % 4):
        c.disc(0.28 + 0.12 * k, 0.22, 0.022, ease(color, BONE, 0.4), INK, 0.010)


# ----------------------------------------------------------------------- hero sheets

def paint_hero(edge_scale: int, hero: int, pose: int) -> Image.Image:
    c = Canvas(edge=edge_scale)
    color = HERO_COLOR[hero % 4]
    body = ease(IRON, color, 0.22)
    skin = ease(BONE, color, 0.12)
    # pose 5 is the upright reference; feet always rest on the shared ground pivot.
    crouch = {0: 0.62, 1: 0.72, 2: 0.86, 3: 0.96, 4: 0.68, 5: 1.0}[pose]
    hip = FLOOR - 0.30 * crouch
    shoulder = FLOOR - 0.52 * crouch
    head_y = FLOOR - 0.62 * crouch
    lean = {0: -0.03, 1: 0.0, 2: 0.0, 3: 0.02, 4: -0.04, 5: 0.0}[pose]
    # legs
    c.stroke([(0.5, hip), (0.42 + lean, FLOOR - 0.02)], body, 0.038)
    c.stroke([(0.5, hip), (0.58 + lean, FLOOR - 0.02)], body, 0.038)
    c.stroke([(0.42 + lean, FLOOR - 0.02), (0.36 + lean, FLOOR)], INK, 0.030)
    c.stroke([(0.58 + lean, FLOOR - 0.02), (0.64 + lean, FLOOR)], INK, 0.030)
    # torso
    c.poly([(0.5 - 0.10 + lean, shoulder), (0.5 + 0.10 + lean, shoulder),
            (0.5 + 0.08, hip + 0.02), (0.5 - 0.08, hip + 0.02)], body, INK, 0.026)
    # arms
    arm = {0: (-0.20, 0.20), 1: (-0.14, 0.14), 2: (-0.22, 0.22), 3: (-0.10, 0.10), 4: (-0.16, 0.16), 5: (-0.12, 0.12)}[pose]
    c.stroke([(0.5 - 0.08 + lean, shoulder + 0.04), (0.5 + arm[0] + lean, shoulder + 0.16)], body, 0.028)
    c.stroke([(0.5 + 0.08 + lean, shoulder + 0.04), (0.5 + arm[1] + lean, shoulder + 0.16)], body, 0.028)
    # head
    c.disc(0.5 + lean, head_y, 0.085, skin, INK, 0.022)
    c.stroke([(0.5 - 0.085 + lean, head_y - 0.02), (0.5 + 0.085 + lean, head_y - 0.02)], color, 0.020)
    # scarf accent per hero keeps sheets visually distinct
    c.stroke([(0.5 - 0.10 + lean, shoulder), (0.5 + 0.10 + lean, shoulder)], color, 0.020)
    return c.icon(edge_scale)


def _build_icon_image(category: str, defn: dict, index: int, group: str = "") -> Image.Image:
    c = Canvas()
    if category == "weapons":
        # resources/rogue_build_content.json uses 1-based families (1 light, 2 heavy,
        # 0 ranged, 3 staff); the atlas key is the authoritative silhouette group.
        paint_weapon(c, group or "light", index, defn)
    elif category == "gear":
        paint_gear(c, int(defn.get("slot", 0)) % 3, index, str(defn.get("template", "A1")), defn)
    elif category == "talents":
        paint_talent(c, int(defn.get("school", 0)) % 12, index, defn)
    elif category == "engravings":
        paint_engraving(c, index, defn)
    else:
        paint_core(c, int(defn.get("family", 0)) % 4, index, defn)
    return c.icon()


def category_of(identifier: str) -> str:
    if identifier.startswith("WC"):
        return "cores"
    return {"W": "weapons", "E": "gear", "T": "talents", "I": "engravings"}[identifier[0]]


def main() -> int:
    content = json.loads((ROOT / "resources" / "rogue_build_content.json").read_text(encoding="utf-8"))
    by_id = {}
    for key in ("weapons", "gear", "talents", "engravings", "cores"):
        for entry in content[key]:
            by_id[str(entry["id"])] = entry
    assert len(by_id) == 252, len(by_id)

    plan = json.loads((OUT / "generation-plan.json").read_text(encoding="utf-8"))
    assert sum(len(p["ids"]) for p in plan) == 252

    OUT.mkdir(parents=True, exist_ok=True)
    record = []
    for spec in plan:
        columns, rows = int(spec["columns"]), int(spec["rows"])
        assert len(spec["ids"]) == columns * rows
        atlas = Image.new("RGBA", (CELL * columns, CELL * rows), (0, 0, 0, 0))
        group = spec["key"].split("-")[1] if spec["key"].startswith("weapons-") else ""
        for i, identifier in enumerate(spec["ids"]):
            defn = by_id[identifier]
            icon = _build_icon_image(category_of(identifier), defn, i, group)
            atlas.paste(icon, ((i % columns) * CELL, (i // columns) * CELL), icon)
        target = OUT / spec["file"]
        atlas.save(target)
        record.append({
            "key": spec["key"],
            "category": category_of(spec["ids"][0]),
            "columns": columns,
            "rows": rows,
            "ids": spec["ids"],
            "final_file": spec["file"],
            "cell": CELL,
            "size": [atlas.width, atlas.height],
            "tool": "tools/generate_rogue_build_art.py",
            "prompt": spec.get("prompt", ""),
            "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        })

    (OUT / "generation-record.json").write_text(
        json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    jump_record = []
    for hero in range(4):
        sheet = Image.new("RGBA", (JUMP_CELL * 3, JUMP_CELL * 2), (0, 0, 0, 0))
        for pose in range(6):
            icon = paint_hero(JUMP_CELL, hero, pose)
            sheet.paste(icon, ((pose % 3) * JUMP_CELL, (pose // 3) * JUMP_CELL), icon)
        target = OUT / f"hero-{hero}-jump-v1.png"
        sheet.save(target)
        jump_record.append({
            "key": f"hero-{hero}-jump-v1",
            "hero": hero,
            "columns": 3,
            "rows": 2,
            "final_file": target.name,
            "cell": JUMP_CELL,
            "poses": ["launch", "rising", "apex", "falling", "landing", "standing"],
            "size": [sheet.width, sheet.height],
            "tool": "tools/generate_rogue_build_art.py",
            "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        })
    (OUT / "jump-generation-record.json").write_text(
        json.dumps(jump_record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    flask = Canvas(edge=224)
    paint_flask(flask)
    flask.icon(224).save(OUT / "blood-flask-v1.png")

    for tool in ("index_rogue_build_art.py", "index_rogue_jump_art.py"):
        result = subprocess.run([sys.executable, str(ROOT / "tools" / tool)],
                                cwd=str(ROOT), capture_output=True, text=True)
        print(result.stdout.strip())
        if result.returncode != 0:
            print(result.stderr.strip(), file=sys.stderr)
            return result.returncode

    print("Generated 13 atlases / 252 icons, 4 hero jump sheets (24 poses), 1 flask icon.")
    return 0


def paint_flask(c: Canvas):
    glass = (206, 226, 232, 235)
    c.poly([(0.40, 0.16), (0.60, 0.16), (0.60, 0.34), (0.76, 0.62), (0.76, 0.80), (0.24, 0.80), (0.24, 0.62), (0.40, 0.34)],
           glass, INK, 0.026)
    c.poly([(0.27, 0.58), (0.73, 0.58), (0.73, 0.78), (0.27, 0.78)], CRIMSON, INK, 0.020)
    c.poly([(0.40, 0.18), (0.60, 0.18), (0.60, 0.26), (0.40, 0.26)], GOLD, INK, 0.018)
    c.disc(0.42, 0.70, 0.030, (255, 255, 255, 190), None, 0)
    c.stroke([(0.34, 0.40), (0.30, 0.58)], (255, 255, 255, 150), 0.014)


if __name__ == "__main__":
    raise SystemExit(main())
