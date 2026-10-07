# 武器图片特效与实际强化

**当前版本**：普通攻击、弹体和范围爆发已改用 32 张按实际机制制作的方图，并增强辉光；以下为上一版 74 张素材与强化接线的历史记录。最新对应表、播放入口与试玩见 [WEAPON-MECHANICS-VFX.md](WEAPON-MECHANICS-VFX.md)。

武器主效果使用内置 ImageGen 生成的独立正方形 RGBA 图片，并结合动画揭示、挂点、粒子、残影和淡出。运行时不使用 1:3 长图。被否决的长图只保存在 output/imagegen/rejected-1x3，不参与游戏或导出。

## 素材与组合

- assets/combat/imagegen-square：52 把不同名称的武器主图；同名的远征/闯关武器共用对应主图，48 把闯关武器之间保持独立图片。
- 绯红单手剑的起手、接斩、终结有三张独立方图。其他武器在各自主图上组合对应攻击类型的接斩/终结绘制层，形成不同的连段轮廓；图片配合动作，而不是用程序形状代替主要画面。
- 八张中性连段图：轻刃、重刃、枪弓、法杖各两张，使用武器本身的配色混合。枪弓层不额外画虚构的子弹数量。
- 十二张核心触发图按实际核心机制表现追击、出血、镜舞、破势、护盾、感电、回返、贯穿标记、退蓝、落地接力、冰缓与灵体延长。
- 四名角色保留原有独立 ImageGen 闪避、蓄力与奥义方图，角色派生按不同路线选择对应画面；终结路线再叠武器的终结绘制层。

以上新图合计 74 张：52 主图 + 绯红单手剑额外两段 + 8 连段层 + 12 核心。原始 alpha 与像素原样复制；不做背景扣除、重绘、锐化或放大。manifest.json 保存生成器、原始路径、尺寸、SHA256 与提示词路径，prompts/ 保存完整生成提示词。

提示词要求光体表面平滑、轮廓干净、透明留白，明确排除鳞片、颗粒凸起、密集碎屑、盔甲花纹和锤打金属等微纹理。冰、石、雷、月等元素由少量大形状或光线表达。

## 强化依据

| 实际状态 | 现有规则 | 表现方式 |
|---|---|---|
| +0～+5 锻造 | 每级增加 3% 攻击池 | 适度提高刃缘光强；不扩大命中范围或虚构新技能 |
| +2 | 可以安装符合类别的武器核心 | 已装核心的真实触发开始使用对应图片 |
| +3 | 可以淬炼；角色连招开放；部分武器派生开放 | 由现有动作识别与 hero_effect 确认事件播放；未解锁不提前播放 |
| +4 | 核心进入第二档 | 同一真实触发的核心画面略加强，触发条件与冷却仍按原规则 |
| +5 | 角色连招数值增强 | 已确认的角色连招增加短促刃缘光；不提前触发 |
| 物品品质 | 闯关倍率 1.00～1.40；远征沿用原品质表 | 与锻造分开读取，轻微增加刃缘光 |

rogue_build.visual_state() 验证当前绑定的武器实例、锻造档位、核心类别与淬炼门槛。context() 在出手时冻结状态；普攻、战技、弹丸、爆炸、连锁与命中事件携带这份快照，之后换装不会改变已经出手的效果。

core_visual() 接在现有机制实际执行的位置。取消、未命中、核心未解锁、冷却未就绪时不会预播；同一攻击根命中不重复播核心；灵契只在已有灵体被延长时播放，不凭空画出新召唤实体。

主要入口：scripts/weapon_image_art.gd、vfx_library.gd、stylized_vfx.gd、weapon_vfx.gd、rogue_build.gd、rogue_actions.gd 与 session.gd。资源准备与只读审计：tools/install_weapon_imagegen.py、tools/audit_weapon_square_art.py。相关测试：weapon_square_art、weapon_vfx_progression、weapon_vfx_identity、weapon_vfx_battle、standalone_vfx、weapon_stroke_stability、all_weapon_mounts。

## 验证与试玩

源码相关 13 组回归共 6100 检查、0 failures；方图原始像素审计 74 项、0 failures。Windows 内嵌 PCK 单文件为 build/CrimsonTide-WeaponImageVFX.exe，成品五组回归共 1467 检查、0 failures。测试细节见 TEST-REPORT.md。

预览：build/weapon-vfx-48.png、build/weapon-vfx-combos.png、build/weapon-image-upgrades.png。重新生成分别运行 tests/weapon_vfx_preview.gd 和 tests/weapon_upgrade_visual.gd；后者以实际 Build.hit_event 触发核心，未解锁档位不播图。所有生成提示词保存在 assets/combat/imagegen-square/prompts/，生成器为内置 ImageGen；续接工作复用已齐全的原图，没有重新生成或加工像素。
