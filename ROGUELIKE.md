# 魔境闯关 · 五层肉鸽模式

闯关装备提供独立属性与被动：12 件防具 / 饰品、4 种武器铭刻，完整数值与构筑见 [闯关装备设计](ROGUE-EQUIPMENT.md)。

开始游戏进入共同营地。走到南侧「搜打撤闸门」进入搜打撤，走到东侧紫色「魔境传送门」进入五层闯关，靠近按 E 或 Space。创建/加入房间后也进入同一个营地，两种模式都支持最多 4 人合作。

## 玩法

- 五层：幽光菌林、魔焰铸炉、星晶幻境、风暴空港、黑曜魔宫。
- 每层走 8～9 个房间（全图 14～16 个节点），每条路线至少 6 场战斗，含守层者。前两区普通战斗，第 3 区必经圣坛，第 4 区战斗/精英，第 5 区商店/宝藏；后段继续战斗，九房层在第 7 区提供「继续战斗 / 特殊房」分支，随后挑战门前战斗与守层者。八房层没有额外服务房，避免连续补给。特殊房保留诅咒、事件、锻炉、赌局和镜像，整局前 3 层内保底可遇一次镜像。图由 seed_value 与层号确定性生成，守层者仍是本层唯一且最深的节点；普通/挑战首领选择保留。
- 战斗地图宽 3600 游戏单位，摄像机跟随角色横向与纵向卷动；每区三段遭遇，向右探索触发后续敌群。商店、宝藏和圣坛使用 3000 游戏单位宽的独立紧凑房间。
- 每区按对应背景图的可见地面校准碰撞轮廓，使用种子生成实体障碍排列；障碍完整底部占地必须落在地面内，沿两侧摆放并留出可通行间隙；末端短距离分叉为一条直行、一条向画面右上转向的平地路线。两条路线没有高差，不设置门或传送门。背景分段使用统一的纹理坐标铺设，保持平地和铺装线条自然，避免按碰撞边缘扭曲图片造成台阶感。场景物件按照脚底位置遮挡排序。
- 人物走路与闪避只推进到最后一个可行位置；碰到边界或障碍后停止，没有移动后的安全点回推、传送或自动滑动。安全点查询仅用于怪物生成。
- 魔焰铸炉有三个岩浆池。橙红池面的椭圆范围每秒造成 14 点基础伤害，受减伤加成影响；离开范围立即停止。奖励选择与清场休息阶段不受岩浆伤害。
- 清场获得本局魔晶并出现品质宝箱。靠近按 E 开箱，只爆出装备、武器、天赋各一份秘藏，全队共用，不随人数增加。装备三选一、武器三选一、天赋三选一分别抽取三个不同的同类候选；刷新保持类别。每份保留随机品质，天赋数值随品质提升。掉落带飞散、浮动和品质光效。
- 奖励可以「选择并领取」或「选择并丢给队友」。丢出的奖励保持原品质、铭刻、被动与天赋数值；队友靠近按 E 直接领取，不会再次随机。行囊的丢弃也改为真实地面掉落，可重新拾取。替换的装备仍放入本局备用背包。
- 个人奖励界面使用内置 ImageGen 生成的完整宝藏祭坛插画，配合缩放弹出、逐项显现、贴图粒子和悬停反馈。可花刷新卡重抽个人候选，或放回地面稍后选择；放回再拾取保持原候选，不能免费刷新。图片与完整生成提示位于 `assets/ui/rewards/`。
- 商店使用本局魔晶，可购买多件，每件只能买一次。刷新卡重抽当前奖励或商店，过期界面点击会被拒绝。
- 三份秘藏全部完成选择（领取或分享均可）后右侧两条路线开放，队伍自行分配，无需每人领取，四人队伍也不会卡住。队员倒地或断线时会放回未选完的秘藏。全队存活成员靠近分叉、救起倒地成员且没有待选择奖励后，任意队员靠近目标路线末端按 E，一起进入下一区。未拾取掉落只保留在当前区域。走到本局最后一层的守层者节点、完成结算后本局结束（节点总数随种子为 35~50 个）。
- 开局使用已有城邦金币购买刷新卡（20/张，最多 5 张），可选绿色初始武器（60 金币），或免费使用当前角色自带武器。费用只在成功启动时扣除。
- 每局免费携带一支急救针。倒地可以按 F 自救一次；队员可以互相救援；全部成员失去战斗能力后本局结束。
- 角色与城邦加成使用当前存档配置，新增构筑加成仅在本局存在。存档中的背包和次元口袋不带入、不丢失。本局装备不带回仓库。
- 完成区域结算每区 12 金币，通关额外 250 金币。失败也按已完成区域结算，结算只支付一次。

控制：WASD 移动与地面前后走位、鼠标瞄准、左键攻击、右键战技、空格闪避、Q 技能、F 使用急救针、E 出口、TAB 行囊与属性。此模式没有搜打撤大地图或撤离点。

## 魔境扩展（2026-10-05 · 节点图 / 深渊变数 / 专属房间 / 守层者池 / 每日挑战 / 灰烬成长树）

