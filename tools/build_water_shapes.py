#!/usr/bin/env python3
"""Bake the deterministic water-shape library used by MapGen P3.

The runtime never builds these shapes procedurally: it randomly samples one of
the 50 lake outlines / 50 river centrelines and transforms it. Keeping the
library as data makes map generation cheap, reproducible and easy to author by
hand later. Re-run this file only when the library itself must change:

    python tools/build_water_shapes.py

Output: resources/water_shapes.json
"""

from __future__ import annotations

import json
import math
import random
from pathlib import Path

TAU = math.pi * 2.0
OUT = Path(__file__).resolve().parent.parent / "resources" / "water_shapes.json"

LAKE_FAMILIES = [
    ("lobe", 12),
    ("bay", 10),
    ("rift", 8),
    ("dendritic", 8),
    ("multi", 6),
    ("crescent", 3),
    ("crater", 3),
]

RIVER_FAMILIES = [
    ("gentle", 10),
    ("meander", 14),
    ("braided", 10),
    ("gorge", 6),
    ("delta", 6),
    ("young", 4),
]


def _family(rng: random.Random, table) -> str:
    total = sum(weight for _, weight in table)
    pick = rng.random() * total
    for name, weight in table:
        pick -= weight
        if pick <= 0:
            return name
    return table[-1][0]


def _normalize(points: list[list[float]]) -> list[list[float]]:
    """Center on the area centroid and scale the farthest vertex to 1."""
    n = len(points)
    cx = sum(p[0] for p in points) / n
    cy = sum(p[1] for p in points) / n
    moved = [[p[0] - cx, p[1] - cy] for p in points]
    longest = max(math.hypot(p[0], p[1]) for p in moved) or 1.0
    return [[round(p[0] / longest, 4), round(p[1] / longest, 4)] for p in moved]


def _lobe(rng: random.Random, theta: list[float]) -> list[float]:
    a2 = rng.uniform(0.14, 0.30)
    a3 = rng.uniform(0.08, 0.22)
    a4 = rng.uniform(0.04, 0.13)
    ph2, ph3, ph4 = (rng.uniform(0, TAU) for _ in range(3))
    out = []
    for t in theta:
        r = 1.0 + a2 * math.cos(2 * t + ph2) + a3 * math.cos(3 * t + ph3) + a4 * math.cos(4 * t + ph4)
        r += 0.035 * math.cos(7 * t + ph2 * 1.3)
        out.append(r)
    return out


def _bay(rng: random.Random, theta: list[float]) -> list[float]:
    a5 = rng.uniform(0.05, 0.13)
    a8 = rng.uniform(0.03, 0.08)
    ph = rng.uniform(0, TAU)
    notch = rng.uniform(0, TAU)
    notch2 = notch + rng.uniform(1.2, 2.6)
    out = []
    for t in theta:
        r = 1.0 + a5 * math.cos(5 * t + ph) + a8 * math.cos(8 * t + ph * 1.7)
        # Two narrow drowned valleys: still a simple radial silhouette.
        r -= 0.34 * math.exp(-((_angle_delta(t, notch)) / 0.20) ** 2)
        r -= 0.24 * math.exp(-((_angle_delta(t, notch2)) / 0.16) ** 2)
        out.append(max(0.32, r))
    return out


def _rift(rng: random.Random, theta: list[float]) -> list[float]:
    a3 = rng.uniform(0.04, 0.09)
    a7 = rng.uniform(0.02, 0.05)
    ph = rng.uniform(0, TAU)
    return [
        1.0
        + a3 * math.cos(3 * t + ph)
        + a7 * math.cos(7 * t + ph * 1.4)
        + 0.02 * math.cos(13 * t + ph * 0.7)
        for t in theta
    ]


