r"""Generate the three extra rogue-guardian body sheets (identities 5..7).

The guardian pool draws 5 of 8 identities, but only five body sheets
(``boss-hd-0`` .. ``boss-hd-4``) ever existed, so a pooled identity fell back to
the floor's art.  Rather than painting new frames, each new identity is derived
from an existing sheet by a hue/saturation/value remap that preserves alpha and
therefore every frame rectangle in ``hd-packed-manifest.json``.  Because the
geometry is untouched, the manifest entries are copied verbatim and only the
``file`` field is rewritten.

Run:  F:\python\python.exe tools/generate_rogue_boss_bodies.py
Idempotent: existing generated sheets and manifest entries are replaced.
"""
import json
import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover - environment guard
    print("Pillow is required: F:\\python\\python.exe -m pip install pillow")
    sys.exit(2)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "rogue", "animations")
MANIFEST = os.path.join(ANIM, "hd-packed-manifest.json")
SKILLS = 5

# identity index -> (source sheet index, hue shift, saturation, value)
# Hue is Pillow's 0..255 channel (= degrees * 255 / 360). The shifts are measured
# against the source sheets' dominant hues so each new identity lands on a
# material family the five base guardians do not occupy:
#   bell  source astral  261.9deg -> 190deg silvery cyan
#   earth source furnace  13.5deg ->  35deg golden ochre
#   abyss source obsidian 352.9deg -> 275deg deep violet
# Recolouring (never repainting) keeps every packed frame rectangle valid.
DERIVED = {
    5: {"source": 2, "hue": -51, "sat": 0.45, "val": 1.15, "name": "bell"},
    6: {"source": 1, "hue": 15, "sat": 0.70, "val": 0.88, "name": "earth"},
    7: {"source": 4, "hue": -55, "sat": 1.35, "val": 0.72, "name": "abyss"},
}


def sheet_names(index, skills=SKILLS):
    yield "boss-hd-%d.png" % index
    for skill in range(skills):
        yield "boss-hd-%d-skill-%d.png" % (index, skill)


def remap(path_in, path_out, hue, sat, val):
    image = Image.open(path_in).convert("RGBA")
    red, green, blue, alpha = image.split()
    hsv = Image.merge("RGB", (red, green, blue)).convert("HSV")
    h, s, v = hsv.split()
    h = h.point(lambda x: (x + hue) % 256)
    s = s.point(lambda x: max(0, min(255, int(round(x * sat)))))
    v = v.point(lambda x: max(0, min(255, int(round(x * val)))))
    rgb = Image.merge("HSV", (h, s, v)).convert("RGB")
    out = Image.merge("RGBA", rgb.split() + (alpha,))
    out.save(path_out)
    return image.size, out.size


def main():
    with open(MANIFEST, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    by_file = {entry["file"]: entry for entry in manifest["assets"]}
    written = []
    for index, spec in sorted(DERIVED.items()):
        source_index = spec["source"]
        for name, source_name in zip(sheet_names(index), sheet_names(source_index)):
            source_path = os.path.join(ANIM, source_name)
            target_path = os.path.join(ANIM, name)
            if not os.path.exists(source_path):
                raise SystemExit("missing source sheet: " + source_path)
            src_size, dst_size = remap(source_path, target_path, spec["hue"], spec["sat"], spec["val"])
            if src_size != dst_size:
                raise SystemExit("size drift for " + name)
            entry = json.loads(json.dumps(by_file[source_name]))
            entry["file"] = name
            entry["derived_from"] = source_name
            entry["derived_tuning"] = {"hue": spec["hue"], "sat": spec["sat"], "val": spec["val"]}
            by_file[name] = entry
            written.append((name, dst_size))
    # Stable order: keep the packed sheets grouped by name, generated ones last.
    priority = {name: i for i, name in enumerate(sorted(by_file))}
    manifest["assets"] = sorted(by_file.values(), key=lambda e: priority[e["file"]])
    manifest["generated_bodies"] = {
        "script": "tools/generate_rogue_boss_bodies.py",
        "identities": {str(k): v["name"] for k, v in sorted(DERIVED.items())},
        "sheets": [name for name, _ in written],
    }
    with open(MANIFEST, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, separators=(",", ":"))
    print("wrote %d sheets, manifest assets now %d" % (len(written), len(manifest["assets"])))
    for name, size in written:
        print("  %-28s %sx%s" % (name, size[0], size[1]))


if __name__ == "__main__":
    main()
