"""Prepare reproducible expression/clothing requests after visual face-anchor calibration.

No network calls or credentials. Faces and bodies share the exact 2160x3840 canvas.
"""
from pathlib import Path
import argparse
import json

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art/story-portraits"
EXPRESSIONS = {
    "smile": "A warm small closed-mouth smile, relaxed brows and gentle open eyes. Quiet relief, not a big grin.",
    "joy": "Genuine bright happiness: lifted cheeks, smiling eyes and a small naturally open smiling mouth with subtle teeth. No comic symbols.",
    "shy": "Subtle embarrassed affection: light rosy cheeks, gaze a little downward while the head stays perfectly stationary, a tiny hesitant closed-mouth smile. No sexual expression.",
    "worried": "Concern and uncertainty: inner eyebrows slightly raised, eyes attentive with gentle tension, small parted lips. No tears or melodrama.",
    "sad": "Quiet restrained sadness: slightly drooping upper eyelids, raised inner eyebrows and a small downturned mouth, a very faint moist eye highlight. No crying streams.",
    "angry": "Controlled displeasure: eyebrows clearly lowered toward the center, focused eyes, firmly pressed lips. No shouting pose, red face or cartoon anger marks.",
    "determined": "Resolute protective determination: steady forward gaze, firm slightly lowered brows, composed serious mouth. Distinct from anger; no smile.",
    "surprised": "Natural surprise: widened eyes, lifted brows and a small round parted mouth. Keep the same iris colors and face identity; no distorted comic eyes.",
    "tired": "Gentle end-of-journey fatigue: heavy half-lidded eyes, relaxed brows, a small neutral parted mouth and a subtle weary softness. No wounds, eye bags drawn as black stripes or altered skin tone.",
}
CLOTHES = {
    "travel": "Travel overlayer: a practical weathered short hooded cloak worn with its hood DOWN over the original costume; sturdy leather travel belt, small closed field satchel, slightly reinforced boots. Preserve the original dress/armor visible beneath, every identifying bow and ornament, and original hand-held props. No large backpack blocking hair, new weapon or standing-pose change.",
    "rest": "Camp rest clothing: elegant modest comfortable long-sleeved soft linen blouse or cleric tunic, fitted waist with simple cloth belt, a softly layered knee-to-calf skirt or split overskirt, opaque stockings and comfortable low boots. Keep the character's signature colors and restrained gothic embroidery. No armor plates on the torso, no nightwear, lingerie, swimsuit, exposed midriff or new accessory characters. Preserve original hair ornaments, hair silhouette, face, gloves/hand identity and hand-held props.",
    "ceremony": "Ceremonial clothing: exquisitely tailored modest high-neck gothic formal dress in the character's signature colors, fitted layered bodice, intricate fine metallic embroidery, delicate lace, graceful knee-to-calf layered skirt with tasteful long back panels, elegant matching closed boots. Preserve the original distinctive hair ornaments and existing hand-held props. No bridal white palette for all characters, large crown, new wings, massive skirt obscuring feet, exposed midriff, cleavage or outfit unrelated to her identity.",
}
PALETTES = {
    "feiyue": "white, black, deep crimson, ruby and antique gold; keep her heart-tip purple tail visible",
    "xueli": "dark navy, cyan/mint, white lace and fine silver; retain her dark veil and cyan lantern",
    "yayu": "black, layered violet and fine silver; retain her high ponytail, circlet and sheathed katana",
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--hero", choices=list(PALETTES), required=True)
    parser.add_argument("--face", nargs=4, type=int, required=True, metavar=("X", "Y", "W", "H"))
    args = parser.parse_args()
    hero = args.hero
    base = ART / "masters" / f"{hero}-regular-neutral.png"
    with Image.open(base) as image:
        if image.size != (2160, 3840): raise ValueError("Expected native 4K source")
    x, y, w, h = args.face
    if min(x, y) < 0 or min(w, h) <= 0 or x+w > 2160 or y+h > 3840:
        raise ValueError("Face anchor outside canvas")
    directory = ART / "masks"; directory.mkdir(parents=True, exist_ok=True)
    face_alpha = Image.new("L", (2160, 3840), 255)
    draw = ImageDraw.Draw(face_alpha)
    draw.rounded_rectangle((x, y, x+w-1, y+h-1), radius=24, fill=0)
    face_alpha = face_alpha.filter(ImageFilter.GaussianBlur(7))
    face_mask = Image.new("RGBA", face_alpha.size, "white"); face_mask.putalpha(face_alpha)
    face_mask.save(directory / f"{hero}-face-edit.png")
    clothing_alpha = Image.new("L", (2160, 3840), 255)
    # Allow clothing below the neck while fixing the face and top of the head.
    ImageDraw.Draw(clothing_alpha).rectangle((0, y+h+32, 2159, 3839), fill=0)
    clothing_alpha = clothing_alpha.filter(ImageFilter.GaussianBlur(12))
    clothing_mask = Image.new("RGBA", clothing_alpha.size, "white"); clothing_mask.putalpha(clothing_alpha)
    clothing_mask.save(directory / f"{hero}-clothing-edit.png")
    prompts = ART / "prompts"; prompts.mkdir(exist_ok=True)
    for expression, detail in EXPRESSIONS.items():
        prompt = f"""Use case: identity-preserve. Image 1 is the exact registered 4K standing portrait EDIT TARGET. Image 2 is the authoritative character turnaround IDENTITY REFERENCE.
Edit only the masked face region of image 1 to make {hero}'s expression: {detail}
Preserve her identity and eye colors, position of the face, head angle, scale, hairstyle, hair strands and accessories. Changes are restricted to natural facial muscles: brows, eyelids, gaze, mouth and slight cheek shading. Do not move the head, shoulders or body. Do not change costume, hands, props, lighting, tail, veil, sword or alpha silhouette.
Return ONE complete standing portrait on the identical 2160x3840 canvas with exactly the original registration, composition and genuine transparent background. No close-up, collage, sheet, lettering, symbols, captions, background, matte, halo or shadow.
Use refined consistent anime linework and soft rendering exactly matching image 1. The emotion must be clearly readable in a small Galgame face, but remain tasteful and anatomically natural. Preserve all pixels outside the masked region as faithfully as possible.
"""
        (prompts / f"{hero}-regular-{expression}.txt").write_text(prompt, encoding="utf-8")
    for costume, detail in CLOTHES.items():
        prompt = f"""Use case: identity-preserve / costume edit. Image 1 is the exact registered 4K full-body standing portrait EDIT TARGET. Image 2 is the authoritative character turnaround identity reference.
Create the {costume} clothing variant of {hero}: {detail}
Palette and immutable identity details: {PALETTES[hero]}.
Keep the entire head, facial features, calm neutral expression, hair style, hair ornaments and hair color EXACTLY like image 1. Preserve body proportions, frontal projection, shoulder height, relaxed hand locations, original props, face center, feet baseline and original 2160x3840 registration. Design beautiful believable clothing suited to this same gothic fantasy RPG character; precise seams, lace and embroidered edges with restrained materials. Keep every silhouette safely inside the canvas.
The mask allows clothing changes below the neck, not identity or camera changes. No head tilt, pose variation, body resizing, extra character, giant sleeve hiding hands, weapon change, unrelated jewelry, wings or text. Match image 1's neutral diffuse lighting and anime illustration style.
Return ONE complete full-body character, transparent PNG alpha. No white background, ground plane, checkerboard painted into pixels, collage, label, watermark, drop shadow or glow outline. Both feet and all accessories remain visible.
"""
        (prompts / f"{hero}-{costume}-neutral.txt").write_text(prompt, encoding="utf-8")
    config = {"hero": hero, "canvas": [2160, 3840], "face_rect": args.face,
              "expressions": ["neutral", *EXPRESSIONS], "costumes": ["regular", *CLOTHES]}
    (ART / f"{hero}-registration.json").write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(config, ensure_ascii=False))


if __name__ == "__main__": main()
