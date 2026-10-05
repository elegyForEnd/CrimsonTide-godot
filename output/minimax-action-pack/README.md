# 角色动作立绘与 MiniMax 图生视频提示词

基于项目 `Catalog.HEROES` 的 4 名可玩角色与现有战斗图集：每人 6 个动作，共 24 张首帧立绘和 24 条独立提示词。
Boss 已另行整理：[查看 10 个 Boss 的 50 张动作首帧和提示词](BOSSES.md)。
使用方式：选择对应 PNG 作为图生视频首帧，复制同名 `.txt` 的完整英文提示词。绿幕用于后续抠像。
行走、跑步为原地循环；闪避和攻击为一次动作并在结尾回到起始姿势。后续选帧时仍应检查循环接缝。
如需导出 8 帧，从完整动作周期中等间隔选取 8 张；首帧不要在末帧重复，检查末帧接回首帧是否自然。
角色朝右；游戏里朝左可水平翻转。武器提示词已锁定握柄、刃尖和杖头方向。墓煜的 staff 图集行实际使用魔书施法，因此对应立绘和提示词保留魔书。
绯月（角色 0）与鸦羽（角色 2）的行走、跑步、闪避均为空手立绘；对应视频提示词要求双手全程保持空手。
12 张攻击首帧保留原版人物、姿势和武器的每个像素，仅把原图居中放入 1536×1536 绿幕画布；画面外侧增加留白。攻击提示词要求明显的蓄力、全身发力、命中姿势和收势，并要求武器始终入镜。

[查看 24 张立绘总览](contact-sheet.jpg)
[查看 12 张攻击立绘总览](attack-contact-sheet.jpg)

| 角色 | 动作 | 首帧立绘 | 生视频提示词 |
|---|---|---|---|
| 绯月 | 行走 | [PNG](stills/heroes/hero-0/walk.png) | [TXT](video-prompts/hero-0/walk.txt) |
| 绯月 | 跑步 | [PNG](stills/heroes/hero-0/run.png) | [TXT](video-prompts/hero-0/run.txt) |
| 绯月 | 闪避 | [PNG](stills/heroes/hero-0/dodge.png) | [TXT](video-prompts/hero-0/dodge.txt) |
| 绯月 | 短剑攻击 | [PNG](stills/heroes/hero-0/sword.png) | [TXT](video-prompts/hero-0/sword.txt) |
| 绯月 | 重剑攻击 | [PNG](stills/heroes/hero-0/heavy.png) | [TXT](video-prompts/hero-0/heavy.txt) |
| 绯月 | 法杖施法 | [PNG](stills/heroes/hero-0/staff.png) | [TXT](video-prompts/hero-0/staff.txt) |
| 雪璃 | 行走 | [PNG](stills/heroes/hero-1/walk.png) | [TXT](video-prompts/hero-1/walk.txt) |
| 雪璃 | 跑步 | [PNG](stills/heroes/hero-1/run.png) | [TXT](video-prompts/hero-1/run.txt) |
| 雪璃 | 闪避 | [PNG](stills/heroes/hero-1/dodge.png) | [TXT](video-prompts/hero-1/dodge.txt) |
| 雪璃 | 短剑攻击 | [PNG](stills/heroes/hero-1/sword.png) | [TXT](video-prompts/hero-1/sword.txt) |
| 雪璃 | 重剑攻击 | [PNG](stills/heroes/hero-1/heavy.png) | [TXT](video-prompts/hero-1/heavy.txt) |
| 雪璃 | 法杖施法 | [PNG](stills/heroes/hero-1/staff.png) | [TXT](video-prompts/hero-1/staff.txt) |
| 鸦羽 | 行走 | [PNG](stills/heroes/hero-2/walk.png) | [TXT](video-prompts/hero-2/walk.txt) |
| 鸦羽 | 跑步 | [PNG](stills/heroes/hero-2/run.png) | [TXT](video-prompts/hero-2/run.txt) |
| 鸦羽 | 闪避 | [PNG](stills/heroes/hero-2/dodge.png) | [TXT](video-prompts/hero-2/dodge.txt) |
| 鸦羽 | 短剑攻击 | [PNG](stills/heroes/hero-2/sword.png) | [TXT](video-prompts/hero-2/sword.txt) |
| 鸦羽 | 重剑攻击 | [PNG](stills/heroes/hero-2/heavy.png) | [TXT](video-prompts/hero-2/heavy.txt) |
| 鸦羽 | 法杖施法 | [PNG](stills/heroes/hero-2/staff.png) | [TXT](video-prompts/hero-2/staff.txt) |
| 墓煜 | 行走 | [PNG](stills/heroes/hero-3/walk.png) | [TXT](video-prompts/hero-3/walk.txt) |
| 墓煜 | 跑步 | [PNG](stills/heroes/hero-3/run.png) | [TXT](video-prompts/hero-3/run.txt) |
| 墓煜 | 闪避 | [PNG](stills/heroes/hero-3/dodge.png) | [TXT](video-prompts/hero-3/dodge.txt) |
| 墓煜 | 短剑攻击 | [PNG](stills/heroes/hero-3/sword.png) | [TXT](video-prompts/hero-3/sword.txt) |
| 墓煜 | 重剑攻击 | [PNG](stills/heroes/hero-3/heavy.png) | [TXT](video-prompts/hero-3/heavy.txt) |
| 墓煜 | 法术攻击 | [PNG](stills/heroes/hero-3/staff.png) | [TXT](video-prompts/hero-3/staff.txt) |

## 立绘生成规格

内置 ImageGen 根据 `assets/portrait-N.png`（角色身份/服饰）与 `output/imagegen-refs/hero-N-ACTION-pose.png`（现有游戏身形/动作）分别生成单张绿幕立绘；统一要求为：1:1 构图、单人全身、朝右三分之二侧视、四周留白、纯绿幕、无文字/运镜/动作特效。持武器动作额外要求手握柄、刃尖朝屏幕右侧，法杖杖头在前上方；墓煜法术动作保留原图的魔书与短法器。
角色 0 和角色 2 的 6 张移动首帧按用户要求采用 ImageGen 定向编辑，移除武器并补全被遮挡的手部。
12 张原版攻击首帧保存在 `source-stills/attacks/`。`tools/pad_minimax_attack_stills.py` 只扩展四周绿色画布，不缩小、不重绘原图；中央 1254×1254 区域与原版像素完全相同。

参考文档 `minimax2live2d.md` 提供的是方法和洛琪希/牛头人示例；此包使用项目自身角色设定。
