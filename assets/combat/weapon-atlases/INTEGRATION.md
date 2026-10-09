已接入游戏的武器动画与特效

四名角色各有 48 把武器的持械待机、行走、奔跑、闪避、普攻与武器技。
每个动作四帧，共 192 个持械配置、1152 段动画、4608 个帧索引。
绯月使用具体武器图集；其他三名角色的近战按具体武器，远程按步枪、
手枪、双铳、弓、弩、法杖六类共用动作。同名远征武器通过现有映射共用。

manifest.json 直接引用原始 RGBA 图片，AtlasTexture 按透明间隔切帧。
一个动作使用固定地面基线和缩放；多动作共页采用站立动作的尺度。
前三把武器已有人工登记的普攻落脚点继续使用原来的登记。
闯关的移动动画从起步累积，走路与奔跑分别使用自己的播放速度。
持械状态保留轻微武器光效。

新增 44 张武器技、弹体、光束与爆发原图已登记到特效清单并接入事件。
具体武器决定图像，原有机制决定命中形状、范围与弹体数量。
原图保留自己的颜色；定向弹体按实际飞行方向及展示宽度绘制。

原图质量仍有待修订：integration-report.json 记录了部分帧贴边与透明
间隔不足。其他角色的 generation-status 清单仍保留动作、握持和发丝
问题。自动登记的武器末端与地面位置仍需逐把视觉微调，不能视为全部
素材已完成人工审核。原始角色图片未改像素，攻击判定和平衡数值保留。

2026-10-08 特效挂点及重武器修订：普攻与武器技的 384 个命中帧登记
刃尖和武器方向；蓄力帧另行登记，弓以出箭位置为挂点。70 个攻击
特效登记自身发光接触点，已有人工接触点保留。左右翻转共用坐标转换。
固定朝向的角色图只提供释放位置和武器长度，实际斩击方向采用鼠标
瞄准方向。释放后特效独立播放，避免收招换帧或转动鼠标拖动已释放
的斩击；持械微光与蓄力光点仍贴在可见武器上。
重剑与战斧分别设置下劈、斜斩、窄幅长柄轨迹。熔炉巨锤、星陨石槌
新增独立原始 PNG 落锤素材，替换完整冲击波圆环；真正环斩保留圆形
攻击机制。原始素材握持、贴边与局部动作衔接问题仍需修订。

挂点重建：tools/register_weapon_mounts.py
特效接触点重建：tools/register_weapon_effect_contacts.py
挂点及翻转验证：tests/weapon_mount_alignment.gd
鼠标八方向及释放稳定性验证：tests/weapon_vfx_battle.gd
重武器预览：build/weapon-heavy-strokes-preview.png

可复现登记：python tools/integrate_weapon_raw_assets.py
完整配置验证：tests/weapon_raw_integration.gd
已人工登记的落脚点验证：tests/weapon_atlas_registration.gd
机制与武器身份验证：tests/weapon_mechanics.gd、weapon_authored_identity.gd
实际战斗事件验证：tests/weapon_vfx_battle.gd
弹体及范围渲染验证：tests/weapon_mechanics_visual.gd
四名角色六种动作预览：build/weapon-raw-integration-preview.png

上下瞄准与尺寸修正（2026-10-08）：
释放挂点保留手部高度，将左右手部伸展量旋转到鼠标方向；可见武器挂点
继续用于持械微光与蓄力。独立近战斩击的绘制中心沿瞄准方向位于虚拟
握点前方，不再因素材接触点或固定朝向偏到左右。重武器的附加斜角
限制为约 22 度，避免把向上的攻击横置；差异仍由原始画面和轨迹比例
保留。近战绘制尺寸增加 22%，旋转特效不再缩小到剑身长度。
八方向预览：build/weapon-mouse-aim-preview.png
像素位置与可读尺寸验证：tests/weapon_mechanics_visual.gd

绯红单手剑：新增原始 ImageGen 透明素材 identity_600_compact_v2.png，
三段普攻换成短厚弧刃，反手斩仅翻转弧的首尾而保留外侧朝向鼠标。
这把剑独立限制绘制宽度，不套用大范围长柄或重剑拖尾的尺寸。

