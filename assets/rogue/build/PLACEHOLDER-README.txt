这些是占位文件，不是美术资产。
================================

背景
----
本工作副本里 assets/rogue/build/ 整个生成物目录缺失（该目录被 .gitignore 忽略，
git 历史里从来没有提交过）。scripts/rogue_art.gd 与 scripts/rogue_jump_frames.gd
直接 preload / 解析这里的文件，缺一个就导致 main.gd 编译失败、源码版根本起不来。

为了让游戏能启动（并完成敌人攻击预警的视觉验收），这里临时放了：
  blood-flask-v1.png      = 从 assets/rogue/crystal.png 复制来的占位图
  atlas-manifest.json     = {}
  jump-manifest.json      = {}

后果
----
- 主世界（营地 / 边境 / 远征 / Boss）完全正常。
- 肉鸽模式的美术与动画会错乱或报错，因为 manifest 是空的。

恢复方法
--------
用项目自带工具重新生成真实内容，然后删掉本文件：

  python tools/build_rogue_content.py
  python tools/index_rogue_build_art.py
  python tools/index_rogue_jump_art.py

如果你手上有完整的 assets/rogue/build/ 备份，直接覆盖本目录即可。

入库状态
--------
自 2026-10-05 起，本目录在 .gitignore 中有例外（!/assets/rogue/build/），
因此这份"能编译的最小集合"会随仓库分发：任何全新 clone 都不会再因为缺
blood-flask-v1.png 而让 main.gd 编译失败。

当前入库的内容：
  blood-flask-v1.png     占位（= assets/rogue/crystal.png 的副本，不是真实血瓶）
  atlas-manifest.json    {}（真实应为 252 个区域 / 13 张图集）
  jump-manifest.json     {}（真实应为 4 角色 24 姿态）
  generation-plan.json   由 tools/plan_rogue_build_art.py 从 resources/rogue_build_content.json 复现

拿到真实素材后：覆盖同名文件 → 重跑 tools/index_rogue_build_art.py 与 index_rogue_jump_art.py
→ 删掉本文件 → 提交。注意 blood-flask-v1.png 也要换成真实血瓶。