> 本节说明 2026-10-05 晚扩展的**现状**（哪些已接线、哪些仍是数据层）。逐条契约与裁决见
> [ROGUE-CONTRACTS.md](output/ROGUE-CONTRACTS.md)；系统 × 接线状态台账、已知红与已知局限见
> [ROGUELIKE-EXPANSION-SUMMARY.md](output/ROGUELIKE-EXPANSION-SUMMARY.md)。

### 1. 层间节点图（取代固定「每层七区」）

每局关卡结构由 `RogueGraph.build(seed_value, floor)` 确定性生成：节点数 ∈ [7,10]、深度 7~9、每层**唯一守层者且最深**、每节点出口 ∈ [1,2]、无死路且从入口全部可达。种子只由 `seed_value` 与层号派生（**局部 RNG**，不消耗 `s.rng`），因此同种子必得同一张图，客户端可本地重建；上图不进快照。地形与碰撞仍由 `RogueMap.region_key` 按节点所属区域选择。

实现位置：`scripts/rogue_graph.gd`（`build/kinds/neighbors/node/signature`、兼容投影 `legacy_areas/from_route`）、`scripts/roguelike.gd` 的 `new_floor()`/`enter()`；验收 `tests/rogue_graph.gd`（83608 检查 / 0 失败）。

### 2. 深渊变数（每层 1 条 · 全队共享 · HUD 可见）

进入新层时抽 1 条变数，全队共享并显示在 HUD 上（例：「血月：敌人伤害 +15% · 掉落品质 +1 档」）。共 **18 条**（boon / bane / mixed 混合），带权重与最小层数门控，同一局内不重复（`raid.variants_seen` 去重）。效果覆盖：受击、普攻、移速、敌人生命/移速/伤害、敌人弹幕弹速与尺寸、魔晶/经验/掉落品质/商店价格/精英出现率。

**红线**：敌人弹幕只影响速度与表现层字段 `bullet_visual`，**命中判定几何一律不变**（`session.gd` 的 `hit_radius` 仍默认 18.0）。

实现位置：`scripts/rogue_variants.gd`（`modifiers_of/describe/pick/_derive_seed`）、`scripts/session.gd` 的 `rogue_mods()` / `rogue_enemy_bolt()`、`scripts/roguelike.gd` 的 `mod_of()` / `roll_tier()` / `roll_offers()` / `settle()`、`scripts/ecology.gd`（生态怪弹幕）；验收 `tests/rogue_variants.gd`、`tests/rogue_hooks_session.gd`、`tests/rogue_hooks_ecology.gd`、`tests/rogue_hooks_roguelike.gd`。

### 3. 诅咒回廊与幽暗异事

- **诅咒回廊（curse 房）**：进房即给每人一条诅咒（**10 条**，CU01–CU10），与既有减伤池**同池相减**（`defense_penalty`），**不新开乘数**；每条诅咒都配对称的正面回报。
- **幽暗异事（event 房）**：**9 个事件 / 25 个选项**，在「幽暗异事」面板里选择后由房主结算（动作 `rogue_event`，先校验 `raid.revision` 防重放）。

实现位置：`scripts/rogue_curses.gd`、`scripts/rogue_events.gd`、`scripts/roguelike.gd` 的 `open_room()` 与 `choose()`；验收 `tests/rogue_curses.gd`（218/0）、`tests/rogue_events.gd`（484/0）。

### 4. 三个专属房间

- **游方锻炉（forge）**：熔炼锻造点（复用 `RogueBuild` 既有锻造规则与预算，不另造数值）、当场锻打 +1 级、转移锻造。
- **赌徒营帐（gamble）**：三种赌法（魔晶 / 奥术灰烬 / 装备升阶），胜率与期望值写进描述文本，三种期望均 ≤ 100%。
- **镜中挑战（mirror）**：应战后生成与挑战者同角色、同武器的真实镜像敌人。敌人按武器类型使用有预警的近战、远程和武器技攻击；击败镜像领取魔晶、灰烬和装备三选一，挑战者倒地或断线则失败。接受挑战即消耗本局一次机会，重复点击不能结算或领奖，挑战期间关闭服务面板并锁住出口。

事件房的全部 25 个选项均落实到实际资源：魔晶、生命、蓝量、血瓶、属性点、锻造点、诅咒及装备选择。消耗不足或已持有同名诅咒时拒绝交易；治疗与血瓶遵守诅咒修正和容量限制，选择后显示实际到账结果。进房清理上一房的事件与镜像状态。补充验收：`tests/rogue_event_completion.gd`。

迷雾诅咒通过跟随本地玩家的遮罩缩小实际目视范围，移除后立即恢复，HUD 不受遮罩遮挡。血蚀／碎盾将受伤加成作为同一减伤池的负贡献，即使没有减伤加成也生效（最多增加 60% 伤害）。双端验收：`tests/rogue_event_network.gd`；界面与迷雾截图：`tests/rogue_room_ui_visual.gd`。

实现位置：`scripts/rogue_rooms.gd`（`offers/resolve/gamble_stake/mirror_accept/mirror_resolve`）、`scripts/roguelike.gd` 的 `open_room()`/`refresh_dedicated()`/`room_action()`/`mirror_action()`/`apply_room_delta()`（换阶会同步 `refresh_max_hp()` 与 `rogue_inventory_revision`）；验收 `tests/rogue_rooms.gd`（1299/0）。

