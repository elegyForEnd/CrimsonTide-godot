"""Build the small 9-slice crops the hunt UI uses from the 2K UI source sheets.

`assets/hunt/ui/*.png` are full 2K generations; Godot's `StyleBoxTexture` margins
are fixed screen pixels, so feeding a 2048px panel into a 340x196 HUD chip (or a
40px toast) draws the frame far too thick.  This script crops the part that is
actually used and pre-scales it to the size the UI skin was designed around.

The panel crop deliberately keeps only the inner stone + thin gold border: the
outer wood frame is ~140px thick at 1:1 and is reserved for a future layout pass
that gives the panel a real 1300px-wide canvas.  Everything here is deterministic;
re-run after regenerating any `*_alpha.png` source.

    python tools/build_hunt_ui_crops.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets/hunt/ui"
OUT = SRC / "crops"


def save(image: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    image.save(path, "PNG")
    print(f"{path.relative_to(ROOT)}  {image.width}x{image.height}")


def fit_width(image: Image.Image, width: int) -> Image.Image:
    height = round(width * image.height / image.width)
    return image.resize((width, height), Image.LANCZOS)


def main() -> None:
    panel = Image.open(SRC / "panel_alpha.png").convert("RGBA")
    save(fit_width(panel.crop((336, 348, 1714, 1702)), 512), "panel.png")

    toast = Image.open(SRC / "toast_alpha.png").convert("RGBA")
    save(fit_width(toast.crop((330, 410, 1720, 729)), 512), "toast.png")

    hotspots = Image.open(SRC / "hotspot_set_alpha.png").convert("RGBA")
    for name, box in {
        "hotspot_ready.png": (762, 150, 1288, 710),
        "hotspot_used.png": (762, 760, 1288, 1292),
        "hotspot_locked.png": (768, 1300, 1280, 1872),
    }.items():
        save(fit_width(hotspots.crop(box), 256), name)

    # The clickable button is split by `slice-alpha.py` into three rows
    # (normal / hover / pressed); each crop keeps the whole spiky button.
    for set_name in ("button_normal_set", "button_accent_set"):
        for row, state in enumerate(("normal", "hover", "pressed"), start=1):
            source = SRC / "individual" / f"{set_name}_r{row}c1.png"
            save(fit_width(Image.open(source).convert("RGBA"), 512), f"{set_name}_{state}.png")


if __name__ == "__main__":
    main()
