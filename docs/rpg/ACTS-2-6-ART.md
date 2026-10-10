# 第二至第六幕：独立区域美术与副本制作

这一版接入五套新区域模块，覆盖五个营地和40个故事/探索区域。保留2D角色、固定俯视相机、连续地表、任务、传送和存档标识。长时间4K跑分仍按用户要求暂缓；截图分辨率不代表已通过4K60性能验收。

直接查看新内容可运行 `Preview-Later-Acts.cmd`，选择2至6幕；临时试玩开放五幕传送阵，进度不保存。正常故事入口继续使用正式存档。命令行也可用 `-- --preview-story --story-act=5 --story-stage=7` 直接进入干船坞。

## 各幕空间身份

| 幕 | 建筑与室外 | 副本空间与新设施 |
|---|---|---|
| 二：白垩城 | 烟砖、机坊、折坡金属屋面、机械钟、工坊烟道；砖砾路肩与维修作业簇 | 偏置作业厅、供料走廊；灰炉铸造厂的炉口、螺旋压机、水轮；地下蓄水机房的双缸泵与阀轮 |
| 三：月晶山地 | 霜松、花岗岩、深檐山屋、守望塔、坡地岩层；雪地和石质通路 | 多边形测星大厅与侧室；观星仪、望远镜、升降架；霜骨祭坛使用独立骨束壁龛与石棺 |
| 四：蔷薇庄园 | 庭园别墅、弧形铁顶、玫瑰窗、修剪树冠、攀枝花架；园地和马赛克铺地 | 长温室、弧形舞台及偏置库房；生长床、玫瑰格架、管风琴；面具藏馆的瓷面具陈列架 |
| 五：潮汐岸线 | 船匠木屋、弧形船梁屋面、缆柱、锚、绞盘；盐沙、潮蚀石和灰木铺地 | 宽阔船体作业槽、两翼船匠室；开放龙骨与曲面船肋；沉锚泵房的独立泵组 |
| 六：王城圣都 | 白石亭阁、飞扶壁、针形尖塔、玫瑰圆窗；碎裂岩层与深色石铺装 | 仪式中轴、八角侧室；圣物华盖、红晶封存匣、供灯壁龛；赤月星仪室的八面晶镜与环形星仪 |

每幕六栋服务建筑另外增加不同轮廓：值守塔、疗养钟楼、锻造烟道、档案高窗、仓库吊架、酒馆上层门廊。屋顶、正面、侧墙分别成组，继承进屋显示与退出迟滞。建筑内部具有床铺、书架、作业台或货箱；营地内部的固定大件进入碰撞数据。

## 新资源与权威源文件

- 新增84个原创建模资源，每幕16个基础模块，另有4个房间专用设施；未使用第一幕房屋、城堡和洞壁网格制作这些主体。
- `art/story-environment/acts-2-6-master.blend` 是新的可编辑权威源文件；第一幕 `opening-master.blend` 保持独立。
- 17套新2K材质，共51张颜色、OpenGL法线、ORM；每幕独立地表、墙面与铺地，木构与金属另有两套新材质。
- 普通灯笼零件、少量辅材、任务/宝箱/角色资源和渲染代码仍共享。不能将“新区域主体”描述成全工程每个资源都全新。
- 资源页、作者、CC0许可、上游校验和、实际文件SHA256记录在 `assets/story/environment/material-sources.json`。资源来自Poly Haven公开资产API，游戏不联网加载。

| 用途 | 第二幕 | 第三幕 | 第四幕 | 第五幕 | 第六幕 |
|---|---|---|---|---|---|
| 地表 | brick_gravel | snow_02 | forest_ground_05 | coast_sand_03 | marble_rock_02 |
| 墙面 | factory_brick | granite_wall | mossy_sandstone | seaworn_sandstone_brick | white_sandstone_blocks_02 |
| 铺地 | herringbone_brick | granite_tile | marble_mosaic_tiles | wood_planks_grey | granite_tile_03 |

