"""Package boss first-frame stills and MiniMax image-to-video prompts."""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "output/minimax-action-pack"
SOURCE = PACK / "boss-source-stills"
STILLS = PACK / "stills/bosses"
VIDEO_PROMPTS = PACK / "video-prompts/bosses"
IMAGE_PROMPTS = PACK / "image-prompts/bosses"
SIZE = 1536
GREEN = np.array([0, 248, 0], dtype=np.float32)
FADE_WIDTH = 80
ACTIONS = ("move", "attack", "idle", "hurt", "death")
ACTION_NAMES = {"move": "移动", "attack": "攻击", "idle": "待机", "hurt": "受击", "death": "倒地"}

# Names, exact identity references and distinguishing details from the project.
BOSSES = {
    "bell-hierophant": ("葬钟圣座", "assets/bosses/bell-hierophant-portrait.png", "blindfolded lavender-haired bishop in ivory and violet robes, mitre, bell halo, one ornate silver crozier"),
    "thorn-huntsman": ("荆棘王誓", "assets/bosses/thorn-huntsman-portrait.png", "masked dark-haired huntsman king with crimson branching antlers, broad white fur mantle, burgundy armor, long thorn spear"),
    "blood-queen": ("永夜月冠", "assets/bosses/blood-queen-portrait.png", "silver-haired blood queen with ruby crown, crimson rapier and six ruby stained-glass blade wings"),
    "mirror-weaver": ("镜墓纺女", "assets/bosses/new/mirror-weaver.png", "silver-haired female mirror weaver in black lace and cracked silver armor, orbiting mirror shards and one crescent mirror blade"),
    "ashen-vesper": ("余烬司祭", "assets/bosses/new/ashen-vesper.png", "masked male ash priest in charred red and gold vestments, ember halo and one ornate flaming censer staff"),
    "nameless-moon": ("无名赤月", "assets/bosses/new/nameless-moon.png", "pale silver-haired blood moon queen, black-scarlet royal gown, red crescent halo and six floating broken crown blades"),
    "earthsplitter": ("裂地钻兽", "assets/bosses/wild/earthsplitter.png", "giant nonhumanoid armored burrowing centipede with molten amber cracks, circular maw and many digging claws"),
    "storm-roc-v2": ("雷骸巨鸟", "assets/bosses/wild/storm-roc-v2.png", "giant nonhumanoid black-feathered thunder roc, cyan lightning veins, two broad wings, hooked beak and talons"),
    "moon-leviathan": ("吞月渊蛇", "assets/bosses/wild/moon-leviathan.png", "giant nonhumanoid armored sea serpent coiled around a broken blood-red moon, horned maw and long scaled body"),
    "frostbone-dragon": ("霜骨古龙", "assets/bosses/dragon/frostbone-dragon.png", "giant nonhumanoid quadrupedal frostbone dragon, exactly four clawed legs, exactly two ragged shoulder wings, long spiked tail, icy blue bone plates"),
}

IMAGE_ACTIONS = {
    "move": "FIRST FRAME of a movement cycle toward screen right. Show a clear readable advancing gait or locomotion pose while preserving natural anatomy and all attached parts.",
    "attack": "FIRST FRAME of one LARGE, forceful attack. Show a clear anticipatory windup with the principal weapon, jaws, claws, wings or magic-bearing arm drawn back, body braced and ready to sweep forward. Keep the complete weapon and limbs inside the canvas. Do not show impact or giant effects yet.",
    "idle": "FIRST FRAME of a stable, readable idle stance. Slightly asymmetrical relaxed guard, full characteristic silhouette clearly visible; no attack, no movement across screen.",
    "hurt": "FIRST FRAME of a brief hit reaction. Show a controlled recoil, head and upper body pulling back while still upright, no attacker, blood or injury, weapon stays with the boss.",
    "death": "FIRST FRAME of a defeat fall. The boss is still upright or partly crouched, visibly losing balance and beginning to buckle; do NOT start already lying on the ground. The upcoming animation will collapse in place. No gore.",
}

MOVE = {
    "earthsplitter": "Crawl in place toward screen right using alternating digging claws and a wave traveling through the armored body segments; the tail follows without detaching.",
    "storm-roc-v2": "Fly in place toward screen right with one smooth repeated wingbeat; the two wings alternate upstroke and downstroke together while talons trail beneath.",
    "moon-leviathan": "Swim in place toward screen right with a smooth head-led undulation through the long coiled body and tail; keep the broken red moon enclosed in the coil.",
    "frostbone-dragon": "Walk heavily in place toward screen right on exactly four alternating clawed legs; the two shoulder wings and tail follow the body motion naturally.",
}

