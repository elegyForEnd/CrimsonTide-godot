"""Keys one supplied 立绘 file into the project's 900 px portrait format.

`prepare_muyu_art.py` builds 墓煜's art from the two reference sheets in _refs/,
which are not part of the repository. This tool is the narrow entry point for the
case where only the 立绘 itself is on hand: it takes the one painting the user
supplied, keys its backdrop, trims the frame and scales it to the height every
立绘 in the project is stored at, then writes it to the requested path.

The 立绘 pipeline is shared, not duplicated: the keying, the trim and the 900 px
standard all come from prepare_muyu_art, so a replacement made here and one made
by a full `prepare_muyu_art.py portrait` run produce the same pixels.

Run:  python tools/key_portrait.py SRC DST
      python tools/key_portrait.py SRC DST --height 900
"""

from __future__ import annotations

import argparse
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from prepare_muyu_art import (PORTRAIT_HEIGHT, build_portrait,  # noqa: E402
                              reference_alpha)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source", help="the supplied 立绘 painting")
    parser.add_argument("dest", help="where to write the keyed PNG")
    parser.add_argument("--height", type=int, default=PORTRAIT_HEIGHT,
                        help="stored height, default %d px" % PORTRAIT_HEIGHT)
    args = parser.parse_args(argv)

    if not os.path.exists(args.source):
        print("missing reference: %s" % args.source, file=sys.stderr)
        return 1

    with Image.open(args.source) as probe:
        already = reference_alpha(probe)
    art = build_portrait(args.source)
    if args.height != PORTRAIT_HEIGHT:
        scale = args.height / art.height
        art = art.resize((max(1, int(round(art.width * scale))), args.height),
                         Image.LANCZOS)

    os.makedirs(os.path.dirname(os.path.abspath(args.dest)), exist_ok=True)
    art.save(args.dest)
    print("%s -> %s (%dx%d, %s)" % (
        args.source, args.dest, art.width, art.height,
        "already had alpha" if already else "backdrop keyed"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