def _dendritic(rng: random.Random, theta: list[float]) -> list[float]:
    arms = [rng.uniform(0, TAU) for _ in range(4)]
    out = []
    for t in theta:
        r = 1.0
        for i, arm in enumerate(arms):
            width = 0.09 + 0.03 * i
            r -= (0.13 + 0.02 * i) * math.exp(-((_angle_delta(t, arm)) / width) ** 2)
        r += 0.045 * math.cos(9 * t + arms[0]) + 0.03 * math.cos(14 * t + arms[1])
        out.append(max(0.35, r))
    return out


def _crater(rng: random.Random, theta: list[float]) -> list[float]:
    a6 = rng.uniform(0.02, 0.055)
    ph = rng.uniform(0, TAU)
    return [
        1.0 + a6 * math.cos(6 * t + ph) + 0.018 * math.cos(16 * t + ph * 2.0)
        for t in theta
    ]


def _multi(rng: random.Random, theta: list[float]) -> list[float]:
    """Union of two or three discs: a peanut / tri-basin silhouette."""
    count = rng.choice([2, 2, 3])
    discs = []
    for i in range(count):
        angle = TAU * i / count + rng.uniform(-0.25, 0.25)
        offset = rng.uniform(0.22, 0.40)
        radius = rng.uniform(0.48, 0.62)
        discs.append((math.cos(angle) * offset, math.sin(angle) * offset, radius))
    out = []
    for t in theta:
        ux, uy = math.cos(t), math.sin(t)
        best = 0.0
        for cx, cy, radius in discs:
            proj = cx * ux + cy * uy
            perp2 = max(0.0, (cx * cx + cy * cy) - proj * proj)
            if radius * radius < perp2:
                continue
            hit = proj + math.sqrt(radius * radius - perp2)
            best = max(best, hit)
        out.append(max(0.18, best))
    # Soften the union seams a little.
    return [r + 0.018 * math.cos(11 * t + rng.uniform(0, TAU)) for t, r in zip(theta, out)]


def _crescent(rng: random.Random) -> list[list[float]]:
    """An oxbow/crescent outline: long outer arc plus a shorter inner arc."""
    span = rng.uniform(1.55, 1.95)
    thickness = rng.uniform(0.34, 0.48)
    steps = 40
    outer = []
    for i in range(steps + 1):
        t = -span + 2 * span * i / steps
        outer.append([math.cos(t), math.sin(t)])
    inner = []
    for i in range(steps + 1):
        t = span - 2 * span * i / steps
        inner.append([math.cos(t) * (1 - thickness), math.sin(t) * (1 - thickness)])
    points = outer + inner
    # Rotate/elongate a touch so crescents do not all point the same way.
    angle = rng.uniform(0, TAU)
    stretch = rng.uniform(0.9, 1.35)
    ca, sa = math.cos(angle), math.sin(angle)
    return [
        [stretch * (p[0] * ca - p[1] * sa), p[0] * sa + p[1] * ca]
        for p in points
    ]


def _angle_delta(a: float, b: float) -> float:
    d = (a - b + math.pi) % TAU - math.pi
    return d


def make_lake(rng: random.Random, family: str) -> list[list[float]]:
    if family == "crescent":
        return _normalize(_crescent(rng))
    segments = 64
    theta = [TAU * i / segments for i in range(segments)]
    if family == "lobe":
        radii = _lobe(rng, theta)
        stretch = (rng.uniform(1.0, 1.5), rng.uniform(0.75, 1.0))
    elif family == "bay":
        radii = _bay(rng, theta)
        stretch = (rng.uniform(1.0, 1.45), rng.uniform(0.72, 1.0))
    elif family == "rift":
        radii = _rift(rng, theta)
        stretch = (rng.uniform(1.9, 3.0), rng.uniform(0.55, 0.8))
    elif family == "dendritic":
        radii = _dendritic(rng, theta)
        stretch = (rng.uniform(1.1, 1.6), rng.uniform(0.8, 1.05))
    elif family == "multi":
        radii = _multi(rng, theta)
        stretch = (rng.uniform(1.0, 1.35), rng.uniform(0.8, 1.0))
    else:
        radii = _crater(rng, theta)
        stretch = (rng.uniform(0.95, 1.15), rng.uniform(0.9, 1.05))
    rotate = rng.uniform(0, TAU)
    ca, sa = math.cos(rotate), math.sin(rotate)
    points = []
    for t, r in zip(theta, radii):
        x = r * math.cos(t) * stretch[0]
        y = r * math.sin(t) * stretch[1]
        points.append([x * ca - y * sa, x * sa + y * ca])
    return _normalize(points)


