"""Read-only PNG audit; writes atlas metadata, never modifies generated pixels."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/bosses/imagegen/actions"
# Measured source grips / jaw hinges. Generative sheets need measured regions,
# not hard equal-cell crops that can sever a long whip or frost trail.
SPECS = {
    "vine_lash_v2": ("thorn-whip-sequence-v2", [0, 581, 1005, 1340, 1792],
        [(68, 325), (507, 325), (934, 325), (1354, 325), (66, 704), (610, 704), (1054, 704), (1390, 704)]),
    "jaw_snap_v2": ("abyss-bite-sequence-v2", [0, 448, 896, 1344, 1792],
        [(55, 225), (488, 225), (922, 225), (1380, 225), (55, 665), (488, 665), (922, 665), (1380, 665)]),
    "claw_swipe_v2": ("dragon-claw-sequence-v2", [0, 481, 900, 1340, 1792],
        [(46, 225), (495, 225), (934, 225), (1375, 225), (46, 677), (495, 677), (934, 677), (1375, 677)]),
}

def main():
    assets = {}
    for role, (name, bottom_bounds, anchors) in SPECS.items():
        path = DEST / (name + ".png")
        image = Image.open(path)
        assert image.mode == "RGBA", (name, image.mode)
        pixels = np.array(image)
        assert pixels[:, :, 3].min() == 0 and pixels[:, :, 3].max() >= 240
        assert image.size == (1774, 887), (name, image.size)
        frames = []
        for index in range(8):
            row, col = divmod(index, 4)
            bounds = ([0, 440, 885, 1308, 1774] if role == "vine_lash_v2" else [0, 448, 896, 1344, 1774]) if row == 0 else bottom_bounds
            left, right = bounds[col:col + 2]
            right = min(right, image.width)
            top = 0 if row == 0 else image.height // 2
            bottom = image.height // 2 if row == 0 else image.height
            alpha = pixels[top:bottom, left:right, 3]
            ys, xs = np.where(alpha > 8)
            assert len(xs) > 80, (name, index, "empty frame")
            # A small transparent guard absorbs filtering without sampling neighbours.
            x0 = max(left, left + int(xs.min()) - 2)
            x1 = min(right, left + int(xs.max()) + 3)
            y0 = max(top, top + int(ys.min()) - 2)
            y1 = min(bottom, top + int(ys.max()) + 3)
            frame = pixels[y0:y1, x0:x1]
            frames.append({"region": [x0, y0, x1-x0, y1-y0],
                           "pivot": [anchors[index][0]-x0, anchors[index][1]-y0],
                           "sha256": hashlib.sha256(frame.tobytes()).hexdigest()})
        assert len({frame["sha256"] for frame in frames}) == 8
        # Frame 4 owns the real forward contact; all frames retain this scale.
        contact = frames[4]
        reach = contact["region"][2] - contact["pivot"][0]
        assets[role] = {"file": name + ".png", "frames": frames, "reach": reach,
                        "states": {"prepare": [0, 1, 2, 3], "contact": [4, 5], "recover": [6, 7]},
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        print(name, "8 distinct RGBA frames; contact reach", reach)
    (DEST / "atlas.json").write_text(json.dumps({"assets": assets}, indent=2) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
