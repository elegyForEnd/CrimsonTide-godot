# 武器动作与光效更新

## Suno 音频替换

通过用户指定的 Apilio API 提交四组 Suno 生成任务（刀剑、重击、魔法、仪式氛围），将返回音频剪辑为 35 条离线素材：34 条立体声 WAV 与一条无缝衔接 OGG 氛围循环。覆盖单手剑三连段、双手剑、法杖、普通/重击命中、枪声、闪避、受伤、拾取、技能、钟声及三名角色的大招蓄力和爆发。音色来自生成音频的采样剪辑、滤波、叠层及包络处理，不是实地录音；已移除旧版运行时正弦波和随机噪声合成。

大招音频使用独立声道，单人暂停战场时继续播放；在 CG 72% 的爆发点切换声音，跳过或换页时停止。联机使用独立裁剪短版，保持原音高。战斗使用最多 24 个播放声道、命中密集触发限流、随机变体与总线峰值限制，避免多人攻击导致过量堆叠。

`assets/audio/suno-manifest.json` 记录提示词、任务 ID、返回模型、原始素材 SHA-256 及全部裁剪参数，不包含 API 密钥或临时下载凭证。原始音频存于不打包的 `build/audio-source/`；`tools/prepare_suno_audio.py` 可重新生成游戏素材。试听合集为 `build/suno-audition.mp3`，顺序为三次轻剑、重剑、法杖、命中、闪避、技能、钟声以及三名角色大招。运行游戏不需要网络或密钥。

验证：`tests/audio.gd` 检查资源加载、连段音效、并发限流、暂停期间播放、大招爆发时点、跳过清理、环境音恢复及三角色联机短版；另检查 PCM 峰值、起音延迟与尾音归零，并运行战斗和 CG 回归测试。自动检查不替代主观试听。

## 全屏奥义 CG 演出

Q 技能成功释放后播放当前角色专属 CG：绯月血色剑光、雪璃冰蓝法阵、鸦羽紫焰夜鸦。插画推镜叠加旋转法阵、流光、粒子、冲击波、短闪光和爆发音效。单人演出 2.6 秒并暂停战场；任意键或点击跳过，自动恢复。联机只在施法者客户端展示 0.85 秒短版，不暂停网络或其他玩家，保留原有技能结算和冷却。此次为插画分层动态演出，不是逐帧角色动画视频。

插画使用内置 image_gen 生成，项目素材：`assets/combat/ultimate-cg.png`，完整提示词：`assets/combat/ultimate-prompt.txt`。`tests/ultimate.gd` 验证实际技能触发、冷却、单人暂停与恢复、联机短版、跳过按键不穿透、自动结束，并输出三个角色截图到 `build/ultimate-0.png` 至 `build/ultimate-2.png`。

## 单手剑连段刀光偏移修复（追加）

反向挥斩之前向 `draw_texture_rect_region` 传入负高度矩形，翻转时会偏离预期中心。现改为正尺寸矩形配合绘制变换镜像，两层刀光都围绕各自原定中心翻转。`tests/slash_alignment.gd` 覆盖三个连段、四个朝向，截图输出到 `build/slash-alignment.png`。

## 角色体型校准（追加）

移动和攻击不再以各图集首帧的透明包围盒高度决定大小。`scripts/character_metrics.gd` 为三名角色的 72 帧记录头顶到下巴的尺寸及落脚原点，将头部统一到 26 个世界像素；帽子、发饰、武器和光效不参与体型计算。每帧等比缩放，保留奔跑腾空和闪避压低身体造成的真实姿势变化。透明裁切区域仅决定取图范围，不再决定体型或脚底基线。

验证：`tests/character_scale.gd` 检查所有帧的等比缩放、头部尺寸、落脚原点，以及图集裁切留白和分辨率变化不会改变角色大小；完整 72 帧预览由 `tests/animation_visual.gd` 输出。

## 移动动画与串图修复（追加）

三名角色新增走路、奔跑、闪避各四姿势，共 36 帧。WASD 走路，按住 Shift 奔跑（1.45 倍移速），空格播放低身闪避与残影。闪避在 0.24 秒内移动 145 像素，逐步碰撞检测，保留两秒冷却；可打断普通攻击，倒地会结束闪避。移动时武器收起，攻击和待机切回当前武器动作。仍使用左右镜像朝向，没有增加八方向素材。

旧攻击图集的长武器越过均分网格导致邻帧碎片。已用内置 imagegen 重制三张攻击图集，保留原文件备份；运行时查找透明间隔，并使用开启 `filter_clip` 的 AtlasTexture 隔离每一帧。新增 `scripts/character_frames.gd` 管理帧和脚底基线。

新增素材位于 `assets/combat/attack-clean-0.png`、`attack-clean-1.png`、`attack-clean-2.png`，以及 `movement-0.png`、`movement-1.png`、`movement-2.png`。提示词完整记录见 `assets/combat/movement-prompts.json`，均使用内置 imagegen，以原角色图为身份参考。

`tests/movement.gd`：83 项移动行为与 72 帧透明边界检查通过；`tests/animation_visual.gd` 生成全部姿势总览 `build/animation-frames.png`；`tests/ui.gd` 增加走路、奔跑、空格闪避和回到待机的实际状态切换检查。

2026-09-22。三名角色均可使用三种新武器，保留原步枪。绯月默认单手剑，雪璃默认法杖，鸦羽默认双手剑。战斗中按 1 / 2 / 3 / 4 切换；攻击前摇、收招与施法期间禁止换武器。

