"""Fetch two CC0 Quaternius trees from a public Godot mirror.

Author/license: https://quaternius.com/packs/ultimatestylizednature.html
Only FBX and image data are used from the mirror; no third-party code runs.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import urllib.request
from PIL import Image

ROOT = Path(__file__).absolute().parents[1]
DEST = ROOT / "assets/vendor/quaternius"
REPO = "walterpalladino/godot-quaternius-ultimate-stylized-nature"


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    lock = DEST / "sources.json"
    previous = json.loads(lock.read_text()) if lock.exists() else {}
    commit = previous.get("commit") or json.loads(subprocess.check_output(
        ["gh", "api", f"repos/{REPO}/commits/main"], encoding="utf-8"))["sha"]
    source = {"author": "Quaternius", "license": "CC0-1.0",
              "author_page": "https://quaternius.com/packs/ultimatestylizednature.html",
              "mirror": "https://github.com/" + REPO, "commit": commit, "files": []}
    for remote, name in [("LICENSE", "MIRROR-LICENSE.txt")] + [
        ("ultimate-stylized-nature/sources/"+path, Path(path).name)
        for path in ["FBX/NormalTree_1.fbx", "FBX/NormalTree_3.fbx",
                     "Textures/NormalTree_Bark.png", "Textures/NormalTree_Leaves.png"]]:
        url = f"https://raw.githubusercontent.com/{REPO}/{commit}/{remote}"
        with urllib.request.urlopen(url, timeout=90) as response:
            data = response.read()
        target = DEST / name
        target.write_bytes(data)
        entry = {"path": name, "url": url, "upstream_sha256": hashlib.sha256(data).hexdigest()}
        if name.endswith(".png"):
            with Image.open(target) as image:
                image.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
                image.save(target, optimize=True)
            entry["modification"] = "Downsampled to at most 1024 pixels; alpha retained."
        entry["local_sha256"] = hashlib.sha256(target.read_bytes()).hexdigest()
        source["files"].append(entry)
        print(name, flush=True)
    (DEST / "LICENSE.txt").write_text(
        "Ultimate Stylized Nature by Quaternius\nLicense: CC0 1.0 Universal\n"
        "https://creativecommons.org/publicdomain/zero/1.0/\n"
        "Author and license declaration: https://quaternius.com/packs/ultimatestylizednature.html\n"
        "Models retrieved from the public Godot mirror recorded in sources.json.\n"
        "Textures downsampled; game materials supplied separately.\n", encoding="utf-8")
    lock.write_text(json.dumps(source, indent=2)+"\n", encoding="utf-8")


if __name__ == "__main__":
    main()
