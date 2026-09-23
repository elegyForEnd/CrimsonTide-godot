# 新 Boss：镜墓、余烬与无名赤月

本次扩展沿用三日远征。第一天和第二天的探索期各有一名可选小 Boss，地图上的蓝色／橙色菱形标记其所在据点；击败后获得“守卫秘藏”。第三天仍先挑战血潮女王，女王倒下后直接进入“无名赤月 · 血潮源核”终局战，打败新形态才会结算终夜。多人模式沿用主机权威伤害、敌人快照及可靠战斗事件。

| Boss | 登场与战斗设计 | 视觉与音频 |
|---|---|---|
| 镜墓纺女 · 碎影 | 第一天据点守卫。折镜穿刺的第二道矛延迟出现；镜面倒影先打环带再打中心；碎影十字按快慢两拍相交；千镜坠落锁定玩家站位。半血后增加追击印记。 | 银镜立绘、冷蓝裂镜能量、碎片粒子、侧边登场／转阶段／死亡演出；独立镜晶音效与《Shards of the Mirror Tomb》。 |
| 余烬司祭 · 晚祷 | 第二天据点守卫。焚香裂焰要求绕背；灰烬晚祷要求进入安全内圈；烬火审判快刺接慢扫；终末弥撒连续锁定落焰。半血后增加背后反击及第三道落焰。 | 焦红祭衣立绘、橙红火焰能量、炽热粒子与侧边演出；独立余烬音效与《Ashen Vespers》。 |
| 无名赤月 · 血潮源核 | 血潮女王之后的终局形态，6900 基础生命，三阶段。血月初升先环后爆；碎冠星轨有矛隙；月刃断章快慢反向斩；终夜坠落连续锁定；血潮源核以环、矛、定点爆发收尾。第三阶段延续外圈封场。 | 赤月新立绘、红色范围预警、血月能量爆发、镜头震动、侧边转阶段演出；独立月蚀音效与《The Nameless Blood Moon》。 |

所有伤害范围使用原有真实几何判定；预警颜色、快慢拍文字与音效跟随主机广播。小 Boss 只在玩家接近后播放侧边登场演出。各 Boss 的战斗音乐随进入战斗范围或远征决战自动交叉淡化，离开小 Boss 后回到废墟探索曲。游戏播放本地 Ogg，无需联网或 API 密钥。

## 素材与复现

- 三张角色图在 `assets/bosses/new/`，原始 ImageGen 提示词见 `generation-prompts.json`。透明 RGBA 图直接用于战场角色与侧边演出。
- 21 个专属音效在 `assets/audio/bosses/`，由项目已署名的 CC0 原录音分层剪辑。制作方式和来源见 `new-boss-sfx-manifest.json`；可运行 `python tools/prepare_new_boss_sfx.py` 重建。
- 三首 BGM 通过用户指定的 Apilio Suno API 生成。请求 `chirp-v4`，接口返回 `chirp-hawk`，两项均如实写入 `assets/audio/music/music-manifest.json`。每首请求的两个候选中使用第一个；约 92、77、82 秒的最终 Ogg 经过首尾交叉淡化与响度处理。源 MP3 和 API 回执在被 Git 忽略的 `build/boss-music-source/`。
- 再次生成音乐需在进程环境中设置 `APILIO_API_KEY`，运行 `python tools/generate_boss_music.py submit`，生成完成后运行 `collect`，最后运行 `python tools/prepare_boss_music.py`。密钥不写入项目；游戏运行无需密钥。生成音乐遵循服务和账户条款，不纳入 CC0 音效署名。

## 验证

`tests/new_bosses.gd` 检查两天小 Boss 生成、攻击时间顺序、奖励、女王到终局形态的过渡、终局结算及素材导入。`tests/new_bosses_visual.gd` 生成三张实际渲染截图至 `build/new-boss-*.png`，用于检查角色、预警、血条和演出。原有 `tests/boss_vfx.gd`、`tests/audio.gd`、`tests/music.gd` 已复测。
