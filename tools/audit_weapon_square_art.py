"""Read-only audit of original square ImageGen assets, alpha and provenance."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "assets/combat/imagegen-square"
manifest = json.loads((BASE / "manifest.json").read_text(encoding="utf-8"))
failures = []
edge_notes = []
for key, entry in manifest["assets"].items():
    path = BASE / entry["file"]
    if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
        failures.append(f"Original generated pixels changed: {key}")
    if not (ROOT / entry["prompt"]).is_file():
        failures.append(f"Prompt missing: {key}")
    with Image.open(path) as im:
        if im.width != im.height or im.width < 1024 or "A" not in im.getbands():
            failures.append(f"Square HD RGBA contract broken: {key}")
            continue
        alpha = im.getchannel("A")
        if alpha.getextrema()[0] != 0:
            failures.append(f"Transparent background missing: {key}")
        perimeter = list(alpha.crop((0, 0, im.width, 1)).getdata()) + list(alpha.crop((0, im.height-1, im.width, im.height)).getdata()) + list(alpha.crop((0, 0, 1, im.height)).getdata()) + list(alpha.crop((im.width-1, 0, im.width, im.height)).getdata())
        clipped = sum(value > 96 for value in perimeter) / len(perimeter)
        if clipped > .02:
            edge_notes.append(f"Inspect visible ink at canvas border: {key} ({clipped:.1%})")
print(f"SQUARE IMAGEGEN ART: {len(manifest['assets'])} originals, {len(failures)} failures")
for note in failures + edge_notes:
    print(note)
raise SystemExit(1 if failures else 0)
