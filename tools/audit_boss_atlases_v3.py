"""Validate generated state atlases and register untouched PNG regions/pivots."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/bosses/imagegen/actions"

def main():
    catalog = json.loads((BASE / "catalog-v3.json").read_text(encoding="utf-8"))
    assets, warnings, missing = {}, [], []
    for spec in catalog["assets"]:
        path = BASE / (spec["id"] + ".png")
        if not path.exists():
            missing.append(spec["id"])
            continue
        image = Image.open(path)
        assert image.mode == "RGBA", (spec["id"], image.mode)
        data = np.array(image)
        assert data[:, :, 3].min() == 0, (spec["id"], "no transparency")
        cw, ch = image.width / 4, image.height / 2
        horizontal = spec["style"] in ["flow", "field", "directional", "projectile", "blade"]
        source = (.15, .55) if horizontal else (.5, .82)
        frames, hashes = [], set()
        contact_height = 1
        for index in range(8):
            row, col = divmod(index, 4)
            x0, x1 = round(col*cw), round((col+1)*cw)
            y0, y1 = round(row*ch), round((row+1)*ch)
            tile = data[y0:y1, x0:x1]
            alpha = tile[:, :, 3]
            ys, xs = np.where(alpha > 8)
            # A quiet final frame is valid; its registration still stays fixed.
            if len(xs):
                left, right = max(0, int(xs.min())-2), min(x1-x0, int(xs.max())+3)
                top, bottom = max(0, int(ys.min())-2), min(y1-y0, int(ys.max())+3)
            else:
                left, right, top, bottom = 0, x1-x0, 0, y1-y0
            if index in [2, 3, 4, 5]: contact_height = max(contact_height, bottom-top)
            edges = np.r_[alpha[0], alpha[-1], alpha[:, 0], alpha[:, -1]]
            if (edges > 100).mean() > .035:
                warnings.append({"asset": spec["id"], "frame": index, "issue": "solid pixels at cell edge"})
            digest = hashlib.sha256(tile.tobytes()).hexdigest()
            hashes.add(digest)
            frames.append({"region": [x0+left, y0+top, right-left, bottom-top],
                           "pivot": [cw*source[0]-left, ch*source[1]-top], "sha256": digest})
        assert len(hashes) == 8, (spec["id"], "repeated frames", len(hashes))
        assets[spec["id"]] = {"file": path.name, "identity": spec["key"], "role": spec["role"],
                              "style": spec["style"], "frames": frames,
                              "reach": cw*.70, "height": ch*.70, "ink_height": contact_height,
                              "states": {"prepare": [0, 1], "contact": [2, 3], "sustain": [4, 5], "recover": [6, 7]},
                              "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    report = {"expected": len(catalog["assets"]), "ready": len(assets), "missing": missing, "warnings": warnings}
    (BASE / "atlas-v3.json").write_text(json.dumps({"assets": assets}, indent=2)+"\n", encoding="utf-8")
    (BASE / "audit-v3.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    # Inspection-only pages. They never replace the generated production images.
    preview = ROOT / "build/boss-atlas-v3"
    preview.mkdir(parents=True, exist_ok=True)
    ids = list(assets)
    for page in range((len(ids)+11)//12):
        sheet = Image.new("RGB", (1280, 1020), "#171d28")
        draw = ImageDraw.Draw(sheet)
        for n, key in enumerate(ids[page*12:(page+1)*12]):
            x, y = n%4*320, n//4*340
            entry = assets[key]
            raw = Image.open(BASE / entry["file"])
            r = entry["frames"][2]["region"]
            sample = raw.crop((r[0], r[1], r[0]+r[2], r[1]+r[3]))
            sample.thumbnail((280, 280))
            sheet.paste(sample, (x+(320-sample.width)//2, y+35+(280-sample.height)//2), sample)
            draw.text((x+14, y+12), key, fill="white")
        sheet.save(preview / ("contact-page-%02d.png" % page))
    print(json.dumps(report, ensure_ascii=False))

if __name__ == "__main__":
    main()
