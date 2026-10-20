# 武器特效参考图

这里的图片只供美术设计对照，`.gdignore` 阻止 Godot 将它们作为游戏资源导入。

- `plates/`：前一轮的十张设计板，保留其成品与阶段参考；下面三排不作为游戏素材。
- `finished/`：后续逐把完整场景参考图，不包含素材网格。
- `split/`：错误流程产生的历史裁片，保留用于追溯，游戏不读取。
- `prompts/`：内置 ImageGen 的生成提示词。

实际效果由 `scripts/weapon_motion_design.gd`、`scripts/weapon_projectile_design.gd` 和 `resources/weapon_sculpted_material.gdshader` 制作。参考图不被裁切、投射或贴到攻击区域中。
