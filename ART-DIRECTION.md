# 哥特二次元视觉改版

## 本次实现

- 首页：插画上直接绘制五项纵向菜单；宋体标题；细线、菱形游标、渐隐红色选中光带；鼠标悬停和键盘焦点切换；背景浮尘与慢速纹章动画。
- 营地：角色大立绘、呼吸浮动、角色选择条、装备图标选择、天赋等级菱形、队伍席位。取消原来的三列实体方框。
- 背包：保留有实际占位意义的 6×4 网格，使用物品图标和详情大图；统一细金色角饰与深色磨砂底。
- 战斗：分离的头像生命栏、武器弹药、技能快捷区；切角小地图；手绘石板材质、四类怪物精灵、图标掉落、攻击火花与技能粒子。
- 大厅、设置、手册和结算：统一宋体层级、无实体框按钮、渐隐面板和角饰。

所有界面仍为 Godot 原生 Control/Button/Label/TextureRect 与 CanvasItem 绘制，按钮不是图片中不可交互的文字。美术改版未改变联机协议或战斗规则。

## 素材

主菜单继续使用 `assets/keyart.png`。新素材保存在 `assets/portrait-0.png`、`portrait-1.png`、`portrait-2.png`、`enemies.png`、`courtyard.png`。物品和装备图标为 `assets/icons/*.svg`，是原生矢量界面资源。

新增 Noto Serif SC 字体采用 SIL OFL，见 `assets/SERIF-LICENSE.txt`。原 Noto Sans SC 继续用于小字号说明。

## 图像生成方式与最终提示词

使用内置 imagegen 工具生成。立绘以 `camp-sentinels.png` 为编辑参考；初次整张角色表存在相邻角色碎片，因此最终采用独立透明立绘。未采用偏写实的单角色候选图。最终 PNG 保留实际 alpha 通道。

立绘最终提示词模板（三次编辑，分别代入 LEFT silver-haired anime rifle sentinel / CENTER ice-blue-haired anime lantern cleric / RIGHT purple-haired anime katana sentinel）：

> Extract ONLY the [character] from this provided three-character sheet. Make a standalone single-character transparent-background PNG, complete body and all hair and clothing restored where originally cut off. Preserve EXACTLY this reference's drawn anime face, proportions, [black/crimson or blue/teal or black/violet] costume and painterly 2D anime linework. Do not turn her into a realistic woman or 3D render. Remove the other two women completely. No glow backdrop, no scenery, no gradients, no checkerboard pixels: actual alpha transparency everywhere outside the one character. Center her with wide transparent padding. One character only, full body visible.

地面最终提示词：

> Create a square perfectly TOP DOWN orthographic seamless tileable game environment texture: weathered dark blue-gray gothic cathedral courtyard cobblestones. Hand-painted high quality anime dark fantasy RPG environment material. Dense irregular rectangular basalt stones, old cracks, tiny restrained moss and dust in seams, a few very subtle burgundy stains. Low contrast, subdued dark slate gray palette, readable as ground below bright characters. Flat even diffuse moonlight, no objects, no props, no walls, no characters, no text, no UI, no perspective, no horizon, no strong lighting gradient. Seamless tiling on all four edges, 1024x1024.

怪物最终提示词：

> Transparent alpha background game sprite sheet for gothic anime top-down action RPG. Exactly FOUR distinct small enemies in one horizontal row, each centered with generous padding wholly inside its equal quarter of a wide canvas, all same elevated 3/4 front view, complete body visible with feet. No text, no UI, no ground, no shadows. 1: hunched crimson hooded skeletal ghoul in ragged black robe, glowing red eyes, long claws. 2: floating violet-robed cursed witch spirit, faceless hood with glowing mauve eyes, tiny purple orb in hand. 3: bulky dark iron corrupted knight, cracked gothic armor, large heavy axe, glowing red fissures. 4: tall elegant blood antler hunter demon, black ragged armored coat, crimson deer-like horns, long claws, red glowing chest jewel. Hand-painted detailed dark fantasy anime game sprites with strong readable silhouettes, restrained steel gray, charcoal, maroon, pale violet colors, subtle red rim light. Distinct professional sprite illustrations, no photorealism, 3-head-tall stylized proportions for readability.

## 验证

`tests/ui.gd` 覆盖首页及选中状态、三名角色营地、战斗、图标背包、物品详情、地图、手册、结算和再次出发。输出截图在 `build/ui-*.png`。本次美术采用独立插画与程序动作；未把完整骨骼或逐帧动作动画算作已交付内容。
