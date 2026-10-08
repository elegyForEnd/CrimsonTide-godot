# 武器特效：按实际动作与弹体选图

2026-10-07 全量验收：69 把武器均已逐页人工核对，记录见 [全部武器核对清单](WEAPON-FULL-AUDIT.md)。最新素材包括重刃 v3、震地 v2；熔炉巨锤和星陨石槌使用身体中心冲击环。战技使用自己的实际前摇，精确出手边界按秒数判定。新版试玩仍为 `build/CrimsonTide-WeaponTipFixed.exe`，逐把预览入口 `build/weapon-full-audit/index.html`。

本版修正上一版把不同武器画成相似能量波、出手和弹体共用主图的问题。当前主画面使用内置 ImageGen 制作的 32 张独立透明方图，按实际用途组合：10 张近战动作轨迹、11 张飞行弹体、2 张出手闪光、1 张直线光束、8 张范围爆发。完整原始图片、尺寸、透明边界、SHA256 和生成提示词在 `assets/combat/imagegen-mechanics/manifest.json` 与 `prompts/`。

**最新重做**：按用户要求，用内置 ImageGen 重新生成了 14 张原图，替换此前太细、亮芯不清或方向错误的素材：轻刃挥击、双刃、突刺、重刃扇斩、轻/重圆斩、仪镰、战戟窄扫，以及月刃、箭、冰针、子弹、雷弹和弓弦出手。新文件统一带 `_v2`，由 `weapon_image_art.gd` 的 `REDRAWN` 映射接入；原32张保留用于来源记录与前后对照，共46张原始RGBA。新图按原始比例显示，已经移除上一轮的主体扩边着色器和横截面拉厚。

角色与十二核心继续使用各自原有素材。之前的 74 张方图保留来源记录与兼容入口，普通武器出手、飞行弹体、光束和爆炸不再把它们当成统一主图。

## 对应实际机制

| 实际动作 | 当前画面 | 示例与限制 |
|---|---|---|
| 短刀/细剑挥击 | 厚实、尖端渐细的亮色刃面 | 长度随实际武器范围；烛影短刀只吃灼烧条件加伤，去掉无条件火焰粒子 |
| 突刺 | 狭长直线刃光 | 鸦喙刺剑普攻；多把轻刃的右键是真实突刺，不继续显示普通横斩 |
| 双刃 | 两条交叉短迹 | 血棘双刃普通挥击；右键仍按真实 thrust 播直线 |
| 周身圆斩 | 以身体为中心的空心刀轮 | 回环弯刀、闯关裂地重剑/熔炉巨锤/星陨石槌；空中圆斩按实际 height 升高 |
| 重刃扇斩/仪镰 | 宽刀迹/钩形刃迹 | 断潮、斩首刃、仪镰等；风暴战戟普攻另用 70° 窄扫，右键按自己的 cone 判定选图 |
| 砸地/下劈 | 接触裂痕/垂直重斩 | 远征裂地重剑与砸地战技；不因为名字相同就把闯关圆斩改成砸地 |
| 枪械 | 短枪焰 + 独立细弹丸 | 镜轨双铳当前普通攻击只发一个模拟弹体，不虚构双弹；齐射数量来自实际 bullets |
| 弓弩 | 弦振 + 实体箭杆、箭头、尾羽 | 长弓箭与连弩短箭分别控制尺寸；弓弩不再显示枪焰 |
| 冰针/火羽 | 一根细晶针/一枚火羽 | 霜针战技的 scatter 机制仍画五根冰针；烬羽画实际五枚火羽 |
| 陨石/虚涡 | 岩核与火尾/紧凑涡球，落点另画爆发 | 爆发只从实际 spell_burst 事件的中心、半径播放 |
| 月刃/魔枪 | 空心弯月/细长魔枪 | 飞行方向来自实际速度；魔枪光束端点另补枪尖 |
| 雷链/棱镜/贯流 | 细电弧/直线光束 | 路径、长度、宽度来自实际事件，不拿波状主图代替 |

## 播放、强化和亮度

`weapon_mechanics.gd` 从 Catalog 的 family/pattern/spell 及战技的 `attack_kind` 选择画面。`rogue_actions.gd` 和 `session.gd` 传递实际招式类型、光束宽度、爆发半径与高度。`weapon_image_art.gd` 依据原图有效透明边界排版；普通刀光与弹体保持原始长宽比，厚度来自重新生成的原图，光束裁取有效光体后映射到实际判定段。