### 5. 守层者池扩容与半血二阶段

守层者由 5 个扩到 **8 个身份**：幽蕈古王、熔炉暴君、星镜女皇、雷翼舰长、黑曜剑圣，新增**暮钟司祭、岩窟冢主、湮潮之主**。每局由 `(seed_value, floor)` 确定性抽 5 个互不重复；**零新美术**（复用既有 17 个美术 key）。每个守层者由 5 招扩到 **7 招**，血量降到 50% 进入**二阶段**（状态单调、只触发一次），两个专属终结技在一阶段绝不出现；一阶段行为与扩容前逐位一致，伤害几何仍走既有 `zone/contains/bolt` 通道。

已知局限：新身份的身体立绘仍按楼层取帧（`enemy_body.gd → rogue_art.boss_animation(rogue_skin)`），零新美术下会回落，但特效/颜色/招式名/构建物按抽到的身份渲染。

实现位置：`scripts/rogue_combat.gd`（`NAMES`/`MOVES`/`boss_pool`/`moves_of`/`setup_boss`）、`scripts/boss_choreography.gd`（`rq_bell/rq_earth/rq_abyss`）、`scripts/boss_effect_art.gd`（`ROGUE` 8 项）、`scripts/sound.gd`；验收 `tests/rogue_boss_pool.gd`（2305/0）、`tests/rogue_boss_phase2.gd`（406/0）、`tests/roguelike_bosses.gd`（**2 条待修**）。

### 6. 种子分享与每日挑战

种子分享串格式：`CT-` + 8 位大写十六进制 + 校验字符（`RogueDaily.encode()` / `parse_seed()`）。每日挑战用 **UTC** 日期派生种子（`utc_today()` / `global_daily_seed()`），且**必须由房主随 `begin` 下发**，客户端不得按本地日期自行计算。`0` 表示随机局，所以种子输入框对空值 / `0` / 越界 / 乱码一律拒绝并停在页面，**绝不静默变成随机局**。

**未落地**：每日打卡记录写在 `profile.data["daily"]`（契约 v3-1 的第三键），但 `scripts/profile.gd` 目前**没有**注册该键的默认值，而 `record_daily()` 刻意"只在键已存在时才写"，因此**打卡目前是空操作**（不产生假成功）。

实现位置：`scripts/rogue_daily.gd`、`scripts/roguelike.gd`（`raid.daily`/`raid.seed_shared`、`record_daily()`）、`scripts/main.gd` 的种子页；验收 `tests/rogue_daily.gd`（132/0）。

### 7. 灰烬与永久成长树

结算（`settle()`，**唯一结算点**、受 `raid.ended` 守卫，只发一次）按层数与结局发放**奥术灰烬**并写入 `profile.data["ashes"]`；成长树 **14 个节点**（沉甸钱囊 / 灰烬矿脉 / 运势护符 / 铁躯 / 猎杀本能 / 守望重甲 / 深袋 / 拾荒者 / 战地医者 / 疾行长靴 / 博识 / 点金之手 / 猎运 / 屠戮研习），满树共 **7305 灰烬**。`power()` 只输出 4 个键，敌人倍率恒 ≤ 1.0——成长树**永不**让敌人更强。存档 `version` 保持 1，只新增顶层键（`ashes` / `growth`）。

实现位置：`scripts/rogue_growth.gd`、`scripts/profile.gd`（默认键与 `sanitize_growth()`）、`scripts/roguelike.gd`（`reset()` 用 `power()` 加成、`settle()` 里 `Growth.grant`）、`scripts/main.gd` 的成长树弹窗；验收 `tests/rogue_growth.gd`（6886/0）、`tests/rogue_profile_migration.gd`（113/0）。

### 8. 界面与入口

HUD 右列新增 5 行：深渊变数、诅咒摘要、灰烬（本局 / 累计分开）、路线（层 · 深度 · 房间名）、本局种子；另加「幽暗异事」面板（3 个选项 + 门槛文案 + 每项选择按钮，门槛不满足自动禁用）、「种子 · 每日挑战」页（显示 UTC 每日种子、分享串输入 / 复制 / 清空）、「灰烬成长树」弹窗（14 节点双列，买不起 / 前置未满足会禁用并给出原因）。所有新动作都携带 `raid.revision`，过期点击被房主拒绝。

实现位置：`scripts/rogue_ui_model.gd`（无窗口可测的 view-model）、`scripts/main.gd`（节点名 `RogueVariant` / `RogueCurses` / `RogueAsh` / `RogueNode` / `RogueSeedLine`、`RogueEventOption%d`、`GrowthBuy_<id>`、`RogueSeedInput` / `RogueDailyPick` / `RogueSeedButton` / `RogueGrowthButton`）；验收 `tests/rogue_ui.gd`（161/0）、窗口截图用例 `tests/rogue_ui_visual.gd`（13/0）。

## 美术

素材均通过内置 imagegen 生成原创奇幻图像；没有鼠类或虫类敌人。

