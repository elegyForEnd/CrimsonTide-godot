# 血潮守望 · 场景背景音乐

2026-10-05：通过用户指定的 Apilio Suno 接口新增 23 首纯器乐配乐，保留原有 9 首，共 32 首。全部以本地 OGG 播放，游戏运行不需要网络或 API 密钥。

新版试玩：`dist/CrimsonTide-Music-v1.exe`。

## 场景与曲目

| 使用场景 | 音乐文件 | 循环时长 | 音色与气氛 |
|---|---|---:|---|
| 血潮守望 · 标题 | [title.ogg](assets/audio/music/title.ogg) | 112.4 秒 | 88 bpm, D minor, solo cello, restrained pipe organ, celesta, stately chamber strings |
| 家园与整备 | [home.ogg](assets/audio/music/home.ogg) | 133.4 秒 | 76 bpm, warm felt piano, acoustic harp, clarinet, soft strings |
| 失乡王城 · 探索 | [city.ogg](assets/audio/music/city.ogg) | 91.6 秒 | 96 bpm, bass clarinet, viola ostinato, hollow bells, muted organ |
| 灵契圣坛 · 构筑 | [sanctuary.ogg](assets/audio/music/sanctuary.ogg) | 126.4 秒 | 68 bpm, glass bells, harp harmonics, soft organ pads, viola |
| 游商营火 | [shop.ogg](assets/audio/music/shop.ogg) | 132.7 秒 | 84 bpm, plucked cello, dulcimer, warm clarinet, brush percussion |
| 遗落宝藏 | [treasure.ogg](assets/audio/music/treasure.ogg) | 87.1 秒 | 78 bpm, celesta, pizzicato strings, harp, soft metallic chimes |
| 凯旋与成功撤离 | [victory.ogg](assets/audio/music/victory.ogg) | 113.9 秒 | 94 bpm, warm strings, french horn, piano, bells |
| 阵亡结算 | [defeat.ogg](assets/audio/music/defeat.ogg) | 118.4 秒 | 62 bpm, solo cello, felt piano, sparse low strings |
| 赤月葬钟主教 | [bishop.ogg](assets/audio/music/bishop.ogg) | 128.4 秒 | 134 bpm, pipe organ, tolling bells, rapid low strings, ritual timpani |
| 荆棘誓约猎王 | [hunter.ogg](assets/audio/music/hunter.ogg) | 187.7 秒 | 142 bpm, sharp string spiccato, hunting horns, toms, low cello |
| 血潮女王 · 永夜月冠 | [queen.ogg](assets/audio/music/queen.ogg) | 88.0 秒 | 148 bpm, grand string orchestra, regal brass, pipe organ, deep taiko |
| 冥火尸王 · 墓玥 | [hidden.ogg](assets/audio/music/hidden.ogg) | 97.7 秒 | 154 bpm, distorted low organ, contrabass, dissonant strings, huge ritual drums |
| 失乡骑士 | [knight.ogg](assets/audio/music/knight.ogg) | 112.0 秒 | 128 bpm, mournful horn, cello ostinato, steel percussion, chamber strings |
| 幽光菌林 | [floor_1.ogg](assets/audio/music/floor_1.ogg) | 98.4 秒 | 104 bpm, breathy flute, bass clarinet, celesta, plucked strings, soft frame drums |
| 幽蕈古王 | [guardian_1.ogg](assets/audio/music/guardian_1.ogg) | 118.8 秒 | 130 bpm, deep bassoon, wooden drums, twisted cello, low organ |
| 魔焰铸炉 | [floor_2.ogg](assets/audio/music/floor_2.ogg) | 62.4 秒 | 116 bpm, muted brass, iron anvil percussion, cello ostinato, low strings |
| 熔炉暴君 | [guardian_2.ogg](assets/audio/music/guardian_2.ogg) | 66.8 秒 | 144 bpm, huge anvil hits, aggressive brass, taiko, fast low strings |
| 星晶幻境 | [floor_3.ogg](assets/audio/music/floor_3.ogg) | 107.0 秒 | 108 bpm, glass harmonica, celesta, harp, shimmering chamber strings |
| 星镜女皇 | [guardian_3.ogg](assets/audio/music/guardian_3.ogg) | 97.1 秒 | 140 bpm, fractured celesta, agile violins, glass bells, pipe organ |
| 风暴空港 | [floor_4.ogg](assets/audio/music/floor_4.ogg) | 119.6 秒 | 122 bpm, soaring strings, french horns, snare, airy woodwinds |
| 雷翼舰长 | [guardian_4.ogg](assets/audio/music/guardian_4.ogg) | 82.4 秒 | 152 bpm, military snare, plunging brass, racing violins, thunder timpani |
| 黑曜魔宫 | [floor_5.ogg](assets/audio/music/floor_5.ogg) | 108.3 秒 | 118 bpm, ominous pipe organ, low viola ostinato, obsidian chimes, restrained drums |
| 黑曜剑圣 | [guardian_5.ogg](assets/audio/music/guardian_5.ogg) | 82.8 秒 | 160 bpm, razor-sharp violin runs, huge taiko, low brass, pipe organ |

