"""Preserve the original attack art and add green canvas space around it."""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "output" / "minimax-action-pack"
SOURCE = PACK / "source-stills" / "attacks"
STILLS = PACK / "stills" / "heroes"
CANVAS_SIZE = 1536
GREEN = np.array([0, 248, 0], dtype=np.float32)
FADE_WIDTH = 80
ACTIONS = ("sword", "heavy", "staff")
ALL_ACTIONS = ("walk", "run", "dodge", *ACTIONS)


def add_green_canvas(source: Path, destination: Path) -> None:
    original = np.asarray(Image.open(source).convert("RGB"))
    height, width = original.shape[:2]
    if width != height or width >= CANVAS_SIZE:
        raise ValueError(f"Unexpected source size: {source}: {width}x{height}")
    left = (CANVAS_SIZE - width) // 2
    top = (CANVAS_SIZE - height) // 2

    # Extend the original green edge outward and blend it to solid chroma green.
    # The complete source rectangle is copied bit for bit without scaling or redraw.
    x = np.arange(CANVAS_SIZE)
    y = np.arange(CANVAS_SIZE)
    source_x = np.clip(x - left, 0, width - 1)
    source_y = np.clip(y - top, 0, height - 1)
    extended = original[np.ix_(source_y, source_x)].astype(np.float32)
    distance_x = np.maximum(np.maximum(left - x, x - (left + width - 1)), 0)
    distance_y = np.maximum(np.maximum(top - y, y - (top + height - 1)), 0)
    distance = np.maximum(distance_y[:, None], distance_x[None, :])
    amount = np.minimum(distance / FADE_WIDTH, 1.0)[..., None]
    canvas = np.rint(extended * (1 - amount) + GREEN * amount).astype(np.uint8)
    assert np.array_equal(canvas[top : top + height, left : left + width], original)
    destination.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(canvas, "RGB").save(destination, optimize=True)


def make_contact_sheet(actions: tuple[str, ...], output_name: str) -> None:
    cell = 410
    label_height = 28
    columns = len(actions)
    sheet = Image.new("RGB", (columns * cell, 4 * (cell + label_height)), "#202020")
    draw = ImageDraw.Draw(sheet)
    for hero in range(4):
        for column, action in enumerate(actions):
            still = Image.open(STILLS / f"hero-{hero}" / f"{action}.png").convert("RGB")
            still.thumbnail((cell - 24, cell - 24), Image.Resampling.LANCZOS)
            x = column * cell + (cell - still.width) // 2
            y = hero * (cell + label_height) + label_height + (cell - still.height) // 2
            sheet.paste(still, (x, y))
            draw.text((column * cell + 12, hero * (cell + label_height) + 7), f"hero {hero} / {action}", fill="white")
    sheet.save(PACK / output_name, quality=92)


def main() -> None:
    for hero in range(4):
        for action in ACTIONS:
            source = SOURCE / f"hero-{hero}" / f"{action}.png"
            destination = STILLS / f"hero-{hero}" / f"{action}.png"
            add_green_canvas(source, destination)
            print(f"{source.relative_to(PACK)} -> {destination.relative_to(PACK)}")
    make_contact_sheet(ACTIONS, "attack-contact-sheet.jpg")
    make_contact_sheet(ALL_ACTIONS, "contact-sheet.jpg")


if __name__ == "__main__":
    main()
