# 3D Boss 制作中：2026-10-11

用户指出程序搭建样板精细度不足，改为调查专门的图片转3D生产路线。本轮模型不是最终美术，不发布新版EXE。

已保存原创参考 art/bosses/references/oath-knight-v1.png，完整提示词在同目录 generation-prompts.json。由 built-in image_gen 生成。Blender源 art/bosses/oath-knight-master.blend 有19根骨骼、15组关键帧，程序样板50284三角形、六材质。只作为动作/坐标/材质接入比较样板。导出器不保存和覆盖源文件，生成器拒绝覆盖已有源。

接入代码默认不启用。只有专用 Preview-Boss-3D.cmd 运行工具设置 CRIMSON_BOSS3D_PREVIEW=1 时启用。故事/远征共享3D世界；闯关采用实时透明SubViewport按原Y顺序合成，尚不是统一3D深度世界。行为、碰撞仍沿用原规则；外观与旧碰撞的一致性尚未验收。未完成全模式战斗/联机/性能验收。

调整的生产路线：统一主体A姿态的正/侧/背面独立参考图 → Meshy/Tripo/Rodin图片转3D → 检查几何而非只看纹理 → Blender分离剑盾与披风、修拓扑/权重/材质 → 动作重定向和Boss专用蓄力/攻击 → 复用表现适配器 → 实景验收。

查询来源：

- https://docs.meshy.ai/en/webapp/image-to-3d
- https://help.meshy.ai/en/articles/16231707-how-to-create-3d-animation-with-auto-rigging
- https://www.tripo3d.ai/blog/multi-view-to-3d
- https://developers.tripo3d.ai/en/docs/generation-image-to-model
- https://hyper3d.ai/features/api
- https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1

已通过插件目录检查 Meshy、Tripo、Hyper3D，均无匹配集成。未提交外部生成、未消耗账号积分、未下载本地大模型。Hunyuan3D2.1原版官方预算形状10GB/纹理21GB/合计29GB，12GB显存不能当作原版全流程可用的保证。