最终运行使用 `assets/rogue/` 内：

- `regions/f1-a1-original-wide-3x.png` 至 `regions/f5-a5-original-wide-3x.png`：原有 25 张 3x 战斗夜景。每层新增 a6/a7 两张战斗图，按七个关位独立加载；shop/talent/treasure 各有五层主题的专用紧凑夜景，共 50 张地图。
- `output/rogue-night-map-prompts/`：内置 ImageGen 生成提示、参考图作用和最终分层虚化/减灯修改提示。旧版本背景保留为美术迭代参考。
- `animations/minion-hd-0-0.png` 至 `minion-hd-4-7.png`：40 种小怪，每种静止 4 帧、移动 4 帧、两个独立技能各 4 帧。
- `animations/boss-hd-0.png` 至 `boss-hd-4.png`：五个原创关底 Boss，静止和移动各 4 帧。
- `animations/boss-hd-0-skill-0.png` 至 `boss-hd-4-skill-4.png`：每个 Boss 五套独立招式动作，每招 8 帧，按技能分表。
- `animations/effects-0.png` 至 `effects-4.png`：五种主题各 4 帧生成特效。
- `animations/source-manifest.json`：内置 ImageGen 的完整生成提示词、参考图作用和修正提示词；原图保留在 `animations/sources/`。
- `animations/hd-packed-manifest.json`、`hd-alpha-validation.json`：70 张新运行图集、880 帧，逐帧至少 64 像素透明留白。透明连通区域按所属帧分离，长武器不会把邻帧带入裁剪结果；最终统一格子重新装配。
- `items_v3.png`：16 个装备、奖励、药剂、刷新卡与宝箱图标。
- `props.png`：12 个岩块、树根、铸炉、星晶、空港与黑曜元素，包含岩浆池。
- `atlas-regions.json`：经过透明边距验证的实际裁剪矩形。运行时 AtlasTexture 只读取各自格内的有效像素，启用 filter_clip 防止采样相邻素材。

早期 SVG、v1/v2/v3 小怪图集和原始试作图保留用于追溯。角色继续使用项目已有动画，守层者使用自己的外观、动画和独立战斗逻辑。

## 小怪与守层者

普通区域每波 6～10 只小怪，随楼层递增；精英区域再增加 2 只。每层 8 种、每种两招，共 40 种、80 招；每波随机抽取，优先两只近战/前排/伏击，支援最多两只、召唤者最多一只，显示高度约 78～87 像素、脚下碰撞半径 13 像素。近战、远程、投掷、召唤、治疗、增幅、护盾、反击、陷阱和控制都有独立招式；近战分方向接近、远程保持距离，出生位置分散随机并避开玩家、障碍、岩浆，避免全部挤成同一剪影。没有鼠类或虫类。

小怪的初始冷却独立随机为 0.35～1.5 秒，每只持有 0.85～1.15 的攻击节奏系数，后续冷却每次另加随机偏移。刚进入攻击距离时至少等待独立的 0.18～0.72 秒反应延迟，避免追击过程中冷却全部归零后同时开始攻击。整群开始蓄力之间有 0.12～0.22 秒的短间隔，多只怪仍可同时处于蓄力、释放或恢复状态。使用本局 RNG，同种子可复现。初始化覆盖旧敌人模板的冷却值；普通攻击蓄力约 0.55 秒，重击约 0.85 秒，支援约 0.8 秒，治疗引导约 1.3 秒；预警和技能帧按实际释放时点同步。

| 楼层 | Boss | 五个招式 |
| --- | --- | --- |
| 幽光菌林 | 幽蕈古王 | 古根横扫、幽光孢雨、根须牢笼、林王践踏、菌林复苏（召唤并少量回复） |
| 魔焰铸炉 | 熔炉暴君 | 熔锤震地、炽铁散射、地火喷涌、锁链冲撞、熔炉火环（中心可躲避） |
| 星晶幻境 | 星镜女皇 | 星棱贯穿、三镜折光、陨星坠落、星轨轮舞、幻镜跃迁 |
| 风暴空港 | 雷翼舰长 | 雷翼斩、折返雷链、游走飓风、疾风俯冲、天穹雷罚 |
| 黑曜魔宫 | 黑曜剑圣 | 王庭三连斩、暗影拔刀、黑剑落雨、禁咒轮印、终焉十字 |

Boss 在第三段遭遇登场，显示独立血条与当前招式名。招式有先行预警、锁定方向/位置、八帧动作、主题特效与真实伤害判定；闪避无敌有效。半血进入狂暴，蓄力和间歇缩短。击败后清理危险效果和召唤物，正常进入区域奖励。不会触发原搜打撤 Boss 的胜利流程。

`assets/audio/rogue/` 提供 60 段原创程序合成音效：25 招各有蓄力和释放音效，五个 Boss 各有狂暴与败亡音效。木质、熔炉金属、晶体、雷电和剑刃采用不同音色。通过现有空间音效系统播放；怪物/地图/道具/特效图像均使用内置 ImageGen。