ATTACK = {
    "bell-hierophant": "Brace, rotate the torso, sweep the crozier in a broad forceful arc toward screen right, show a clear strike pose, then recover. The bell head remains at the same end of the shaft and the hand grips the shaft, never the ornament.",
    "thorn-huntsman": "Plant the rear foot, draw the thorn spear back, then make a long committed thrust toward screen right with a strong hit pose and return to guard. Both hands stay on the shaft behind the spear tip.",
    "blood-queen": "Draw the rapier back, rotate hips and shoulders, take one grounded step and cut a wide arc toward screen right. The six ruby wings flare and settle while the rapier stays in the same hand.",
    "mirror-weaver": "Gather the orbiting mirror shards, twist the body and swing the single crescent mirror blade through a wide arc toward screen right; follow through and recover. The shards remain distinct attached design elements.",
    "ashen-vesper": "Pull the censer staff behind the shoulder, step and rotate into a heavy forward swing toward screen right; the hanging censer trails then catches up. Its flame stays small and attached to the censer.",
    "nameless-moon": "Draw the commanding arm back, rotate the torso and sweep it broadly toward screen right as the six floating crown blades arc together; show a strong release pose, then return to the opening stance.",
    "earthsplitter": "Coil the front body back, then drive the circular maw and leading claws in one large lunge toward screen right; the armored segments and tail follow, then recoil to the opening coil.",
    "storm-roc-v2": "Pull both wings high, then make one broad forward talon strike toward screen right with a strong wing downbeat; recover to the opening flight pose. Keep exactly two wings and two taloned legs.",
    "moon-leviathan": "Tighten the coil around the blood-red moon, draw the horned head back, then lunge its open maw widely toward screen right; the long body follows and recoils into the starting coil.",
    "frostbone-dragon": "Brace on four legs, draw the head and shoulders back, then make one large forward bite and claw strike toward screen right; wings flare briefly and settle. No extra limbs or giant breath beam.",
}


def image_prompt(name: str, action: str) -> str:
    identity = BOSSES[name][2]
    return (
        f"Use case: stylized-concept. Asset type: ONE green-screen first-frame illustration for a 2D side-scrolling anime boss sprite, action {action}. "
        "Image 1 is the exact project identity and visual-style reference. Image 2 is a supporting gameplay pose reference; "
        f"preserve Image 1 details while following the pose idea. Exactly one {identity}. {IMAGE_ACTIONS[action]} "
        "Keep the same exact head, body, outfit, colors, appendages, ornaments and weapon construction throughout. "
        "Three-quarter side or natural creature view FACING SCREEN RIGHT. The entire creature/person, all tips and flowing parts "
        "are fully inside a SQUARE canvas, with at least 12 percent vivid chroma green space on each edge. "
        "Uniform bright green (#00f800) background only, no floor, scenery, shadow, captions, UI, frame, duplicate "
        "character, extra limbs, new props or motion blur. Clean detailed hand-painted anime game art."
    )


def video_prompt(name: str, action: str) -> str:
    identity = BOSSES[name][2]
    common = (
        "Use the supplied green-screen image as the EXACT FIRST FRAME and identity reference. "
        f"Animate exactly one {identity} as a 2D hand-painted anime game boss sprite. "
        "Preserve its face, anatomy, costume, weapon and all signature parts in every frame. "
        "Maintain the opening three-quarter side or natural creature view FACING SCREEN RIGHT. "
        "Fixed camera: no pan, zoom, cut or perspective change. Pure uniform chroma green background, no floor, scenery or shadow. "
        "At EVERY instant the entire boss, weapon, antlers, horns, wings, tail, ornaments and effects remain INSIDE the frame with visible green margin. "
    )
    if action == "move":
        movement = MOVE.get(name, "Walk or glide in place toward screen right with a clear alternating stride and natural motion in clothing and accessories.")
        motion = f"Make one smooth locomotion LOOP. {movement} Keep the center and scale nearly fixed. The last pose flows naturally into the first pose with no pause, teleport or sudden limb reset."
        audio = "Only synchronized movement and subtle cloth, wing or body sounds; no music."
    elif action == "attack":
        motion = f"Perform ONE LARGE readable attack. {ATTACK[name]} The attack must have an obvious windup, full-body acceleration, distinct impact/release pose, follow-through and controlled recovery to the FIRST FRAME stance. Keep weapon tips and limbs inside the green canvas throughout. No detached weapon, projectile, oversized slash trail or explosion."
        audio = "One strong action swish, impact and body movement sound only; no music."
    elif action == "idle":
        motion = "Make a restrained IDLE LOOP: tiny breathing or body sway, subtle cloth or appendage movement, stable stance and no travel. The last pose joins naturally to the first; no attack, walking, turning or sudden gesture."
        audio = "Only faint costume, wing or breath sound; no music."
    elif action == "hurt":
        motion = "Show ONE brief hit reaction starting from this first frame: recoil slightly farther, visibly absorb the impact, then regain the exact opening guard. No attacker, projectile, blood, wound, fall, dropped weapon or added body parts. Keep the reaction concise and fully in frame."
        audio = "One restrained hit and recovery sound only; no music."
    else:
        motion = "Show ONE defeat animation beginning from this first frame: balance fails, the body and appendages fold under their own weight, and the boss collapses fully within the frame. End in a stable fallen pose and remain motionless. Never stand up, revive, rotate toward camera, lose equipment outside the frame, or add blood or gore. This is a one-shot animation, not a loop."
        audio = "A restrained fall and settling sound only; no music."
    end = (
        "Stable anatomy and design: no flicker, morphing, duplicate body, extra limbs, reversed weapon, wrong number of wings, "
        "motion blur or background elements. Timing should be concise and readable at game sprite size. "
        "No soundtrack, background music, ambient music, song or speech. "
    )
    return common + motion + " " + end + audio