释放类素材捕获挂点或身体位置；蓄力才跟随挂点。光束起点存为地面局部坐标，相机移动时两端一起投影。完整圆斩围绕身体而不是围绕武器尖端。远程派生通过实际弹体/施法事件表现，取消额外剑弧与升空冰晶；近战派生沿用自己的刀迹。

强化、品质与核心仍依据真实状态：出手冻结快照；+2/+4 核心档位、+3/+5 角色连招不提前播放。亮度采用饱和色亮芯、局部边缘辉光和终结残影，命中阶段先保持清晰，再在收招阶段淡出。没有修改伤害、碰撞、弹丸数量、冷却或解锁规则。

当前主体使用 `stylized_texture.gdshader` 直通原图，边缘辉光仍由独立光层表现。保持枪焰半径30、法杖出手27、轻/重命中闪光26/38及0.14/0.18秒停留，刀光在生命周期前56%保持亮度后收束。新箭杆明亮，冰针减少密集小切面，雷弹尖端改为实际飞行朝向；圆斩保留透明中心。所有新图直接复制原始RGBA，不进行扣背景、重绘、锐化或像素加工。

## 验证与预览

### 2026-10-07 剑尖与方向修复

远征和闯关的 `weapon_effect_socket()` 现在将 `stroke_tip` 设为角色图集中的真实武器端点。攻击朝向仍来自实际攻击向量，但不再把剑尖搬到一个虚拟方向位置。释放、延迟残影一次捕获后保持世界位置，蓄力继续跟随武器；圆斩和震地继续围绕身体，范围爆发继续落在目标处。

`weapon_image_art.gd` 的 `mechanic_contact()` 在素材有效边界内定位亮刃，按实际等比缩放映射到挂点；突刺从剑尖向外延伸。`stylized_vfx.gd` 的 `draw_mechanic()` 去掉释放刀光的额外旋转和固定半径偏移。主体饱和色保留银白亮芯，叠加光晕由 0.62 降到 0.14，避免盖住角色。`attack_pose_frame()` 与远征绘制使用实际 `build_strike_windup`，修正攻速加成后的出手姿势不同步。

本轮通过内置 ImageGen 重画两张原始透明图：`assets/combat/imagegen-mechanics/motion_double_slash_v3.png`（朝前交汇的双刃刀迹）、`assets/combat/imagegen-mechanics/motion_heavy_overhead_v2.png`（方向统一的重刃终结切痕）。完整生成提示词位于同目录 `prompts/` 下的同名 `.txt`，来源、有效边界与 SHA256 记在 `manifest.json`。旧图保留，原始 RGBA 像素直接复制。

新增 `tests/weapon_mechanic_contact.gd`：真实渲染器、七种刀迹、三段连击、八方向、三个播放时刻及带斜切的地面投影，共 505 项亮刃接触检查。`weapon_stroke_directions.gd` 扩展为全部远征/闯关近战武器，验证真实剑尖契约。`tests/weapon_mount_preview.gd` 生成八种动作四方向角色预览 `build/weapon-mount-repaired.png`。新版试玩为 `build/CrimsonTide-WeaponTipFixed.exe`。

`tests/weapon_mechanics.gd` 检查实际普攻/战技事件、弹体数量、选图、落点和判定尺寸；`tests/weapon_mechanics_visual.gd` 以真实 GPU 检查箭/针/枪的细长轮廓、身体中心、空中高度、光束相机稳定性与亮芯可见性。既有武器身份、释放挂点、强化、核心、战斗与法术回归继续执行。原图审计为 `tools/audit_weapon_mechanics.py`。

新旧原图对照：`build/weapon-imagegen-redraw.png`（运行 `tests/weapon_redraw_preview.gd` 重新生成）。选图对照：`build/weapon-mechanics-comparison.png`；动态对照：`build/weapon-mechanics-motion.gif`；实际战场截图：`build/weapon-vfx-battle-*.png`。运行 `tests/weapon_mechanics_preview.gd -- --motion-preview` 可重新生成 viewport 帧，再直接编码为 GIF。最新试玩：`build/CrimsonTide-WeaponImageRedraw.exe`，测试记录见 `TEST-REPORT.md`。