素材装配可复现：先运行 `python tools/index_rogue_source_components.py`，再用 Godot 执行 `tools/pack_rogue_animations.gd`，最后运行 `python tools/check_rogue_animation_gutters.py`。索引脚本只分析源图并输出像素归属元数据，Godot 完成图集装配；合并或缺失的帧会被拒绝。

## 实现

横版角色显示比例从 1.65 调至 1.15（缩小约 30%），脚下标记同步下移。`CombatVisuals` 已同时支持原搜打撤视图和横版视图：角色连击、法术、大招、墓煜符阵/剑雨/冥火、受击和伤害数字复用原素材及事件。语音距离与音效监听使用当前横版相机，长地图后半段不会因为旧相机位置被静音。缺失的终极技能音乐源文件会使用既有回退录音，忽略残留的 `.import` 缓存。

`scripts/rogue_enemy_vfx.gd` 在真实伤害区域释放时创建动态 Shader 和带贴图的 `CPUParticles2D`：流动光束、扇形横扫、保留安全中心的火环、旋转飓风、召唤能量及五层主题的地面爆发。预警仍依据原伤害几何绘制；视觉层不重复造成伤害。粒子在地图坐标中跟随横版相机，单层同时最多 24 个发射器、64 个着色器实例，区域切换清理。角色发光强度略降，减少多层叠加的过曝。

40 种小怪使用实际 AI 的蓄力、释放、打断事件驱动特效。近战释放扇形刀光，突进增加定向能量拖尾与碎片，弹幕施法有发射闪光、四帧主题弹丸和渐隐轨迹，地面施法有提前预警与落点爆发。受击产生主题碎屑，死亡产生消散环和粒子；弹丸撞人、撞墙或消失时触发碰撞效果。伤害区域首次激活会立即发送呈现事件，短至 0.12 秒的攻击也不会依赖渲染轮询才显示。持续危险按 0.38 秒间隔追加视觉脉冲。打断和死亡会撤掉所属蓄力效果；一次释放只播放一次。

五层地面法术分别使用攀升根须/孢光、流动火舌、棱形晶枪、分叉闪电、暗剑/旋转符印五套 Shader，粒子贴图也分别选择既有生成图集中的不同纹理。弹丸与拖尾复用已生成的五套四帧特效图集；新增特效没有引入需要重新裁剪的素材图。拖尾最多 220 个，离屏攻击不创建额外视觉实例。

可扩展组件（本轮没有安装第三方插件）：

