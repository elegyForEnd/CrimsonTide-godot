# 独立 PNG 攻击动画帧

已接入游戏。游戏使用 `assets/combat/generated-attacks/` 中经过脚部锚点校准的版本；当前目录保留原始交付图。校准标注在 `tools/attack-foot-landmarks.json`，安装脚本为 `tools/install_attack_frames.py`。已接入 9 组角色攻击和 10 组 Boss 攻击，墓煜暂缓。

已完成 **10 个 Boss 的攻击动作**，每个动作 8 张独立的 1536×1536 RGBA 透明 PNG：`000.png` 至 `007.png`。按文件名顺序播放。首帧来自已确认的立绘并抠除绿幕，其余帧使用 Rolldek `gpt-image-2.5-sunburst` 图片编辑 API **逐张生图**，参考首帧与动作相邻帧。仅对交付图做透明背景清理、统一缩放和画布对齐，没有通过程序生成姿势。

每组目录另有 `preview.jpg`（逐帧总览）、`preview.gif`（播放预览）和 `animation.json`（帧顺序与画布信息）。第 8 帧回到接近第 1 帧的姿势，可从末帧接回首帧。建议在游戏中将攻击按一次动作播放，实际速度可按角色手感调整；预览使用约 10 FPS。逐帧生图提示词整理在 [Boss 提示词总表](BOSS-PROMPTS.md)，原始文本保存在 `prompts/bosses/{boss}/attack/02.txt` 至 `08.txt`。

[查看 10 个 Boss 的起手、冲击、回收总览](bosses-contact-sheet.jpg)

| Boss | 动作特色 | 8 张 PNG | 预览 |
| --- | --- | --- | --- |
| 灰烬晚祷者 | 锁链香炉横扫 | [帧](bosses/ashen-vesper/attack/) | [GIF](bosses/ashen-vesper/attack/preview.gif) |
| 钟鸣大祭司 | 钟杖重挥 | [帧](bosses/bell-hierophant/attack/) | [GIF](bosses/bell-hierophant/attack/preview.gif) |
| 血之女王 | 刺剑跨步斩击，六片翼刃张合 | [帧](bosses/blood-queen/attack/) | [GIF](bosses/blood-queen/attack/preview.gif) |
| 裂地者 | 环形巨口与前爪突刺 | [帧](bosses/earthsplitter/attack/) | [GIF](bosses/earthsplitter/attack/preview.gif) |
| 冰骨龙 | 昂首蓄力、咬击与短促冰息 | [帧](bosses/frostbone-dragon/attack/) | [GIF](bosses/frostbone-dragon/attack/preview.gif) |
| 镜织者 | 镜刃与碎镜联动挥出 | [帧](bosses/mirror-weaver/attack/) | [GIF](bosses/mirror-weaver/attack/preview.gif) |
| 月海兽 | 盘绕血月、探首突袭 | [帧](bosses/moon-leviathan/attack/) | [GIF](bosses/moon-leviathan/attack/preview.gif) |
| 无名之月 | 六枚冠刃随手势扫出 | [帧](bosses/nameless-moon/attack/) | [GIF](bosses/nameless-moon/attack/preview.gif) |
| 雷鹏 | 双翼下压、双爪前探 | [帧](bosses/storm-roc-v2/attack/) | [GIF](bosses/storm-roc-v2/attack/preview.gif) |
| 荆棘猎王 | 长矛跨步突刺 | [帧](bosses/thorn-huntsman/attack/) | [GIF](bosses/thorn-huntsman/attack/preview.gif) |

逐帧独立生图会有少量纹理与饰品变化。接入项目时建议用游戏中的实际显示尺寸检查动作；`preview.gif` 只用于查看，游戏应使用透明 PNG。角色的已有攻击资产保留在 `heroes/`；墓煜按本次要求暂缓。
