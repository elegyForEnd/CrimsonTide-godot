# 圣堂 UI 美术更新

使用内置 imagegen 生成并接入 Godot 原生 UI。营地使用独立圣堂背景；16 类物品使用统一透明图集，覆盖装备、天赋、背包物品、详情、拖拽预览及 HUD。按用户反馈恢复此前的界面布局、细线装饰、文字角色切换和无实心底板按钮；移除新增卡片与角色缩略图，保留新生成的背景和物品素材。营地保留适合圣堂背景的亮度，使用原有渐变遮罩保障文字可读性。

## 文件

- `assets/ui/sanctuary.png`：营地与次级页面背景。
- `assets/ui/reliquary-transparent.png`：最终透明物品图集，4 × 4，通过 AtlasTexture 使用原图区域，无需切图。
- `assets/ui/reliquary-atlas.png`：保留生成时的背景版本。
- `scripts/ui_art.gd`：共享图集区域与缓存；旧 SVG 保留作为未收录图标的回退。

## 最终提示词

### 圣堂背景

Use case: stylized-concept. Asset type: production background illustration for a gothic anime RPG equipment camp UI, landscape 1536x1024. A moonlit sanctuary inside a ruined gothic cathedral, elegant hand painted anime game environment, midnight navy, muted antique gold and restrained burgundy, luminous fine detail. Composition: left third a beautiful tall pointed arched window with a distant pale blood moon, cool moonlight on a circular stone dais in the lower left for a separate character sprite. Right two thirds are quiet dark blue-black shadowed stone wall and soft atmospheric darkness to provide legible space for overlay equipment UI. Thin columns at far edges, small candles near floor, delicate crimson roses near bottom left, exquisite stone tracery. No people, no characters, no objects in the center or right UI reading area, no text, no lettering, no UI panels, no watermark. Sophisticated restrained lighting, readable silhouettes, painterly premium fantasy game art, not photorealistic. Fill the entire canvas.

### 物品图集

Use case: stylized-concept. Asset type: one production RPG inventory icon atlas, 1024x1024 square, EXACTLY 4 columns by 4 rows of equally sized 256px cells, no gaps between cells. All 16 objects centered exactly in their respective cells, isolated, full object inside central 72 percent of its cell with generous padding. Uniform solid midnight navy background #0d121c, no borders, no text, no letters, no numbers, no grid lines, no watermark, no backdrop scenes. Hand painted premium gothic anime fantasy equipment illustrations, exquisite readable silhouettes, antique gold filigree, blackened silver, crimson gems, teal potion glass, soft moonlit metallic highlights. Each is a single large readable game item. Row 1 left to right: black silver gothic breastplate with red gem; antique gold optical rifle scope with red lens; pair of elegant black leather raven boots; teal glass healing syringe with ornate metal fittings. Row 2 left to right: cluster of three vivid red blood crystals; silver clockwork gears; ornate gold crescent moon relic around ruby; silver raven pendant with amethyst. Row 3 left to right: brass rifle cartridge ammo clip; burgundy leather expedition backpack; long gothic flintlock rifle diagonal; slim crimson single handed sword diagonal. Row 4 left to right: massive silver two handed greatsword diagonal; moon crystal sorcerer staff diagonal; ruby heart jewel in delicate gold setting; violet crescent moon magical skill emblem. Keep order exact. Objects should look substantial and polished with painterly dimensional shading, not simple flat vector symbols. Consistent object scale, absolutely no crossing cell boundaries.

### 透明背景处理

Use case: background-extraction. Edit target: provided 4x4 gothic inventory item atlas. Remove ONLY the dark navy background from all sixteen cells, replacing it with genuine transparent alpha. Preserve all sixteen objects, their precise grid arrangement, full silhouettes, colors, details, positions and scale. Do not redraw, move, resize, add or remove any item. Keep the square canvas and exact four rows and four columns. Preserve dark metal, black leather, raven wings and shadows that belong to the items. Remove background between objects and inside open loops, keep no black square backplates. Output actual transparent PNG, no checkerboard pattern, no text.

## 验证

界面回退后再次运行 `tests/ui.gd`，结果为 `UI INTEGRATION: 0 failures`，并检查营地截图。回退验证日志：`build/ui-rollback-test.log`。

运行 Godot 原生窗口下的 tests/ui.gd，最终结果：UI INTEGRATION: 0 failures。检查了营地与物品详情截图，覆盖原测试中的选择、拖拽、旋转、装备、地图、结算和再次出发。日志：build/ui-art-test-final.log；截图：build/ui-camp.png、build/ui-inventory-selected.png。

编辑器导入时，项目原有 pv 目录中的两份 WAV 报非 PCM 格式错误；新 UI 纹理导入与 UI 测试均成功。此次未修改这些 PV 音频。
