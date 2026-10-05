"""Collect the exact per-frame boss prompts into one readable document."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output/attack-animation"
FEATURES = {
    "ashen-vesper": ("灰烬晚祷者", "锁链香炉蓄势后横扫，火焰跟随香炉"),
    "bell-hierophant": ("钟鸣大祭司", "钟杖从肩侧蓄力并大幅挥出"),
    "blood-queen": ("血之女王", "刺剑跨步斩击，六片红色翼刃张开后收拢"),
    "earthsplitter": ("裂地者", "环形巨口和前爪带动分节身躯突刺"),
    "frostbone-dragon": ("冰骨龙", "四足蓄力、昂首咬击，短促冰息后伏身"),
    "mirror-weaver": ("镜织者", "镜刃与悬浮碎镜联动，划出宽阔弧线"),
    "moon-leviathan": ("月海兽", "围绕血月收紧盘绕，探首突袭再回卷"),
    "nameless-moon": ("无名之月", "手势带动六枚冠刃环绕扫出"),
    "storm-roc-v2": ("雷鹏", "双翼下压，带雷光的双爪前探"),
    "thorn-huntsman": ("荆棘猎王", "双手持长矛，后脚发力完成长距离突刺"),
}


def main() -> None:
    lines = [
        "# Boss 攻击动画逐帧提示词",
        "",
        "每个 Boss 的攻击为 8 张独立 PNG：已确认的首帧加 7 张逐张生成的续帧。",
        "模型：Rolldek `gpt-image-2.5-sunburst` 图片编辑 API；要求输出真正的透明 PNG。",
        "通常 Image 1 是已确认的透明首帧，Image 2 是紧前一帧；每一帧的原始英文提示词如下。",
        "第 8 帧要求接近第 1 帧，以便循环衔接。裂地者生成时临时镜像参考，交付时镜像回原朝向；月海兽第 2 帧额外参考第 3 帧作为中间姿势目标。",
        "",
        "| Boss | 独特攻击动作 |",
        "| --- | --- |",
    ]
    for slug, (name, feature) in FEATURES.items():
        lines.append(f"| {name} (`{slug}`) | {feature} |")
    for slug, (name, _) in FEATURES.items():
        lines.extend(["", f"## {name} (`{slug}`)", ""])
        for number in range(2, 9):
            prompt_path = OUT / "prompts/bosses" / slug / "attack" / f"{number:02d}.txt"
            if not prompt_path.exists():
                lines.extend([f"### 第 {number} 帧", "", "生成中。", ""])
                continue
            prompt = prompt_path.read_text(encoding="utf-8").strip()
            lines.extend([f"### 第 {number} 帧", "", "```text", prompt, "```", ""])
    (OUT / "BOSS-PROMPTS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(OUT / "BOSS-PROMPTS.md")


if __name__ == "__main__":
    main()