- [Godot 原生粒子](https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html)：CPUParticles2D / GPUParticles2D、贴图序列、曲线和渐变，当前运行已使用 CPU 粒子和自定义 CanvasItem Shader。
- [EffekseerForGodot4](https://effekseer.github.io/Help_Godot/v4/en/introduction.html)：专门制作与播放多层效果；官方 1.80.2 版本使用 Godot 4.6 基础库，当前 4.7.2 项目尚未实机验证。适合重点制作 Boss 和大招；2D 模式的深度测试、软粒子等有限制。
- [BurstParticles2D](https://godotengine.org/asset-library/asset/1814)：MIT，支持贴图、曲线、渐变的单次爆发粒子，适合命中、碎片与爆炸。资产库标记 Godot 4.0，4.7.2 兼容性尚未测试。
- [Kenney Particle Pack](https://godotengine.org/asset-library/asset/784)：CC0，80 张粒子/光照/着色器用贴图，适合补充粒子形状；属于素材包。

- `scripts/roguelike.gd`：层/区域/遭遇推进、奖励、商店、开局装备、一次性结算。
- `scripts/rogue_combat.gd`：40 种小怪、80 招、五个守层者、25 招；小怪独立逻辑在 scripts/rogue_minions.gd、预警与伤害共用几何、召唤、狂暴、音效事件。
- `scripts/rogue_map.gd`：独立二维地图、逐图校准的地面边界、场景碰撞、安全绕行、岩浆范围。
- `scripts/rogue_field.gd`：二维横版呈现、镜头跟随、动作图集、遮挡排序、瞄准与场景绘制。
- `scripts/rogue_art.gd`：生成资源加载、透明区域裁剪、图标映射。
- `scripts/main.gd`、`scripts/session.gd`：新模式入口、准备购买、HUD、现有战斗与存档接入。

宝箱、地面奖励、个人候选与领取状态使用现有房主权威操作和快照协议同步，支持 2～4 人合作。没有发布或重新打包可执行文件。

## 验证

Godot 4.7.2：

- `tests/roguelike.gd`：**当前不可用**（2026-10-05 晚实测：无汇总行 + `SCRIPT ERROR: Out of bounds get index '1'`（`tests/roguelike.gd:67`），另有 3 条断言失败 `Starting purchases applied` / `Unexpected phase` / `All five floors and every graph row completed`）。它的「五层 25 区」口径已被节点图取代、尚未移植；请改用 `tests/roguelike_seven_rooms.gd`（11832 检查 / 0 失败）与门禁基线里的节点图口径用例。
- `tests/roguelike_bosses.gd`：已按「8 身份 × 7 招」新口径移植，但**2026-10-05 晚实测 466 检查 / 2 失败**（`Damage geometry includes advertised danger area`、`Standing inside released danger actually takes damage: 4/3 幽蕈深潜`）——两条都是「按 shape 反推一个位于危险区内的点」的启发式在新身份下失效，属**待修**，见门禁基线与汇总文档。
- `tests/roguelike_vfx.gd`：139 项通过，验证长地图角色事件和语音、原角色大招素材、五主题六类真实粒子/Shader、镜头跟随、实例上限、区域清理以及视觉层不造成额外伤害。
- `tests/roguelike_vfx_visual.gd`：已截图检查角色攻击、墓煜原有大招与敌人贴图粒子，运行无脚本或绘制错误。
- `tests/roguelike_minion_vfx.gd`：643 项通过，验证全部 40 种小怪的 80 个招式从实际 AI 发出的蓄力、受击打断、唯一释放、弹幕拖尾、地面预警/主题 Shader、死亡和真实弹丸碰撞事件及切区清理。
- `tests/roguelike_attack_timing.gd`：55 项通过，覆盖四种种子、八只同类怪物、初始冷却和追击冷却归零场景、20 秒连续攻击、后续不重新同步、每只怪持续出招及同种子可复现。
- `tests/roguelike_minion_vfx_visual.gd`：五主题各四种小怪的蓄力、释放和落地法术共 15 张截图，运行无脚本或着色器错误，已人工检查代表画面。这是为并排检查素材而刻意同步动作的展示场景；实际 AI 攻击节奏由独立计时测试验证。
- `tests/hybrid_vfx.gd`：9 项通过，原搜打撤混合特效回归；`tests/ultimate_release.gd`：41 项通过，角色大招释放回归。
- `tests/voices.gd`：123 项通过，原角色语音、大招旁白、跳过与结束行为回归。
- `tests/roguelike_animations.gd`：**当前不可用**（2026-10-05 晚实测：运行 94 秒到帧上限、无汇总行；用例仍在调用已移除的 `rogue_art.spell_animation`）。
- `tools/check_rogue_animation_gutters.py`：使用 --hd：880 帧逐帧 Alpha 检查通过，70 张图集没有侵入相邻格。
- `tests/roguelike_boss_visual.gd`：五层小怪群及全部 25 招的预警和释放分别截图，共 55 张画面；截图位于 `build/rogue-minions-*` 和 `build/rogue-boss-*`。
- `tests/roguelike_art.gd`：90 项通过，验证 25 区独立背景、最终素材透明边距、完整数量、各层三种区域配置的出口可达性，避开岩浆仍可到达。
- `tests/roguelike_geometry.gd`：399 项通过，验证贴图地形与碰撞共享边界顶点，以及顶住边界、停在边缘、向边缘闪避时不弹回。
- `tests/roguelike_regions_visual.gd`：25 个区域分别输出截图，已人工查看各层代表区域；地面图像与碰撞边界一致性同时由几何测试验证。
- `tests/movement.gd`：107 项通过，原有移动与动画帧回归。
- `tests/roguelike_visual.gd`：开局准备、五层画面、横向镜头、奖励界面已截图检查；验证金币扣款、刷新卡入局、重复点击不重复扣款与余额不足时不启动。
- 原模式回归：`tests/expedition.gd` 79 项、`tests/combat.gd` 78 项通过。

截图和运行日志位于 `build/rogue-*`。墓煜终极技能音乐的残留导入文件已通过源文件检查和既有回退录音处理；完整特效截图运行不再报告这些加载错误。

参考机制资料：[《失落城堡2》Steam 官方介绍](https://store.steampowered.com/app/2445690/?l=schinese)，采用随机武器/防具/宝藏构筑的方向，主题和素材均为本项目原创。
# 小怪扩展设计与分散刷新

本轮 40 种小怪每种两招，待机/移动/技能一/技能二各 4 帧；五个 Boss 每招 8 帧。使用内置 ImageGen 重制，提示词和修正版本记录在 `assets/rogue/animations/hd-source-manifest.json`，原图保留在 `hd-sources/`。70 张运行图集共 880 帧，全部通过 64 像素透明边距检查；采用无损导入、mipmap 缩小采样、身体尺寸参照与像素位置对齐。原地图、道具和主题效果素材继续使用。

新增治疗/增幅连线、临时护盾与破裂、抛物线投掷、回旋/追踪弹、陷阱、召唤与可击毁分身；伤害、治疗、减速和防护都有实际判定。召唤者与额外召唤数量受限，主人死亡召唤物消散，额外召唤不给重复击杀奖励。每个小怪技能有独立合成音效，80 个 WAV 的来源与参数见 `assets/audio/rogue/minion-manifest.json`。小怪声音优先级低于 Boss 与角色关键动作。

验证：小怪技能 103 检查（其中 1 条既存失败，见汇总文档）、分散刷新 6166 项、错峰出招 55 项、动画与资源 2660 项、原角色语音 123 项；实际 GPU 截图覆盖五层 40 种小怪的两招、五个 Boss 与 25 套技能。

40 种魔物、80 个特色招式的完整设计见 [ROGUE-MINION-DESIGN.md](ROGUE-MINION-DESIGN.md)。该文档的 40 种、80 招已实装。当前使用重制的 40 种小怪，出生位置已改为战斗段内分散随机采样，避开障碍、岩浆与玩家，并随机排列种类。空间允许时优先保留 150 像素间距，狭窄区域选择最大可用空隙。刷新检查覆盖五层、三段战斗及多个种子。


## 营地与联机

队长选择入口决定队伍模式，切换模式会清除旧准备状态。闯关入口打开开局购买界面，各自确认刷新卡和初始武器，全部队员准备后队长出发。购买费用在本地收到成功开局事件时扣一次；准备后返回营地会取消该次购买准备。原有 ENet 直连、P2P 与服务器房间共用这一模式协议。

角色输入、怪物招式、伤害、奖励购买和区域推进由房主/服务器处理。地图随楼层和区域重建，包含同一组障碍、岩浆及边界；客户端使用自己的角色跟随相机和瞄准。地面技能与投掷物同步位置、延迟和状态，充能、命中特效和音效沿用战斗事件同步。每位角色使用自己的开局配置，不使用房主的刷新卡或武器。最终结算可靠发送给所有客户端。

区域奖励允许不同队员选择相同选项，已领取者不能重复领取。任意队员领取后该组奖励禁止刷新，避免修改队友已看到的选择。商店库存为队伍共享，每件售出后全队不可重复购买。

验证入口：`tests/camp_modes.gd`，`tests/camp_flow.gd`，`tests/camp_collision.gd`。真实 4 进程 ENet 验证：`tests/roguelike_network.gd -- --server --four` 启动房主，另外启动三份 `tests/roguelike_network.gd -- --four` 客户端，覆盖配置、个人领取、防重复领取、集合换区、岩浆地图、技能特效、输入与结算。

## 独立行囊与构筑

- TAB 打开、TAB / ESC 关闭。底部显示当前伤害、攻击间隔、移动速度、生命上限、蓝量和实际综合减伤，读取战斗公式。战斗不会因打开行囊暂停。
- 左侧角色立绘周围显示主手、护甲、法器和战靴；右侧在备用物品与祝福间切换，每页 12 个物品图标。顶部显示魔晶与刷新卡，补给位位于物品区下方。无重量与格子拼接要求。
- 悬停装备显示武器基础伤害、当前构筑下伤害及相对当前武器的差值、攻击间隔、距离、蓝耗、属性补正、战技，或防具属性。
- 右键备用装备可装备或丢弃；右键已装备物品可收回备用背包或丢弃；急救针可使用或丢弃一支。丢弃需在菜单内再次确认，无法找回。初始自带武器不可丢弃；收回主手后恢复自带武器。
- 换装自动保留旧装备。备用装备不生效，只有已穿戴装备和已获得祝福计入属性。换装不能刷生命或弹药；施法、攻击与闪避动作结束后才可管理物品。
- 急救针使用独立本局计数，F 治疗 / 自救不再走搜打撤快捷栏；原格子背包、次元口袋、背包柜及拖拽操作不参与肉鸽玩法。
- `scripts/rogue_inventory.gd` 为独立界面，`roguelike.gd` 验证本局物品操作与版本号，拒绝过期菜单操作。

行囊验证：`tests/rogue_inventory.gd` 29 项通过，覆盖独立补给、治疗/自救、替换收纳、装备/收回/丢弃、初始武器保护、旧菜单拒绝、无换装回血/补弹、实际鼠标悬停与右键、二次丢弃确认、TAB 开关和分页；GPU 截图位于 `build/rogue-inventory-*.png`。原远征 79 项、战斗 78 项通过。五层通关测试在临时副本中适配当前多出口坐标后 115 项通过，未修改并行更新中的出口实现。

行囊视觉 v2：使用内置 ImageGen 生成 `assets/ui/rogue-inventory-sanctum-v2.png` 圣堂底图，完整提示词记录在同目录 `.generation.json`。现有四角色立绘按区域尺寸适配，装备槽与品质光效由 `scripts/rogue_inventory_socket.gd` 绘制；默认界面以图像和数值为主，长描述在悬停时展开。已验证四角色、12 格分页、祝福、普通/铭刻武器详情和右键丢弃确认；背包 29 项与装备 114 项通过。
墓煜行囊专用全身立绘为 assets/ui/rogue-inventory-muyu-v2.png，使用内置 ImageGen 参照原角色绘制，保持透明 Alpha；提示词与参考路径保存在同目录 .generation.json。

## 夜景地图更新

25 个区域使用独立 ImageGen 地图（`assets/rogue/regions/f*-a*-original-wide-3x.png`），保留原版半写实绘画质感。每层统一配色与材质，区域分别呈现古树林、湖岸、回廊、矿坑、铸炉、仓库、观星台、晶石庭院、飞艇机库、图书馆和宫殿等地标。全部为夜景，月光柔和提亮，装饰灯笼减少。图片本身采用近景轻微、远景更强的分层虚化，不使用运行时模糊着色器。完整生成提示保存在 `output/rogue-oblique-map-prompts/`。旧夜景提示词保留在 `output/rogue-night-map-prompts/`。

两条分叉共用平面移动与碰撞，靠近末端按 E 选择路线；过期操作、远距离操作及队友未集合的操作会被拒绝。角色、怪物、战斗预警和文字不参与背景虚化。进入新区域时摄像机直接对准出生点，避免从上一关末端回扫。商店界面在走到分叉附近时自动收起，让路线可见。


## 地图纵深与镜头更新（2026-10-04）

新版保留原来的 3:1 横长画幅，稍微提高俯视角度，地面适度加宽。每关道路有轻微宽窄、转角变化，入口和末段不再统一做成窄口。背景仍使用半写实夜景、柔和月光和生成时的分层虚化；角色、地面技能和界面保持清晰。25 张地图和逐图地面边界位于 assets/rogue/regions/；生成提示词和道路轮廓参考位于 output/rogue-oblique-map-prompts/。

战斗地图世界尺寸为 3600×1200，休整区域为 3000×1000，保持 3:1 比例。地面碰撞使用 ground-manifest.json 中每关独立测量的 UV 边界；障碍物与刷怪仅放在地面内。贴图采用统一 UV 映射，不拉扯地面或制造台阶。右侧两个平坦短路口仍可选择下一关。

镜头在屏幕 x=590..850、y=440..600 内保持稳定，越界后平滑跟随，并限制在地图画幅范围内。角色向下移动时场景向上滚动；瞄准、武器插槽、角色影子、法术预警和敌人特效共用同一二维镜头偏移。切区或重新开局时镜头直接对准出生点。

验证入口：tests/roguelike_ground_bounds.gd（上下边界、障碍物、两条出口连通）、tests/roguelike_camera.gd（双轴跟随与镜头限制）、tests/roguelike_oblique_visual.gd（五层及向下移动实机截图）。


2026-10-04：按原夜景系列方向重新生成全部 25 张地图，扩大路面，保持单路入口、右端两个平面出口。最终原图与逐图提示词保存在 output/rogue-original-wide-redo/；项目加载 assets/rogue/regions/f*-a*-original-wide-3x.png。旧 oblique 与 night-soft-3x 地图移至 output/unused-rogue-maps/before-original-wide-redo/。每张成图单独校准 ground-manifest.json，已通过地面边界、障碍物、出口连通、镜头与实机截图检查。

2026-10-04：切换用户提供的全部 25 张 original-wide-3x 地图；逐图验证宽高均为原图三倍。地图世界尺寸、归一化地面边界、出口和镜头范围不变。1x 资源与导入文件移至 output/unused-rogue-maps/original-wide-1x/。

2026-10-04：完成全部 25 张 3x 地图的路面边界审查，按各图前景植被、护栏与码头边缘分别下移过早截断的路沿。边界叠图位于 build/boundary-audit/f1.png 至 f5.png（黄线为碰撞边缘，绿点为实际移动停止点）。tests/roguelike_ground_bounds.gd 新增独立的 25 关可见石板位置回归检查；保留上下边界、障碍物完整脚印和两条出口连通检查，长房间与紧凑房间都覆盖。

出口对齐：25 张地图分别标定斜向支路两侧，以及直行道路末段的四组路沿；出口点移至各自道路中央。提示标签居中，并通过细线与地面圆环标明触发点。tests/roguelike_exit_alignment.gd 验证所有长/短地图沿支路逐段行走、出口净空及 E 切换区域。

2026-10-05：每层改为 7 关（共 35 关）。普通房间的两个出口从战斗、精英、商店、宝藏、圣坛中随机抽取不同目的地；第 6 关出口选择普通或挑战首领，第 7 关守层者结束后进入下一层。商店、宝藏和圣坛各有五层主题的专用夜景地图，保持 3:1 比例，生成时前景轻虚化、远景重虚化。原 25 张 3x 地图继续用于战斗关卡；地图贴图与碰撞统一通过 RogueMap.region_key 选择，联机同步同一房间类型。生成记录：output/rogue-safe-night/generation-prompts-seven-rooms.json；流程验证：tests/roguelike_seven_rooms.gd。
2026-10-05：切换用户提供的新增关卡 3x 贴图，25 张均逐图确认宽高严格等于生成原图三倍。RogueMap.texture_path 优先选择已导入的 3x 资源，所有新增关卡已切换到 3x。道路 UV 边界和世界尺寸保持不变。替换的 1x 图及导入文件归档到 output/unused-rogue-maps/seven-room-1x-before-3x/。尺寸报告：build/map-3x-replacement-audit.json。

2026-10-05（晚）：层间结构由固定「每层七区（共 35 关）」改为**节点图**（每层 7~10 节点、共 35~50 个，见上节「魔境扩展」§1），并新增深渊变数、诅咒回廊 / 幽暗异事、游方锻炉 / 赌徒营帐 / 镜中挑战、守层者池 8 身份与半血二阶段、种子分享与每日挑战、灰烬与永久成长树，以及对应的 HUD、事件面板、种子页与成长树弹窗。本条目**取代**上面 2026-10-05 那条「每层改为 7 关（共 35 关）」中的层结构描述；该条关于专用夜景地图与 `RogueMap.region_key` 的部分仍然有效。契约与逐轮验收见 output/ROGUE-CONTRACTS.md、output/ROGUELIKE-EXPANSION-SUMMARY.md。
