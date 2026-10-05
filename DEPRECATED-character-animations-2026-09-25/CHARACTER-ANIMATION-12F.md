# 可玩角色 12 帧动画图集

四名可玩角色各有 6 张独立动作图：`walk`、`run`、`dodge`、`sword`、`heavy`、`staff`，共 24 张。每张只含一个动画，12 帧按 4 列 × 3 行从左到右、从上到下排列；图像为 3840×2160 RGBA PNG。行走和奔跑循环播放，闪避和攻击按动作进度播放。

图集位于 `assets/combat/animations/hero-0/` 至 `hero-3/`。战斗逻辑优先读取新图；某张图缺失时回退到原来的 `attack-clean-N.png` 或 `movement-N.png` 四帧动作。旧图未覆盖，营地立绘、Boss 和怪物动画不受影响。

## 生成和重建

使用 imagegen 技能的 API 路径，以及项目已有的 `tools/generate_enemy_art.py` 兼容适配器，通过 `https://rolldek.com/v1` 的 `gpt-image-2.5-sunburst` 编辑接口，以各角色原动作图为造型参考、高品质 3840×2160 生成。第一次透明背景样张混入深色背景，因此最终采用纯绿色背景，在打包时抠像并清理跨格碎片。完整提示词由 `tools/build_character_animation_jobs.py` 生成到 `output/imagegen/character-animation-jobs.jsonl`；生成规格和每个动作的 12 帧内容保存在该脚本中。API 密钥仅从进程环境读取，不保存在项目里。

重建步骤：

```powershell
python tools/build_character_animation_jobs.py
$env:OPENAI_BASE_URL = 'https://rolldek.com/v1'
# 在本机环境设置 OPENAI_API_KEY，勿写入项目文件。
python tools/generate_enemy_art.py --jobs output/imagegen/character-animation-jobs.jsonl
python tools/prepare_character_animations.py
& .\Godot_v4.7.2-stable_win64_console.exe --headless --editor --import --path .
```

原始 API 输出保存在被 Git 忽略的 `output/imagegen/character-animations/`；游戏实际读取的是 `assets/combat/animations/`。新动画不改变攻击命中时机、移动速度或联机状态数据。

## 验证

- 24 张游戏图集均为 3840×2160 RGBA，合计 288 帧；每格有透明隔离边缘。
- `tests/movement.gd`：327 项，0 失败；包括所有动作 12 帧、帧边界及动作索引。
- `tests/character_scale.gd`：871 项，0 失败；验证角色大小与脚下锚点。
- `tests/combat.gd`：78 项，0 失败；Godot 主场景 headless 启动成功。
- Windows Desktop 发布版已重新导出到 `dist/CrimsonTide.exe`，并通过 headless 启动检查。
