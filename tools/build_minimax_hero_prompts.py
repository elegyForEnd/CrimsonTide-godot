"""Write paste-ready MiniMax image-to-video prompts for the four playable heroes."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "minimax-action-pack"

HEROES = {
    0: ("绯月", "a white-haired, red-eyed gothic heroine in a black-and-white dress with crimson bows and gold details"),
    1: ("雪璃", "a pale-blue-haired, blue-eyed cleric in a dark navy outfit with a hood, silver ornaments and teal ribbons"),
    2: ("鸦羽", "a long-purple-haired, purple-eyed swordswoman in dark violet and black armor with trailing ribbons"),
    3: ("墓煜", "a long-white-haired, red-eyed necromancer in black and burgundy gothic clothing with an occult grimoire"),
}

ACTIONS = {
    "walk": (
        "行走",
        "Make a smooth WALKING-IN-PLACE loop toward screen right. Keep the torso mostly upright. "
        "The left and right legs alternate through contact, passing and weight-transfer poses. "
        "Arms swing in the opposite rhythm, while hair and clothing follow gently. "
        "Keep the figure at the same screen position and scale. The final pose flows naturally into the first pose; "
        "no pause, teleport, duplicated limb or sudden change in stride length.",
        "Only light, synchronized footsteps and subtle clothing movement sounds; no music.",
    ),
    "run": (
        "跑步",
        "Make a fast RUNNING-IN-PLACE loop toward screen right, clearly faster than walking. "
        "Lean the body forward, use long alternating strides with a brief airborne phase, and swing bent arms in rhythm. "
        "Hair, ribbons and coat trail behind. Keep the figure at the same screen position and scale. "
        "The final stride connects smoothly to the initial stride with continuous momentum and no sudden snap.",
        "Only synchronized running footsteps and minimal cloth sounds; no music.",
    ),
    "dodge": (
        "闪避",
        "Perform ONE short evasive dodge toward screen right: bend the knees, push off, lower the body, "
        "shift quickly a small distance and recover to the original ready stance. "
        "The entire body stays inside the frame. Do not spin, roll toward the camera, vanish or turn left. "
        "End in a pose matching the opening stance so the clip can reconnect cleanly.",
        "A brief foot scrape and clothing movement only; no music.",
    ),
    "sword": (
        "短剑攻击",
        "Perform ONE BIG, CLEAR short-sword attack toward screen right: visibly pull the sword and shoulder back, "
        "twist the hips, take one grounded step, then sweep the arm and blade through a wide forward arc with a "
        "strong unmistakable hit pose. Follow through and recover to the opening guard. The sword motion should be "
        "substantially larger than a small wrist flick, while staying readable as one attack. "
        "Use a NORMAL FORWARD GRIP: the hand holds the handle behind the guard, the sharp blade and tip extend toward "
        "the target on screen right at the hit. Never reverse the grip, hold the blade or swap handle and tip. "
        "Keep the sword solid and identical throughout. At EVERY instant the entire sword, hair, hands, legs and clothing "
        "must stay well INSIDE the green canvas, with visible green space around all edges; shorten the arm extension "
        "rather than crossing the frame boundary. Keep the character centered instead of traveling across the frame. "
        "No camera tracking or zoom. "
        "No projectile, beam, oversized slash trail or extra weapon.",
        "One strong blade swish and a clear footstep only; no music.",
    ),
    "heavy": (
        "重剑攻击",
        "Perform ONE LARGE, WEIGHTY two-handed greatsword attack toward screen right: lower the center of gravity, "
        "draw the weapon back to shoulder height, rotate the hips and shoulders, then make a broad forceful "
        "diagonal forward-and-downward swing. Show a distinct impact pose, follow-through, and a controlled return "
        "to the opening ready stance. The movement spans the arms, torso and legs, not just the wrists. "
        "Both hands grip the HANDLE behind the guard at all times; never reverse the grip or deform the blade. "
        "At EVERY instant the full greatsword including its tip and both hands stays well INSIDE the green canvas "
        "with visible green margin. Keep the body near the same place; do not compensate by moving the camera or zooming. "
        "No projectile, beam, giant impact effect or extra weapon.",
        "One strong heavy blade swish, a firm step and restrained impact sound only; no music.",
    ),
    "staff": (
        "法杖施法",
        "Perform ONE LARGE, READABLE staff-casting attack toward screen right: brace the feet, sweep the staff "
        "back across the torso to prepare, rotate shoulders and hips, then draw a broad forward casting arc "
        "at chest-to-head height with a strong release pose and visible recovery to the opening stance. "
        "The upper body and arms move clearly; this is not a tiny wrist gesture. Both hands hold the SHAFT. "
        "The ornamented magical HEAD remains at the upper/front end toward screen right; the plain butt remains at the "
        "lower/back end. Never invert the staff, change its length or exchange head and handle. "
        "At EVERY instant the complete staff, its head, the body and clothing stay well INSIDE the green canvas "
        "with green margin at each edge. Do not pan or zoom the camera to follow the staff. "
        "A faint glow may stay tightly around the staff head, but no projectile, beam or large spell effect leaves the frame.",
        "One clear casting swish, cloth movement and soft localized magical chime only; no music.",
    ),
}

MUYU_MAGIC = (
    "法术攻击",
    "Perform ONE BIG, READABLE necromancy cast toward screen right: brace the feet, twist the shoulders, "
    "draw the focus arm back, then sweep it forward in a wide controlled casting arc with a distinct release "
    "pose and follow-through before recovering to the exact opening stance. The motion uses the torso and arm, "
    "not just a wrist flick. The LEFT hand holds an OPEN GRIMOIRE near the chest; "
    "the RIGHT hand extends a SHORT magical focus toward the target. The book stays open, close to her body, "
    "and keeps the same cover, pages and orientation. The focus stays short and points forward; do not transform "
    "it into a sword, spear or long staff. At EVERY instant the book, focus, hair, clothing, feet and hands remain "
    "well INSIDE the green canvas with visible margin at every edge. Fixed camera, no pan or zoom. "
    "A localized glow may appear at the focus, but no projectile, beam, large spell effect or flying book.",
    "One strong casting swish, quiet page rustle and localized magical chime only; no music.",
)

COMMON_START = (
    "Use the supplied green-screen still as the FIRST FRAME and identity reference. "
    "Create a 2D flat anime game sprite animation of exactly one full-body character: {identity}. "
    "Preserve her face, hair, outfit, accessories, game-character proportions, colors and drawing style exactly. "
    "Any weapon, lantern, book or focus visible in the still stays in the same hand and retains its exact shape and construction while rotating naturally with the action. "
    "Keep a stable three-quarter side view FACING SCREEN RIGHT for the entire clip. "
    "The camera is locked: no pan, zoom, cut, rotation or perspective change. "
    "Use a perfectly uniform solid chroma green background, with no floor, landscape or shadow. "
    "The full character, weapon, hair and clothing remain inside the frame at every instant, with visible green margin. "
)

COMMON_END = (
    "Stable anatomy and consistent weapon design in every frame; no flicker, morphing, extra limbs, duplicate character, "
    "motion blur, changing clothes, front view or left-facing turn. Keep timing concise and readable for a game. "
    "No soundtrack, background music, ambient music, song or speech. {audio}"
)


def main() -> None:
    lines = [
        "# 角色动作立绘与 MiniMax 图生视频提示词",
        "",
        "基于项目 `Catalog.HEROES` 的 4 名可玩角色与现有战斗图集：每人 6 个动作，共 24 张首帧立绘和 24 条独立提示词。",
        "Boss 已另行整理：[查看 10 个 Boss 的 50 张动作首帧和提示词](BOSSES.md)。",
        "使用方式：选择对应 PNG 作为图生视频首帧，复制同名 `.txt` 的完整英文提示词。绿幕用于后续抠像。",
        "行走、跑步为原地循环；闪避和攻击为一次动作并在结尾回到起始姿势。后续选帧时仍应检查循环接缝。",
        "如需导出 8 帧，从完整动作周期中等间隔选取 8 张；首帧不要在末帧重复，检查末帧接回首帧是否自然。",
        "角色朝右；游戏里朝左可水平翻转。武器提示词已锁定握柄、刃尖和杖头方向。墓煜的 staff 图集行实际使用魔书施法，因此对应立绘和提示词保留魔书。",
        "绯月（角色 0）与鸦羽（角色 2）的行走、跑步、闪避均为空手立绘；对应视频提示词要求双手全程保持空手。",
        "12 张攻击首帧保留原版人物、姿势和武器的每个像素，仅把原图居中放入 1536×1536 绿幕画布；画面外侧增加留白。攻击提示词要求明显的蓄力、全身发力、命中姿势和收势，并要求武器始终入镜。",
        "",
        "[查看 24 张立绘总览](contact-sheet.jpg)",
        "[查看 12 张攻击立绘总览](attack-contact-sheet.jpg)",
        "",
        "| 角色 | 动作 | 首帧立绘 | 生视频提示词 |",
        "|---|---|---|---|",
    ]
    for index, (name, identity) in HEROES.items():
        for key, (zh, motion, audio) in ACTIONS.items():
            if index == 3 and key == "staff":
                zh, motion, audio = MUYU_MAGIC
            unarmed = (
                "Both hands are EMPTY in the supplied first frame and must stay EMPTY for the ENTIRE clip. "
                "Do not show, summon, draw, holster or hold any sword, staff, blade, dagger, wand, book, scabbard "
                "or other weapon or prop at any point. Keep natural empty-hand arm swings. "
                if index in (0, 2) and key in ("walk", "run", "dodge") else ""
            )
            text = COMMON_START.format(identity=identity) + unarmed + motion + " " + COMMON_END.format(audio=audio)
            prompt_path = OUT / "video-prompts" / f"hero-{index}" / f"{key}.txt"
            prompt_path.parent.mkdir(parents=True, exist_ok=True)
            prompt_path.write_text(text + "\n", encoding="utf-8")
            lines.append(
                f"| {name} | {zh} | [PNG](stills/heroes/hero-{index}/{key}.png) | "
                f"[TXT](video-prompts/hero-{index}/{key}.txt) |"
            )
    lines += [
        "",
        "## 立绘生成规格",
        "",
        "内置 ImageGen 根据 `assets/portrait-N.png`（角色身份/服饰）与 "
        "`output/imagegen-refs/hero-N-ACTION-pose.png`（现有游戏身形/动作）分别生成单张绿幕立绘；"
        "统一要求为：1:1 构图、单人全身、朝右三分之二侧视、四周留白、纯绿幕、无文字/运镜/动作特效。"
        "持武器动作额外要求手握柄、刃尖朝屏幕右侧，法杖杖头在前上方；墓煜法术动作保留原图的魔书与短法器。",
        "角色 0 和角色 2 的 6 张移动首帧按用户要求采用 ImageGen 定向编辑，移除武器并补全被遮挡的手部。",
        "12 张原版攻击首帧保存在 `source-stills/attacks/`。`tools/pad_minimax_attack_stills.py` 只扩展四周绿色画布，不缩小、不重绘原图；中央 1254×1254 区域与原版像素完全相同。",
        "",
        "参考文档 `minimax2live2d.md` 提供的是方法和洛琪希/牛头人示例；此包使用项目自身角色设定。",
    ]
    (OUT / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {len(HEROES) * len(ACTIONS)} video prompts")


if __name__ == "__main__":
    main()
