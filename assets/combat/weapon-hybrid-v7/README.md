# 武器混合特效素材

用户授权使用生成参考图里的特效部分，与独立运动、拖尾、烟雾和命中反馈结合。

本目录新增 **14 张彩色展开材质、4 张独立命中素材**，由内置 ImageGen 依据既有武器参考图重新制作；完整提示词和生成器原文件位置保存在 [generation.json](generation.json)。镜面材质复用已制作的 `../crystal-cut-v1/ribbon.png`，合计 15 种材质词汇。没有将完整人物战斗截图作为运行贴片。

这些材质与 `../imagegen-mechanics/weapon-v5/` 中 **52 把武器各自独立的展开素材**共同采样。枪箭和法术弹体使用项目原有的独立彩色弹体素材，按真实弹道飞行；原生网格继续控制轨迹、分叉、碎片与收尾。

- `metal / blood / tide / frost / storm / stone / cloth / soul / void / feather / star / sun / bell / heat.png`：彩色表面细节。
- `stone-impact / frost-impact / tide-impact / heat-impact.png`：底部锚定的独立接触爆发；不是整招动画，独立扩张、消散并配合飞散网格。
- `materials.json`：透明边界对应的采样 UV、原图尺寸、SHA-256。

PNG 原始 RGBA 未经重绘、裁切或抠色。工具只测量 alpha 边界并配置 UV 与 mipmaps。烟尘复用 `../imagegen-mechanics/smoke-v3/` 的独立密度图。

运行文件：`scripts/weapon_hybrid_design.gd`、`scripts/weapon_hybrid_material.gd`、`scripts/weapon_projectile_vfx_3d.gd`。闯关透明视口使用预乘 alpha 合成，修正同一透明度被重复乘算造成的发淡。

实机对照：`build/vfx-hybrid/index.html`。页面同时提供同段录像的近景和完整范围、三种招式与实际使用的贴图。近景仅裁切录像，没有二次增加特效。
