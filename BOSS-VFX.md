# Boss 特效与音效

2026-10-06：当前招式规划与动作图集接入见 [BOSS-ATTACK-DESIGN.md](BOSS-ATTACK-DESIGN.md)。近战由身体动作、实际接触路径与多状态贴图驱动，警示按攻击语义生成。

## 当前版本：贴图、动态能量与粒子组合

2026-09-23 更新：保留原始绘制素材，Boss 主体素材与法杖素材均按原始宽高比缩放；长矛使用等比例分段素材叠加动态能量束。原先变形贴图网格的地面预警改为真实判定几何，爆发层采用流动噪声 Shader、CPUParticles2D 和原始主题素材。登场、转阶段、死亡增加不暂停战斗的侧边立绘演出。单手剑、双手剑和角色大招保持原效果。

实现与验证见 `HYBRID-VFX.md`。下方为原素材制作记录；其中“纹理网格”“旧圆环描边移除”等描述属于此前版本。

2026-09-23：四位 Boss 的攻击、反应招式、防御和阶段演出已接入专属素材。

## 图像

使用内置 ImageGen 生成四张实际尺寸为 1254×1254 的 RGBA 透明图集，每张 4×4，共 64 个绘制元素。最终提示词完整保存在 `assets/bosses/vfx/generation-prompts.json`；原始输出已原样复制到项目，没有重新抠图或用程序图形替代生成素材。

| 图集 | 主题 | 覆盖招式 |
|---|---|---|
| `assets/bosses/vfx/bell.png` | 幽紫钟魂、银色圣堂、月蚀 | 葬钟回响、月蚀祷告、急鸣丧钟、停钟再鸣、十字葬仪、翻滚落点追击、装填追击 |
| `assets/bosses/vfx/thorn.png` | 黑棘、血晶长矛、鹿角护架 | 猎王血矛、荆棘断誓、猎誓虚晃、三棘追猎、回身收割、格挡反击、防御、破防、翻滚落点追击、装填追击 |
| `assets/bosses/vfx/queen.png` | 红金月冠、彩窗翼刃、血潮 | 月冠审判、血潮王令、永夜加冕、女王处刑、蚀月错拍、翻滚落点追击、装填追击、三阶段外围封场 |
| `assets/bosses/vfx/knight.png` | 银白剑风、钢铁碎片、残破誓旗 | 誓约三连、逐风突刺、失乡风暴、截步快斩、举剑虚晃、架剑反击、防御、破防；反应追击沿用对应突刺/快斩 |

另有每位 Boss 的登场、转阶段、死亡碎片与消散。图集包含蓄力、爆发和残留状态的元素；运行时通过贴图变换、混合、碎片运动与震屏形成动画，并非每招一条完整的逐帧影片。

旧的 Boss 圆环描边、扇形纯色填充、矩形攻击条和防御弧已移除。地面纹理网格直接采用伤害判定的半径、内圈、方向和锥角；空中斩痕与碎片是装饰层。环带安全内圈不做满屏爆闪。保留快慢拍文字辅助和非 Boss 的地图/撤离圈标记。

## 现成音效

`assets/audio/bosses/` 包含 32 个 48 kHz、16-bit PCM WAV。全部剪辑、叠加自项目已有的 15 个 CC0 音效录音，未使用 AI 生成音频，也没有合成振荡器或噪声。

- 主教：rubberduck 钟鸣与锣声、Lentikula 风系冲击。
- 猎王：Lentikula 植物/大地冲击、artisticdude 刀刃掠风。
- 女王：Lentikula 冰晶冲击、rubberduck 玻璃破碎与锣声。
- 骑士：Lentikula 风系冲击、artisticdude 掠风、StarNinjas 金属交击。

每位 Boss 有 charge / quick / sweep / burst / lance / ritual / fall 七类声音，猎王与骑士额外各有 guard / break。不同招式组合、快慢节奏和多段出手分别驱动对应声音，延迟重斩另叠加低频冲击。同一来源的同帧放射矛音效去重，避免 12 道王矛叠加爆音。

完整作者、原始素材网址、SHA-256 和逐项剪辑配方：`assets/audio/bosses/manifest.json`；简明署名：`assets/audio/bosses/CREDITS.txt`。复现：`python tools/prepare_boss_audio.py`（需要已有 `build/audio-library/`、NumPy、SciPy 和 ffmpeg）。

## 接入

- `scripts/boss_presentation.gd`：统一演出事件与音效选择。
- `scripts/boss_vfx.gd`：透明贴图、范围网格、姿态蓄力、碎片与阶段演出。
- `scripts/expedition.gd` / `scripts/session.gd` / `scripts/boss_tactics.gd`：在实际蓄力、出手、格挡和阶段变化时发送事件。
- `scripts/sound.gd` / `scripts/main.gd`：播放现成音效，停止过期蓄力音，管理优先级和去重。

沿用主机权威的伤害判定和可靠 combat RPC；范围元数据随原有快照同步。未改动技能伤害、命中时间和闪避规则。

## 验证与运行

- `tests/boss_tactics.gd`：186 项通过，原有招式时序、追击、防御和伤害规则。
- `tests/boss_vfx.gd`：289 项通过，所有招式事件覆盖、透明素材、音效可加载及无重复命中演出。
- `tests/audio.gd`：170 项通过，音频加载、并发与混音规则。
- `tests/boss_vfx_network.gd`：双进程主机/客户端通过，四种主题、范围元数据、出手、防御、破防、阶段、死亡同步。
- `tests/boss_vfx_visual.gd`：OpenGL 实机渲染 12 张截图，保存在 `build/boss-vfx-*.png`，检查四位 Boss 的预警、释放和阶段表现。
- 32 个新增音频全部非静音、采样率 48 kHz，最大采样峰值 0.8595 以下。

Windows 版本：`dist/CrimsonTide-BossVFX.exe`。许可记录和生成提示词随包附带；导出排除了宣传视频工作目录 `pv/`，避免把与游戏无关的 PV 音视频装入游戏。项目编辑器扫描可能仍提示该目录中两份既有 PV WAV 格式不支持，本次新增音效均可正常导入。