| 武器 | 节奏 | 演出 |
|---|---|---|
| 绯红单手剑 | 0.10 秒前摇，0.38 秒基础周期；第三击 1.4 倍伤害 | 红色双层刀光，交替斩向，身体前倾与残影 |
| 破晓双手剑 | 0.34 秒前摇，0.88 秒基础周期 | 双手举剑、重劈、金色地裂、冲击波，强击退与震动 |
| 星辉法杖 | 0.22 秒前摇，0.62 秒基础周期 | 举杖聚能、前伸发射，青蓝彗星弹道与法阵 |

每个角色图集包含 3 类武器 × 4 个完整身体姿势。采用分帧动作、插值倾斜、冲刺偏移与残影组合，左右镜像朝向；不是完整八方向骨骼动画，步枪沿用旧角色素材与后坐动作。近战伤害在前摇结束时判定，受墙体和扇形范围限制；法杖使用连续线段弹道碰撞。

命中有闪亮染色、伤害数字、火花、击退、敌人硬直和角色动作停顿（轻击 45ms / 重击 85ms）。停顿仅冻结角色挥击动画，不暂停世界或网络模拟。所有武器、伤害、击退由房主判定；可靠 RPC 同步演出事件，快照同步武器和动作状态。

Q 技能保留角色规则：绯月向前连续血刃；雪璃治疗法阵、光柱和上升粒子；鸦羽紫色爆发与三重环斩。光效采用手绘位图、加法混合、边缘羽化着色器，无需依赖 Compatibility 渲染器不支持的全屏 Bloom。演出最多保留 240 个纹理粒子，并过滤远离镜头的事件。

## 新增素材与生成记录

使用内置 imagegen 工具，原始生成文件已复制到工程，保留原透明通道。角色参照 `assets/sentinels.png`。

- `assets/combat/hero-0.png`：绯月的 12 姿势。
- `assets/combat/hero-1.png`：雪璃的 12 姿势。
- `assets/combat/hero-2.png`：鸦羽的 12 姿势。
- `assets/combat/vfx-atlas.png`：9 格光效图集。
- `resources/combat_glow.gdshader`：加法混合与图集边缘羽化。

角色最终提示词模板（依次代入 silver white haired red eyed girl, black crimson white gothic dress / ice blue haired teal eyed girl, dark cleric outfit teal scarf / purple ponytail girl violet eyes dark armored gothic coat）：

> Use case: stylized-concept. Create one precise game sprite animation atlas on ACTUAL TRANSPARENT background. Reference is identity reference only. Use ONLY the [character] from reference, preserve her distinctive identity and detailed anime costume. Exactly 4 columns and 3 rows equal cells, 12 full body sprites, consistent size and feet baseline within each cell. All sprites facing RIGHT in three-quarter view. Row 1: wielding ornate crimson ONE HANDED SWORD: column1 ready stance, column2 twist torso wind up sword back, column3 forceful forward horizontal slash extended sword to right, column4 follow through lowered sword. Row2: wielding huge golden TWO HANDED GREATSWORD: ready stance, both hands raise sword overhead, heavy forward downward cleave bent knees, low recovery stance. Row3: wielding tall cyan crystal MAGIC STAFF: ready, lean back lift staff gather magic, thrust staff to right casting with extended arms, settle recovery. Real differences in arms torso legs hair and clothing between frames. No guns. No special effects, no floor, no shadows, no glow background, no text, no grid, no checkerboard. Entire body hair and weapon wholly within respective cell with 12 percent clear margins, never overlap cells. Professional hand-painted detailed anime chibi action RPG sprites, 3 heads tall, rich textile armor details. Landscape 4:3 atlas.

光效最终提示词：

> Create a production game VFX texture atlas for a gothic anime action RPG. Square 1536x1536 image divided into exactly 3 columns and 3 rows of equal square cells, no grid lines, no text. Pure black background for ADDITIVE blending, all effects isolated with generous black margins inside each cell. Row 1: left crimson sweeping crescent sword slash with white hot edge and many wispy flame filaments; middle huge amber gold downward cleaving sword impact with jagged radiant shards; right cyan violet magical comet flying toward RIGHT with bright head and long trailing wisps to left. Row 2: left elaborate cyan circular arcane sigil seen from directly above, concentric runes and intricate floral sacred geometry; middle violet explosive starburst with smoky spectral feathers; right warm white gold sharp impact spark with branching filaments. Row 3: left soft cyan luminous energy orb with turbulent swirling plasma; middle crimson smoky slash shockwave halo; right tall cyan white holy light pillar with feathered rays. Detailed hand-painted luminous fantasy spell effects, HDR looking bloom baked into texture, rich layered translucent wisps, cinematic energy, NOT flat vector shapes. Each effect completely within its cell, centered on exact cell center. No characters or weapons.

## 验证

- `tests/systems.gd`：261 项原有规则通过。
- `tests/combat.gd`：前摇伤害、换武器锁、实际命中、弹道、击退、命中停顿、墙体遮挡、背后扇形排除、非法武器、技能与倒地打断。
- `tests/ui.gd`：原 UI 流程及 1～4 键真实输入事件。
- `tests/combat_visual.gd`：9 组武器动作、3 组技能截图，输出到 `build/combat-*.png`，已人工查看刀光、重劈和治疗技能。
- `tests/network.gd`：本机 2 / 4 人进程通过，新增远端战斗事件与换武器快照验证。尚未实测公网延迟环境。

运行示例：`Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/combat.gd`。画面验证省略 `--headless` 并使用 `tests/combat_visual.gd`。
