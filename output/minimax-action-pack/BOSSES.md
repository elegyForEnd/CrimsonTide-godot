# Boss 动作首帧与 MiniMax 图生视频提示词

项目 `BossFrames` 使用 10 个 Boss，每个图集有移动、攻击、待机、受击、倒地 5 类状态。本包对应提供 50 张独立首帧立绘和 50 条英文图生视频提示词。
每个动作取同名 PNG 作视频第一帧，复制同名 TXT 的完整内容。移动和待机要求首尾循环；攻击与受击完成一次动作后回到起始姿势；倒地只播放一次。
立绘使用内置 ImageGen，参考项目原始 Boss 全身图与动作图集。原始生图保存在 `boss-source-stills/`；交付 PNG 仅在外侧补绿幕到 1536×1536，中心人物像素不缩放、不重绘。裂地者原始图面向左，交付图做了精确水平镜像以匹配统一朝右提示词。
图集动画仍需通过 MiniMax 生成视频后逐帧检查，尤其检查动作接缝、武器形状和出框情况。

[查看 50 张首帧总览](boss-contact-sheet.jpg)

| Boss | 动作 | 绿幕首帧 | 图生视频提示词 | 生图提示词 |
|---|---|---|---|---|
| 葬钟圣座 | 移动 | [PNG](stills/bosses/bell-hierophant/move.png) | [TXT](video-prompts/bosses/bell-hierophant/move.txt) | [TXT](image-prompts/bosses/bell-hierophant/move.txt) |
| 葬钟圣座 | 攻击 | [PNG](stills/bosses/bell-hierophant/attack.png) | [TXT](video-prompts/bosses/bell-hierophant/attack.txt) | [TXT](image-prompts/bosses/bell-hierophant/attack.txt) |
| 葬钟圣座 | 待机 | [PNG](stills/bosses/bell-hierophant/idle.png) | [TXT](video-prompts/bosses/bell-hierophant/idle.txt) | [TXT](image-prompts/bosses/bell-hierophant/idle.txt) |
| 葬钟圣座 | 受击 | [PNG](stills/bosses/bell-hierophant/hurt.png) | [TXT](video-prompts/bosses/bell-hierophant/hurt.txt) | [TXT](image-prompts/bosses/bell-hierophant/hurt.txt) |
| 葬钟圣座 | 倒地 | [PNG](stills/bosses/bell-hierophant/death.png) | [TXT](video-prompts/bosses/bell-hierophant/death.txt) | [TXT](image-prompts/bosses/bell-hierophant/death.txt) |
| 荆棘王誓 | 移动 | [PNG](stills/bosses/thorn-huntsman/move.png) | [TXT](video-prompts/bosses/thorn-huntsman/move.txt) | [TXT](image-prompts/bosses/thorn-huntsman/move.txt) |
| 荆棘王誓 | 攻击 | [PNG](stills/bosses/thorn-huntsman/attack.png) | [TXT](video-prompts/bosses/thorn-huntsman/attack.txt) | [TXT](image-prompts/bosses/thorn-huntsman/attack.txt) |
| 荆棘王誓 | 待机 | [PNG](stills/bosses/thorn-huntsman/idle.png) | [TXT](video-prompts/bosses/thorn-huntsman/idle.txt) | [TXT](image-prompts/bosses/thorn-huntsman/idle.txt) |
| 荆棘王誓 | 受击 | [PNG](stills/bosses/thorn-huntsman/hurt.png) | [TXT](video-prompts/bosses/thorn-huntsman/hurt.txt) | [TXT](image-prompts/bosses/thorn-huntsman/hurt.txt) |
| 荆棘王誓 | 倒地 | [PNG](stills/bosses/thorn-huntsman/death.png) | [TXT](video-prompts/bosses/thorn-huntsman/death.txt) | [TXT](image-prompts/bosses/thorn-huntsman/death.txt) |
| 永夜月冠 | 移动 | [PNG](stills/bosses/blood-queen/move.png) | [TXT](video-prompts/bosses/blood-queen/move.txt) | [TXT](image-prompts/bosses/blood-queen/move.txt) |
| 永夜月冠 | 攻击 | [PNG](stills/bosses/blood-queen/attack.png) | [TXT](video-prompts/bosses/blood-queen/attack.txt) | [TXT](image-prompts/bosses/blood-queen/attack.txt) |
| 永夜月冠 | 待机 | [PNG](stills/bosses/blood-queen/idle.png) | [TXT](video-prompts/bosses/blood-queen/idle.txt) | [TXT](image-prompts/bosses/blood-queen/idle.txt) |
| 永夜月冠 | 受击 | [PNG](stills/bosses/blood-queen/hurt.png) | [TXT](video-prompts/bosses/blood-queen/hurt.txt) | [TXT](image-prompts/bosses/blood-queen/hurt.txt) |
| 永夜月冠 | 倒地 | [PNG](stills/bosses/blood-queen/death.png) | [TXT](video-prompts/bosses/blood-queen/death.txt) | [TXT](image-prompts/bosses/blood-queen/death.txt) |
| 镜墓纺女 | 移动 | [PNG](stills/bosses/mirror-weaver/move.png) | [TXT](video-prompts/bosses/mirror-weaver/move.txt) | [TXT](image-prompts/bosses/mirror-weaver/move.txt) |
| 镜墓纺女 | 攻击 | [PNG](stills/bosses/mirror-weaver/attack.png) | [TXT](video-prompts/bosses/mirror-weaver/attack.txt) | [TXT](image-prompts/bosses/mirror-weaver/attack.txt) |
| 镜墓纺女 | 待机 | [PNG](stills/bosses/mirror-weaver/idle.png) | [TXT](video-prompts/bosses/mirror-weaver/idle.txt) | [TXT](image-prompts/bosses/mirror-weaver/idle.txt) |
| 镜墓纺女 | 受击 | [PNG](stills/bosses/mirror-weaver/hurt.png) | [TXT](video-prompts/bosses/mirror-weaver/hurt.txt) | [TXT](image-prompts/bosses/mirror-weaver/hurt.txt) |
| 镜墓纺女 | 倒地 | [PNG](stills/bosses/mirror-weaver/death.png) | [TXT](video-prompts/bosses/mirror-weaver/death.txt) | [TXT](image-prompts/bosses/mirror-weaver/death.txt) |
| 余烬司祭 | 移动 | [PNG](stills/bosses/ashen-vesper/move.png) | [TXT](video-prompts/bosses/ashen-vesper/move.txt) | [TXT](image-prompts/bosses/ashen-vesper/move.txt) |
| 余烬司祭 | 攻击 | [PNG](stills/bosses/ashen-vesper/attack.png) | [TXT](video-prompts/bosses/ashen-vesper/attack.txt) | [TXT](image-prompts/bosses/ashen-vesper/attack.txt) |
| 余烬司祭 | 待机 | [PNG](stills/bosses/ashen-vesper/idle.png) | [TXT](video-prompts/bosses/ashen-vesper/idle.txt) | [TXT](image-prompts/bosses/ashen-vesper/idle.txt) |
| 余烬司祭 | 受击 | [PNG](stills/bosses/ashen-vesper/hurt.png) | [TXT](video-prompts/bosses/ashen-vesper/hurt.txt) | [TXT](image-prompts/bosses/ashen-vesper/hurt.txt) |
| 余烬司祭 | 倒地 | [PNG](stills/bosses/ashen-vesper/death.png) | [TXT](video-prompts/bosses/ashen-vesper/death.txt) | [TXT](image-prompts/bosses/ashen-vesper/death.txt) |
| 无名赤月 | 移动 | [PNG](stills/bosses/nameless-moon/move.png) | [TXT](video-prompts/bosses/nameless-moon/move.txt) | [TXT](image-prompts/bosses/nameless-moon/move.txt) |
| 无名赤月 | 攻击 | [PNG](stills/bosses/nameless-moon/attack.png) | [TXT](video-prompts/bosses/nameless-moon/attack.txt) | [TXT](image-prompts/bosses/nameless-moon/attack.txt) |
| 无名赤月 | 待机 | [PNG](stills/bosses/nameless-moon/idle.png) | [TXT](video-prompts/bosses/nameless-moon/idle.txt) | [TXT](image-prompts/bosses/nameless-moon/idle.txt) |
| 无名赤月 | 受击 | [PNG](stills/bosses/nameless-moon/hurt.png) | [TXT](video-prompts/bosses/nameless-moon/hurt.txt) | [TXT](image-prompts/bosses/nameless-moon/hurt.txt) |
| 无名赤月 | 倒地 | [PNG](stills/bosses/nameless-moon/death.png) | [TXT](video-prompts/bosses/nameless-moon/death.txt) | [TXT](image-prompts/bosses/nameless-moon/death.txt) |
| 裂地钻兽 | 移动 | [PNG](stills/bosses/earthsplitter/move.png) | [TXT](video-prompts/bosses/earthsplitter/move.txt) | [TXT](image-prompts/bosses/earthsplitter/move.txt) |
| 裂地钻兽 | 攻击 | [PNG](stills/bosses/earthsplitter/attack.png) | [TXT](video-prompts/bosses/earthsplitter/attack.txt) | [TXT](image-prompts/bosses/earthsplitter/attack.txt) |
| 裂地钻兽 | 待机 | [PNG](stills/bosses/earthsplitter/idle.png) | [TXT](video-prompts/bosses/earthsplitter/idle.txt) | [TXT](image-prompts/bosses/earthsplitter/idle.txt) |
| 裂地钻兽 | 受击 | [PNG](stills/bosses/earthsplitter/hurt.png) | [TXT](video-prompts/bosses/earthsplitter/hurt.txt) | [TXT](image-prompts/bosses/earthsplitter/hurt.txt) |
| 裂地钻兽 | 倒地 | [PNG](stills/bosses/earthsplitter/death.png) | [TXT](video-prompts/bosses/earthsplitter/death.txt) | [TXT](image-prompts/bosses/earthsplitter/death.txt) |
| 雷骸巨鸟 | 移动 | [PNG](stills/bosses/storm-roc-v2/move.png) | [TXT](video-prompts/bosses/storm-roc-v2/move.txt) | [TXT](image-prompts/bosses/storm-roc-v2/move.txt) |
| 雷骸巨鸟 | 攻击 | [PNG](stills/bosses/storm-roc-v2/attack.png) | [TXT](video-prompts/bosses/storm-roc-v2/attack.txt) | [TXT](image-prompts/bosses/storm-roc-v2/attack.txt) |
| 雷骸巨鸟 | 待机 | [PNG](stills/bosses/storm-roc-v2/idle.png) | [TXT](video-prompts/bosses/storm-roc-v2/idle.txt) | [TXT](image-prompts/bosses/storm-roc-v2/idle.txt) |
| 雷骸巨鸟 | 受击 | [PNG](stills/bosses/storm-roc-v2/hurt.png) | [TXT](video-prompts/bosses/storm-roc-v2/hurt.txt) | [TXT](image-prompts/bosses/storm-roc-v2/hurt.txt) |
| 雷骸巨鸟 | 倒地 | [PNG](stills/bosses/storm-roc-v2/death.png) | [TXT](video-prompts/bosses/storm-roc-v2/death.txt) | [TXT](image-prompts/bosses/storm-roc-v2/death.txt) |
| 吞月渊蛇 | 移动 | [PNG](stills/bosses/moon-leviathan/move.png) | [TXT](video-prompts/bosses/moon-leviathan/move.txt) | [TXT](image-prompts/bosses/moon-leviathan/move.txt) |
| 吞月渊蛇 | 攻击 | [PNG](stills/bosses/moon-leviathan/attack.png) | [TXT](video-prompts/bosses/moon-leviathan/attack.txt) | [TXT](image-prompts/bosses/moon-leviathan/attack.txt) |
| 吞月渊蛇 | 待机 | [PNG](stills/bosses/moon-leviathan/idle.png) | [TXT](video-prompts/bosses/moon-leviathan/idle.txt) | [TXT](image-prompts/bosses/moon-leviathan/idle.txt) |
| 吞月渊蛇 | 受击 | [PNG](stills/bosses/moon-leviathan/hurt.png) | [TXT](video-prompts/bosses/moon-leviathan/hurt.txt) | [TXT](image-prompts/bosses/moon-leviathan/hurt.txt) |
| 吞月渊蛇 | 倒地 | [PNG](stills/bosses/moon-leviathan/death.png) | [TXT](video-prompts/bosses/moon-leviathan/death.txt) | [TXT](image-prompts/bosses/moon-leviathan/death.txt) |
| 霜骨古龙 | 移动 | [PNG](stills/bosses/frostbone-dragon/move.png) | [TXT](video-prompts/bosses/frostbone-dragon/move.txt) | [TXT](image-prompts/bosses/frostbone-dragon/move.txt) |
| 霜骨古龙 | 攻击 | [PNG](stills/bosses/frostbone-dragon/attack.png) | [TXT](video-prompts/bosses/frostbone-dragon/attack.txt) | [TXT](image-prompts/bosses/frostbone-dragon/attack.txt) |
| 霜骨古龙 | 待机 | [PNG](stills/bosses/frostbone-dragon/idle.png) | [TXT](video-prompts/bosses/frostbone-dragon/idle.txt) | [TXT](image-prompts/bosses/frostbone-dragon/idle.txt) |
| 霜骨古龙 | 受击 | [PNG](stills/bosses/frostbone-dragon/hurt.png) | [TXT](video-prompts/bosses/frostbone-dragon/hurt.txt) | [TXT](image-prompts/bosses/frostbone-dragon/hurt.txt) |
| 霜骨古龙 | 倒地 | [PNG](stills/bosses/frostbone-dragon/death.png) | [TXT](video-prompts/bosses/frostbone-dragon/death.txt) | [TXT](image-prompts/bosses/frostbone-dragon/death.txt) |
