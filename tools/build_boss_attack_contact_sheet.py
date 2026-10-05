"""Make a compact overview of opening, impact and recovery for every boss."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "output/attack-animation"
NAMES = [
    "ashen-vesper", "bell-hierophant", "blood-queen", "earthsplitter",
    "frostbone-dragon", "mirror-weaver", "moon-leviathan",
    "nameless-moon", "storm-roc-v2", "thorn-huntsman",
]


def main() -> None:
    columns, tile_width, tile_height, frame_size = 2, 768, 282, 240
    sheet = Image.new("RGB", (columns * tile_width, 5 * tile_height), (27, 29, 37))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 19)
    except OSError:
        font = ImageFont.load_default()
    for index, name in enumerate(NAMES):
        x = (index % columns) * tile_width
        y = (index // columns) * tile_height
        draw.rectangle((x + 2, y + 2, x + tile_width - 3, y + tile_height - 3), outline=(68, 71, 84), width=2)
        draw.text((x + 16, y + 12), name, font=font, fill=(246, 246, 250))
        folder = BASE / "bosses" / name / "attack"
        for slot, frame_number in enumerate((0, 4, 7)):
            path = folder / f"{frame_number:03d}.png"
            if not path.exists():
                continue
            frame = Image.open(path).convert("RGBA").resize((frame_size, frame_size), Image.Resampling.LANCZOS)
            board = Image.new("RGBA", frame.size, (42, 44, 54, 255))
            board.alpha_composite(frame)
            sheet.paste(board.convert("RGB"), (x + 12 + slot * 252, y + 32))
            draw.text((x + 20 + slot * 252, y + 260), ("OPEN", "IMPACT", "RETURN")[slot], font=font, fill=(220, 220, 230))
    target = BASE / "bosses-contact-sheet.jpg"
    sheet.save(target, quality=92)
    print(target)


if __name__ == "__main__":
    main()