def pad_green(source: Path, destination: Path, mirror: bool) -> None:
    image = Image.open(source).convert("RGB")
    if image.size != (1254, 1254):
        raise ValueError(f"Unexpected image size: {source}: {image.size}")
    if mirror:
        image = ImageOps.mirror(image)
    original = np.asarray(image)
    pad = (SIZE - 1254) // 2
    x = np.arange(SIZE)
    y = np.arange(SIZE)
    sx = np.clip(x - pad, 0, 1253)
    sy = np.clip(y - pad, 0, 1253)
    extended = original[np.ix_(sy, sx)].astype(np.float32)
    dx = np.maximum(np.maximum(pad - x, x - (pad + 1253)), 0)
    dy = np.maximum(np.maximum(pad - y, y - (pad + 1253)), 0)
    amount = np.minimum(np.maximum(dy[:, None], dx[None, :]) / FADE_WIDTH, 1.0)[..., None]
    output = np.rint(extended * (1 - amount) + GREEN * amount).astype(np.uint8)
    assert np.array_equal(output[pad : pad + 1254, pad : pad + 1254], original)
    destination.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(output).save(destination, compress_level=3)


def contact_sheet() -> None:
    cell = 280
    label = 26
    sheet = Image.new("RGB", (cell * len(ACTIONS), (cell + label) * len(BOSSES)), "#202020")
    draw = ImageDraw.Draw(sheet)
    for row, name in enumerate(BOSSES):
        for col, action in enumerate(ACTIONS):
            image = Image.open(STILLS / name / f"{action}.png").convert("RGB")
            image.thumbnail((cell - 12, cell - 12), Image.Resampling.LANCZOS)
            x = col * cell + (cell - image.width) // 2
            y = row * (cell + label) + label + (cell - image.height) // 2
            sheet.paste(image, (x, y))
            draw.text((col * cell + 6, row * (cell + label) + 6), f"{name} / {action}", fill="white")
    sheet.save(PACK / "boss-contact-sheet.jpg", quality=92)


def main() -> None:
    lines = [
        "# Boss 动作首帧与 MiniMax 图生视频提示词",
        "",
        "项目 `BossFrames` 使用 10 个 Boss，每个图集有移动、攻击、待机、受击、倒地 5 类状态。本包对应提供 50 张独立首帧立绘和 50 条英文图生视频提示词。",
        "每个动作取同名 PNG 作视频第一帧，复制同名 TXT 的完整内容。移动和待机要求首尾循环；攻击与受击完成一次动作后回到起始姿势；倒地只播放一次。",
        "立绘使用内置 ImageGen，参考项目原始 Boss 全身图与动作图集。原始生图保存在 `boss-source-stills/`；交付 PNG 仅在外侧补绿幕到 1536×1536，中心人物像素不缩放、不重绘。裂地者原始图面向左，交付图做了精确水平镜像以匹配统一朝右提示词。",
        "图集动画仍需通过 MiniMax 生成视频后逐帧检查，尤其检查动作接缝、武器形状和出框情况。",
        "",
        "[查看 50 张首帧总览](boss-contact-sheet.jpg)",
        "",
        "| Boss | 动作 | 绿幕首帧 | 图生视频提示词 | 生图提示词 |",
        "|---|---|---|---|---|",
    ]
    for name, (title, _, _) in BOSSES.items():
        for action in ACTIONS:
            source = SOURCE / name / f"{action}.png"
            destination = STILLS / name / f"{action}.png"
            pad_green(source, destination, mirror=name == "earthsplitter")
            video = VIDEO_PROMPTS / name / f"{action}.txt"
            image = IMAGE_PROMPTS / name / f"{action}.txt"
            video.parent.mkdir(parents=True, exist_ok=True)
            image.parent.mkdir(parents=True, exist_ok=True)
            video.write_text(video_prompt(name, action) + "\n", encoding="utf-8")
            image.write_text(image_prompt(name, action) + "\n", encoding="utf-8")
            lines.append(
                f"| {title} | {ACTION_NAMES[action]} | [PNG](stills/bosses/{name}/{action}.png) | "
                f"[TXT](video-prompts/bosses/{name}/{action}.txt) | [TXT](image-prompts/bosses/{name}/{action}.txt) |"
            )
    contact_sheet()
    (PACK / "BOSSES.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Packaged {len(BOSSES) * len(ACTIONS)} boss stills and video prompts")


if __name__ == "__main__":
    main()
