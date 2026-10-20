# 本机技能特效研究与实现记录

研究目标：参考用户提供的《英雄联盟》安装包，改进血潮守望特效的分层、节奏、材质表现。研究日：2026-10-18。所有游戏资源只读；解码后的参考图仅放在忽略的 `build/lol-vfx-study/reference-textures/`，未加入运行素材。

## 证据与边界

- 实际调用 REA MCP 的 `open_binary`，识别 `Game/League of Legends.exe` 为 x86_64 PE，SHA-256 为 `ee3c887b4579aeab12ca77b2a43cc1cc3411a8aa30bc43d2dfea856f6ce497c8`。
- REA 会话报告没有可用的原生分析后端：Ghidra 未配置，Hopper 不支持 Windows，IDA MCP 未配置。因此没有声称反编译或观测到实际渲染函数。
- REA 打开 `Lux.wad.client` 返回 unsupported binary format。随后改用本地格式解析器；这些结果属于本地包的静态观察，**不是 REA Evidence**。REA 诊断保存在 `build/lol-vfx-study/rea-status.json`；已关闭 REA 会话。
- 格式参考 [CDTB 源码](https://github.com/CommunityDragon/CDTB/tree/3367589fdd3ee3d0d01383d2f98dba12b04d1371/cdtb)、[LeagueToolkit TEX 文档](https://wiki.leaguetoolkit.dev/reference/file-formats/tex/)。WAD 3.4 分块按 SubChunkTOC 边界解压，校验每块 XXH3 与解压大小；纹理用 DDS 解码到 PNG。
- 不启动客户端、不注入进程、不修改安装包。静态属性中的寿命、blendMode 等不能单独证明最终合成或玩法时长。

## 观察到的配置

从各英雄 skin0.bin 开始，只跟随包内明确链接的配置，逐个记录 member 路径、偏移、解压大小和 SHA-256：

| 包 | 读取配置成员 | 特效系统 | 复杂发射器 |
|---|---:|---:|---:|
| Lux | 16 | 37 | 278 |
| Ashe | 15 | 19 | 117 |
| Yasuo | 21 | 82 | 390 |

这些是基础皮肤入口及其共享依赖的数量，不代表所有皮肤或运行时同时存在的数量。选取示例最多展示每系统前 16 个发射器，未知字段没有被猜测为已解码字段。

- `Lux_Base_E_tar_nova` 有 11 个发射器，包含短 flash、CenterFlare、shockwave、motes、distortion；配置中的 flash particleLifetime 为约 0.1 秒，motes_RAINBOW 为约 0.8 秒。
- `Ashe_Base_R_tar` 有 8 个发射器，包含 snow_flurry、frost_smoke、ring、smoke、Frozen_Ground。短冲击与后续雾层分开。
- `Yasuo_Base_Q_hit_tar` 有 5 个发射器，包括 bloodstrands、blast、suckin、flash、bloodball；可见网格型 primitive、独立纹理和颜色曲线。

实际解出 12 张 128–256 像素的原始特效纹理，另制作 RGB/Alpha 对照图 `build/lol-vfx-study/reference-textures/lol-original-textures.jpg`。可见灰度烟纹、软光点、条状光纹及少量大块碎片；它们不是每张都画好一个完整技能，而是供发射器、网格和材质组合的零件。

重跑：

```powershell
git clone --depth 1 https://github.com/CommunityDragon/CDTB.git build/reference-tools/CDTB
git -C build/reference-tools/CDTB checkout 3367589fdd3ee3d0d01383d2f98dba12b04d1371
python -m pip install --target build/reference-tools/python zstandard==0.25.0 xxhash==4.0.1
python tools/inspect_lol_vfx.py 'H:\game\WeGameApps\英雄联盟'
python tools/inspect_lol_textures.py 'H:\game\WeGameApps\英雄联盟'
```

另需本地已有的 Pillow、requests。运行时代码不依赖这些研究工具或第三方包。

## 当前实现状态（2026-10-19）

全部 48 把武器与 21 个剧情/临时入口已接入空间网格、粒子与密度材质组合，详细架构、模式差异、预算、验证与预览命令见 [weapon-vfx-3d.md](weapon-vfx-3d.md)。刀光按动作路径逐段生成；弹体按真实 fx_id 留下历史拖尾。贴图、颜色、网格和粒子由同一武器描述表统一。主刀光与亮芯已按实战反馈增强，烟雾保持次要层次。

22 张选定原创素材保留原始像素、prompt、尺寸和 SHA-256；空间层使用密度图和弹体零件，其余完整释放原画保留兼容来源。早期被拒绝的粗糙水刃不在生产覆盖表中。没有复用解码的英雄联盟运行资产。

本机静态配置明确出现 Yasuo 风墙的 VfxPrimitiveMesh（yasuo_w_windwall_mesh.scb），Q 风弹的 tornado/tornado_shape 网格，以及 Q windstrike 的 VfxPrimitiveArbitraryQuad。结合 Riot 对洛的三角形插值拖尾的公开说明，可确认应学习多种 primitive、发射器与材质协作。不能仅凭截图断言用户两张特定皮肤截图的每一层实现。

参考：[Riot 拖尾性能分析](https://www.riotgames.com/en/news/profiling-real-world-performance-league)、[Godot 三维粒子拖尾](https://docs.godotengine.org/en/stable/tutorials/3d/particles/trails.html)。Compatibility 不支持 Godot 内置粒子 trails；这里采用有限顶点的 ArrayMesh 空间拖尾，保留正常深度测试。
