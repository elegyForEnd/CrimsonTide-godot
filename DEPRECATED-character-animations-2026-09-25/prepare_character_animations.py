"""Key generated chroma green and pack 12 isolated poses per hero animation."""

import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[1]
JOBS = ROOT / "output/imagegen/character-animation-jobs.jsonl"
CELL = (960, 720)
SCALE = 0.78


def pack(job: dict) -> None:
    source = ROOT / "output/imagegen" / job["out"]
    destination = ROOT / "assets/combat/animations" / Path(job["out"]).relative_to("character-animations")
    with Image.open(source) as image:
        if image.size != (3840, 2160):
            raise ValueError(f"{source}: expected 3840x2160, got {image.size}")
        pixels = np.array(image.convert("RGBA"))

    rgb = pixels[:, :, :3].astype(np.int16)
    green_strength = rgb[:, :, 1] - np.maximum(rgb[:, :, 0], rgb[:, :, 2])
    if np.median(green_strength[:40, :40]) < 100:
        raise ValueError(f"{source}: background is not flat chroma green")
    opacity = np.clip((100.0 - green_strength) / 80.0, 0.0, 1.0)
    pixels[:, :, 3] = (pixels[:, :, 3].astype(np.float32) * opacity).astype(np.uint8)
    spill = green_strength > 20
    pixels[:, :, 1][spill] = np.minimum(
        rgb[:, :, 1][spill], np.maximum(rgb[:, :, 0][spill], rgb[:, :, 2][spill]) + 8
    ).astype(np.uint8)
    clean = Image.fromarray(pixels, "RGBA")
    atlas = Image.new("RGBA", (3840, 2160))
    width, height = round(CELL[0] * SCALE), round(CELL[1] * SCALE)
    for index in range(12):
        col, row = index % 4, index // 4
        cell = clean.crop((col * CELL[0], row * CELL[1], (col + 1) * CELL[0], (row + 1) * CELL[1]))
        cell_pixels = np.array(cell)
        labels, count = ndimage.label(cell_pixels[:, :, 3] > 32)
        if count:
            sizes = np.bincount(labels.ravel())
            remove = np.flatnonzero((sizes < max(120, int(sizes[1:].max() * 0.02))) & (np.arange(len(sizes)) > 0))
            if len(remove):
                cell_pixels[:, :, 3][np.isin(labels, remove)] = 0
                cell = Image.fromarray(cell_pixels, "RGBA")
        used = cell.getchannel("A").point(lambda alpha: 255 if alpha > 32 else 0).getbbox()
        if used is None:
            raise ValueError(f"{source}: frame {index} is empty")
        if used[0] == 0 or used[1] == 0 or used[2] == CELL[0] or used[3] == CELL[1]:
            print(f"Warning: {source.name} frame {index} reaches source cell edge: {used}", flush=True)
        shrunk = cell.resize((width, height), Image.Resampling.LANCZOS)
        atlas.alpha_composite(shrunk, (col * CELL[0] + (CELL[0] - width) // 2,
                                       row * CELL[1] + (CELL[1] - height) // 2))
    destination.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(destination, optimize=True)
    print(f"Packed {destination.relative_to(ROOT)}", flush=True)


def main() -> None:
    jobs = [json.loads(line) for line in JOBS.read_text(encoding="utf-8").splitlines() if line]
    for job in jobs:
        source = ROOT / "output/imagegen" / job["out"]
        if source.exists():
            pack(job)


if __name__ == "__main__":
    main()
