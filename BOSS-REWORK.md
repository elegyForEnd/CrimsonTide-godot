# Boss 招式与特效重做

2026-10-06 动作联动更新：当前规范见 [BOSS-ATTACK-DESIGN.md](BOSS-ATTACK-DESIGN.md)。覆盖 104 招，恢复身体出招，近战采用身体锚点与接触路径，新增三套有准备、接触、收尾状态的逐帧图集。下文为旧版本制作记录，“无刀光姿态”“完整地面实体即判定”等说明不再适用于近战。

覆盖 17 种 Boss 身份与 73 个独立编排的招式。参考深度链接最新的 `Monster_Attack_Research/BOSS_MOVES_AND_STAGING.md`，借鉴多段动作、持续弹体、机关联动与强招收招的制作方式；没有复制苍翼的贴图或源码。

## 独立美术与招式

| Boss 身份 | 独立素材 | 战斗机制 |
|---|---|---|
| bell | pendulum / score / fracture / dial | 钟摆逐拍、止声错拍、可破坏钟塔 |
| thorn | bramble / seed / root / hunt | 荆种落地生根、根结解除囚庭、蛇行藤鞭 |
| queen | sabres / regalia / petals / crown | 悬剑落点、旋转御令、棋盘间隙、破冠取消攻击 |
| hidden | rift / hands / ribcage / tomb | 裂隙鬼手、枯骨牢门、墓碑召魂、迁葬易位 |
| mirror | frame / thread / glass / loom | 多节点折射、纺线、可破坏倒映、碎镜雨 |
| ember | censer / moths / pyre / vesper | 香炉持续火道、早段追踪烬蛾、灭灯取消晚祷 |
| moon | eye / drop / artery / eclipse | 扫动血瞳、凝血种植、脉络拖拽、吸引后爆发 |
| earth | furrow / plate / stalactite / fault | 钻地折返、可破坏石甲、穹顶落岩 |
| storm | feather / chain / eye / plume | 雷羽返回、连锁雷笼、旋转风眼、超载后长收招 |
| abyss | maw / current / tide / devour | 吸引后噬咬、错齿落点、换岸潮流、深潜易位 |
| dragon | icicle / breath / wings / frost | 持续扫庭吐息、残留冰区、可破坏冰柱遮挡吐息 |
| grove | roots / spore / bloom / mycelium | 根网减速、孢荚、打碎滋养菌冠阻止回血、召生 |
| furnace | chain / rivets / hammer / kiln | 锁链拖拽、炽铆连射、破坏阀门取消喷发、过载 |
| astral | prism / refraction / starfall / orrery | 折射路径、星棱环游、陨星三拍、镜位替身 |
| wing | gust / return / cyclone / helm | 逆风推动、回旋雷翼、移动风眼、折线位移 |
| obsidian | scar / echo / rain / seal | 墨影三次易位、悬剑雨、四角安全布局、拔刀长收招 |
| knight | slash / lance / burst / crest | 踏步返刃、残影易位、可破防架势、拔剑留反击窗 |

## 范围与缩放约定

- 68 张内置 ImageGen 原创 RGBA 图片，每张独立 PNG，均至少 1024 像素；路径、哈希与尺寸见 `assets/bosses/imagegen/manifest.json`，精确提示词见每张图旁的 `.prompt.txt`。第一版通用模板废稿已移到 output，运行时不会寻址它们。
- 图片只做等比例缩放；长路径以相同尺度的完整图片分段排布。UV 按世界平面距离换算，不把正方形拉成长条。
- **完整发光地面实体（含主体色区）**与伤害几何共用 `boss_geometry.gd`。透明的图片细节用于丰富实体，不会在其外产生伤害；受击依据完整地面实体，而非把图片每根细丝都作为单独伤害框。
- 同一数据驱动预警、持续危险、旋转、移动、内圈、缺口与 GPU 裁切。弹体使用本帧前后位置形成的可见扫掠胶囊。
- 冰柱遮挡区域的 CPU 与 GPU 均以同样的圆形遮挡投影扣除。新 Boss 伤害实体不再额外暗中叠加地图视线遮挡；地形阻挡仍约束角色移动。
- 仍可见的释放实体可以命中后来进入者，每次接触只命中一次；闪避/无敌、生命状态和持续攻击间隔仍参与最终扣血。
- 移除旧攻击动画内嵌的大刀光，新招式使用原有无刀光角色姿态与独立特效；未声称重新绘制整套 Boss 身体动画。

## 验证

- `tests/boss_damage_geometry.gd`：38,942 项，包含 GPU 渲染像素与 CPU 范围比对、旋转和移动、内圈与缺口、遮挡阴影、方形及非方形贴图等比例缩放。零失败、GPU 零差异。
- `tests/boss_choreography.gd`：910 项，验证 73 个招式、机关取消、弹体路径、前摇、反击窗口、打断、晚进入释放范围的伤害。
- `tests/boss_redesign.gd`：744 项；肉鸽 Boss 438 项；Boss VFX 425 项；Boss AI 186 项；Boss 身体素材 139 项；战斗、角色武器特效与旧特殊 Boss 回归通过。
- 主机/客户端新招式网络验证通过。实战截图覆盖主 Boss、八个特殊身份及五名肉鸽 Boss 的 25 招预警与释放。

## 试玩与预览

`build/CrimsonTide-boss-redesign.exe` 为本次独立导出。`build/boss-effects-1.png`、`boss-effects-2.png`、`boss-effects-3.png` 是三页独立美术总览。实战截图位于 build 的 boss-choreography、boss-special-choreography 和 rogue-choreography 前缀文件。

已直接加载导出的 exe 内嵌资源包验证：招式 910 项、素材 744 项、GPU 与伤害范围 38,942 项全部通过。最终产物约 938 MiB，未覆盖旧 dist 导出。