原有音乐继续用于：营地整备（camp）、边境探索（ruins）、镜墓纺女（mirror）、余烬司祭（ember）、无名赤月（final）、裂地异兽（earth）、雷霆巨鸟（storm）、吞月巨兽（abyss）、霜骨古龙（dragon）。

## 自动选择

- 标题播放 title，可行走家园播放 home；经典整备界面与账户、仓库等菜单播放 camp，闯关出发准备播放 sanctuary。
- 五层普通战斗与精英试炼播放各层 floor_1～floor_5；第三波守层 Boss 实际出现后播放对应 guardian_1～guardian_5，击败后恢复楼层曲。
- 游商、宝藏、灵契圣坛各自播放 shop、treasure、sanctuary。
- 王城探索播放 city，距离 850 内的失乡骑士触发 knight；离开范围或击败后恢复探索曲。边境野外小 Boss 同样按距离选择最近的战斗。
- 远征首领优先覆盖探索音乐：葬钟主教 bishop、誓约猎王 hunter、血潮女王 queen；无名赤月 final、冥火尸王 hidden、吞月巨兽 abyss 具有独立覆盖。
- 个人成功撤离 / 闯关获胜播放 victory，阵亡或失败播放 defeat。
- 切换采用 1.8 秒交叉淡化，同一曲不重新开始；退出战局清除 Boss 状态。对白压低 6 dB，奥义演出压低 12 dB，暂停时仍播放。设置里的音乐音量独立控制。

## 制作与来源

完整的场景设计与提示词见 `resources/scene_music_plan.json`。生成请求、任务 ID、候选音频 ID、实际返回模型、剪辑参数及 SHA-256 见 `assets/audio/music/music-manifest.json`。新增曲目请求 chirp-v4，实际型号按接口返回记录。所有曲目均为真实 Suno 返回音频。熔炉暴君使用同一次任务的第二候选版本，以保留超过一分钟的循环长度；其他新增曲目使用第一候选版本。

新增曲目裁去开头 2 秒与结尾 5 秒，首尾交叉混合 3 秒；边缘增加 5 毫秒微淡化以减少编码接缝，响度处理为 -20 LUFS、-2 dBTP。处理后的新曲长 62.4～187.7 秒。没有使用程序合成音替代 Suno。音乐适用生成服务与账户条款，不属于项目 CC0 音效库。

原始 MP3、完整回执与查询状态保存在 Git 忽略的 `build/scene-music-source/`。密钥仅使用进程环境变量 APILIO_API_KEY，不写入项目或导出游戏。

## 复现

```powershell
python tools/generate_scene_music.py submit
python tools/generate_scene_music.py collect
python tools/generate_scene_music.py master
```

submit 自动跳过已有任务；collect 自动跳过已下载素材；master 自动跳过已有 OGG。重新剪辑用 `master --remaster`，单独处理用 `--cue guardian_2`。submit 与 collect 需要先设置 APILIO_API_KEY；master 不需要密钥。生成的 OGG 与清单原子替换，避免 Godot 读取未写完的文件。

## 验证

- `python tests/scene_music_assets.py`：23 首新曲全部通过来源哈希、真实 PCM 解码、双声道 44.1 kHz、时长、能量、峰值与循环采样接缝检查。
- Godot `tests/music.gd`：70 项检查通过，覆盖 32 个本地音轨、场景及 Boss 选择、跨场景淡化、暂停、对白及演出压低、独立静音。
- Godot `--headless --fixed-fps 60 --script tests/audio.gd`：366 项音效回归检查通过。未限制帧率的无界面测试存在环境声 tween 和计时器的时间差，采用固定 60 FPS 验证该项；未修改原有音效逻辑。
- 修复 `scripts/boss_damage_visual.gd` 一处动态粒子数组长度的 int 类型声明，确保项目脚本可编译。
- 新版 Windows 单文件导出成功，并通过加载内嵌 PCK 的无界面启动检查，无脚本或音乐资源错误；文件约 1.32 GiB。
- 验证为音频信号和运行行为检查，不代表人工听审。
