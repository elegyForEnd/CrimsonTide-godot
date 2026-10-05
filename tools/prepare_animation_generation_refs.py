"""Extract original pose strips for image-generation reference only."""

import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "output" / "imagegen-refs"
DEST.mkdir(parents=True, exist_ok=True)


def hero_row_boundaries(image: Image.Image) -> list[int]:
    occupied = np.count_nonzero(np.asarray(image.convert("RGBA"))[:, :, 3] > 20,
                                axis=1)
    bounds = [0]
    for expected in (image.height // 3, image.height * 2 // 3):
        near = [y for y in range(expected - 35, expected + 55)
                if occupied[y] < 3]
        groups = []
        for y in near:
            if not groups or y != groups[-1][-1] + 1:
                groups.append([y])
            else:
                groups[-1].append(y)
        group = max(groups, key=len)
        bounds.append((group[0] + group[-1]) // 2)
    return bounds + [image.height]


for hero in range(4):
    for source_name, actions in (("attack-clean", ("sword", "heavy", "staff")),
                                 ("movement", ("walk", "run", "dodge"))):
        image = Image.open(ROOT / "assets" / "combat" /
                           f"{source_name}-{hero}.png").convert("RGBA")
        bounds = hero_row_boundaries(image)
        for row, action in enumerate(actions):
            strip = image.crop((0, bounds[row], image.width, bounds[row + 1]))
            strip.save(DEST / f"hero-{hero}-{action}-reference.png")

bosses = json.loads((ROOT / "assets" / "bosses" /
                     "motion-atlas.json").read_text(encoding="utf-8"))
for name, data in bosses.items():
    image = Image.open(ROOT / data["path"].removeprefix("res://")).convert("RGBA")
    for row, action in enumerate(("move", "attack", "idle")):
        width = 1920 if action == "idle" else image.width
        strip = image.crop((0, row * 720, width, (row + 1) * 720))
        strip.thumbnail((1920, 720), Image.Resampling.LANCZOS)
        strip.save(DEST / f"boss-{name}-{action}-reference.png")

print(f"Prepared {4 * 6 + len(bosses) * 3} reference strips in {DEST}")
