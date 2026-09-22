# 大招结束后的技能释放与音效

按 Q 成功施法后先播放角色 CG；CG 内的闪光与报招只属于演出，不再提前造成伤害、治疗或生成战场技能特效。单人完整播放或按键跳过后，恢复战场并结算一次技能。离开战斗页面会取消尚未释放的技能。

联机保持 0.85 秒短演出，不暂停其他玩家。房主在蓄力结束时结算并广播技能事件；客户端跳过 CG 不会提前结算。蓄力期间固定施法方向、停止移动和其他操作，倒地或断线取消施法。冷却仍在成功起手时开始，伤害、范围及治疗量沿用原规则。

## 选用素材

2026-09-22 核对作者页面：下列包均标注 CC0，可用于游戏并随包分发。利用项目已有原始下载加工，不需要购买或在线音频服务；角色语音与背景音乐各自沿用原许可。

| 角色 / 技能 | 落招设计 | 原始音源 | 成品长度 |
|---|---|---|---|
| 绯月 · 红莲月华 | 火焰冲击、低频落点、五段金属剑鸣，对齐 55 ms 连续血刃 | Fire Spell Impact 2、Earth Spell Impact 1、sword.6、Wind Spell Impact 4 | 1.45 秒 |
| 雪璃 · 拂晓之祈 | 厚实圣光展开、延迟 100 ms 冰晶光柱、明亮治疗尾音 | Healing Spell Impact 11 / 7、Ice Spell Impact 2、Earth Spell Impact 1 | 1.85 秒 |
| 鸦羽 · 夜鸦断罪 | 雷击裂响、地裂低频、间隔 90 ms 的三段风刃 | Lightning Spell Impact 1、Earth Spell Impact 4、Wind Spell Impact 4 | 1.60 秒 |

- Lentikula：[Basic Spell Impacts](https://lentikula.itch.io/freecc0-basic-spell-impacts-sfx)、[Druid Spell Impacts](https://lentikula.itch.io/druid-spell-impacts)、[Healing Spell Impacts](https://lentikula.itch.io/healing-spell-impacts)。作者说明使用自己的录音与 CC0 声音进行设计，并以 CC0 发布。
- StarNinjas：[20 Sword Sound Effects](https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes)。
- [CC0 1.0 许可](https://creativecommons.org/publicdomain/zero/1.0/)。

成品是离线剪辑、滤波、变速和叠层后的 48 kHz 双声道 WAV。使用已有 `assets/audio/skill-0.wav` 至 `skill-2.wav` 槽位，运行音量从 -11 dB 调至 -5 dB，优先级高于普通攻击，仍遵循位置衰减和总线峰值保护。独立于 CG 音轨播放，CG 结束清理不会切掉落招尾响。本地角色和附近队友均可听到。

`tools/prepare_ultimate_audio.py` 仅重建三条释放音效；`tools/prepare_anime_audio.py` 全库重建时也保留这套配方。原素材哈希、各层处理参数和成品哈希写入 `assets/audio/library-manifest.json`。`build/Ultimate-Release-Preview.wav` 按绯月、雪璃、鸦羽顺序提供试听，它是三条成品按播放增益拼接的预览，不是游戏实录。

## 验证

- `tests/ultimate_release.gd`：41 项通过，覆盖三角色 CG 前无效果、CG 内闪光不结算、结束后伤害/治疗与音效、重复输入、跳过、离场、联机计时及倒地取消。使用 WASAPI 音频驱动验证，退出无资源清理错误。
- 原有 `tests/combat.gd` 30 项、`tests/systems.gd` 261 项、`tests/audio.gd` 138 项通过。
- `tests/audio_assets.py`：113 条 WAV 与环境音通过起音、尾音、过采样峰值、素材溯源和循环接缝检查。
- 本机 ENet 双人、四人联机最终均通过。首次双人运行客户端有一次未分项的失败，增加失败诊断后双人及四人通过；保留诊断便于后续定位，未进行公网延迟测试。
- 已更新 `dist/CrimsonTide.pck`，并使用该包重新执行释放时序检查：41 项通过，WASAPI 退出无资源清理错误。

自动检查验证音频信号和游戏行为，不代表人工主观听审。
