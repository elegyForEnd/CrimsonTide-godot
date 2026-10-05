# 精简续做记录

最新决定：从绯月走路第 1 帧重新生成，使用下面的方法。v3 留作对照，不能把候选图当成最终素材。

- 范围：绯月、雪璃、鸦羽；短剑、重剑、法杖、走路、跑步、闪避各 8 张独立透明 PNG，共 144 张。
- 一个角色、一个动作依次完成；内置 imagegen 每帧单独生成，立即保存并检查；不保存提示词文件。
- 沿用我们原来的参考，不使用用户新做的三视图或其他新素材。
- 原攻击画风：软绘动漫、细而浅的线条、柔和色彩。绯月原攻击参考为 assets/combat/generated-attacks/heroes/hero-0/sword/000.png。
- 已选的走路比例、留白与细线浅色参考：output/hero-animation-v3/hero-0/walk/000-before-expression.png。这是最初首帧，不可用反复编辑后的图片替代它作为画风基准。
- 新首帧固定画布与人物尺度。沿用 1254×1254 方形、主体约 79% 高度与充分留白；后续不得放大头部、改变头身比例、加粗发丝或加深颜色。
- 走路有清楚但轻微的浅笑。攻击蓄力时专注抿嘴，打击帧短促张嘴像「喝」，回收时放松；保持脸型与眼睛大小。
- 剑刃必须笔直，手握剑柄，护手在手与剑刃之间；原武器设计保留。
- 角色特色：绯月轻巧、雪璃从容、鸦羽低而利落。步行按接触、下沉、经过、抬升、反侧接触、反侧下沉、反侧经过、反侧抬升。
- 图像生成以不可变首帧固定比例和画风，上一帧仅辅助姿势；不要累计重绘导致头部放大或色调变暗。
- 最新头发方案：Godot 小幅局部形变，让外侧发梢、红丝带和呆毛随步伐滞后摆动，保持原纹理色彩与细线；脸、发根、身体与手部保持稳定。shader 位于 shaders/hero_hair_motion.gdshader。
- 已完成一个只动头发的 24 帧 Godot 预览：output/hero-animation-v3/hero-0/hair-preview/。这是技术预览，尚未接入游戏。工具 tools/preview_hero_hair.gd。
- 新生成原始帧保存到 output/hero-animation-v4/source/hero-0/walk/；经过检查和头发动态处理的交付帧保存到 output/hero-animation-v4/hero-0/walk/。
- 当前下一步：生成新 000.png，检查比例、颜色、线条、表情和 alpha，再依次完成绯月该动作 8 帧，做循环预览；之后继续剩余动作与角色，最终校准、接入并验证游戏。
- 不触碰其他聊天和项目中已有的无关修改。

## v4 本次进度

- 绯月走路原始 000–007 已重新生成并保存；校准及局部头发动态烘焙完成，8 张 1254 方形透明 PNG 在 hero-0/walk。
- 新不可变首帧：output/hero-animation-v4/hero-0/walk/000.png；保留浅笑、原比例留白、浅色细线。原始生成的首帧被整体放大，已在 Godot 等比缩回原主体高度 988px。后续七帧没有缩放头部或水平移动人物，仅锁定脚底基线1166。
- 8帧占画布高度77.8–79.5%；发色取样不存在逐帧单调变深；笑容均可见。
- 头发局部形变已烘焙进每帧，另有24张身体固定的 hair-preview 用来单独查看摆动。
- preview.html 提供播放、速度、逐帧检查；walk-preview.png为APNG循环预览，walk-contact.png为检查拼图（不作为交付精灵图）。
- 新增 tools/bake_hero_walk_v4.gd；修复 shader 的 phase0 丝带偏移为零；preview_hero_hair.gd 支持输入和输出路径参数。
- 本动作仍待循环视觉验收，没有接入游戏。剩余动作和两个角色尚未重做，下一步检查本循环后继续绯月跑步。

## 游戏接入试看

- 已接入 v3 绯月短剑8帧、v4绯月走路8帧、v3雪璃/鸦羽走路各4帧，共24帧。其他动作继续使用游戏此前素材。
- 安装目录 assets/combat/hero-animation-preview，独立manifest；CharacterFrames优先覆盖对应动作，保留原始移动高度缓存；攻击命中时序保持第5帧。
- v4走路使用固定身体中心(735,1166)，避免交替落脚造成横向跳动；旧两角色走路整体等比校准，以脸/躯干对齐。短剑按后侧支撑脚对齐。
- 安装工具 tools/install_hero_animation_preview.py；游戏试看工具 tools/play_hero_animation_preview.gd。试看使用user://hero-animation-preview.json，不写常规存档。
- 已导出 dist/CrimsonTide-animation-preview.exe；export_presets已包含新manifest。常规源项目游戏也使用本次动作覆盖。
- CHARACTER SCALE 415检查通过；GENERATED ATTACKS 689检查通过；新路径/帧序检查通过。游戏内截图game-walk.png和game-sword.png已确认加载新图。
- 本地启动存在墓煜4个尚未提供的究极技WAV导入残留报错，属于既有素材缺失；不阻止动画或游戏试看，未改无关音频代码。

## 换脚定位纠正

用户反馈攻击和走路都有突然交换问题。检查确认旧短剑定位算法只采全图最低34px，打击004/005的后脚比前脚高，导致误选前脚：原x854/903，正确后脚x204/197。已移除自动猜测，用逐帧审核后脚鞋底点，包括每只后脚自己的y。走路固定躯干中心，不依据落地脚选择锚点。新回归测试检查打击两帧的后脚点及8张走路统一中心，通过。registration-fixed.png是游戏库渲染的逐帧定位检查，青色十字标原点。已重新导出试看exe并重开源项目试看。

## 用户决定：回退最初多帧图集

新动画效果不满意，用户要求回到最一开始的多图版。已设置 CharacterFrames.USE_GENERATED_HERO_ANIMATIONS=false，USE_FEIYUE_3D=false；原 attack-clean-{hero}.png 和 movement-{hero}.png 成为所有角色唯一运行时动画来源，每动作4帧，原尺寸、定位和时序恢复。独立帧及试验素材仅保留在磁盘，不加载进角色。所有角色原图集路径检查、295尺寸检查、17回退检查、680旧素材/时序检查通过。原动画72姿势已用Godot渲染确认。dist/CrimsonTide.exe已重新导出，旧动画试看exe也同步为原图集版，避免误开旧包。以前的标准exe备份到CrimsonTide-before-atlas-rollback.exe。今后不要自动恢复新独立帧，除非用户重新要求。
