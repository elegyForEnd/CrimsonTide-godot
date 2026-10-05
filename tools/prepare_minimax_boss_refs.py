"""Extract the five boss states used by the game's 12-cell atlases."""

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "minimax-action-pack" / "boss-pose-refs"
FRAMES = {"move": 0, "attack": 5, "idle": 8, "hurt": 10, "death": 11}


def main() -> None:
    atlas_data = json.loads((ROOT / "assets/bosses/motion-atlas.json").read_text(encoding="utf-8"))
    for name, record in atlas_data.items():
        atlas = Image.open(ROOT / record["path"].removeprefix("res://")).convert("RGBA")
        for action, frame in FRAMES.items():
            x = (frame % 4) * 960
            y = (frame // 4) * 720
            cell = atlas.crop((x, y, x + 960, y + 720))
            box = cell.getbbox()
            if box is None:
                raise ValueError(f"Empty reference: {name}/{action}")
            pose = cell.crop(box)
            pose.thumbnail((660, 660), Image.Resampling.LANCZOS)
            canvas = Image.new("RGBA", (1024, 1024))
            canvas.alpha_composite(pose, ((1024 - pose.width) // 2, 820 - pose.height))
            dest = OUT / name / f"{action}.png"
            dest.parent.mkdir(parents=True, exist_ok=True)
            canvas.save(dest)
            print(dest.relative_to(ROOT))


if __name__ == "__main__":
    main()
