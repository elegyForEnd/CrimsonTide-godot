# 霜骨古龙 · 苍殒

第二天探索期新增一处独立龙巢，地图上以冰蓝菱形标记。霜骨古龙是可选 Boss，四足双翼，基础生命 2750；打败后掉落“龙巢遗珍”。原有小 Boss、女王和隐藏终局的解锁条件不变。

| 招式 | 预警与应对 |
|---|---|
| 苍白吐息 | 龙头方向依次扫过三道窄扇形，半血后四道。落点留下约 2.8 秒寒域，首次爆发后每 0.75 秒再次结算伤害。移动到龙侧后方并避开蓝色残留圈。 |
| 古龙摆尾 | 身后半环形弧带命中，靠近身侧内圈或转到正面安全；半血后追加转向尾扫。 |
| 霜翼拍地 | 左右翼先后落下，龙头与尾巴方向留有中轴空位；半血后玩家脚下追加寒域。 |
| 霜华绽裂 | 龙身周围六个交错时间的冰爆点会留下寒域，观察先后顺序穿过空位；半血后锁定玩家追加落冰。 |

新弧带判定 `arc` 与预警共用角度、内外半径；寒域由主机持续结算伤害，联机客户端接收同一危险区快照。入场、转阶段和倒下使用冰蓝色侧边演出与粒子，音效为 7 个独立龙系提示音。专属器乐 BGM `assets/audio/music/dragon.ogg` 通过用户指定的 Apilio Suno API 生成，本地循环播放。请求参数和实际返回模型记载于 `assets/audio/music/music-manifest.json`；原始 MP3 与接口回执在被 Git 忽略的 `build/boss-music-source/`，项目不存储 API 密钥。

美术与提示词见 `assets/bosses/dragon/`，音效重建脚本为 `tools/prepare_dragon_sfx.py`，来源见 `assets/audio/bosses/dragon-sfx-manifest.json`。`tests/dragon_boss.gd` 验证独立巢穴、招式判定、寒域脉冲、阶段与奖励；`tests/dragon_boss_visual.gd` 生成两张实际渲染截图到 `build/dragon-boss-*.png`。