木构：oak_wood_planks；金属：metal_plate。许可来源：[Poly Haven](https://polyhaven.com/license)。第三幕主线矿坑使用独立花岗岩表面作为矿床地面，测星站采用建筑铺地。

## 地编、地形与玩法契约

`resources/story-later-acts.json` 保存五幕45区的主题、可编辑多边形房间组合、设施、用途簇和占地。`resources/story-later-terrain.json` 保存15个室外区域的50逻辑单位采样地形。道路附近渐进压低起伏，台阶/台基继续覆盖地表高度，模型地面与角色移动从相同数据读取。

室内多边形组合形成连续外轮廓；地面按外轮廓裁切，墙体沿同一轮廓摆放。室外服务房的下方地面被裁掉，避免建筑内部双层地面；建筑基础与人物高度对齐。小树继续不阻挡。固定设施、岩块和作业道具使用独立占地；任务目标、宝箱和入口周边留通行空间。

墙体按3.10米压顶的实际宽度缩放拼接，转角以独立隅柱覆盖接合；隅柱占地与逻辑阻挡一致，随前景遮挡隐藏，排除固定GI。避免名义3米间距引起压顶重叠。书库、人偶工坊、彩窗工区与灯塔采用各自专用设施；后续增量换设施必须确认LightmapGIData没有引用该节点，否则必须重烘焙，不能直接替换。

额外副本改名但不改ID：

| ID | 第一层 / 第二层 |
|---|---|
| a2_explore_1 / a2_explore_2 | 灰炉铸造厂 / 地下蓄水机房 |
| a3_explore_1 / a3_explore_2 | 废弃测星站 / 霜骨祭坛 |
| a4_explore_1 / a4_explore_2 | 失控温室 / 面具藏馆 |
| a5_explore_1 / a5_explore_2 | 封闭干船坞 / 沉锚泵房 |
| a6_explore_1 / a6_explore_2 | 封印圣物库 / 赤月星仪室 |

73个任务内容、奖励和原地图ID不变。副本继续有战斗、探索宝箱、传送阵和原路返回；炉具、星仪、面具等环境设施目前作为场景叙事道具，未追加独立解谜或新Boss招式。

## 编辑、导出、烘焙

初次作者脚本拒绝覆盖已有源文件。之后编辑 `.blend` 和场景，不要反复执行初始化脚本。独立导出支持指定集合，并保留其他源文件的资源清单：

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.5\blender.exe' --background --factory-startup --python tools/export_story_models.py -- --source=art/story-environment/acts-2-6-master.blend --assets=a3_hero,a3_secondary
```

45个编辑场景为 `scenes/story/act2-0.tscn` 至 `act6-8.tscn`。静态对象生成UV2并烘焙LightmapGI；可隐藏屋顶、正面、侧墙与轮廓墙不作为固定烘焙遮挡体。运行时加载压缩 `.scn`，Compatibility使用对应 `-compat.scn`。区域仍按相机距离加载/释放。不同幕有独立月光、环境光、局部灯色；重点设施增加动态暖光，部分室外地面增加低雾。

```powershell
# 初始化只用于新场景，默认保留现有场景。
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/build_story_scenes.gd -- --act=3 --stages=0,7
& .\tools\Bake-Later-Acts.ps1 -Acts @(2,3,4,5,6) -Stages @(0,1,2,3,4,5,6,7,8)
```

烘焙通过实际编辑器Lightmap工具逐场执行。只确认启动了编辑器不能算烘焙成功；脚本要求每场 `.lmbake` 更新时间改变，并校验全部完成日志。若编辑场景与JSON布局改动不同步，必须重新检查场景摆放ID、占地、轮廓与旧存档入口，不能用一个新JSON掩盖旧缓存。

## 验证与边界

专项 `tests/story_later_acts.gd` 检查新资源、五幕主题、真实分支行走、传送往返、小树、缓存摆放与烘焙资源。GPU模式另检查实际场景模块、30栋建筑进出遮挡，并输出45个3840×2160场景截图。`tests/story_geography.gd` 检查真实任务物体、地图连接、宝箱和上下层入口。网格绕序由 `tools/check_story_meshes.py` 检查。

`tests/story_regional_scene_models.gd` 逐项核对两种缓存的实际model元数据，避免JSON更新而缓存仍显示旧设施。所有导出实例在展平成编辑场景前清除scene_file_path，避免重复继承网格造成双层模型。

最新实际结果见根目录TEST-REPORT，试玩为 `dist/CrimsonTide-ForwardPlus-v5.exe`。本轮不是4K60正式性能验收，也没有完成全部主线新Boss/新解谜制作；商业重制版级别的逐件雕刻、专用动画、完整LOD和长时间性能验收仍属于后续质量工作。
