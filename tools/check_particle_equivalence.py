"""Check reference/current PNGs produced by particle_render_equivalence.gd."""
from pathlib import Path

import numpy as np
from PIL import Image


def main() -> None:
    directory = Path(__file__).resolve().parents[1] / "output/particle-equivalence"
    references = sorted(directory.glob("*-before.png"))
    assert len(references) == 15, "Run tests/particle_render_equivalence.gd first"
    worst_mean = 0.0
    worst_pixels = 0
    for reference in references:
        current = reference.with_name(reference.name.replace("-before", "-after"))
        before = np.asarray(Image.open(reference)).astype(np.int16)
        after = np.asarray(Image.open(current)).astype(np.int16)
        assert before.shape == after.shape, reference.name
        difference = np.abs(before - after)
        mean = float(difference.mean())
        changed_pixels = int((difference.max(axis=2) > 2).sum())
        worst_mean = max(worst_mean, mean)
        worst_pixels = max(worst_pixels, changed_pixels)
        # Allow sparse subpixel edge rasterization differences, not missing,
        # brighter, resized or differently timed particles.
        assert mean < 0.001 and changed_pixels <= 50, (
            reference.name, mean, changed_pixels
        )
    print(f"15 render pairs passed; max mean channel error={worst_mean:.6f}/255; "
          f"max pixels differing by >2/255={worst_pixels}/700000")


if __name__ == "__main__":
    main()
