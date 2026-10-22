# 武器 VFX：参考设计与引擎实现

2026-10-20。早期批量实现未通过用户的视觉验收，不能把覆盖数量和测试通过当成美术完成。经两把样例和单手剑晶刃试作后，用户授权把「生成参考图里的特效部分」与动态特效结合，并继续制作其他武器。当前制作范围为 52 个视觉身份、69 个入口的普攻、重击和战技；当前录制状态以 `build/vfx-hybrid/coverage.json` 为准。

## 当前混合制作路径

- `weapon_hybrid_design.gd`：大幅加宽的彩色刀面，三种动作的加速、形状、分叉、落地和命中停顿。熔炉锤也接入火焰、熔渣和烟尘素材，保留单手剑晶刃专用路径。
- `weapon_hybrid_material.gd`：15 种彩色材质与 52 把武器独立的展开素材共同采样。新增 14 张材质、4 张独立命中素材的完整提示词和原文件记录在 `assets/combat/weapon-hybrid-v7/generation.json`；镜面材质复用已有晶刃素材。
- `weapon_projectile_vfx_3d.gd`：独立彩色弹体贴图放在真实世界网格上，读取实际弹道；只显示一份弹头，不叠加备用模型或白球。扩大连续尾迹，火、冰和魂系附加独立雾尾。
- `weapon_hybrid_smoke.gdshader`：复用已有烟尘密度图；枪口短烟、地面尘层、冷雾与魂纱分开控制。命中烟雾晚于主闪光淡出。
- `weapon_vfx_composite.gdshader`：修复透明 3D 视口叠到闯关地图时二次乘 alpha 的问题。GPU 控制场景中，输入红色 `.498`、alpha `.498`，旧合成输出红色 `.247`，修复后输出 `.498`；`tests/weapon_vfx_compositing.gd` 防止回归。

伤害、范围、弹数和碰撞仍由原战斗逻辑决定。命中只响应真实正伤害；爆发、碎片、拖尾和烟尘独立清理。早期过淡录像不算当前验收结果。

`tools/record_weapon_hybrid_battle.gd` 录制每把武器三种招式和真实木灵接触，记录命中次数、伤害、录制版本。录制器为每段补充合法弹药并隔离桌面失焦产生的取消输入；正式游戏的失焦取消仍保留。`tools/build_weapon_hybrid_gallery.py` 默认要求当前版本 52 把、156 段正伤害录像和 52 份检查图齐全，才生成完整对照页。`--allow-incomplete` 仅用于制作中查看进度。

## 样例阶段记录

### 单招晶刃试作

用户提供新的粉色晶刃战斗参考后，仅为身份 600 的战技（及同身份剧情入口）试作新路径：`weapon_crystal_cut.gd`。普攻、重击与巨锤仍走原样例。此试作不代表其他武器验收。

双条开放三次曲线在真实命中时汇向事件给定的目标位置，命中事件独立产生不等大的晶片。空挥不产生目标爆裂。用户随后明确选择将「生成参考图里的特效部分」作为贴图与自制特效混合，因此本招改用 `assets/combat/crystal-cut-v1/` 两份透明派生素材（内置 imagegen 重新制作，非逐像素抠图）。`weapon_crystal_painted.gdshader` 在弯曲刀面和独立晶片上采样这些素材；引擎保留轨迹、命中、停顿和飞散。原完整参考图仍不进入运行材质。派生素材的完整提示词记录在对应目录的 `generation.json`，旧版原生切面录像保存在对照页。

闯关地面为绘制背景，在人物层下用 `weapon_crystal_ground.gd` 与柔光材质绘制短暂反光；有原生 3D 光照的场景使用现有灯池的粉色脉冲。这是二维地图上的反光近似，不宣称真实物理反射或逐肢体遮挡。

针对「偏淡」反馈，仅增强此招的贴图覆盖度、色彩、主刀面厚度和命中短促辉光。低 alpha 噪点先衰减，避免增密后把原透明边缘变成方框；暗反射面保持可见。时序、命中范围和伤害不变。对照页 `before-density.mp4` 保留加实前的贴图混合版本。

`tools/record_weapon_design_battle.gd -- --crystal` 只录此战技，使用真实苔冠木灵目标、真实伤害和命中事件，60 fps。`tools/build_crystal_cut_review.py` 生成 `build/vfx-crystal/index.html`，保留用户原图、无修饰截图与实机录像。放大版本仅裁切同一录像，不能当作另一套实机输出。`tests/weapon_crystal_cut.gd` 检查实际目标汇聚、四向瞄准、空挥与收尾；视觉质量仍需直接对照，不能由这些测试判定。

力量感调整：两把样例缩短出刀和拖尾，巨锤的爆发对齐释放时的伤害判定。只有真实正伤害命中才暂停对应攻击者的已发出刀面（剑 40–60 ms，锤 55–80 ms）；目标切口继续播放，多目标不叠加停顿。闯关新增短促定向镜头冲击、目标压缩与回弹；镜头跟随使用不带冲击的基准位置，避免将震动累积进相机移动。保留现有伤害、判定范围、击退与音效。

