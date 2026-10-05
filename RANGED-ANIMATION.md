# 弓箭与步枪动画

2026-10-05，使用内置 imagegen，参考 `assets/combat/attack-clean-0.png` 到 `attack-clean-3.png` 生成四名角色的弓箭和步枪动作。每类武器每名角色四帧，共 8 段动画、32 张运行时透明 PNG。

- 弓箭：持弓、满弦瞄准、放箭、收势。墓煜使用独立 2×2 原图，以保留完整弓尖。
- 步枪：低位持枪、举枪瞄准、开火后坐力、收势。零蓄力步枪直接从开火帧开始播放。
- 普通战斗和肉鸽战斗均使用 `CharacterFrames.equipped_attack_frame()` 选择远程动作；肉鸽蓄力读取 `build_strike_windup`，战技蓄力读取 `build_pending_art.remaining`。
- `spell=arrow` 使用弓箭动作，其他 family=0 武器使用步枪动作。这是远程武器类别的通用动画，未为连弩、双枪等衍生武器分别生成动作。
- 统一单段动画的画布、角色比例、脚底支点；按已有行走身高缩放。开火挂点跟随新图集，肉鸽远程攻击不再额外叠加第二把武器图标。
- 优先保留现有独立持械待机动画；缺失时使用本次生成的持械帧。行走、奔跑、闪避和跳跃继续使用已有动作。

运行时素材与 manifest：`assets/combat/ranged-imagegen/hero-0` 至 `hero-3`，各自含 `bow`、`rifle` 目录。原始 imagegen 图集为 `bow-v2.png`、`rifle-v1.png`、`muyu-bow-v1.png`；`bow-v1.png` 是留白不足的早期版本，不在运行时使用。

完整最终提示词保存在同目录下的 `bow-prompt.txt`、`bow-layout-prompt.txt`、`rifle-prompt.txt`、`muyu-bow-prompt.txt`。生成方式为内置 imagegen，未使用 API CLI。

可重复执行的切帧与支点登记工具：

```powershell
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/pack_ranged_imagegen.gd
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/ranged_animations.gd
```

验证：远程动画 272 项、现有战斗 78 项和待机 75909 项检查通过。`tests/ranged_animations_visual.gd` 在实际场景内捕获两种模式的弓枪释放动作，最终运行无脚本错误；截图与四角色动作对照图位于 `output/ranged-animation/`。
