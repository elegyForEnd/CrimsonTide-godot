# 开场环境精修 · 2026-10-10

本文记录最初13模型／1K材质迭代。当前已升级到Forward+、68原创模块与两套CC0植被、十套2K材质、实际GI烘焙和可编辑地编；以 [新的生产流程](FORWARDPLUS-ART-PIPELINE.md) 与TEST-REPORT为准，下文旧版本边界不代表当前实现。

本轮落实“参考图 → Blender模型 → 共享PBR材质 → 游戏内摆放 → 实机检查”的流程。重点为雷霆要塞、南门、风铃原野与落叶洞窟，保持3D场景和现有2D人物。

## 当前可玩版本

运行 `dist/CrimsonTide-Story-Polished.exe`，标题选择故事模式。源码入口同样可用。旧故事EXE保留，旧文件不会随代码自动更新。

## 实际交付

- 13个原创GLB：六类服务建筑、南门、城墙、洞口、树木、岩石、碎石、草簇。建筑分别包含可隐藏的Front和Roof，保留1.10米门洞与原碰撞。
- 营地建筑区分为城垛值守所、铃塔疗养所、烟囱锻造坊、尖顶档案室、木构仓库与挂招牌的酒馆；内部工作台、账册、炉火和货物一起制作在模型中。
- 实际可编辑的Blender 4.5源文件 `art/story-environment/thunder-bastion-kit.blend`，附带ImageGen参考图；源文件不打包到游戏。重复执行建模脚本可重新导出。
- 五套Poly Haven的1024尺寸CC0材质，带色彩、OpenGL法线和ORM（R遮蔽/G粗糙度/B金属）。来源、作者、MD5、SHA256与大小保存在 `assets/story/environment/material-sources.json`。
- 第一幕地面混合石板路与林地，建筑使用石墙、旧木和灰蓝瓦面；寒色环境光与暖色灯火分离。落叶洞窟周边改为岩壁与木支撑。
- 首图路旁残柱和木栏纳入story_region碰撞；草簇使用MultiMesh批量显示；模型和材质实例共享。2D人物、NPC与敌人有脚下接触阴影池。

## 素材来源与再制作

材质来自[Poly Haven CC0库](https://polyhaven.com/license)：[石板路](https://polyhaven.com/a/cobblestone_floor_08)、[林地](https://polyhaven.com/a/forest_ground_04)、[旧石墙](https://polyhaven.com/a/old_stone_wall_02)、[木板](https://polyhaven.com/a/weathered_brown_planks)、[瓦面](https://polyhaven.com/a/roof_slates_02)。本地下载工具遵守API User-Agent要求，游戏不依赖网络。

```powershell
python tools/fetch_story_pbr.py
& 'C:\Program Files\Blender Foundation\Blender 4.5\blender.exe' --background --factory-startup --python tools/build_story_models.py
python tools/check_story_meshes.py
& .\Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import
```

参考图与完整提示词见 `art/story-environment/REFERENCE.md`。参考用于建筑轮廓、材质配色和灯火组织，并未自动转换为相同画质的3D场景。

## 已修正的模型缺面问题

第一版导出时将游戏深度映射到Blender负Y轴，反射了坐标但遗漏面绕序，导致背面剔除后岩石和洞口像只剩一半。已反转绕序，并逐个凸部件校正外向法线；单面瓦片/叶片保留开口面规则。

`check_story_meshes.py`直接读取导出的GLB，焊接UV分离顶点，识别闭合连通部件并检查正的有向体积。1,153个闭合部件外向通过。开放屋面和叶片不属于闭合体，仍需实机目视检查。不会以全部关闭背面剔除掩盖错误。

## 验证与边界

专项检查见TEST-REPORT。实际画面在 `build/story-polished-*.png`，包括营地、进屋、南向穿门、首图、洞口与洞窟。新视觉用例逐栋检查全部屋顶/正面绑定与隐藏恢复，实际模拟穿过南门并通过E入口进入第7区；素材法线检查独立于视觉测试退出码。

本轮是可玩的开场美术迭代，尚未达到参考图或商业重制作品的精度。其余幕营地仍使用原程序建筑，第一幕后续野外房屋也未全部重做；外观仍需更多手工造型、构图、破损变体和地表细节。洞窟的可走区域继续使用原房间连通布局；屋顶和前景仍为直接隐藏，尚未加入柔和遮挡过渡。渲染保持Compatibility，未切换全工程渲染器，也未启用体积雾、烘焙GI或SSR。没有把参考游戏的美术文件导入本项目。
