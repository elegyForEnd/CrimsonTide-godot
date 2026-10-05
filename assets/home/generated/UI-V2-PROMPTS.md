# 家园界面 v2

生成方式：内置 ImageGen。最终素材：`hearthhaven-ui-v2.png`（1536 × 1024 RGBA）。保留生成文件的 alpha；背景区域 alpha 为 0，未进行脚本抠图或重绘。一次背景提取候选未选用。

用途：家园 HUD 木质铭牌、小队面板、底栏、商店和厨房卡片、按钮与 i 说明面板。`scripts/home_ui_skin.gd` 按实际图像边界裁切 AtlasTexture，交互文字、库存和价格由 Godot 动态显示。

## 最终选用素材的完整提示词

```text
Use case: ui-mockup. Asset type: production game UI skin atlas, transparent PNG, landscape 1536x1024. For a Chinese lakeside homestead in a fantasy action RPG. Hand-painted warm walnut wood, patinated bronze fine edges, dark teal leather insets, restrained wheat and leaf motifs, beautifully crafted game interface, crisp readable blank surfaces. EXACT atlas layout in pixel coordinates on 1536x1024 canvas: upper left region x0 y0 w768 h640 is ONE rectangular large modal panel, rounded carved walnut outer edge, bronze corners, dark teal leather center entirely blank, subtle texture and no illustration covering center. Upper right region x800 y0 w704 h192 is ONE horizontal HUD plaque with same materials, blank center. Right region x800 y224 w336 h128 is ONE small blank horizontal button plaque. Right region x1168 y224 w336 h128 is ONE gold-highlighted blank primary button plaque. Right region x800 y384 w704 h256 is ONE blank horizontal info/team panel. Bottom left x0 y672 w384 h320 is ONE blank item card with thin bronze frame and dark leather. Bottom right x800 y672 w704 h128 is ONE slim bottom toolbar plaque. All seven panels isolated with actual transparent gutters, each fits its exact requested rectangle, straight front-on UI view. No text, letters, numbers, symbols, icons, objects outside the specified seven panels, no backdrop, no shadows outside regions. Every panel has generous blank center for dynamic live game text. No mockup screenshot, this is an actual texture atlas.
```

## 验证

Godot 4.7.2 实机渲染通过。`tests/homestead_ui.gd` 53 项检查，覆盖卡片购买、出售、烹饪、携带、卸下餐食、i 弹窗的输入恢复、面板边界以及原有地图和农事流程。另通过 homestead 64 项、camp_activities 89 项、camp_modes 10 项。

实机预览位于 `build/home-overview.png`、`build/home-home_shop-panel.png`、`build/home-kitchen-panel.png`、`build/home-map-guide.png` 和 `build/home-info-home_shop.png`。