### Held surface light correction
Held accents no longer select or shrink release_source paintings. weapon_held_glow reads opaque pixels along the current pose's real grip-to-tip segment, caches their material colors, and draws low-opacity native radial light on those pixels. Melee uses a moving sequence along the blade; ranged weapons use a quiet head light. Empty material samples remain unlit. Both field renderers retain their original pose transforms. Verification: 42,593 checks across four heroes and 48 weapons, including pixel attachment, intensity, and no attack-painting reuse; zero failures.


### Full weapon effects audit (2026-10-08)
Six original ImageGen replacements are registered by tools/register_weapon_effect_audit.py: identity_610_cut_v2, identity_612_cut_v2, identity_618_cut_v2, identity_623_cut_v2, audit_637_burst_v2, audit_639_burst_v2. Normal cut selection and burst payload selection consume these assets; original alpha and RGB remain unchanged. Spins retain the captured body center instead of the grip. Charge uses quiet native gathering light at the live weapon socket rather than miniature released art. Full per-weapon render coverage and observations: build/weapon-full-audit/AUDIT.md. Held glow sampling coverage separately records 83 candidate mount/material misses; these stay unlit until source landmarks are refined.



## 左键点按 / 长按攻击（2026-10-08）

已接入闯关、远征和主机权威输入。左键按下只记录手势，松开执行；长按不再自动重复普攻。

| 武器 | 满蓄时间 | 长按释放 |
| --- | --- | --- |
| 单手武器 | 0.65 秒 | 按武器专属招式释放回旋、突刺等强化攻击，伤害倍率 1.65 |
| 重武器 | 1.05 秒 | 专属重劈、锤砸、旋转等强化攻击，伤害倍率 2.15、增强击退 |
| 枪弓 | 0.70 秒 | 枪弹贯穿 2 人、弓箭贯穿 3 人；散射类缩小散布；消耗 1 发弹药 |
| 法杖 | 0.85 秒 | 按每把法杖原有元素招式释放光束、齐射或爆发，伤害倍率 1.65 |

- 0.18 秒开始显示聚能光与武器材质粒子；满蓄发出一次碎光提示。角色静止时保持现有战技预备帧，移动仍使用持械走跑动画。
- 未满蓄就松开，执行现有普通攻击并保留连击与输入缓存。攻击前摇、后摇期间不能白赚蓄力进度。
- 满蓄攻击使用每把武器已有专属战技素材，叠加新的聚能与释放碎光；本次没有生成新的 48 套位图或角色动作。
- 满蓄不占用右键战技冷却。近战 / 法杖耗蓝为基础战技蓝耗的 35%，闯关仍应用普攻耗蓝修正；枪弓不耗蓝。
- 闪避、跳跃、装填、技能、换武器、打开界面或失去战斗状态取消手势。客户端发送可靠按下 / 松开动作，主机计时与结算，不接收客户端自报蓄力强度。
- 蓄力光跟随实际武器挂点；攻击松开时捕获鼠标方向，后续角色动作不拖动已经释放的特效。

验证：`tests/weapon_hold_attack.gd` 覆盖 48 武器 × 两种模式、资源消耗、冷却独立、取消与重复松开（1002 检查）；战斗回归 78 检查、特效释放稳定性 196 检查通过。预览：`build/weapon-hold-preview.png`（聚能中 / 满蓄 / 释放瞬间；远程投射物沿用游戏现有绘制，预览展示释放光）。


## 2026-10-09 独立蓄力素材补齐

48 把武器已配置独立新 ImageGen 透明原图：24 近战、14 飞行弹体、4 光束、6 爆发。左键蓄力不再复用右键战技贴图；charged 标记贯穿主机结算、投射物与特效事件。远征同名武器使用相同的蓄力招式类别，避免齐射/光束类别错配。

630–635、639–647 按用户追加要求使用连续干净轮廓，无细碎鳞片纹理，并关闭这些蓄力动作的碎片粒子；满蓄用光脉冲。其余前批原图保留。614/615/619 地面碎岩加入角色位置的局部遮挡处理。

详细原图与四方向预览：`build/weapon-charged-audit/README.md`。素材/方向 737、手势与资源 1056、释放稳定性 196、战斗回归 78 检查通过。
