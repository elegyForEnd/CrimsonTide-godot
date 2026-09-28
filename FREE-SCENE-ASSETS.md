# 免费场景资产接入 · 2026-09-25

地图已使用下载的真实 3D 模型替换主要几何占位：城堡、教堂、矿场、集市、高塔、断墙、拱门、桥面、灯笼、植被、祭坛与宝箱。保持 3D 地图 + 原有 2D 二次元人物。免费模型原生属于风格化低多边形奇幻美术；游戏侧加入冷灰石色、暗红屋顶、蔷薇树冠及柔化分段光照，以配合哥特二次元主题。

## 来源与许可

| 素材包 | 本地模型数 | 用途 | 原作者页面 | 许可 |
| --- | ---: | --- | --- | --- |
| KayKit Dungeon Remastered 1.0 | 18 | 墙、桥面、旗帜、宝箱、室内道具 | https://kaylousberg.itch.io/kaykit-dungeon-remastered | CC0 |
| KayKit Halloween Bits | 8 | 石拱、祭坛、灯笼、枯树、墓碑 | https://kaylousberg.itch.io/halloween-bits | CC0 |
| KayKit Medieval Hexagon | 12 | 城堡、教堂、市场、塔、矿场、岩石、水草 | https://kaylousberg.itch.io/kaykit-medieval-hexagon | CC0 |
| Quaternius Ultimate Stylized Nature | 2 | 有树干、分枝和透明叶片的树木 | https://quaternius.com/packs/ultimatestylizednature.html | CC0 |

共保存 40 个模型，部分作为备选，不是全部都布置在当前地图。CC0 允许个人及商业项目使用、修改，无强制署名要求；项目保留作者和许可证。未下载付费 EXTRA / SOURCE 内容。

KayKit 来自作者公开的 `KayKit-Game-Assets` GitHub 仓库。注意官网下载页已更新到 Dungeon Pack 1.1，本项目固定使用作者仓库中的 Dungeon Remastered 1.0，不宣称是最新包。

Quaternius 的 CC0 许可在原作者页面核实；FBX 和贴图从 `walterpalladino/godot-quaternius-ultimate-stylized-nature` 公开镜像取得，只取模型和贴图，没有执行镜像内的脚本。镜像自己的 MIT LICENSE 另存为 `MIRROR-LICENSE.txt`，不将其冒充原模型许可。

本地许可证、固定提交、原始地址及哈希在 `assets/vendor/kaykit/` 和 `assets/vendor/quaternius/`。下载工具为 `tools/fetch_scene_assets.py`、`tools/fetch_nature_assets.py`；网络恢复下载需要 GitHub CLI，树木贴图压缩另需 Pillow。运行游戏本身不联网下载素材。

## 接入细节

- `scripts/scene_assets.gd` 复用导入模型与材质，保留原始 UV。GLTF 的外部贴图路径改为项目内相对路径；树木贴图压缩至不超过 1024 像素。
- 树木 FBX 自带了额外的 X 轴 90° 节点旋转，而顶点本身已经 Y 向上。实例先用包装节点取消该旋转，再计算包围盒、缩放与落地，不能只靠缩放处理。
- `scripts/scene_asset_layout.gd` 共享建筑占地，`Ruins.blocked()` 和显示层使用相同矩形。道路、据点中心、封印和撤离点保持可达。树木、灯笼等小装饰继续使用原有非阻挡规则。
- 宝箱使用原模型的铰链节点开盖；普通、高档和已搜空状态不同。材质变体缓存避免每帧重复创建。
- 保留原有河湖轮廓、贴图地面和与碰撞一致的岩台基座，岩台上补入岩石模型。这里没有宣称水体和整个地形都已替换为外部模型。
- 原来的二维全图贴图仍用于战术地图，尚未重烘焙新建筑轮廓。`dist` 旧发布包没有重新导出，使用根目录 `源码版启动.cmd` 查看当前效果。

## 验证

`tools/check_scene_assets.ps1` 检查结果：

- 模型、贴图、落地、树干轴向、宝箱铰链、建筑占地：174 项通过。
- 2.5D 显示、投影、地图重建与回收：32 项通过。
- 三种子地图通路：204 项通过。
- 移动与动作帧：107 项通过。
- 系统：10812 项通过。
- 实际 OpenGL 渲染：八个据点、桥梁、三种宝箱状态与王庭截图；深度遮挡回归通过。

截图：`build/asset-region-*.png`、`build/asset-bridge.png`、`build/asset-chests.png`、`build/asset-city.png`。日志为 `build/check-*.log`。主菜单既有音频缺失问题见 `MAP-2-5D.md`；本次图形测试使用战场场景，不将其算作完整主菜单启动验证。
