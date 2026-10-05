"""Recover alpha when an image edit paints a pale checkerboard into a PNG.

Only bright neutral pixels are removed, including enclosed gaps between fins.
This is background cleanup of a generated frame; it does not synthesize motion.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    args = parser.parse_args()
    rgb = np.asarray(Image.open(args.source).convert("RGB"), dtype=np.uint8)
    low = rgb.min(axis=2).astype(np.int16)
    spread = rgb.max(axis=2).astype(np.int16) - low
    possible_background = ((low >= 220) & (spread <= 18)).astype(np.uint8)
    background = possible_background.astype(bool)
    foreground = (~background).astype(np.uint8)
    alpha = cv2.GaussianBlur(foreground * 255, (0, 0), 0.55)
    alpha[background & (cv2.distanceTransform(background.astype(np.uint8), cv2.DIST_L2, 3) > 2)] = 0
    rgba = np.dstack((rgb, alpha.astype(np.uint8)))
    args.target.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(args.target)
    print(f"Recovered transparent frame: {args.target}")


if __name__ == "__main__":
    main()
