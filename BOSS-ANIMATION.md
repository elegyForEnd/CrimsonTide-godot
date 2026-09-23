# Boss 4K 动作图集

2026-09-23：原三位主 Boss 的动作图集重新绘制，镜墓纺女、余烬司祭、无名赤月、裂地钻兽、雷骸巨鸟、吞月渊蛇和霜骨古龙补齐动作图集。原角色单张立绘仍用于登场、转阶段与死亡的侧边演出。

每张图集为 3840×2160 RGBA，按 4 列 × 3 行排列，共 12 帧。第 0–3 帧为移动，第 4–7 帧为蓄力、保持、出手、收招，第 8–9 帧为待机，第 10 帧为受击，第 11 帧为倒下。战斗中统一调用 `BossFrames.pose()`，不再用静态立绘假装移动。长兵器、镜片与龙息等跨格部分按连通的原始绘制元素归属角色后重排，不采用简单的等分硬裁切。

通过用户指定的 `https://rolldek.com/v1` 图像编辑接口、`gpt-image-2.5-sunburst` 模型，以现有图集或单张角色图为参考、高品质 3840×2160、真实透明背景生成。统一要求保持同一角色身份、造型和比例，十二个不同动作，不添加背景、棋盘格、文字与边框。最终素材路径和打包后的高度记录在 `assets/bosses/motion-atlas.json`；API 密钥没有写入项目。原始候选图在被 Git 忽略的 `build/*-sheet-candidate.png`，可用于重新打包：

```powershell
python tools/prepare_boss_animation.py
```

运行时按 Boss 类型延迟加载新增图集，保留原有立绘和 HUD 图。不改变攻击时序、判定和联机数据。打开 Godot 源码项目后会自动导入新贴图；`dist/` 中已有的导出版本不会自动包含这些变化。

验证：`Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/boss_art.gd`，以及 `tests/new_bosses_visual.gd`、`tests/wild_bosses_visual.gd` 和 `tests/dragon_boss_visual.gd` 的实际渲染截图。
