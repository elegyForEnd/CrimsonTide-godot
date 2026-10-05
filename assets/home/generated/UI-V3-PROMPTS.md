# 血潮家园 UI v3

生成方式：内置 ImageGen。风格参考为项目现有 `assets/ui/sanctuary.png` 与 `assets/ui/rogue-inventory-sanctum-v2.png`。整体构图采用血月、哥特拱窗、暗红帷幕、黑石与细金属刻线。所有素材已保存到本目录，控件图集保留生成 alpha，没有用脚本抠图或绘制替代图像。

界面使用整体背景与无独立外框的物品陈列；说明收纳于 i。真实三维家园增加轻微边缘暗化和降低饱和度的画面处理。地图仅用于设施导览，不参与碰撞或寻路；原点击归一化坐标保持不变。

## 整体界面背景

最终路径：`D:/develop/school/CrimsonTide-godot/assets/home/generated/hearthhaven-sanctum-v3.png`

```text
Use case: ui-mockup. Asset type: actual dark gothic action-RPG homestead menu background, landscape 1536x1024. Reference images are style references only: match Crimson Tide's existing sanctuary and inventory art, blood moon, weathered black stone, black iron, muted wine-red silk, sparse aged silver and very dim antique bronze fine linework. Primary request: one elegant composed background painting for a home shop and cooking menu, no mockup UI, no text. Composition: LEFT 29 percent is an atmospheric vertical illustration of a Gothic lakeside refuge seen from beneath a pointed arch: distant sharp bell tower and quiet lake beneath a small veiled blood moon, two weak candle flames at bottom, a tiny foreground herb garden and medieval iron cooking pot, with dark red curtain at far left. Illustration flows softly into shadow by x470. RIGHT 71 percent (x470 to1536) and TOP title space must be almost uniform charcoal-black subtly textured old slate, quiet readable negative space for interactive item pictures and live text. A single understated outer margin with hairline worn metal trim, tiny thorn carvings at outer corners, never thick ornamental frames; no internal frames, panels, cards, slots, grid, buttons, illustration or large symbols in right 71 percent. The right negative space extends from y80 to y920; bottom edge a very faint crimson fog fade. Premium painterly dark fantasy, cinematic chiaroscuro, restrained contrast, sophisticated editorial composition, no brightly lit gold, no wood, no green leather, no decorative leaves, no mobile game gold frames, no cheerful harvest look, no watermark. Front-on interface backdrop, exact 3:2 canvas.
```

## 控件图集

最终路径：`D:/develop/school/CrimsonTide-godot/assets/home/generated/hearthhaven-chrome-v3.png`

```text
Use case: ui-mockup. Asset type: actual transparent game UI component atlas for Crimson Tide, a gothic blood-moon fantasy action RPG. 1536x1024 canvas, straight front-on. Style matches the supplied sanctuary/inventory reference: matte charcoal black iron, tiny dark wine-red accents, fine scratched tarnished silver trim, sparse needle-thin gothic pointed corner flourishes. Extremely restrained elegant dark UI, interiors nearly black flat slate. Never bright gold, wood, emerald, green leather, thick 3D bevels, harvest motifs, foliage, big ornaments, excessive borders. Layout SIX components, exact regions requested: x0 y0 w736 h192 one wide title HUD surface, black cloudy slate with softly feathered transparent edges, no obvious rectangle border, subtle single 1px crimson underline. x800 y0 w704 h288 one small team HUD surface, same barely perceptible edging with small pointed upper corners, generous empty center. x0 y256 w480 h112 one plain understated rectangular navigation button, 1px silver contour, softly feathered dark interior. x0 y416 w480 h112 one primary action button, same silhouette with faint dark crimson lit interior and delicate short crimson underline. x0 y608 w704 h288 one blank information panel with slate interior and hairline fine gothic corners. x800 y352 w704 h112 one extremely slim toolbar background, softly feathered black smoke, single faint fine line along top. These SIX components must be isolated from each other, with REAL alpha transparency everywhere outside them. No checkerboard rendered, no opaque background, no shadows outside regions. All centers blank; no letters, text, numbers, icons, jewels, seals, faces. Do not create screenshot or app mockup; only six production blank UI bitmap surfaces. Interior opaque, exterior alpha=0.
```

## 地图导览

最终路径：`D:/develop/school/CrimsonTide-godot/assets/home/generated/hearthhaven-map-v3.png`

```text
Use case: lighting-weather. Edit target: Image 1 is the homestead guide map. Image 2 is STYLE REFERENCE only, Crimson Tide's dark gothic sanctuary. Transform Image 1's lighting and subtle surface appearance to match this game's dark blood-moon gothic theme: nocturnal cold charcoal stone, dark wine-red canvas roofs, muted desaturated plants, deep silver-blue lake, little crimson moonlight reflected on water, sparse small candle glow. Preserve the exact square canvas, top-down map composition and EVERY landmark's exact position, silhouette and dimensions, including 3 tents top, 3x3 vegetable beds upper left, kitchen upper center, pier upper right, circular stone meeting table center, merchant booth lower left, supply crates bottom middle-left, shrine lower middle, forge lower right, gateway bottom. Preserve paths, shoreline and garden cell grid so existing game clickable hotspots still align. Do not add new architecture, frames, UI, moons in the map, text, numbers or symbols. Refine the style from cheerful orange/green to richly painted Gothic charcoal/crimson, keep landmark details readable, do not crush everything into black. Same exact geometry, only lighting, colors, delicate material and textile styling. No golden UI frames.
```

## 验证

Godot 4.7.2：homestead_ui 53 项、camp_activities 89 项、camp_modes 10 项均通过。编辑器导入无脚本编译错误。实机截图检查：build/home-home_shop-panel.png、build/home-kitchen-prepared.png、build/home-overview.png、build/home-map-guide.png、build/home-info-home_shop.png。
