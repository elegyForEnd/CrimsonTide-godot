"""Resume eight-frame attack actions, one API image edit per missing frame.

Requires OPENAI_API_KEY in the process environment. Each action is generated
strictly in numerical order; existing frames are preserved. Prompts are saved
beside the animation deliverables for review and later regeneration.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys
import time

from PIL import Image, ImageOps
from assemble_attack_frames import remove_green


ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "output/minimax-action-pack/stills"
OUT = ROOT / "output/attack-animation"

HERO_PHASES = {
    "sword": {
        2: "Begin the windup: shift weight onto the rear leg and draw the sword hand slightly back.",
        3: "Coil more deeply, rotating shoulders and raising the sword diagonally behind the head.",
        4: "Reach the largest preparatory pose: knees compressed, hips turning, sword high behind the shoulder, ready to cut.",
        5: "Explode into a large, unmistakable forward sword cut toward screen right with full hip rotation and a planted front foot.",
        6: "Complete the strike: blade sweeps down-right past the hit position, torso follows, hair and clothing lag behind.",
        7: "Recover from the hit: draw the sword back toward the original right-facing guard and straighten the torso.",
        8: "Finish recovery almost exactly in the opening guard of Image 1, with nearly matching feet, hands, blade angle, and silhouette, so frame 8 connects smoothly to frame 1.",
    },
    "heavy": {
        2: "Begin loading the rear leg and lift the greatsword slightly, keeping both hands on its handle.",
        3: "Coil deeper and lift the broad blade over the shoulder; knees bend and torso rotates back.",
        4: "Reach the highest overhead preparation with compressed knees and full-body tension before the heavy strike.",
        5: "Drive a powerful downward-forward greatsword strike toward screen right, with planted front foot and clear impact pose.",
        6: "Follow through beyond the hit: blade travels low-right while knees absorb the force and cloak or hair trails.",
        7: "Rise and pull the blade back toward the opening low-right guard, halfway through recovery.",
        8: "Nearly match Image 1's opening low-right guard, foot placement, hand grip and silhouette, so frame 8 connects smoothly to frame 1.",
    },
    "staff": {
        2: "Slightly draw back the SAME magic implement, gather power and shift weight to the rear foot.",
        3: "Turn shoulders farther back and draw the SAME implement inward, building an obvious windup.",
        4: "Reach the largest casting windup: body coiled, implement fully visible inside the canvas.",
        5: "Release a large forward casting gesture toward screen right with clear whole-body movement; no detached projectile.",
        6: "Follow through past the release, torso leaning forward while the implement stays gripped and clothing trails.",
        7: "Draw the implement back toward the original ready pose; body begins to straighten.",
        8: "Return very close to Image 1's opening ready pose, matching hand positions, feet, implement orientation, and silhouette for a smooth seam.",
    },
}

HERO_IDENTITIES = {
    "hero-2": "The same violet-eyed dark-purple-ponytailed female knight in black armor and a torn purple cloak. Preserve the exact face, hairstyle, ribbon, armor, proportions and linework.",
    "hero-3": "The same pale white-haired female warrior in black and deep crimson clothing, red eye accents and flowing ragged mantle. Preserve the exact face, hairstyle, outfit, proportions and linework.",
}

BOSSES = {
    "ashen-vesper": ("masked male ash priest in charred red-gold vestments, ember halo, and one flaming censer staff", "Pull the censer staff behind his shoulder, step and rotate into a heavy forward swing toward screen right. The hanging censer trails then catches up; its small flame stays attached."),
    "bell-hierophant": ("blindfolded lavender-haired bishop in ivory-violet robes, mitre, bell halo, and one silver crozier", "Brace, rotate the torso, then sweep the crozier in a broad forceful arc toward screen right. Its bell ornament stays at the same end of the shaft; hands grip only the shaft."),
    "blood-queen": ("silver-haired queen with ruby crown, crimson rapier, and exactly six ruby stained-glass blade wings", "Draw the rapier back, rotate hips and shoulders, take one grounded step and cut a wide arc toward screen right. All six wings flare then settle."),
    "earthsplitter": ("giant nonhumanoid armored burrowing centipede with molten amber cracks, circular maw and many digging claws", "Coil the front body back, then drive circular maw and leading claws in a large lunge toward screen right. Armored segments and tail follow and recoil."),
    "frostbone-dragon": ("giant quadrupedal frostbone dragon with exactly four clawed legs, two ragged shoulder wings, long spiked tail and icy blue bone plates", "Brace on four legs, draw head and shoulders back, then make one large forward bite and claw strike toward screen right. Wings flare briefly then settle. No breath beam."),
    "mirror-weaver": ("silver-haired female mirror weaver in black lace and cracked silver armor, orbiting mirror shards and one crescent mirror blade", "Gather the distinct mirror shards, twist the body and swing the single crescent mirror blade through a wide arc toward screen right, then recover."),
    "moon-leviathan": ("giant nonhumanoid armored sea serpent coiled around a broken blood-red moon, with horned maw and long scaled body", "Tighten the coil around the red moon, draw the horned head back, then lunge its open maw widely toward screen right. The long body follows and recoils into the starting coil."),
    "nameless-moon": ("pale silver-haired blood moon queen in a black-scarlet royal gown, red crescent halo and exactly six floating broken crown blades", "Draw the commanding arm back, rotate the torso and sweep broadly toward screen right while the six crown blades arc together, then return to the opening stance."),
    "storm-roc-v2": ("giant nonhumanoid black-feathered thunder roc with cyan lightning veins, exactly two broad wings, hooked beak and two taloned legs", "Lift both wings high, then make one broad forward talon strike toward screen right with a strong wing downbeat, then recover to opening flight pose."),
    "thorn-huntsman": ("masked dark-haired huntsman king with crimson branching antlers, broad white fur mantle, burgundy armor and one long thorn spear", "Plant rear foot, draw thorn spear back, then make a long committed thrust toward screen right and return to guard. Both hands stay behind the spear tip on the shaft."),
}

BOSS_BEATS = {
    "ashen-vesper": ("pull the staff and chained censer back toward screen left while coiling the shoulders", "swing the chained flaming censer across into a strong screen-right impact", "keep the censer on screen right and let it drop slightly lower as the robes trail", "lift the censer from low-right toward the original high-right guard"),
    "bell-hierophant": ("draw the crozier bell head back across the upper body and brace the rear leg", "sweep the crozier bell head in a broad strike toward screen right", "keep the bell head on the right as the shaft continues lower and robes lag", "lift the crozier from low-right back toward the original guard"),
    "blood-queen": ("draw the rapier back behind the shoulder and fold the six wings slightly inward", "step and slash the rapier in a large arc toward screen right as all six wings flare", "keep the rapier blade on the right in a low finishing position while wings trail", "draw the rapier back from low-right toward the original guard as wings settle"),
    "earthsplitter": ("retract the circular maw and front claws toward screen left while compressing the segmented body", "drive the circular maw and leading claws in one strong lunge toward screen right", "keep the maw on screen right as the front segments finish extending and tail follows", "recoil the front segments from the extended rightward lunge toward the starting coil"),
    "frostbone-dragon": ("pull the head and neck back while four legs brace and two shoulder wings lift", "snap the maw and front claws forward toward screen right in one large bite-strike", "keep the head on screen right as it lowers from the bite and the two wings trail", "retract the head and front claws toward the starting four-legged stance"),
    "mirror-weaver": ("draw the crescent blade back across the shoulder while the orbiting shards gather closer", "sweep the crescent mirror blade toward screen right in a large strike with shards arcing behind", "keep the blade on screen right and lower it slightly as shards trail the impact", "draw the blade back from rightward follow-through while shards return to their original orbit"),
    "moon-leviathan": ("tighten the body coil around the blood-red moon and draw the horned head back", "lunge the open horned maw widely toward screen right while the coil extends", "keep the horned head on screen right as the long body completes its extension", "recoil the head and body from the extended rightward lunge back around the moon"),
    "nameless-moon": ("draw the commanding arm back and gather the six crown blades close behind her", "sweep the arm toward screen right and send all six attached-orbit crown blades through one broad arc", "keep the six blades on screen right briefly as the arm finishes its sweep and gown trails", "draw the arm back and guide the six blades toward their opening positions"),
    "storm-roc-v2": ("raise both wings higher and tuck the two talons while drawing the body back", "strike both talons forward toward screen right with one strong downbeat of two wings", "keep the talons forward-right as the wings finish the downbeat and feathers trail", "draw the talons back and raise both wings toward the opening flight pose"),
    "thorn-huntsman": ("plant the rear foot and withdraw the thorn spear tip toward screen left behind the shoulder", "drive the thorn spear tip in a committed thrust toward screen right", "keep the spear tip extended screen right as the torso follows into the lunge", "pull the spear back from the extended thrust toward the opening guard"),
}


def boss_phase(number: int, name: str) -> str:
    windup, impact, follow, recover = BOSS_BEATS[name]
    return {
        2: f"Make only a small preparatory shift: {windup}. Do not strike yet.",
        3: f"Deepen the same windup: {windup}. Clearly progress from the previous pose without releasing the attack.",
        4: f"Reach the largest held anticipation: {windup}. Store tension for the NEXT frame; do not strike yet.",
        5: f"NOW deliver the single biggest hit: {impact}. Show an unmistakable impact pose.",
        6: f"Move immediately AFTER the hit: {follow}. This is follow-through, not a second attack or a return to windup.",
        7: f"Begin controlled recovery: {recover}. Move halfway toward Image 1, without a second strike.",
        8: "Nearly match Image 1's opening pose, including all body parts, weapon orientation, and silhouette; make the change from Image 2 modest so frame 8 connects smoothly to frame 1.",
    }[number]


def prompt_for(kind: str, name: str, action: str, number: int) -> str:
    if kind == "heroes":
        identity = HERO_IDENTITIES[name]
        equipment = {
            "sword": "the SAME short sword, in a correct forward-facing grip",
            "heavy": "the SAME greatsword, with both hands on the same hilt",
            "staff": "the SAME magic implement or spell focus shown in Image 1, with any visible book kept in its original hand",
        }[action]
        phase = HERO_PHASES[action][number]
    else:
        boss_identity, _ = BOSSES[name]
        identity = f"The same {boss_identity}. Preserve exact anatomy, face or head, costume, colors, signature parts and 2D hand-painted anime linework."
        equipment = "all original weapons, wings, claws, tails and ornaments in their original counts and attachments"
        phase = boss_phase(number, name)
    previous = ("Image 1 is the exact approved opening frame and identity reference." if number == 2 else
                f"Image 1 is the exact approved opening frame and identity reference. Image 2 is frame {number - 1}, the IMMEDIATELY previous chronological pose in this action.")
    facing = "same screen-right-facing three-quarter or natural creature view"
    return (
        f"Create exactly ONE finished 2D anime game sprite: frame {number} of an eight-frame attack sequence. {previous}\n"
        f"Identity: {identity}\n"
        f"Action now: {phase} Make this frame visibly progress from the previous pose; do not repeat it.\n"
        f"Invariants: preserve {equipment}. Maintain the {facing}, fixed camera, similar character scale and ground or flight baseline. Keep the entire subject and every weapon tip, wing, horn, tail and ornament safely INSIDE the square canvas, with clear transparent margin on all sides. Genuine transparent alpha PNG like the input reference; EMPTY areas must have alpha zero, never paint a gray-and-white checkerboard pattern. Exactly one subject. No scenery, floor, cast shadow, text, detached weapon, oversized projectile, blur, extra limbs, reversed weapon, duplicated body, or sprite sheet.\n"
    )


def process(kind: str, name: str, action: str, end: int = 8) -> None:
    if kind == "heroes":
        still = PACK / kind / name / f"{action}.png"
        relative = Path(kind) / name / action
    else:
        still = PACK / kind / name / "attack.png"
        relative = Path(kind) / name / "attack"
    raw_dir = OUT / "working" / relative
    prompt_dir = OUT / "prompts" / relative
    delivery = OUT / relative
    raw_dir.mkdir(parents=True, exist_ok=True)
    prompt_dir.mkdir(parents=True, exist_ok=True)
    if kind == "bosses":
        transparent_reference = raw_dir / "opening-reference.png"
        if not transparent_reference.exists():
            remove_green(Image.open(still)).save(transparent_reference)
        if name == "earthsplitter":
            reference = raw_dir / "opening-reference-mirrored.png"
            if not reference.exists():
                ImageOps.mirror(Image.open(transparent_reference).convert("RGBA")).save(reference)
        else:
            reference = transparent_reference
    else:
        reference = still
    for number in range(2, end + 1):
        output = raw_dir / f"{number:02d}.png"
        prompt_path = prompt_dir / f"{number:02d}.txt"
        if not prompt_path.exists():
            prompt_path.write_text(prompt_for(kind, name, action, number), encoding="utf-8")
        if output.exists():
            print(f"SKIP existing {relative}/{number:02d}", flush=True)
            continue
        images = [reference]
        if number > 2:
            previous = raw_dir / f"{number - 1:02d}.png"
            if not previous.exists():
                raise FileNotFoundError(previous)
            images.append(previous)
        command = [sys.executable, str(ROOT / "tools/rolldek_image_edit.py")]
        for image in images:
            command += ["--image", str(image)]
        command += ["--prompt-file", str(prompt_path), "--out", str(output)]
        print(f"GENERATE {relative}/{number:02d}", flush=True)
        max_attempts = 5
        for attempt in range(1, max_attempts + 1):
            result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
            if result.stdout:
                print(result.stdout.strip(), flush=True)
            if result.returncode == 0:
                break
            if result.stderr:
                print(result.stderr.strip(), flush=True)
            if "API_ERROR" not in result.stderr or attempt == max_attempts:
                raise RuntimeError(f"Could not generate {relative}/{number:02d}")
            print(f"RETRY transient API failure {relative}/{number:02d}", flush=True)
            time.sleep(12 * attempt)
    if end == 8:
        assembly = [sys.executable, str(ROOT / "tools/assemble_attack_frames.py"),
                    str(still), str(raw_dir), str(delivery)]
        if name == "earthsplitter":
            assembly.append("--mirror-generated")
        subprocess.run(assembly, check=True, cwd=ROOT)
        print(f"COMPLETE {relative}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("kind", choices=["heroes", "bosses"])
    parser.add_argument("name")
    parser.add_argument("action", nargs="?", default="attack")
    parser.add_argument("--end", type=int, choices=range(2, 9), default=8)
    args = parser.parse_args()
    if args.kind == "heroes" and (args.name not in HERO_IDENTITIES or args.action not in HERO_PHASES):
        parser.error("Only unfinished hero-2 / hero-3 attack actions are supported")
    if args.kind == "bosses" and args.name not in BOSSES:
        parser.error("Unknown boss")
    process(args.kind, args.name, args.action, args.end)


if __name__ == "__main__":
    main()
