# 绯月 3 渲 2：免费动作适配版
> 2026-09-30：按用户要求，游戏已切回此前精灵图版本。此目录、3D 渲染帧及实验版 EXE 均保留。当前可玩版本是 ../../dist/CrimsonTide.exe；下文为保留的 3D 实验记录。
## 使用入口
- 游戏：../../dist/CrimsonTide-feiyue-3d.exe。运行后选择绯月，进入营地或出征。
- 可编辑主文件：feiyue-character.blend，使用 Blender 5.2 LTS 的 EEVEE。
- 动画预览：feiyue-animation-preview.gif；逐帧检查：animation-review.png。
- 游戏资源：../../assets/combat/feiyue-3d/，10 个动作、80 张 384 × 384 透明 PNG。
原始 feiyue.glb 保留原样。feiyue-toon-preview.blend 是早期材质试验，当前工作以 feiyue-character.blend 为准。
旧版程序生成动作的主文件另存为 feiyue-procedural-backup.blend。
## 免费动作来源与适配
当前 10 段动作以 KayKit Character Animations 1.1 免费版为基础，已核对随包 License.txt 的 CC0 1.0 许可。免费 FBX/GLB 可以导入 Blender 修改，不需要购买 .blend 源文件。
- 官方来源：https://kaylousberg.itch.io/kaykit-character-animations
- idle：Idle_A；walk：Walking_A；run：Running_A；dodge：Dodge_Forward。
- sword：Melee_1H_Attack_Chop；heavy：Melee_2H_Attack_Chop；staff：Ranged_Magic_Shoot。
- idle_sword / idle_staff：对应攻击的准备姿态加呼吸；idle_heavy：Melee_2H_Idle。
- 将源骨骼的 chest/wrist 等映射到绯月骨骼，处理源 T 姿势与目标 A 姿势的差异。使用目标骨骼长度，修正手臂、腕部与武器朝向；重剑握点限制在双臂共同可达范围，双手沿同一握柄定位。
- 剑攻击重新采样，将挥砍帧对齐游戏索引 4；保持脚底接触、固定镜头、统一缩放。游戏控制角色位移，渲染帧不复制素材的水平根位移。
- 头发/裙摆、握持形态键和攻击张嘴作为目标角色的补充动作，和素材动作一起烘焙。
- 实际使用的素材名称及 CC0 许可随渲染规格、游戏 manifest 和 Blender Action 一并保存。
其他下载的 Quaternius 免费包保存在 motion-sources，供后续连击扩展；本版尚未接入这些连击。
## 已完成
- 将 glTF 接缝处的重复顶点焊接（204644 个），保留 UV；约 149 万面降到 59998 三角面、29579 顶点，身体和呆毛两个连通部分。
- 清理表面、平滑法线；双档明暗卡通材质，去除原始 PBR 金属高光和法线噪声，贴图内嵌。
- 23 根控制/变形骨骼；身体、四肢、头发、裙摆权重；双手握持修正形态键，驱动值包含在骨骼动作中。
- 直刃剑、重剑和青色晶石法杖独立建模并控制；重剑双手求解。
- 攻击命中和随后的帧张嘴，表现短促发力；没有新增语音。
- 10 段免费素材适配动作：无武器待机、走、跑、闪避、剑/重剑/法杖攻击，及三种持武器待机。每段 8 张渲染帧。
- 固定正交相机、画布和地面原点，统一缩放，图像不按单帧轮廓重新居中。
- 游戏战斗与营地使用新模型渲染帧；四帧运动相位转换为八帧，保持原循环速度；攻击索引 4 对齐游戏命中时刻。
- 发布清单包含新 manifest；Windows 可执行文件已构建。
## 在 Blender 修改
选中 Feiyue_Rig，在 Action Editor 切换 Feiyue_* 动作。各动作的 NLA 轨道默认静音，避免叠加。武器显隐、嘴部显隐以及握持属性都随骨骼 Action 保存，无需另外切换对象动画。
24 FPS 下建议播放范围：
- idle / idle_sword / idle_heavy / idle_staff：1–49
- walk：1–25；run：1–17；dodge：1–8
- sword / staff：1–22；heavy：1–29
材质依赖 EEVEE Shader to RGB。当前游戏接入的是其渲染结果，主 .blend 的自定义节点不自动成为 Godot 的同款实时材质。
## 重现命令
在项目根目录使用 Blender --background --factory-startup --python：
1. tools/prepare_feiyue_mesh.py（依赖先前静态材质试验文件）
2. tools/build_feiyue_character.py（旧版程序动画基础；已有 feiyue-procedural-backup.blend 时可跳过）
3. tools/retarget_feiyue_motions.py（免费素材动作适配、完整烘焙和 80 帧渲染；-- --preview 只输出到 motion-preview，不安装）
4. Python tools/install_feiyue_3d.py
5. Godot --headless --editor --path . --import
6. Godot --headless --path . --export-release "Windows Desktop" "dist/CrimsonTide-feiyue-3d.exe"
tools/verify_feiyue_blend.py 可重新打开主文件，通过保存的 Action 独立重渲染，验证无需构建脚本也能播放。
免费素材版重新打开主文件检查了全部 80 个姿态：脚底高度误差小于 0.001，武器/嘴部显隐正确；重剑左掌偏离握柄轴线的最大距离约 0.00000023（模型单位）。各活动动作有非零骨骼变化。检查结果保存在 inspection/saved-motion-audit.json。
## 验证记录
- 80 张图片的透明背景、非空轮廓与画布安全边距通过。
- tests/character_scale.gd：439 检查，0 失败。
- tests/generated_attacks.gd：689 检查，0 失败。
- tests/feiyue_3d.gd：236 检查，0 失败。
- tests/camp.gd：73 检查，0 失败。
- tests/feiyue_packed.gd：成功挂载最新 EXE 内嵌资源包，确认 10 段动作的 CC0 来源元数据，加载全部 80 张角色图。
- tests/feiyue_3d_visual.gd：在实际游戏截取待机、三类攻击、跑步、闪避，输出 build/feiyue-3d-*.png。该次完整主场景加载还报告原项目中墓煜的四个缺失音频导入缓存，不属于本次新增资源。
- 保存的 Blender Action 可独立播放并渲染，不依赖已移除的素材骨骼。独立重渲染的 idle 0 / sword 4 / heavy 3 / walk 2 与本次构建图像逐像素一致。
## 首版边界
网格基于生成模型的减面与权重修整，没有制作手工四边面重拓扑；角色和武器为基本款。大幅改造体型、夸张动作或高分辨率近景时，应继续检查袖口、发丝接触处与手部。当前完成的是现有游戏动作和显示流程的可玩首版。

