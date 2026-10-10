# v9 实地外景、南门河道与道路衔接

地图外侧采用真实坡地和装饰，南门两块地图之间以河道和跨河桥分隔。连接应有场景用途与材质过渡，不能以大面积空地板或一整块石板贴片代替地编。

## 制作范围

- 六幕19片室外和六营地新增`DressedExteriorLandscape`：地表起伏、树/岩/植被组合。装饰保留在非通行区域，河岸另布置碎石和草簇；原有可走区域、任务、宝箱、传送与小树非实体规则保持。
- `scripts/story_exterior_composition.gd`从实际边缘取高度，外侧生成坡肩、沟洼与背景丘陵；相邻场景分配独立范围，使用共同世界高度，消除同面叠放。新景观不会覆盖原地面和连接道路，不能变成新增可走区域。
- 第一幕南门外加入曲折河道，浅沟和河岸从地面缓降，水面水平；营地与原野的背景各承担其河岸，水在桥下连续。桥有两侧矮栏、石柱、桥台和桥体侧面，原连接通行宽度保留。
- `resources/story_connection.gdshader`采用两端的PBR材质，按长度过渡。路心与路肩分别处理，跨河段保留桥面石板，落地后过渡为原野泥路；其他连接采用各自地区材质。
- 六营地原有向外扩张10米的静态地面裁回营地包络并完成六场GI重烘；新的有装饰外景补足实际视觉范围。室外静态地面/GI和人工道具保留。

## 生产与数据契约

`tools/patch_story_exterior_landscape.gd`更新25场的非通行外景，检查它没有静态GI用户；保留静态地面、建筑与原有GI。GLB装饰必须先清除scene_file_path再赋场景owner，避免保存时重复实例化子节点。脚本只替换自身生成的外景分组；旧命令patch_story_boundary_aprons现在指向此工具。

完整源码生成由story_environment.terrain调用同一套制作函数。地面变更时才重烘；本轮六营地使用`tools/Bake-Exploration-Scenes.ps1 -CampsOnly`。烘焙编辑器保存之前调用植被prepare_capture，将CPU source_transforms作为权威数据，不保存实时MultiMesh缓冲。

`tools/pack_story_boundary_scenes.gd`可在烘焙后规范化25场植被缓存，保留GI。之后运行pack_compatibility_scenes。地图多边形做世界平移前先duplicate，不能由渲染裁切改动通行轮廓。

背景材质不套用营地石板覆盖设置。Forward+和GL保持暗色远景背景，避免尚未加载的远处空间出现浅蓝色清屏。正常流送32米预载/44米卸载保持，长时间性能验收仍暂缓。

## 验证与试玩

`tests/story_boundary_surfaces.gd -- --packed`检查实际地表接缝、水面位置、背景起伏、装饰在非通行区及GI；`--generated`执行六幕出口实际移动，检查连接材质、路肩和南门桥体；`--photos-only`包含南门、原野入口、其他连接、桥梁与六幕代表边界。

实机照片为1920×1080、正常15米视野，两种渲染器各12张：build/landscape-<act>-<stage>.png与-compat.png。具体日志及剩余质量边界见TEST-REPORT.md。不是概念图或跑分报告。

最新版`dist/CrimsonTide-ForwardPlus-v9.exe`。`Preview-Boundaries.cmd`从第一幕营地开始，沿南门向下走检查河道/桥/原野入口；预览不保存进度。副本、后五幕预览及兼容入口同步指向v9。

本轮复用现有原创模型和既有许可植被，没有新增商业级雕刻模型。南门完成河道分隔，其余区域完成外侧坡地与装饰，仍可继续按各地用途精修；未宣称全部美术达到商业重制品质或4K60。
