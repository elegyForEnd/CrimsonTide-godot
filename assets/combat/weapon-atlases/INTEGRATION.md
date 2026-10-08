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
