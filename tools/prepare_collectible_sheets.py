"""Validate the generated 3x3 sheets and install exact-cell PNG atlases."""

import argparse
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "output" / "imagegen" / "collectibles"
DESTINATION = ROOT / "assets" / "icons"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sheet", type=int, choices=range(1, 7), nargs="*")
    args = parser.parse_args()
    numbers = args.sheet if args.sheet else range(1, 7)
    for number in numbers:
        source = SOURCE / f"sheet-{number:02d}.png"
        with Image.open(source) as file:
            image = file.convert("RGBA")
        if image.size != (1024, 1024):
            raise ValueError(f"Unexpected size for {source}: {image.size}")
        # A 1023 px atlas has three exact 341 px cells; the last source edge is
        # transparent padding, so removing it cannot clip any of the objects.
        atlas = image.crop((0, 0, 1023, 1023))
        for row in range(3):
            for column in range(3):
                x0, y0 = column * 341, row * 341
                x1, y1 = (column + 1) * 341, (row + 1) * 341
                cell = atlas.getchannel("A").crop((x0, y0, x1, y1))
                bounds = cell.getbbox()
                if bounds is None:
                    raise ValueError(f"Empty icon in sheet {number}, cell {row * 3 + column + 1}")
        output = DESTINATION / f"collectibles-{number:02d}.png"
        atlas.save(output, optimize=True)
        print(f"Installed {output}")


if __name__ == "__main__":
    main()
