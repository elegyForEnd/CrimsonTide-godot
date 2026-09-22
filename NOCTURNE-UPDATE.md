# 夜祷怪物 · 哥特惊悚改版

十种原有野外怪物全部使用重新生成的夜祷版图集，另新增三种地区怪物，野外总计十三种。失乡骑士保留原有哥特甲胄图集，三日远征 Boss 使用各自已有素材。

本次造型采用冷灰、炭黑、旧骨白、暗红与锈金，突出骨面、狭长眼睛、破损祭服、黑铁刑具、虫足、枯枝角与幽魂裹尸布。面部和外轮廓保留月光高光，攻击预警仍使用清晰的浅色描边。

| 地区 | 当前怪物 |
|---|---|
| 风铃原野 | 血晶食尸兔、丧钟夜蛾 |
| 白垩旧城 | 哀钟幽灵、禁卷鸦枭 |
| 月晶高地 | 枯月骨鹿、墓翼石像鬼（新增） |
| 蔷薇庭域 | 蔷薇刑偶、赤月灾狐、血棘妖 |
| 雾汐湿地 | 雾汐冥水母、溺钟怨灵（新增） |
| 圣血王庭 | 腐羽狮鹫、提灯刽子手（新增） |

三个新物种使用原有栖息区规则：仅在对应地区的据点区块内生成，校验地形、安全距离与数量上限。M → 4 查看最新物种分布。

- **墓翼石像鬼**：0.9 秒前摇，锁定落点后俯冲；飞行显示抬升，移动经过分步碰撞检查，落地时对 60 单位范围造成伤害。移出落点、打断或利用墙体可以避开。
- **溺钟怨灵**：1 秒前摇，五道扇形钟波飞出 0.75 秒后原路折返，命中或撞墙后消失；返回段改变颜色，玩家需要注意第二次经过的路线。
- **提灯刽子手**：1.05 秒前摇，在锁定方向的 190 单位扇形内发动锁链横扫；扇形之外与身后安全。攻击命中时重新检查距离、角度和遮挡。

## 素材与重建

使用内置 `image_gen`。十套改版图以对应旧图集为物种参考、失乡骑士为哥特细节参考；三种新怪物按相同文字美术规范独立生成。每种十二姿势：四移动、四攻击、两待机、一受击、一战败，共生成十三张图集、156 个姿势。

- 最终提示词及原始生成路径：`assets/enemies/nocturne-prompts.json`。
- 游戏图集：`assets/enemies/*-nocturne.png` 共十张，以及 `grave-gargoyle.png`、`drowned-bell-wraith.png`、`lantern-executioner.png`。
- 原始生图：`output/imagegen/` 下对应十三个同名 PNG；旧版素材保留。
- 六种新增重型怪物已使用 `gpt-image-2.5-sunburst` 重新生成 3264×2448（4K 级）4×3 图集；月晶系使用暗紫、雾汐系使用暗绿/青、圣血系使用暗红。提示词记录在 `assets/enemies/nocturne-heavy-4k-prompts.jsonl`，母版位于 `output/imagegen/nocturne-heavy-4k/`。
- `tools/prepare_nocturne_art.gd` 用 Godot 按四列三行分帧，保留真实 alpha，使用整套统一缩放比例，将每帧落脚点对齐到单元格第 210 像素，输出 1024×768 图集。
- 运行时使用对应落脚锚点渲染；怪物血量、攻击进度、锁定落点、回旋弹状态均通过现有权威快照同步。

## 验证入口

- `tests/nocturne.gd`：新物种栖息地、前摇、命中、闪避、打断、穿墙保护、横扫角度、俯冲帧率稳定性与钟波折返/寿命。
- `tests/nocturne_art.gd`：原图透明度、图集尺寸、十二帧非空、边距和落脚点。
- `tests/ecology.gd` 及原有 enemies / combat / map / city / expedition / systems 回归。
- `tests/ecology_network.gd`：双进程本机同步九种新增生态怪物、栖息区与攻击落点。
- `tests/nocturne_visual.gd`：实际 OpenGL 游戏画面、三种新攻击预警及地图。输出 `build/nocturne-roster-0.png`、`nocturne-roster-6.png`、`nocturne-roster-11.png`、`nocturne-telegraphs.png`、`nocturne-habitats.png`。

独立可执行文件：`dist/CrimsonTide-Nocturne.exe`。
