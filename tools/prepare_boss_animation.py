"""Pack approved 4K transparent boss motion sheets into fixed 4x3 game atlases."""

import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[1]
CELL = (960, 720)
DESTINATIONS = {
    "bell-hierophant": "assets/bosses/bell-hierophant-atlas.png",
    "thorn-huntsman": "assets/bosses/thorn-huntsman-atlas.png",
    "blood-queen": "assets/bosses/blood-queen-atlas.png",
    "mirror-weaver": "assets/bosses/new/mirror-weaver-atlas.png",
    "ashen-vesper": "assets/bosses/new/ashen-vesper-atlas.png",
    "nameless-moon": "assets/bosses/new/nameless-moon-atlas.png",
    "earthsplitter": "assets/bosses/wild/earthsplitter-atlas.png",
    "storm-roc-v2": "assets/bosses/wild/storm-roc-v2-atlas.png",
    "moon-leviathan": "assets/bosses/wild/moon-leviathan-atlas.png",
    "frostbone-dragon": "assets/bosses/dragon/frostbone-dragon-atlas.png",
}


def gutter(profile, target, radius):
    start, end = max(1, target - radius), min(len(profile) - 1, target + radius)
    smoothed = np.convolve(profile, np.ones(15) / 15, mode="same")
    candidates = np.arange(start, end)
    return int(candidates[np.argmin(smoothed[start:end] + abs(candidates - target) * 0.12)])


def pack(name, destination):
    source = ROOT / "build" / f"{name}-sheet-candidate.png"
    with Image.open(source) as image:
        if image.size != (3840, 2160) or image.mode != "RGBA":
            raise ValueError(f"{source}: expected a 3840x2160 RGBA image")
        original = image.copy()

    alpha = np.asarray(original.getchannel("A")) > 96
    rows = [0] + [gutter(alpha.sum(axis=1), 720 * index, 190) for index in (1, 2)] + [2160]
    frames = []
    for row in range(3):
        top, bottom = rows[row:row + 2]
        labels, _ = ndimage.label(alpha[top:bottom])
        sizes = np.bincount(labels.ravel())
        sizes[0] = 0
        bodies = sorted(np.argsort(sizes)[-4:],
                        key=lambda index: ndimage.center_of_mass(labels == index)[1])
        if any(sizes[index] < 2000 for index in bodies):
            raise ValueError(f"{source}: row {row} has fewer than four complete poses")
        centers = [ndimage.center_of_mass(labels == index)[1] for index in bodies]
        groups = [[index] for index in bodies]
        regions = ndimage.find_objects(labels)
        for index, region in enumerate(regions, 1):
            if region is None or sizes[index] < 80 or index in bodies:
                continue
            center = (region[1].start + region[1].stop) / 2
            nearest = min(range(4), key=lambda column: abs(centers[column] - center))
            groups[nearest].append(index)
        for group in groups:
            selected = [regions[index - 1] for index in group]
            left = max(0, min(region[1].start for region in selected) - 3)
            right = min(3840, max(region[1].stop for region in selected) + 3)
            upper = max(0, min(region[0].start for region in selected) - 3)
            lower = min(bottom - top, max(region[0].stop for region in selected) + 3)
            frame = original.crop((left, top + upper, right, top + lower))
            owned = np.isin(labels[upper:lower, left:right], group)
            rgba = np.asarray(frame).copy()
            rgba[~ndimage.binary_dilation(owned, iterations=3), 3] = 0
            frames.append(Image.fromarray(rgba, "RGBA"))

    widest = max(frame.width for frame in frames)
    tallest = max(frame.height for frame in frames)
    scale = min(900 / widest, 650 / tallest, 1.0)
    atlas = Image.new("RGBA", (3840, 2160))
    for index, frame in enumerate(frames):
        size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
        sprite = frame.resize(size, Image.Resampling.LANCZOS)
        x = (index % 4) * CELL[0] + (CELL[0] - size[0]) // 2
        y = (index // 4) * CELL[1] + 685 - size[1]
        atlas.alpha_composite(sprite, (x, y))

    path = ROOT / destination
    path.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(path, optimize=True)
    print(f"{name}: 12 frames, {widest}x{tallest} max crop, {scale:.3f} scale")
    return {"path": "res://" + destination, "packed_height": round(tallest * scale, 2)}


def main():
    metadata = {name: pack(name, destination) for name, destination in DESTINATIONS.items()}
    (ROOT / "assets/bosses/motion-atlas.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
