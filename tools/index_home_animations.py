"""Index generated originals without rewriting any image pixels.

Frame counts/row cuts were inspected against all four ImageGen outputs. This
stores source rectangles, support-foot pivots and per-action standing scales.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets/home/animations"
ACTIONS = ("plant", "water", "harvest", "cast", "reel")
ROWS = {
    0: [0, 262, 500, 712, 936, 1145],
    1: [0, 233, 458, 678, 910, 1145],
    2: [0, 246, 478, 713, 929, 1145],
    3: [0, 273, 497, 713, 934, 1145],
}
COUNTS = {0: [7, 7, 6, 6, 6], 1: [7, 7, 7, 6, 6],
          2: [6, 6, 6, 6, 6], 3: [7, 7, 7, 6, 6]}


def main():
    manifest = {}
    for hero in range(4):
        image = Image.open(ROOT / f"hero-{hero}-v1.png").convert("RGBA")
        alpha = np.array(image.getchannel("A")) > 50
        height, width = alpha.shape
        assert (width, height) == (1374, 1145), "Re-audit cuts when originals change"
        manifest[str(hero)] = {}
        for row, action in enumerate(ACTIONS):
            y0, y1 = ROWS[hero][row:row + 2]
            count = COUNTS[hero][row]
            occupancy = alpha[y0:y1].sum(axis=0)
            cuts = [0]
            for column in range(1, count):
                lo, hi = int(width * (column / count - .045)), int(width * (column / count + .045))
                cuts.append(lo + int(np.argmin(occupancy[lo:hi])))
            cuts.append(width)
            frames, body_heights = [], []
            for column in range(count):
                x0, x1 = cuts[column:column + 2]
                cell = alpha[y0:y1, x0:x1]
                central = cell[:, int(cell.shape[1] * .30):int(cell.shape[1] * .72)]
                ys = np.flatnonzero(central.sum(axis=1) >= 3)
                assert len(ys), (hero, action, column)
                foot = int(ys[-1]) + 1
                # Bottom of the central silhouette avoids ponytail/rod extremities.
                band = central[max(0, foot - 9):foot]
                xs = np.flatnonzero(band.sum(axis=0) > 0)
                pivot = float(xs.mean()) + int(cell.shape[1] * .30)
                body_heights.append(foot - int(ys[0]))
                frames.append({"region": [x0, y0, x1 - x0, y1 - y0], "pivot": [round(pivot, 2), foot]})
            reference = -2 if action == "harvest" else 0
            manifest[str(hero)][action] = {
                "scale": 1.0 / body_heights[reference],
                "standing_pixels": body_heights[reference], "frames": frames,
            }
    (ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("Indexed", sum(len(s["frames"]) for h in manifest.values() for s in h.values()), "new frames; source images unchanged")


if __name__ == "__main__":
    main()