- `scripts/weapon_sample_design.gd`：两把武器专用的刀面、血丝、锤击、碎岩、裂缝、热烟与尘层；`weapon_release_vfx_3d.gd` 仅在对应视觉身份上选择该模块。
- `resources/weapon_sample_surface.gdshader`：专用血液折光、岩石细节、熔火与热烟；不采样参考图。
- `tools/review_weapon_samples.gd`：固定相机尺度的三动作近景。
- `tools/build_weapon_sample_review.py`：只编码两把武器的六段真实命中录像，生成 `build/vfx-samples/index.html`。录像由原战斗场景和原人物动画产生。

原图与实机仍有造型及绘画质感差别，当前状态是供用户判断的两把样例，不宣称与参考图完全一致或其余武器已完成。

## 参考的用途

`art/weapon-vfx-reference-v6/` 保存 52 个武器的美术参考：十张早期动作设计板和 42 张完整场景图。参考目录有 `.gdignore`，不导入、不作为释放贴片、弹体或烟雾素材。早期设计板下方的裁片只保留为历史记录。

图片由内置 ImageGen 生成。`generation-records.json` 记录原图位置、SHA-256、用途和已留存的提示词；52 份参考均与生成器保存的原文件哈希匹配。最初两张试稿的完整提示词没有留存，对应方向保存在 `briefs.json`，没有补写假记录。

本轮误接入的参考裁片运行代码已经移除。原有武器、角色和其他美术资源保留。

## 实际制作

- `scripts/weapon_motion_design.gd`：近战逐把曲线与切面，三段普攻、蓄力重击、战技的运动区别，刀口与内部薄膜，落地与碎散。曲线在事件触发时采样，释放后不跟随下一帧人物或鼠标。
- `resources/weapon_sculpted_material.gdshader`：血膜、薄水、金属、冰面、雷光、石层、火、魂衣、虚涡、镜片、丝帛等材质。使用程序化纤维、折面、细脉、泡沫和侵蚀，没有参考图采样器。
- `scripts/weapon_projectile_design.gd`：实体弹芯、箭杆与尾羽、倒钩、冰针、陨石、月片、燃羽、折页和魂衣等原生几何。保留真实弹道中心；弹数由战斗逻辑决定。
- `scripts/weapon_projectile_vfx_3d.gd`：真实弹道历史、连续尾迹、销毁后的收尾与预算。移除了参考图贴片和叠加的通用白芯。
- `scripts/weapon_combat_vfx_3d.gd`：普通斩击读取出刀挂点，枪口和杖头读取实际端点。命中读取目标位置，落点法术读取实际目标坐标。

重锤先下落，再产生有立体面的深色碎石和低矮尘浪；熔渣只出现在局部接缝。细剑突刺遵循窄轴，不把弧形斩击横向拉长。周身斩保留先后与缺口。法术爆发区分外碎、内塌、放电、契页和魂帛；光束保持瞬时贯通，并以晶尘、月片或折射面区分身份。

人物继续使用项目原动画。VFX 不新增命中、伤害、弹数或持续危险区域；未命中不播放目标命中爆发。

## 审查产物

- `build/vfx-v6/index.html`：52 个身份的参考与引擎输出，支持名称和编号筛选。
- `build/vfx-v6/weapon-<编号>.png`：每把武器三种动作、四个时刻的真实 GPU 输出。
- `build/vfx-v6/battle/`：五类样板各三段闯关录制，使用真实敌人、伤害与弹道碰撞。
- `build/vfx-v6/battle-capture.json`：15 段录制的真实命中次数与伤害，所有片段均产生合法命中。
- `build/vfx-v6/sample-600.mp4`：绯红单手剑普攻、重击、战技的连续实机样片。

审查图不等于最终美术质量评分。重点检查武器衔接、切面层次、运动连续性、命中时机和收尾；游戏内仍应以实际镜头和场景表现为准。

## 复现

```powershell
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/weapon_vfx_designs.gd
.\Godot_v4.7.2-stable_win64_console.exe --path . --rendering-method gl_compatibility --script tests/weapon_action_vfx_visual.gd
.\Godot_v4.7.2-stable_win64_console.exe --path . --rendering-method gl_compatibility --script tools/review_weapon_vfx_v6.gd -- --all
.\Godot_v4.7.2-stable_win64_console.exe --path . --rendering-method gl_compatibility --script tools/record_weapon_design_battle.gd
python tools/encode_weapon_design_battle.py
python tools/audit_weapon_design_references.py
python tools/build_weapon_vfx_v6_gallery.py
```

行为回归包括事件不变、挂点投影、释放锁定、全身份覆盖、三类动作、蓄力与中断、真实命中、弹道位置及清理。GPU 回归包括主体可见性、材质与几何独立、墙体遮挡、时间演变、取消后像素清理和并发预算。闯关与剧情使用实际战斗入口验证。
