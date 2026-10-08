# 全部武器特效核对 · 2026-10-07

69/69 把武器已逐页人工核对，覆盖 21 把远征武器与 48 把闯关武器。每页四角色、三段普攻、战技、普攻飞行、战技飞行/爆发、命中和蓄力，共 2208 格；不存在的弹体或蓄力明确标为不适用。截图使用原始范围等比缩略，不改变素材比例。

完整 GPU 矩阵：69 武器 × 4 角色 × 8 方向 × 4 攻击阶段 × 2 模式 = 17664 组合，每组合检查三个播放时刻。151375 项检查通过，0 失败；包括真实挂点、投影朝向、释放位置、实际接触像素和真实战技起手/出手姿势；另包含 3520 个飞行弹体组合，检查可见性及细长弹体的速度投影轴。独立图页另有 1908 项去掉角色像素后的特效可见性检查，0 失败。

本轮新增修复：重刃白色主体过厚遮住角色（ImageGen motion_heavy_slash_v3）；震地缺少落地冲击感（ImageGen motion_quake_v2）；熔炉巨锤 615、星陨石槌 619 改为破碎冲击环而非剑刃圆斩。真实战技记录自己的前摇；出手边界改为秒数比较，避免 16 把重武器在精确出手时被判回前摇。

生成图直接复制原始 RGBA。完整提示词： [重刃](assets/combat/imagegen-mechanics/prompts/motion_heavy_slash_v3.txt)、[震地](assets/combat/imagegen-mechanics/prompts/motion_quake_v2.txt)；素材出处、尺寸、有效边界与 SHA256 位于 [manifest](assets/combat/imagegen-mechanics/manifest.json)。

已保存并接入的内置 ImageGen 新图：[motion_heavy_slash_v3.png](assets/combat/imagegen-mechanics/motion_heavy_slash_v3.png)、[motion_quake_v2.png](assets/combat/imagegen-mechanics/motion_quake_v2.png)。

人工核对关注：轮廓是否符合武器动作、四角色挂点是否贴合、方向是否一致、主体是否遮挡角色、连击及战技是否可辨、弹体数量/轮廓是否匹配实际机制。八方向的全部组合由 GPU 像素矩阵检查，不宣称每一帧都逐张人工检查。

[浏览全部核对页](build/weapon-full-audit/index.html) · [覆盖数据](build/weapon-full-audit/coverage.json) · [矩阵日志](build/weapon-full-matrix-complete.log) · [图页日志](build/weapon-full-visual-final.log)

