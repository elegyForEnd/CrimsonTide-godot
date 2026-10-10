# 开场样板与 Forward+ 场景生产流程

目标平台为本机 RTX 3080 Ti 12GB、i5-13600KF、约64GB内存，3840×2160输出60帧，允许超分。保留现有2D人物、固定俯视相机、任务编号和战役存档。

## 实际运行与画质

最新独立试玩为 `dist/CrimsonTide-ForwardPlus-v2.exe`，营地选择故事模式；旧版试玩保留。独立包兼容入口为同目录Start-Compatibility.cmd。

源码默认 Forward+ / Vulkan；设置→画面设置提供高画质、标准、兼容三档和FSR2、FSR1、原生分辨率。默认FSR2的3D内部比例0.67，界面按输出分辨率绘制。兼容渲染需重启，独立入口为根目录 `Start-Compatibility.cmd`。切图或大距离传送时重置时间超分历史。

兼容模式加载单独的-compat.scn缓存，移除不支持的体积雾资源，并使用无实例参数的材质；保留同一套地图、模型、PBR及烘焙光照，遮挡采用整组隐藏。

高画质使用ACES固定曝光、月光实时阴影、局部暖光、适量SSAO、ReflectionProbe、SSR和局部地面体积雾。标准档关闭SSR与体积雾；烘焙间接光与主要材质保留。SDFGI未作为正式默认。

雷霆要塞、风铃原野与落叶洞窟有实际LightmapGI资源、EXR纹理及可编辑场景。屋顶/正面与植被不作为固定烘焙遮挡，摄像机裁切不留下屋顶暗影。水面使用不透明浅水材质，因此可参与SSR；透明人物和特效不以SSR作为正确反射的保证。

## 模型与材质资产

- 80个原创GLB：六类服务建筑、自然基础资产、21组完整/破损结构模块、13类生活/自然模块及12类室内家具。瞭望塔、钟楼尖顶、锻炉烟道、档案塔、仓库斜棚和酒馆廊台区分服务建筑。
- 两个经过归一化、减面和合批的CC0植被模型：Poly Haven树木和蕨类。树木按树干、枝条、叶片分别保留轮廓，约14.3万三角，蕨类6232三角；地表植被按16米空间网格分组MultiMesh，避免整图一批全部提交。布局中的树木读取当前GLB，因此继续编辑master后不会停留在旧缓存网格。
- 十套2K PBR材质，共30张颜色、OpenGL法线、ORM贴图；ORM为R遮蔽/G粗糙度/B金属。岩石、树皮、铁件和布料使用独立贴图。
- 门洞维持既有可走尺寸；导出检查闭合部件面朝向，开放叶片单独做实机检查。损坏拱门和屋面实际移除结构件，未用纹理代替轮廓破损。

