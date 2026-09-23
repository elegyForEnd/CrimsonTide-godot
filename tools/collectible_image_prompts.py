"""Write three 3x3 image-generation sheets for the collectible icons."""

import argparse
import json
from pathlib import Path


SUBJECTS = {
    "wind_chime": "an ancient silver wind chime core, three hanging pale jade crystal tongues, a cracked brass mount and a faint crimson oath rune",
    "rabbit_bell": "a small silver funeral bell with two long rabbit-ear finials, lavender enamel and a tiny black ribbon",
    "oath_banner": "a torn pilgrimage banner on a short black iron pole, burgundy velvet and a single shattered moon sigil, no writing",
    "forbidden_page": "one curled ash-stained page from a forbidden grimoire, silver corner clasps and a glowing eye-shaped seal, no legible writing",
    "reverse_hand": "one ornate antique clock hand pointing backwards, pale brass filigree and a small crimson gear at its pivot",
    "absolution_mask": "a blank iron judgment mask with ivory enamel, narrow dark eye holes and one red teardrop inlay",
    "moon_core": "a jagged violet moonstone crystal with a tiny second crescent moon trapped inside its transparent core",
    "antler_star": "a branching bleached bone deer antler with a small floating silver star caught between its tips",
    "star_lens": "an antique handheld brass observatory lens, deep midnight-blue glass with a single sharp star reflection",
    "blood_rose": "one preserved black-red rose with metallic thorns, a stem wrapped in pale silver wire, no bouquet",
    "mirror_shard": "one tall jagged fragment of an enchanted silver mirror, violet reflections and a single ghostly red eye inside the glass",
    "thorn_crown": "a delicate circular crown made of black thorns and three dark crimson roses, old gold clasp",
    "drowned_clapper": "a mossy bronze bell clapper with turquoise water droplets hanging impossibly from the metal",
    "undersea_ticket": "one aged single-trip ghost ferry ticket with frayed corners, sea-green wax seal and fine rope tassel, no legible text",
    "silent_tide": "a squat alchemical glass bottle containing a miniature swirling dark tide, tarnished silver stopper",
    "sacred_goblet": "a narrow crimson crystal ritual goblet in a golden thorn setting, dark red liquid caught inside",
    "verdict_seal": "a heavy royal judgment stamp of antique gold, blood-red wax residue and an eclipsed sun emblem",
    "empty_crown": "a broken pale-gold royal crown fragment with missing central jewel and a small dark crimson inset",
    "mirror_thread": "an elegant black-silver spindle wound with luminous violet mirror thread, tiny reflected shards suspended around it",
    "ember_heart": "a charred ceremonial heart-shaped ember core, orange fire glowing through black cracks, no flesh or gore",
    "fault_scale": "one massive jagged scale from an underground beast, layered dark stone plates and glowing fault lines",
    "storm_feather": "a single long blue-black feather from a thunderbird, a branching lightning bolt glowing along its shaft",
    "frost_teardrop": "a large crystalline tear from an ancient frost dragon, ice-blue facets with a tiny frozen dragon silhouette within",
    "abyss_shedding": "a coiled piece of a moon-devouring serpent's shed skin, iridescent midnight scales and a crescent-shaped void",
    "royal_diadem": "a thin damaged royal diadem of antique gold, a single crimson moonstone and missing side gemstones",
    "twilight_edict": "a rolled royal decree tied with burgundy cord, black wax eclipse seal and burned parchment edges, no legible writing",
    "dawn_testament": "a folded ivory farewell letter with a red wax seal, warm dawn light leaking from the fold, no legible writing",
    "fog_chime": "a thin bronze spirit-register tag with tiny engraved cloud strokes and a single luminous bell bead",
    "nightwatch_pin": "a blackened silver patrol brooch holding one broken raven feather, muted jade enamel and a crimson pin",
    "weightless_oathstone": "a flat dark oath stone levitating above its own shadow, antique gold runes and wind-carved edges",
    "hourless_token": "a small old city guard token made of worn brass, stopped clock hands and a red crescent stamp",
    "last_mass_leaf": "a scorched prayer leaf with a blackened gold edge, a crimson ember seal and no readable writing",
    "mute_judgement": "an iron silence verdict plaque, pale silver face, narrow stitched-mouth motif and a dark wine-red seal",
    "seer_eye": "a palm-sized violet star crystal shaped like an observatory eye, tiny constellations inside",
    "silver_stag_bell": "a silver bell nestled between small bleached antler branches, pale moonstone clapper",
    "meteor_core": "a dense meteor beast core with rough lavender crystal plates and one bright star fissure",
    "sleeping_veil": "a folded sheet of black bridal veil caught around a tiny antique gold crown clasp and one dark rose",
    "blood_vow_clasp": "one ornate crimson wedding garment clasp, gold thorns around a dark red gemstone",
    "thorn_heart": "a small black rose heart wrapped in fine silver thorns, glowing burgundy center, no gore",
    "moonbone_flute": "a carved pale bone flute with sea-glass rings and a crescent moon mouthpiece",
    "sunken_lantern": "a compact drowned bronze lantern containing one calm turquoise spirit eye, trailing a short chain",
    "abyssal_rite_drum": "a round sea-priest ritual disc of green bronze, tide engravings and a dark pearl center",
    "redmoon_betrothal": "an ancient royal betrothal token with two crossed red ribbons, pale gold frame and crimson moonstone",
    "weeping_cairn": "a carved royal wall stone of rose quartz, one suspended tear inside the stone and faded gold edging",
    "nameless_standard": "a small blackened banner finial with a blank burgundy pennant scrap and an antique silver spear tip",
    "mirror_fate_ledger": "a tiny black-silver spindle wound with mirrored violet thread, reflections of tiny blank pages",
    "vesper_last_page": "an ash-edged ceremonial scripture wrapped in dark red cord, a burning gold seal, no readable writing",
    "fault_pulse_fossil": "a compact fossil heart of layered dark earthstone with glowing amber fault lines and brass clamps",
    "thunder_coffin_nail": "a long antique silver coffin nail wrapped in branching blue lightning and black feathers",
    "frostbone_king_remains": "a monumental frost dragon emperor skull and crown fused into one relic, pale blue ice and crimson kingstone, richly detailed, iconic single silhouette, intended as a legendary 3x3 inventory treasure",
    "storm_roc_sunheart": "a colossal thunderbird emperor heart encased in black feathers and gold lightning rings, a vivid red core, iconic single silhouette, intended as a legendary 3x3 inventory treasure",
    "bloodmoon_nightwomb": "a mystical crimson eclipse chrysalis held in an antique gold royal reliquary, tiny blood moon suspended within, iconic single silhouette, intended as a legendary 3x3 inventory treasure",
    "abyssal_motherheart": "an immense deep-sea serpent mother pearl wrapped in midnight scales and silver abyssal filigree, glowing red heart, iconic single silhouette, intended as a legendary 3x3 inventory treasure",
    "eternal_night_thronecore": "a miniature gothic royal throne reliquary containing a radiant crimson eclipse core, black silver and antique gold, iconic single silhouette, intended as a legendary 3x3 inventory treasure",
}