def make_river(rng: random.Random, family: str) -> tuple[list[list[float]], list[float]]:
    count = 41
    xs = [-1.0 + 2.0 * i / (count - 1) for i in range(count)]
    phase = rng.uniform(0, TAU)
    if family == "gentle":
        amp = rng.uniform(0.05, 0.12)
        freq = rng.uniform(0.8, 1.6)
        ys = [amp * math.sin(math.pi * freq * x + phase) for x in xs]
    elif family == "meander":
        amp = rng.uniform(0.16, 0.30)
        freq = rng.uniform(1.5, 2.6)
        amp2 = rng.uniform(0.03, 0.07)
        ys = [
            amp * math.sin(math.pi * freq * x + phase)
            + amp2 * math.sin(math.pi * freq * 2.7 * x + phase * 1.6)
            for x in xs
        ]
    elif family == "braided":
        ys = [
            0.10 * math.sin(math.pi * 1.4 * x + phase)
            + 0.06 * math.sin(math.pi * 3.1 * x + phase * 2.1)
            + 0.035 * math.sin(math.pi * 5.3 * x + phase * 0.7)
            for x in xs
        ]
    elif family == "gorge":
        ys = [
            0.07 * math.sin(math.pi * 1.7 * x + phase)
            + 0.045 * math.sin(math.pi * 4.6 * x + phase * 1.3)
            + 0.02 * math.sin(math.pi * 9.0 * x + phase * 2.3)
            for x in xs
        ]
    elif family == "delta":
        ys = [
            0.08 * math.sin(math.pi * 1.1 * x + phase)
            + 0.04 * math.sin(math.pi * 2.9 * x + phase * 1.9)
            for x in xs
        ]
    else:  # young
        ys = [0.035 * math.sin(math.pi * 0.9 * x + phase) for x in xs]

    longest = max(abs(y) for y in ys) or 1.0
    ys = [y / longest * rng.uniform(0.30, 0.46) for y in ys]

    growth = {
        "gentle": rng.uniform(0.25, 0.55),
        "meander": rng.uniform(0.35, 0.65),
        "braided": rng.uniform(0.30, 0.55),
        "gorge": rng.uniform(0.20, 0.45),
        "delta": rng.uniform(1.4, 2.2),
        "young": rng.uniform(0.10, 0.30),
    }[family]
    widths = []
    for i in range(count):
        t = i / (count - 1)
        w = 0.72 + growth * (t ** 1.35)
        w += 0.10 * math.sin(4.0 * math.pi * t + phase)
        w += 0.05 * math.sin(9.0 * math.pi * t + phase * 2.0)
        widths.append(max(0.35, w))
    mean = sum(widths) / len(widths)
    widths = [round(w / mean, 3) for w in widths]
    points = [[round(x, 4), round(y, 4)] for x, y in zip(xs, ys)]
    return points, widths


def main() -> None:
    rng = random.Random(20261019)
    lakes = []
    for _ in range(50):
        family = _family(rng, LAKE_FAMILIES)
        lakes.append({"family": family, "points": make_lake(rng, family)})
    rivers = []
    for _ in range(50):
        family = _family(rng, RIVER_FAMILIES)
        points, widths = make_river(rng, family)
        rivers.append({"family": family, "points": points, "widths": widths})
    data = {
        "version": 1,
        "note": "Baked by tools/build_water_shapes.py; sampled by MapShapes.",
        "lakes": lakes,
        "rivers": rivers,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    print("wrote", OUT, OUT.stat().st_size, "bytes,", len(lakes), "lakes,", len(rivers), "rivers")


if __name__ == "__main__":
    main()