| ID | 武器 | 普攻素材用途 | 战技素材用途 | 人工结论 / 修复 | 核对图 |
|---|---|---|---|---|---|
| 0 | 守夜步枪 | muzzle_fire | muzzle_fire | 已核对 | [查看](build/weapon-full-audit/weapon-000.png) |
| 1 | 绯红单手剑 | motion_slash | motion_spin | 已核对 | [查看](build/weapon-full-audit/weapon-001.png) |
| 2 | 破晓双手剑 | motion_heavy_slash | motion_quake | 已核对；重刃遮挡已重画修复；震地已重画修复 | [查看](build/weapon-full-audit/weapon-002.png) |
| 3 | 星辉法杖 | cast_star | cast_star | 已核对 | [查看](build/weapon-full-audit/weapon-003.png) |
| 4 | 赤陨法杖 | cast_fire | cast_fire | 已核对 | [查看](build/weapon-full-audit/weapon-004.png) |
| 5 | 霜针短杖 | cast_ice | cast_ice | 已核对 | [查看](build/weapon-full-audit/weapon-005.png) |
| 6 | 鸣雷之杖 | cast_storm | cast_storm | 已核对 | [查看](build/weapon-full-audit/weapon-006.png) |
| 7 | 月弧法杖 | cast_moon | cast_moon | 已核对 | [查看](build/weapon-full-audit/weapon-007.png) |
| 8 | 曦光棱镜杖 | cast_light | cast_light | 已核对 | [查看](build/weapon-full-audit/weapon-008.png) |
| 9 | 烬羽散华杖 | cast_fire | cast_fire | 已核对 | [查看](build/weapon-full-audit/weapon-009.png) |
| 10 | 虚涡法杖 | cast_void | cast_void | 已核对 | [查看](build/weapon-full-audit/weapon-010.png) |
| 11 | 蚀月长枪杖 | cast_moon | cast_moon | 已核对 | [查看](build/weapon-full-audit/weapon-011.png) |
| 12 | 鸦喙刺剑 | motion_thrust | motion_thrust | 已核对 | [查看](build/weapon-full-audit/weapon-012.png) |
| 13 | 回环弯刀 | motion_spin | motion_spin | 已核对 | [查看](build/weapon-full-audit/weapon-013.png) |
| 14 | 断潮巨刃 | motion_heavy_slash | motion_heavy_slash | 已核对；重刃遮挡已重画修复 | [查看](build/weapon-full-audit/weapon-014.png) |
| 15 | 裂地重剑 | motion_quake | motion_quake | 已核对；震地已重画修复 | [查看](build/weapon-full-audit/weapon-015.png) |
| 16 | 暮羽长弓 | release_bow | release_bow | 已核对 | [查看](build/weapon-full-audit/weapon-016.png) |
| 17 | 黑铁短剑 | motion_slash | motion_thrust | 已核对 | [查看](build/weapon-full-audit/weapon-017.png) |
| 18 | 祭祀短杖 | cast_star | cast_star | 已核对 | [查看](build/weapon-full-audit/weapon-018.png) |
| 19 | 破碎大剑 | motion_heavy_slash | motion_heavy_overhead | 已核对；重刃遮挡已重画修复 | [查看](build/weapon-full-audit/weapon-019.png) |
| 20 | 湮魂之镰 | motion_scythe | motion_spin | 已核对 | [查看](build/weapon-full-audit/weapon-020.png) |
| 600 | 绯红单手剑 | motion_slash | motion_spin | 已核对 | [查看](build/weapon-full-audit/weapon-600.png) |
| 601 | 鸦喙刺剑 | motion_thrust | motion_thrust | 已核对 | [查看](build/weapon-full-audit/weapon-601.png) |
| 602 | 回环弯刀 | motion_spin | motion_spin | 已核对 | [查看](build/weapon-full-audit/weapon-602.png) |
| 603 | 血棘双刃 | motion_double_slash | motion_thrust | 已核对 | [查看](build/weapon-full-audit/weapon-603.png) |
| 604 | 银月细剑 | motion_slash | motion_thrust | 已核对 | [查看](build/weapon-full-audit/weapon-604.png) |
| 605 | 烛影短刀 | motion_slash | motion_thrust | 已核对 | [查看](build/weapon-full-audit/weapon-605.png) |
| 606 | 星霜佩剑 | motion_slash | motion_thrust | 已核对 | [查看](build/weapon-full-audit/weapon-606.png) |
| 607 | 鸣电军刀 | motion_slash | motion_thrust | 已核对 | [查看](build/weapon-full-audit/weapon-607.png) |
| 608 | 断誓直剑 | motion_slash | motion_thrust | 已核对 | [查看](build/weapon-full-audit/weapon-608.png) |
| 609 | 镜花曲剑 | motion_slash | motion_spin | 已核对 | [查看](build/weapon-full-audit/weapon-609.png) |
| 610 | 葬铃仪剑 | motion_slash | motion_thrust | 已核对 | [查看](build/weapon-full-audit/weapon-610.png) |
| 611 | 黑曜戒律剑 | motion_slash | motion_thrust | 已核对 | [查看](build/weapon-full-audit/weapon-611.png) |
| 612 | 破晓双手剑 | motion_heavy_slash | motion_heavy_slash | 已核对；重刃遮挡已重画修复 | [查看](build/weapon-full-audit/weapon-612.png) |
| 613 | 断潮巨刃 | motion_heavy_slash | motion_heavy_slash | 已核对；重刃遮挡已重画修复 | [查看](build/weapon-full-audit/weapon-613.png) |
| 614 | 裂地重剑 | motion_heavy_spin | motion_heavy_spin | 已核对 | [查看](build/weapon-full-audit/weapon-614.png) |
| 615 | 熔炉巨锤 | motion_hammer_spin | motion_hammer_spin | 已核对；锤类选图已修复 | [查看](build/weapon-full-audit/weapon-615.png) |
| 616 | 霜骨战斧 | motion_heavy_slash | motion_heavy_slash | 已核对；重刃遮挡已重画修复 | [查看](build/weapon-full-audit/weapon-616.png) |
| 617 | 雷骸重剑 | motion_heavy_slash | motion_heavy_slash | 已核对；重刃遮挡已重画修复 | [查看](build/weapon-full-audit/weapon-617.png) |
| 618 | 血狱斩首刃 | motion_heavy_slash | motion_heavy_slash | 已核对；重刃遮挡已重画修复 | [查看](build/weapon-full-audit/weapon-618.png) |
| 619 | 星陨石槌 | motion_hammer_spin | motion_hammer_spin | 已核对；锤类选图已修复 | [查看](build/weapon-full-audit/weapon-619.png) |
| 620 | 余烬壁刃 | motion_heavy_slash | motion_heavy_slash | 已核对；重刃遮挡已重画修复 | [查看](build/weapon-full-audit/weapon-620.png) |
| 621 | 风暴战戟 | motion_narrow_sweep | motion_heavy_slash | 已核对；重刃遮挡已重画修复 | [查看](build/weapon-full-audit/weapon-621.png) |
| 622 | 冥潮仪镰 | motion_scythe | motion_heavy_spin | 已核对 | [查看](build/weapon-full-audit/weapon-622.png) |
| 623 | 无名王剑 | motion_heavy_slash | motion_heavy_slash | 已核对；重刃遮挡已重画修复 | [查看](build/weapon-full-audit/weapon-623.png) |
| 624 | 守夜步枪 | muzzle_fire | muzzle_fire | 已核对 | [查看](build/weapon-full-audit/weapon-624.png) |
| 625 | 暮羽长弓 | release_bow | release_bow | 已核对 | [查看](build/weapon-full-audit/weapon-625.png) |
| 626 | 血棘连弩 | release_bow | release_bow | 已核对 | [查看](build/weapon-full-audit/weapon-626.png) |
| 627 | 烬鸦火铳 | muzzle_fire | muzzle_fire | 已核对 | [查看](build/weapon-full-audit/weapon-627.png) |
| 628 | 霜月猎弓 | release_bow | release_bow | 已核对 | [查看](build/weapon-full-audit/weapon-628.png) |
| 629 | 雷翼卡宾枪 | muzzle_fire | muzzle_fire | 已核对 | [查看](build/weapon-full-audit/weapon-629.png) |
| 630 | 黑曜长枪 | muzzle_fire | muzzle_fire | 已核对 | [查看](build/weapon-full-audit/weapon-630.png) |
| 631 | 镜轨双铳 | muzzle_fire | muzzle_fire | 已核对 | [查看](build/weapon-full-audit/weapon-631.png) |
| 632 | 逐风短弓 | release_bow | release_bow | 已核对 | [查看](build/weapon-full-audit/weapon-632.png) |
| 633 | 断誓穿甲枪 | muzzle_fire | muzzle_fire | 已核对 | [查看](build/weapon-full-audit/weapon-633.png) |
| 634 | 葬铃灵弩 | release_bow | release_bow | 已核对 | [查看](build/weapon-full-audit/weapon-634.png) |
| 635 | 晨曦信号枪 | muzzle_fire | muzzle_fire | 已核对 | [查看](build/weapon-full-audit/weapon-635.png) |
| 636 | 星辉法杖 | cast_star | cast_star | 已核对 | [查看](build/weapon-full-audit/weapon-636.png) |
| 637 | 赤陨法杖 | cast_fire | cast_fire | 已核对 | [查看](build/weapon-full-audit/weapon-637.png) |
| 638 | 霜针短杖 | cast_ice | cast_ice | 已核对 | [查看](build/weapon-full-audit/weapon-638.png) |
| 639 | 鸣雷之杖 | cast_storm | cast_storm | 已核对 | [查看](build/weapon-full-audit/weapon-639.png) |
| 640 | 月弧法杖 | cast_moon | cast_moon | 已核对 | [查看](build/weapon-full-audit/weapon-640.png) |
| 641 | 曦光棱镜杖 | cast_light | cast_light | 已核对 | [查看](build/weapon-full-audit/weapon-641.png) |
| 642 | 烬羽散华杖 | cast_fire | cast_fire | 已核对 | [查看](build/weapon-full-audit/weapon-642.png) |
| 643 | 虚涡法杖 | cast_void | cast_void | 已核对 | [查看](build/weapon-full-audit/weapon-643.png) |
| 644 | 蚀月长枪杖 | cast_moon | cast_moon | 已核对 | [查看](build/weapon-full-audit/weapon-644.png) |
| 645 | 血契仪杖 | cast_moon | cast_moon | 已核对 | [查看](build/weapon-full-audit/weapon-645.png) |
| 646 | 冥庭唤魂杖 | cast_soul | cast_soul | 已核对 | [查看](build/weapon-full-audit/weapon-646.png) |
| 647 | 晨钟祈愿杖 | cast_bell | cast_bell | 已核对 | [查看](build/weapon-full-audit/weapon-647.png) |
