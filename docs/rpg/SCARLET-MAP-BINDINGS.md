# 赤月遗书 · 原地图绑定与恢复范围

以原地图为基础，只添加剧情和玩法。`story_world.gd`、`world_3d.gd`、`story_environment.gd`、`story_region.gd`、`story_map.gd`、`graphics_quality.gd` 均继续使用原文件。

保留 55 张原地图：六个营地及 49 张野外／副本。主线之外的原地图由事件层补充探索入口。野外沿原连接道路连续行走，副本沿原父子入口进入和返回；不把原地图拆成新造的小方场。

渲染通过 `scarlet/render_campaign.gd` 提供原生世界坐标给原 StoryWorld；镜头、角色帧动画、脚点、接触阴影、NPC、烘焙光照、PBR、遮挡渐隐、GraphicsQuality 和原 StoryCombatVFX 都由原实现负责。原行囊、仓库、商店、装备、锻造、专精继续可用。

剧情物件使用单独的 StoryAdditions 节点，只有 Boss 机关、母晶、试航水面与小船等必要增补；不会改写基础场景资源。新 NPC 立绘用于 ADV。六位新剧情 Boss 暂复用原各章战斗外观，专用动作／模型另见制作清单。

| 剧情事件地区 | 原地图 | 底图文件前缀 |
|---|---|---|
| 1:0 · 边境客舍 | 雷霆要塞 | `scenes/story/opening-0` |
| 1:1 · 驿路浅河 | 风铃原野 | `scenes/story/opening-1` |
| 1:2 · 换马驿站 | 断羽驿路 | `scenes/story/opening-2` |
| 1:3 · 村医的小屋 | 静钟村 | `scenes/story/opening-3` |
| 1:4 · 雾桥礼拜堂 | 遗灯礼拜堂 | `scenes/story/opening-5` |
| 1:5 · 囚车与修院侧道 | 灰棘旧堡 | `scenes/story/opening-9` |
| 1:6 · 边境修院主厅 | 白钟修院 | `scenes/story/opening-6` |
| 2:0 · 白垩避难所 | 白垩避难庭 | `scenes/story/act2-0` |
| 2:1 · 白垩外街 | 白垩外街 | `scenes/story/act2-1` |
| 2:2 · 查封工匠铺 | 坠钟广场 | `scenes/story/act2-2` |
| 2:3 · 旧审判庭地牢 | 旧审判庭 | `scenes/story/act2-3` |
| 2:4 · 灰页书库 | 灰页书库 | `scenes/story/act2-4` |
| 2:5 · 地下炉渠 | 地下炉渠 | `scenes/story/act2-5` |
| 2:6 · 焚书礼堂 | 焚书礼堂 | `scenes/story/act2-6` |
| 3:0 · 月晶驿站 | 月晶驿站 | `scenes/story/act3-0` |
| 3:1 · 月晶坡地 | 月晶坡地 | `scenes/story/act3-1` |
| 3:2 · 骨鹿猎道 | 骨鹿猎道 | `scenes/story/act3-2` |
| 3:3 · 断星矿坑 | 断星矿坑 | `scenes/story/act3-3` |
| 3:4 · 流星坠谷 | 流星坠谷 | `scenes/story/act3-4` |
| 3:5 · 观星信站 | 废弃测星站 | `scenes/story/act3-7` |
| 3:6 · 山口祭场 | 誓猎祭场 | `scenes/story/act3-6` |
| 4:0 · 蔷薇篱营 | 蔷薇篱营 | `scenes/story/act4-0` |
| 4:1 · 行宫荒园 | 蔷薇荒园 | `scenes/story/act4-1` |
| 4:2 · 裁衣工坊 | 刑偶工坊 | `scenes/story/act4-2` |
| 4:3 · 旧卧室长廊 | 嫁衣长廊 | `scenes/story/act4-3` |
| 4:4 · 庭院地下医室 | 花眠庭院 | `scenes/story/act4-4` |
| 4:5 · 手术档案室 | 镜墓 | `scenes/story/act4-5` |
| 4:6 · 外科示范厅 | 倒影剧场 | `scenes/story/act4-6` |
| 5:0 · 月舟码头 | 月舟码头 | `scenes/story/act5-0` |
| 5:1 · 修船坞 | 封闭干船坞 | `scenes/story/act5-7` |
| 5:2 · 沉舟滩 | 沉舟滩 | `scenes/story/act5-2` |
| 5:3 · 潮盐工事 | 潮盐工事 | `scenes/story/act5-3` |
| 5:4 · 海防高坡 | 沉钟遗迹 | `scenes/story/act5-4` |
| 5:5 · 逆潮水道 | 逆潮水道 | `scenes/story/act5-5` |
| 5:6 · 黑帆旗舰 | 归航灯塔 | `scenes/story/act5-6` |
| 6:0 · 旧水门营地 | 王城残灯 | `scenes/story/act6-0` |
| 6:1 · 水门登陆台 | 封印圣物库 | `scenes/story/act6-7` |
| 6:2 · 通风侧廊 | 朝圣大道 | `scenes/story/act6-1` |
| 6:3 · 失乡庭院 | 失乡庭院 | `scenes/story/act6-3` |
| 6:4 · 彩窗工区 | 彩窗工区 | `scenes/story/act6-4` |
| 6:5 · 王座前室 | 圣血外廊 | `scenes/story/act6-2` |
| 6:6 · 赤月王座 | 王座大教堂 | `scenes/story/act6-6` |
| 6:7 · 王城外墙 · 观景台 | 朝圣大道 | `scenes/story/act6-1` |

未出现在上表的原地图也保留：地图绑定会为其增加原名探索入口。原传送阵、宝箱及营地 NPC 服务使用原位置；剧情目标与护送点另在原可达地面落位。

1800 仅为剧情事件的编辑索引坐标。地面、模型和世界尺寸不缩放，索引在运行时转换为原地图世界坐标。改变剧情落点时，先检查原地图的墙体、水域、楼梯和可达分量。
