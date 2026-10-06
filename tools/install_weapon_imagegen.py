"""Install original ImageGen RGBA sheets without modifying their pixels."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/combat/imagegen-square"


def install(source: Path, key: str, columns: int, prompt: Path) -> None:
    with Image.open(source) as im:
        assert "A" in im.getbands(), f"Missing generated alpha: {source}"
        alpha = im.getchannel("A")
        assert alpha.getextrema()[0] == 0, "Sheet has no transparent negative space"
        width, height = im.size
        frames = []
        for stage in range(columns):
            left = round(width * stage / columns)
            right = round(width * (stage + 1) / columns)
            frame = alpha.crop((left, 0, right, height))
            bounds = frame.point(lambda value: 255 if value > 12 else 0).getbbox()
            assert bounds, f"Empty stage {stage}: {source}"
            frames.append({"region": [left, 0, right-left, height], "ink": list(bounds)})
    DEST.mkdir(parents=True, exist_ok=True)
    target = DEST / f"{key}.png"
    shutil.copy2(source, target)
    manifest_path = DEST / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {"generator": "built-in ImageGen", "original_rgba": True, "assets": {}}
    prompt_name = f"assets/combat/imagegen-square/prompts/{prompt.name}"
    manifest["assets"][key] = {"file": target.name, "original": str(source), "size": [width, height], "frames": frames, "sha256": hashlib.sha256(source.read_bytes()).hexdigest(), "prompt": prompt_name}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(f"Installed {key}: {width}x{height}, {columns} stages, original RGBA preserved")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("key")
    parser.add_argument("--columns", type=int, default=3)
    parser.add_argument("--prompt", type=Path, required=True)
    args = parser.parse_args()
    install(args.source, args.key, args.columns, args.prompt)
