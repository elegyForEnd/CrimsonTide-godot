"""Place individually generated attack frames on a common transparent canvas.

This script does no pose synthesis. Frame 1 is a chroma-keyed version of the
approved still; the remaining frames are individual ImageGen PNGs.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps


CANVAS = 1536


def remove_green(image: Image.Image) -> Image.Image:
    rgb = np.asarray(image.convert("RGB"), dtype=np.float32)
    # The approved stills use a slightly noisy #00f800 green, not #00ff00.
    chroma = np.array([0.0, 248.0, 0.0], dtype=np.float32)
    distance = np.linalg.norm(rgb - chroma, axis=2)
    alpha = np.clip((distance - 25.0) / 72.0, 0.0, 1.0)
    # Undo the green contribution of partially covered edge pixels.
    safe = np.maximum(alpha, 0.02)[..., None]
    restored = np.clip((rgb - (1.0 - alpha[..., None]) * chroma) / safe, 0, 255)
    restored[alpha < 0.015] = 0
    return Image.fromarray(
        np.dstack((restored.astype(np.uint8), (alpha * 255).astype(np.uint8))),
        "RGBA",
    )


def content_box(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.where(alpha > 24)
    if len(xs) == 0:
        raise ValueError("Empty alpha frame")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def foot_center(image: Image.Image, box: tuple[int, int, int, int]) -> float:
    alpha = np.asarray(image.getchannel("A"))
    x0, y0, x1, y1 = box
    strip_start = max(y0, y1 - max(48, int((y1 - y0) * 0.105)))
    _, xs = np.where(alpha[strip_start:y1, x0:x1] > 128)
    return float(np.median(xs + x0)) if len(xs) else (x0 + x1) / 2


def body_height(image: Image.Image) -> int:
    """Estimate head-to-foot height while ignoring thin raised weapons."""
    alpha = np.asarray(image.getchannel("A"))
    row_widths = np.count_nonzero(alpha > 128, axis=1)
    broad_rows = np.flatnonzero(row_widths >= 80)
    if len(broad_rows) == 0:
        return content_box(image)[3] - content_box(image)[1]
    return content_box(image)[3] - int(broad_rows[0])


def place(image: Image.Image, target_x: float, target_bottom: int) -> Image.Image:
    box = content_box(image)
    dx = round(target_x - foot_center(image, box))
    dy = target_bottom - box[3]
    # Keep all art inside the frame, including long weapons and trailing hair.
    dx = min(max(dx, 24 - box[0]), CANVAS - 24 - box[2])
    dy = min(max(dy, 24 - box[1]), CANVAS - 24 - box[3])
    canvas = Image.new("RGBA", (CANVAS, CANVAS))
    canvas.alpha_composite(image, (dx, dy))
    return canvas


def preview(frames: list[Image.Image], folder: Path) -> None:
    side = 384
    sheet = Image.new("RGB", (side * 4, side * 2), (28, 30, 38))
    draw = ImageDraw.Draw(sheet)
    for index, frame in enumerate(frames):
        tile = Image.new("RGBA", (side, side), (42, 44, 54, 255))
        small = frame.resize((side, side), Image.Resampling.LANCZOS)
        tile.alpha_composite(small)
        x, y = (index % 4) * side, (index // 4) * side
        sheet.paste(tile.convert("RGB"), (x, y))
        draw.text((x + 10, y + 8), f"{index + 1:02d}", fill="white", font=ImageFont.load_default())
    sheet.save(folder / "preview.jpg", quality=92)
    gif_frames = []
    for frame in frames:
        base = Image.new("RGBA", frame.size, (42, 44, 54, 255))
        base.alpha_composite(frame)
        gif_frames.append(base.resize((384, 384), Image.Resampling.LANCZOS).convert("RGB"))
    gif_frames[0].save(
        folder / "preview.gif", save_all=True, append_images=gif_frames[1:],
        duration=[110, 120, 100, 75, 95, 110, 120, 120], loop=0,
        optimize=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("still", type=Path)
    parser.add_argument("generated", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--mirror-generated", action="store_true")
    args = parser.parse_args()
    args.destination.mkdir(parents=True, exist_ok=True)
    first = remove_green(Image.open(args.still))
    if first.size != (CANVAS, CANVAS):
        raise ValueError(f"First frame must be {CANVAS}x{CANVAS}: {first.size}")
    base_box = content_box(first)
    target_x = foot_center(first, base_box)
    target_bottom = base_box[3]
    frames = [first]
    last_raw = Image.open(args.generated / "08.png").convert("RGBA")
    scale = float(np.clip(body_height(first) / body_height(last_raw), 0.65, 1.15))
    for number in range(2, 9):
        raw = Image.open(args.generated / f"{number:02d}.png").convert("RGBA")
        if args.mirror_generated:
            raw = ImageOps.mirror(raw)
        if raw.getchannel("A").getextrema()[0] == 255:
            raise ValueError(f"Generated frame {number} lacks transparency")
        if abs(scale - 1.0) > 0.015:
            raw = raw.resize(
                (round(raw.width * scale), round(raw.height * scale)),
                Image.Resampling.LANCZOS,
            )
        frames.append(place(raw, target_x, target_bottom))
    boxes = []
    for index, frame in enumerate(frames):
        frame.save(args.destination / f"{index:03d}.png")
        boxes.append(content_box(frame))
    preview(frames, args.destination)
    (args.destination / "animation.json").write_text(
        json.dumps({
            "frame_count": 8,
            "canvas": [CANVAS, CANVAS],
            "one_shot_fps": 10,
            "generated_frame_scale": round(scale, 4),
            "loop": False,
            "frame_order": [f"{n:03d}.png" for n in range(8)],
            "content_boxes": boxes,
            "source_still": str(args.still),
            "method": "Individual image-generated frames; frame 1 chroma-keyed from approved still; uniform scaling and translation for alignment",
        }, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(boxes))


if __name__ == "__main__":
    main()
