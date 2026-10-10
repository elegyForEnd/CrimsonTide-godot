# v8 地形边界与连接修复

截图中的黑缝来自可走地形之外缺少连续地表、道路按地图矩形裁切、连接路只有顶面，以及水面与区域偏移不同步。本轮处理六幕19片室外区域和六个营地的可视边界；30个副本空间类型、地图ID、73任务、移动和存档目标保留。

## 几何与通行契约

- `scripts/story_surface_geometry.gd`统一可见陆地、水域、连接路的多边形裁切。部分淹水的网格只裁去真实水域，不再整格删除。
- 道路按实际地形轮廓扣除重叠部分，并保留侧面与下封面；沿用逻辑高度，不做漂浮的单面纸片。
- `BoundaryApron/ContinuousBoundaryGround`补足岩块和崖壁之外的非通行地表。与可走地面共用边界采样高度；相邻区域分配独立的背景范围，并使用统一世界高度，避免同面叠放。
- 背景预算覆盖11—21米正常相机缩放、斜俯视投影和营地的横向偏移。营地已有10米地面余量，新衬底不覆盖它；营地的虚拟外缘不能取代邻接原野的真实边缘高度。
- 水面与岸壁共享水域轮廓，水面保持水平并使用区域世界偏移；岸壁沿地面网格交点分段，关闭沿岸缺口。
- PackedVector2Array赋值会共享数组；道路裁切必须先duplicate，再添加世界偏移，绝不能修改移动轮廓。
- 小树继续没有实体碰撞。背景衬底不新增可走范围或碰撞，不把原有岩壁改成可穿越道路。

## 可编辑场景与烘焙

静态陆地和岸壁变化后，用`tools/Build-Exploration-Scenes.ps1 -OutdoorsOnly`生成19场，再用`tools/Bake-Exploration-Scenes.ps1 -OutdoorsOnly`烘焙。较大的室外网格每场采用独立进程进行UV2展开；authoring_stage和authoring期间的流送隔离保证只捕获指定区域。

仅调整背景或未烘焙水面时，可使用`tools/patch_story_boundary_aprons.gd`。工具检查GI用户，保留人工摆放、静态地面和GI；新增衬底为GI_MODE_DISABLED。保存TSCN/SCN后重跑`tools/pack_compatibility_scenes.gd`。植被继续通过CPU source_transforms安全捕获，不能序列化Dummy渲染器的实例缓冲。

正常流送范围增加到32米，卸载范围44米，保证背景可见时邻区已加载。渲染设置和超分方案保持现有配置。

## 验证与交付

`tests/story_boundary_surfaces.gd`检查真实缓存的边缘顶点、高度、水面位置、地表互斥、连接口覆盖以及移动轮廓不被裁切修改。`--generated`执行真实场景生成；`--packed`覆盖普通和兼容资源；`--photos-only`在3840×2160、正常最大21米视野拍摄六幕十处边缘。

试玩为`dist/CrimsonTide-ForwardPlus-v8.exe`；`Preview-Boundaries.cmd`进入第一幕道路区域，从主路向地图东侧走可检查截图中的连接位置。现有副本、后五幕及兼容启动脚本也指向v8。预览不保存战役进度。

原始截图保存在`build/boundary-<幕>-<区>.png`和`-compat.png`。专项结果、PCK和发布版启动验证见根目录TEST-REPORT.md。没有长时间跑分、帧率/显存达标声明；本轮修复几何接缝，没有完成全部商业级模型、材质与地编精修。
