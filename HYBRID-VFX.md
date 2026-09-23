# 混合战斗特效

## 当前效果

- 单手剑和双手剑：恢复并保留原有素材、加色材质、双层刀光、重剑冲击、命中火花与震屏。
- Boss：原始 4 套主题素材与流动能量 Shader、纹理粒子叠加。直线攻击组合多段等比例素材；扇形叠加快速扫掠；钟鸣与环形冲击保持内圈透明；圆形爆发叠加上升能量柱。
- 演出：登场、转阶段与死亡使用原立绘、侧边字幕、动态法阵、光点和冲击光。侧边演出不会暂停操作或改变联机时序。
- 法杖：8 种原素材按宽高比绘制，加入弹道残影、施法粒子、贯穿能量束及爆炸层。法杖使用独立加色图层，避免误用剑光 3×3 图集的边缘遮罩。

## 素材规则

本次复用现有素材，没有调用生图 API，没有新增或写入 API 凭据。Boss stamp 和法术 stamp 使用等比例缩放；长距离光束通过 shader 生成及重复放置原图表达，未将图片拉长。Shader 渲染区域尺寸代表生成效果的范围，不是图像变形。原有双剑和角色大招按用户要求保留原实现。

## 代码

- `scripts/boss_vfx.gd`：Boss 事件、真实范围预警、素材层和混合特效调度。
- `scripts/energy_bursts.gd`：动态 Shader 节点及 CPUParticles2D 发射器；每个管理器最多 64 个能量层、24 个发射器，到期释放。
- `resources/energy_burst.gdshader`：火焰、能量束、环带、扫掠、聚能五种程序化形态；环带安全中心硬遮罩。
- `scripts/boss_cinematic.gd`：不暂停游戏的侧边立绘演出。
- `scripts/combat_visuals.gd`：原双剑效果与新的法杖独立图层。

## 验证

Godot 4.7.2 / GL Compatibility：

- `tests/boss_vfx.gd`：289 检查通过。
- `tests/spells.gd`：69 检查通过。
- `tests/combat.gd`：78 检查通过。
- `tests/ultimate_release.gd`：41 检查通过。
- `tests/hybrid_vfx.gd`：9 检查通过，覆盖中断清理、地图重置、生命周期、数量上限及双剑不额外挂载新效果。
- `tests/energy_ring_visual.gd`：真实 GPU 渲染像素检查；安全内圈最大 alpha 为 0，环带最大 alpha 为 0.608。
- `tests/boss_vfx_visual.gd`、`tests/slash_alignment.gd`、`tests/spells_visual.gd`：完成四位 Boss、12 个连击方向组合及 8 种法杖画面检查。

预览：`build/hybrid-vfx-preview.mp4`，约 18 秒，四位 Boss 的攻击与转阶段。录制命令：

```powershell
godot --path . --script tests/hybrid_vfx_preview.gd --write-movie build/hybrid-vfx.avi --fixed-fps 30
```

录制场景的平均 CPU/GPU 渲染时间约为 2.99/2.26 ms（RTX 3080 Ti，1280×800）；这仅代表该预览，不代表多人满屏战斗性能。
