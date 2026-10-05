"""Write the 24 reference-guided character animation edit jobs."""

import json
from pathlib import Path


HEROES = [
    "Feiyue: white-haired, red-eyed chibi gothic girl, white flower and black bow in hair, black and white bell dress with burgundy ribbon and black shoes",
    "Xueli: ice-blue-haired, teal-eyed chibi gothic cleric, black cap with pale flower, teal scarf, black embroidered coat and dark boots",
    "Yayu: dark-purple ponytailed, violet-eyed chibi gothic warrior, black armored coat with purple accents, dark boots",
    "Muyu: long silver-white-haired, pale-eyed gothic necromancer, black and wine-purple tattered coat-dress, black boots and floating dark grimoire",
]

MOTIONS = {
    "walk": "A seamless walk cycle of twelve successive distinct poses: left heel contact, weight acceptance, mid stance, heel rise, toe off, left leg passing, right heel contact, weight acceptance, mid stance, heel rise, toe off, right leg passing. Arms counter-swing, hair and clothing follow through. Hands empty; no weapon.",
    "run": "A seamless run cycle of twelve successive distinct poses: left foot strike, compression, push off, first airborne lift, legs passing, reach forward, right foot strike, compression, push off, second airborne lift, legs passing, reach forward. Stronger forward lean and much wider leg extension than walking. Hands empty; no weapon.",
    "dodge": "One complete twelve-pose dodge sequence, NOT a loop: upright alert, knees bend, deep crouch, push off to the right, low lateral dash, stretched airborne travel, feet tucked, low landing, slide, brace with one hand, rise, ready upright. The character remains anatomically intact with clear changes in legs and torso. Hands empty; no weapon.",
}

ATTACKS = {
    "sword": "One complete twelve-pose single-handed sword attack: ready, early draw-back, deeper windup, full windup, first forward cut, mid slash, extended hit, follow-through, deceleration, lower blade, return to guard, settled ready. Give this hero a compact ornate crimson sword; for Muyu use her dark soul scythe as the blade instead. Keep the blade wholly inside its own cell; no slash trails or detached effects.",
    "heavy": "One complete twelve-pose heavy greatsword attack: ready, grip and brace, raise the sword, full overhead windup, downward acceleration, descending blade, strong groundward cleave, follow-through, low blade, recover stance, lift to guard, settled ready. Large black and antique-gold greatsword, complete and entirely inside each cell; no slash trails or detached effects.",
    "staff": "One complete twelve-pose magic staff cast: ready with staff, lift and turn, gather power, full casting windup, first forward thrust, extended staff, peak cast, follow-through, withdraw staff, straighten, return to guard, settled ready. Slender black-and-gold staff with restrained cyan crystal for the first three heroes; violet grimoire magic and dark staff for Muyu. Keep all props entirely inside each cell; no separate VFX or particles.",
}

COMMON = (
    "Use case: identity-preserve. Asset type: final production 2D anime game animation sprite sheet. "
    "The provided input image is the character-design and rendering-style reference. Preserve the SAME ONE hero's face, hair, costume, proportions and painterly chibi linework. "
    "The input sheet includes several action types; the output must depict ONLY the animation named here. "
    "Exactly TWELVE chronological full-body poses in a rigid FOUR-COLUMN by THREE-ROW atlas, reading left-to-right then top-to-bottom. "
    "Highest-detail 3840x2160 landscape PNG, each implied cell exactly 960x720. "
    "Keep one complete character at constant size and consistent floor/foot baseline in every cell, elevated three-quarter view facing RIGHT. "
    "Each complete character and every weapon tip or hair strand must fit inside the central 60 percent of its own cell, with wide completely empty gutters on all four sides. "
    "The entire background and all gutters MUST be perfectly flat pure chroma green RGB #00FF00, solid color with no gradients, shadows, halos or texture, suitable for exact chroma key extraction. "
    "No scene, floor, shadow, lettering, numbers, grid lines, cell borders, checkerboard pattern, extra figures, repeated pose or overlapping neighboring cells. "
)


def main() -> None:
    jobs = []
    for hero, design in enumerate(HEROES):
        for name, motion in {**MOTIONS, **ATTACKS}.items():
            category = "movement" if name in MOTIONS else "attack-clean"
            jobs.append({
                "out": f"character-animations/hero-{hero}/{name}.png",
                "image": f"assets/combat/{category}-{hero}.png",
                "model": "gpt-image-2.5-sunburst",
                "size": "3840x2160",
                "quality": "high",
                "background": "opaque",
                "prompt": COMMON + f"Hero identity: {design}. Animation: {name}. " + motion,
            })
    destination = Path("output/imagegen/character-animation-jobs.jsonl")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text("\n".join(json.dumps(job, ensure_ascii=False) for job in jobs) + "\n", encoding="utf-8")
    print(f"Wrote {len(jobs)} animation jobs to {destination}")


if __name__ == "__main__":
    main()
