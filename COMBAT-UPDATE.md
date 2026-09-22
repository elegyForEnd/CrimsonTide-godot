# 武器动作与光效更新

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