STYLE = (
    "Use case: stylized-concept. Asset type: a square 3 by 3 inventory icon atlas "
    "for a gothic dark fantasy anime RPG. Match the visual language of an ornate "
    "reliquary game icon sheet: painterly realistic materials, blackened metal, "
    "antique gold filigree, restrained crimson and moonlit accents, dramatic but "
    "clear silhouettes, polished tiny prop details, elevated three-quarter view. "
    "Exactly NINE separate objects in three even rows and three even columns. "
    "Every object centered inside its own equal square cell with at least 10 percent "
    "empty padding; no icon crosses into another cell. Transparent alpha background "
    "and transparent gutters, no checkerboard or colored backdrop. No labels, words, "
    "letters, dividers, borders, frames, hands, characters, scenery or watermarks. "
    "Order from left to right, top to bottom: "
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="tmp/imagegen/collectible-sheets.jsonl")
    parser.add_argument("--sheet", type=int, choices=[1, 2, 3, 4, 5, 6], nargs="*")
    args = parser.parse_args()
    output = Path(args.out)
    output.parent.mkdir(parents=True, exist_ok=True)
    all_kinds = list(SUBJECTS)
    assert len(all_kinds) == 54
    sheets = args.sheet if args.sheet else [1, 2, 3, 4, 5, 6]
    with output.open("w", encoding="utf-8") as file:
        for number in sheets:
            names = all_kinds[(number - 1) * 9 : number * 9]
            sequence = " ".join(
                f"Cell {i + 1}: {SUBJECTS[name]}." for i, name in enumerate(names)
            )
            job = {
                "out": f"collectibles/sheet-{number:02d}.png",
                "prompt": STYLE + sequence,
                "size": "1024x1024",
                "background": "transparent",
            }
            file.write(json.dumps(job, ensure_ascii=False) + "\n")
    print(f"Wrote {len(sheets)} image sheet prompts to {output}")


if __name__ == "__main__":
    main()
