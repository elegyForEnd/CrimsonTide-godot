# 战役界面美术资源

使用 imagegen 技能的内置 image_gen 工具制作原创资源；没有使用 API CLI、第三方游戏图标或参考游戏的美术文件。保留人物原有立绘。

- `inventory-atlas-v2.png`：十二种原创装备、药剂和材料图标，RGBA 透明背景。
- `icon-regions.json`：经检查的实际图标区域，Godot AtlasTexture 裁取并等比显示，避免模型/武器图标缺一半。
- `interface-sanctum-v1.png`：哥特石材、皮革与黄铜框架底板。
- `control-materials-v1.png` 与 `control-regions.json`：九种控件材质；运行时制成九宫切片，覆盖空格、装备槽、按钮、属性卡、提示、商店货架、铁匠与危险操作。
- `generation-prompts.json`：所有实际使用的完整提示词。第一张图只作为第二张的参考，未选入游戏。

所有文字、物品状态、格子占位、选中/禁用/拖放、货币与锻造结果都是实时 Godot 控件。背景图没有烘入文字、人物或操作按钮。