材质来自 [Poly Haven CC0库](https://polyhaven.com/license)。植被来源为 [tree_small_02](https://polyhaven.com/a/tree_small_02) 与 [fern_02](https://polyhaven.com/a/fern_02)；作者、许可、下载地址、MD5及SHA256分别保存在material-sources.json和vegetation-sources.json。项目不读取参考游戏的美术资源。

## 可编辑源文件与再制作

1. `art/story-environment/opening-master.blend` 是当前模型权威源文件，带真实材质。修改模型后运行 `tools/export_story_models.py`；它只导出带ct_asset标记的集合，不重新生成或保存master。原始原型生成器和一次性作者工具均保留，不能用于覆盖后续人工修改。
2. `art/story-environment/opening-terrain.blend` 保存三个地形网格。仅编辑顶点高度，保持XY与拓扑；运行 `tools/export_story_terrain.py` 导出逻辑高度与岸线数据。地面和行走判定都读取相同数据，楼梯/平台覆盖明确。
3. `scenes/story/opening-0.tscn`、`opening-1.tscn`、`opening-7.tscn` 是可继续编辑的地编场景。运行 `tools/Bake-Opening.ps1` 实际调用Godot编辑器烘焙，并输出压缩SCN运行缓存。手工调整场景后重新烘焙。
4. `tools/build_story_scenes.gd` 仅用于建立初始场景，默认保留已有文件。`--replace-generated`会覆盖这些地编文件，只适合有备份的重新生成；不属于日常导出流程。其余第一幕野外有预生成场景缓存，用于消除行走中的程序建图卡顿，并不代表都已达到样板美术精度。

模型导出支持 `-- --assets=service_0,ward_cot`，只更新指定集合，并合并其清单，其他模型文件不重写。新增家具已保存于master；`author_story_interiors.py`和`refine_story_sidewalls.py`为带修订保护的一次性作者工具，不能用于覆盖以后编辑。

`resources/story-opening-dressing.json`保存44处开场补充摆放，其中18处室内家具同时声明移动占地。`story_set_dressing.gd`将建筑局部偏移转换为区域坐标，逻辑和场景读取同一数据。若移动带碰撞的家具，必须同步这份数据，再更新场景与烘焙。`patch_story_workplaces.gd`只追加补充组，保护已有地形和摆放；`--refresh-buildings`仅刷新营地六栋建筑模型，保留根变换。当前人工场景已有补充组，默认再次执行会保留它。

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.5\blender.exe' --background --python tools/export_story_models.py
& 'C:\Program Files\Blender Foundation\Blender 4.5\blender.exe' --background --python tools/export_story_terrain.py
& .\Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --import
& .\tools\Bake-Opening.ps1
```

ImageGen建筑参考与完整提示词保存在REFERENCE.md；参考图用于方向，不等同于游戏截图。

## 地编、人物与兼容

营地服务区位置错开；中央道路及工作场所保留石板，周边改为泥地、台基与排水边缘。原野包含曲岸河沟、坡地、路旁残柱、损坏推车、工具与树根。洞窟有岩壁、支架、弃置工具、货物与浅积水。

屋顶约0.25秒抖动淡出，门口有迟滞；进入判断跟随人物。前景按投影遮挡逐个处理。人物保持原画，用有限环境染色与暖光融合；脚底和接触阴影使用地形高度，阴影方向随坡度调整。4K宽屏调整视口比例并修正故事鼠标投影。

六栋营地建筑内部分别布置地图桌与武器架、病床与药柜、炉具与风箱、阅览台与卷轴、货架与箱桶、吧台与餐桌。相机方向的侧墙独立为Side组，随屋顶和正面淡出，地板、后墙和另一侧墙保留。淡出处理包含MeshInstance3D根节点，避免只修改子节点造成屋顶突然消失。Side/Front/Roof均排除固定烘焙遮挡。营地建筑脚底使用6厘米基础顶面高度；家具避让门口与中央通道。

南门增加运输物资，原野增加弃置工具与洞口货物，洞内增加岩层、断梁、绳索、货架和灯具。小树不阻挡的规则保留。烘焙脚本禁止同时运行两套烘焙，编辑器插件检查烘焙文件确实更新后才报告成功。

逻辑地图不随视野卸载，任务、宝箱、敌人状态和传送标识保持。渲染区域预加载，远处视觉节点卸载，返回时从压缩缓存恢复。

地形与楼梯/平台不同时绘制顶面：按矩形精确裁去结构占用区域，保留基础地形高度；营地外延和区域连接面也做互斥裁切，消除同高重叠导致的闪烁。450逻辑单位（4.5米）及以下的装饰树、细枯树不生成移动阻挡；大型树木及其他结构物仍按原规则处理。

## 验收记录与范围

正式性能结果、加载时间、显存及全模式回归记在TEST-REPORT；原始数据由 `tests/story_4k_benchmark.gd` 和 `tools/monitor_story_gpu.py` 输出。基线快照在build/environment-baseline-20261010.zip，旧试玩保留。

当前是开场样板与生产流程升级。六幕均使用新渲染器，但第二至第六幕尚未逐幕重做资产与构图。后续扩展应复用模块、材质规格及灯光方式，仍需按各幕环境独立制作与验收；不能以渲染器切换作为整部游戏达到商业重制精度的证明。
