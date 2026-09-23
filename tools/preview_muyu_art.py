"""Contact sheet preview for tools/prepare_muyu_art.py so cuts can be eyeballed.

Besides the contact sheets this prints, for every cell of both game atlases, the
alpha bounding box and how far it sits from the cell border, plus the number of
detached silhouette fragments the frame still carries. A cell is only healthy
when the box is inside the cell with a transparent margin all round and the
fragment count is 1.
"""
import importlib.util
import os

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("muyu", os.path.join(ROOT, "tools", "prepare_muyu_art.py"))
muyu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(muyu)

OUT = os.path.join(ROOT, "output", "muyu-preview")
os.makedirs(OUT, exist_ok=True)


def sheet(images, cols, cell, name, labels=None, bg=(24, 20, 34, 255), ruler=False):
    rows = (len(images) + cols - 1) // cols
    canvas = Image.new("RGBA", (cols * cell, rows * cell), bg)
    for i, art in enumerate(images):
        if art is None:
            continue
        a = art.copy()
        a.thumbnail((cell - 8, cell - 8), Image.LANCZOS)
        canvas.alpha_composite(a, ((i % cols) * cell + (cell - a.width) // 2,
                                   (i // cols) * cell + (cell - a.height) // 2))
    draw = ImageDraw.Draw(canvas)
    if labels:
        for i, text in enumerate(labels):
            if text:
                draw.text(((i % cols) * cell + 4, (i // cols) * cell + 2), text, fill=(255, 240, 140))
    if ruler:
        for c in range(1, cols):
            draw.line([(c * cell, 0), (c * cell, canvas.height)], fill=(90, 70, 110))
        for r in range(1, rows):
            draw.line([(0, r * cell), (canvas.width, r * cell)], fill=(90, 70, 110))
    canvas.convert("RGB").save(os.path.join(OUT, name))
    print("wrote", name)


def report(name, img, cell=(362, 362), floor=(361, 361, 361)):
    """Per cell: bounding box, distance to the border, detached pieces, floor.

    Alpha under LEVEL is ignored: resampling leaves a two or three pixel shadow
    of almost transparent pixels around every sprite, which never shows in game,
    and counting it would report a fragment for every frame.

    A detached piece is reported as a fragment only when it is small and sits
    well away from the figure. An attack frame deliberately wears its own
    spellwork - a rune blade beside the hand, a burst around the fist - and that
    shows up as several silhouettes in one cell."""
    LEVEL = 20
    a = np.asarray(img)[:, :, 3]
    problems = []
    for row in range(3):
        for col in range(4):
            seg = a[row * cell[1]:(row + 1) * cell[1], col * cell[0]:(col + 1) * cell[0]]
            solid = seg > LEVEL
            ys, xs = np.nonzero(solid)
            if not len(ys):
                problems.append("%s r%dc%d EMPTY" % (name, row, col))
                print("  %s row %d col %d EMPTY" % (name, row, col))
                continue
            box = (int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max()))
            labels, count = ndimage.label(solid, structure=np.ones((3, 3), int))
            sizes = [int(s) for s in ndimage.sum(solid, labels, range(1, count + 1))]
            order = sorted(range(count), key=lambda i: -sizes[i])
            big = [s for s in sizes if s >= 40]
            strays = 0
            for i in order[1:]:
                if sizes[i] < 40:
                    continue
                sl = ndimage.find_objects(labels, count)[i]
                touch = (sl[1].start == box[0] and sl[1].stop - 1 == box[1]
                         and sl[0].start == box[2] and sl[0].stop - 1 == box[3])
                if not touch and sizes[i] < 0.08 * sizes[order[0]]:
                    strays += 1
            margins = (box[0], cell[0] - 1 - box[1], box[2], cell[1] - 1 - box[3])
            flags = []
            if min(margins) < 2:
                flags.append("TOUCHES-BORDER")
            if sizes[order[0]] < 3000:
                flags.append("TINY")
            if strays:
                flags.append("STRAY=%d" % strays)
            if abs(box[3] - floor[row]) > 4:
                flags.append("FLOOR-%+d" % (box[3] - floor[row]))
            print("  %-16s r%dc%d  cell x %3d..%3d  y %3d..%3d  h=%3d  margins L%3d R%3d T%3d B%3d"
                  "  pieces %d  %s"
                  % (name, row, col, box[0], box[1], box[2], box[3], box[3] - box[2] + 1,
                     margins[0], margins[1], margins[2], margins[3], len(big),
                     " ".join(flags) or "ok"))
            problems += ["%s r%dc%d %s" % (name, row, col, f) for f in flags]
    return problems


def main():
    keys = ["idle_a", "idle_b", "idle_c", "idle_d",
            "walk_a", "walk_b", "walk_c", "walk_d",
            "atk_a", "atk_b", "atk_c", "atk_d", "atk_e", "atk_f", "atk_g", "atk_spell",
            "skill_a", "skill_b", "skill_c", "skill_d", "skill_e", "skill_fx",
            "hit_a", "hit_b", "hit_c", "hit_d", "down_a", "down_b",
            "other_a", "other_b", "other_c",
            "fx_ring", "fx_cross", "fx_blade", "fx_book",
            "fx_dagger", "fx_sword", "fx_nail"]
    sheet([muyu.trim(muyu.cut2(k)) for k in keys], 6, 300, "sheet2-frames.png", keys)

    keys1 = list(muyu.S1.keys())
    sheet([muyu.trim(muyu.cut1(k)) for k in keys1], 4, 340, "sheet1-frames.png", keys1)
    sheet([muyu.trim(muyu.key_background(muyu.sheet1().crop(muyu.S1_KEYART)))], 1, 760,
          "sheet1-keyart.png")

    problems = []
    for name, img in [("attack-clean-3", muyu.build_attack()), ("movement-3", muyu.build_movement())]:
        print("%s %s" % (name, img.size))
        problems += report(name, img)
        img.convert("RGB").resize((724, 543), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))
        for row in range(3):
            band = img.crop((0, row * 362, 1448, (row + 1) * 362)).resize((1448, 362), Image.LANCZOS)
            base = Image.new("RGB", (1448, 362), (0, 90, 40))
            base.paste(band, (0, 0), band)
            draw = ImageDraw.Draw(base)
            for col in range(1, 4):
                draw.line([(col * 362, 0), (col * 362, 362)], fill=(255, 255, 0))
            draw.line([(0, 361), (1448, 361)], fill=(0, 255, 255))
            base.save(os.path.join(OUT, "%s-row%d.png" % (name, row)))
    for name, img in [("rune-rain", muyu.build_rune_rain()), ("hellfire", muyu.build_hellfire()),
                      ("ultimate-cg", muyu.build_ultimate_cg())]:
        img.convert("RGB").save(os.path.join(OUT, name + ".png"))
        print("wrote", name, img.size)

    singles = [("muyu-idle", Image.open(os.path.join(ROOT, "assets", "muyu-idle.png"))),
               ("muyu-down", Image.open(os.path.join(ROOT, "assets", "muyu-down.png"))),
               ("portrait-3", Image.open(os.path.join(ROOT, "assets", "portrait-3.png"))),
               ("hidden-boss", Image.open(os.path.join(ROOT, "assets", "muyu", "hidden-boss.png"))),
               ("grimoire", Image.open(os.path.join(ROOT, "assets", "muyu", "grimoire.png"))),
               ("soul-scythe", Image.open(os.path.join(ROOT, "assets", "muyu", "soul-scythe.png")))]
    sheet([i.convert("RGBA") for _, i in singles], 3, 420, "singles.png", [n for n, _ in singles])

    print("\nPROBLEMS: %d" % len(problems))
    for p in problems:
        print("   ", p)


main()

