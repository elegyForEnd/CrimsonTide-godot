# 建筑室内铺地修正

此前`story_environment.terrain()`把建筑室内也交给`physical_ground()`，继续混合林地泥土与户外鹅卵石道路。城堡只用顶点颜色把大厅的道路比例提高，墓室没有专属材质，台基还用了墙面石材。这是v3的遗漏，建筑室内没有完成地面材质分流。

v4由`story_floor_palette.gd`统一选择建筑铺地，使用独立的`story_interior_floor.gdshader`，完全不采样野外soil、mud、paving，也不以道路顶点色决定室内铺装。按实际区域布局选择：

| 场所 | 地面 | 分区 |
|---|---|---|
| 城堡与普通大厅 | 磨损石板 | 城堡中央礼仪带与升高领主厅用铺砖 |
| 墓室 | 独立暗色磨损石板 | 保留低强度潮湿与磨损，适量环境光保持通路可读 |
| 礼拜堂/大教堂 | 修院石铺地 | 中央礼仪带用独立铺砖 |
| 书库 | 木地板 | 使用木材颜色/法线/ORM，保持统一实际尺寸 |
| 天然洞窟与矿坑 | 岩土 | 继续使用自然地面，区分建筑和天然空间 |

分区在同一个材质中完成，无叠加共面地板，地图几何、台阶高度、碰撞和任务数据不变。城堡的台基与台阶也使用建筑铺地；传送阵石柱保持原来的独立材质。

新增三套完整2K PBR（各颜色、OpenGL法线、ORM），来源：[Monastery Stone Floor](https://polyhaven.com/a/monastery_stone_floor)、[Slab Tiles](https://polyhaven.com/a/slab_tiles)、[Marble Tiles](https://polyhaven.com/a/marble_tiles)，均按[Poly Haven CC0](https://polyhaven.com/license)使用。作者、下载地址与校验记录在material-sources.json；没有运行时联网。

`tools/fetch_story_pbr.py --roles interior_stone,crypt_slab,ceremonial_tile`仅更新这些贴图并合并来源清单。`prepare_story_floor_imports.py`统一mipmap与VRAM压缩，法线按数据贴图导入。`patch_story_interior_floors.gd`只修改旧堡已有地面、台阶和台基材质，保留网格、UV2、灯光、摆放与移动数据；然后重新烘焙第九区。其余建筑副本在运行时生成时采用同一材质分流。

测试`story_architectural_floors.gd`覆盖六幕所有建筑布局的材质选择、PBR完整性、旧堡实际缓存的地面和台阶，以及实机城堡大厅/领主厅、墓室、礼拜堂、书库五个4K机位。截图在build/story-floor-*.png，兼容版本单独保存。仍未做长时间跑分或整部游戏美术验收。
