# 血潮守望 · Crimson Tide — 项目工作指引

> 本文件是整个项目的唯一导航手册：说明每个游戏功能由哪些文件实现、改动应该落在哪个/哪几个文件。
> **本文件就放在项目根目录**（本机路径：`D:\dsh\Game\CrimsonTide-godot\PROJECT-GUIDE.md`），下文所有相对路径都以项目根为基准。
> 所有 `文件:行号` 锚点基于 git 提交 `abcbaaf`（2026-10-05）：行号会随提交漂移，**函数名/常量名长期有效**，因此锚点一律写成 `文件:行号 符号名()`。
> 自检脚本：`python tools/verify_anchors.py --guide PROJECT-GUIDE.md --root . --summary`（漂移就按报告改，见 §12.3）。
> 接手开发前请先读 §0 与 §12：§12 规定了「一个功能做完、交接前必须更新这份路牌」的强制流程与自检命令。

---

## 0. 这份文件怎么用

1. **接到一个需求** → 先查 §5「我要改 X 速查表」，再跳到 §4 对应功能域细读；
2. **想理解架构** → 读 §3（必读，5 分钟）；
3. **要调数值** → 查 §6 数值常量速查；
4. **改完要验证** → 查 §7 测试体系；
5. **涉及素材/音频/服务器/打包** → 查 §8、§9；
6. **做完一个功能、只剩交接前** → 按 §12 更新这份路牌（**强制项**，不要把版本停在「代码已改、路牌没改」的状态）。

---

## 1. 项目速览

- **游戏**：《血潮守望 · Crimson Tide》，哥特二次元画风的 1~4 人合作「搜打撤 + 肉鸽闯关」游戏。
- **引擎**：Godot 4.7.2，Windows默认Forward+；兼容入口保留OpenGL。GDScript逻辑与Blender/离线制作工具协作，开场美术流程见docs/rpg/FORWARDPLUS-ART-PIPELINE.md。
- **三种玩法**：
  1. **三日远征（搜打撤）**——主模式：边境大地图搜刮、缩圈、黎明 Boss、王城、血潮女王、隐藏结局；
  2. **魔境闯关（肉鸽）**——五层、每层 8～9 房横版闯关、252 项构筑（48 武器/72 装备/96 天赋/24 铭刻/12 核心）；
  3. **营地/家园**——出征前整备 + 种植/钓鱼/料理的湖畔营地。
- **运行**：双击 `游戏启动.cmd`（源码，带类缓存守卫）或 `Start-Game.cmd`；无头测试用 `Godot_v4.7.2-stable_win64_console.exe`。
- **权威文档**：`README.md`（总览）+ 根目录 40 余份专题 `*.md`（索引见 §10）。

## 2. 顶层目录结构

> 克隆/下载后的仓库根就等于下图的 `CrimsonTide-godot\`（本机路径 `D:\dsh\Game\CrimsonTide-godot\`）。

```
D:\dsh\Game\
└─ CrimsonTide-godot\          ← 项目根（唯一代码库）
   ├─ project.godot            ← 引擎配置（主场景 boot.tscn，无 autoload）
   ├─ scenes\                  ← 仅 2 个场景：boot.tscn（开场）、main.tscn（空壳根节点）
   ├─ scripts\                 ← 全部游戏逻辑（112 个 .gd / 3.77 万行，UI/逻辑均由代码构建）
   │  └─ story_*.gd            ← 独立故事战役、连续地表、分层副本、环境、显示、UI、探索图
   │      story_act_art / story_regional_environment ← 第二至第六幕的区域布局、独立建筑、材质与灯光
   │      story_exploration_art / story_exploration_environment ← 六幕副本房间图、空洞、多段高程、地编与室外有机边界
   ├─ resources\               ← 16 个 .gdshader + rogue_build_content.json + scene_music_plan.json + audio_bus.tres
   ├─ shaders\                 ← hero_hair_motion.gdshader（仅离线烘帧用）
   ├─ assets\                  ← 全部美术/音频/模型资源（见 §8.4）
   ├─ tests\                   ← 213 个 GDScript 回归测试（2.36 万行）+ 6 个 Python 测试
   ├─ tools\                   ← 147 个素材/音频/索引/门禁脚本（Python 为主，另有 GD 预览/烘焙）
   ├─ docs\rpg\               ← 故事计划/全文/任务、实现范围、本地MPQ/CASC地图研究
   ├─ server\                  ← Python 标准库房间服务器（app.py）+ Godot 房间进程（room.gd）
   ├─ pv\ output\              ← 宣传片；生成产物/性能探针/报告（非游戏资源）
   ├─ DEPRECATED-…09-25\       ← 已废弃的角色动画归档（.gdignore，勿动）
   ├─ Godot_v4.7.2-…win64.exe            ← 编辑器版引擎
   ├─ Godot_v4.7.2-…win64_console.exe    ← 控制台版（跑测试/服务器必用它）
   ├─ 游戏启动.cmd / Start-Game.cmd / 源码版启动.cmd
   ├─ game.cfg                 ← 客户端服务器地址配置（api_url）
   ├─ compose.yaml / Dockerfile / .env.example / export_presets.cfg
   └─ README.md + 40 余份专题设计文档 *.md
```

---

## 3. 核心架构（必读）

### 3.1 启动链

```
project.godot:18  主场景 = scenes/boot.tscn
  └─ boot.gd        开场：健康忠告(boot.gd:24) → PV(pv/pv.ogv) → 切换到 main.tscn
      └─ scenes/main.tscn：只有一个根节点 CrimsonTide 挂 main.gd
          └─ main.gd:_ready (main.gd:154) 代码创建全部服务与 UI：
             Profile(存档) → OnlineService(账号) → TideSound(音效) → TideSession(权威模拟)
             → TideP2P(打洞) → Battlefield(2.5D 战场) → rogue_field(闯关战场)
             → UltimateCinematic(大招CG) → camp_screen(营地, main.gd:918 ensure_camp())
```

**没有 autoload**——所有脚本要么 `class_name` 全局可见（如 `TideSession`、`Catalog`、`Profile`），要么被 `preload().new()` 手工组装。

### 3.2 分层模型（改代码前先判断层）

| 层 | 文件 | 特征 |
|---|---|---|
| **UI / 输入层** | main.gd + 各 `*_screen.gd`、`*_ui.gd`、`*_inventory.gd` | 只发 `session.action(...)` 动作请求，不做规则判定 |
| **权威模拟层** | session.gd（核心）+ roguelike/expedition/boss_*/ecology 等策略模块 | 只有房主/服务器执行；玩家是纯 Dictionary，10Hz GZIP 快照广播 |
| **表现层** | battlefield.gd、world_3d.gd、combat_visuals.gd、rogue_field.gd、attack_telegraph.gd、rogue_room_ui.gd 等 | 只读 session 状态渲染，"Presentation only"，不产生伤害 |
| **数据/规则表** | catalog.gd、attributes.gd、ecology.gd、weapon_arts.gd、rogue_content.gd、resources/rogue_build_content.json | 静态常量表 + 纯函数 |

**反向注入模式**：session 的子模块（roguelike/expedition/Boss 模块等）拿参数 `s`（=session 自身）反向读写 `s.players / s.enemies / s.raid / s.ruins`——改这些模块时经常需要同时看 session.gd 的对应字段。

### 3.3 模式开关

故事入口为 `main.gd` 的独立 `story` 页面：`story_screen` → `story_campaign` → `story_map` / `story_region`，由 `story_world` / `story_environment` 显示。它使用独立战役存档，当前是单人及两名AI伙伴，不加入TideSession的联机或结算生命周期。

故事物品由 `story_inventory.gd` 权威处理，`story_items_ui.gd`、`story_item_grid.gd` 负责实际控件与原生拖拽，`story_ui_skin.gd` 使用原创材质九宫切片。不要调用远征/肉鸽的货币、装备或存储函数。v10发布采用小运行入口与补丁，挂载现有v9地图底包；正常启动Start-Story-GUI，临时试玩Preview-Inventory。

`session.gd:228 select_mode()` 分派 `campaign`（搜打撤）与 `rogue`（魔境）。两模式共用：
- 同一个 `TideSession`（session.gd:78-82 同时持有 roguelike/expedition/mini_bosses/wild_bosses/dragon_boss 实例）；
- 库存类动作在 `session.gd:1675 perform()` 里分派：魔境把库存动作移交 `roguelike`，远征走本文件存储区；
- 魔境七子系统（abcbaaf 新增）在 `roguelike.gd:4-17` 预载：Variants / NodeGraph / Curses / Events / Rooms / Growth / Daily；
- 背包 UI：`main.gd:3634 show_inventory()` 分支转交 `rogue_inventory.gd`（魔境）、`extraction_inventory.gd`（远征）或 `camp_pack.gd`（营地行囊）。

---

## 4. 功能域指引

### A. 应用骨架与全站 UI

| 功能 | 文件:锚点 |
|---|---|
| 开场忠告/PV/跳过 | `scripts/boot.gd`（忠告 boot.gd:24，按键跳过 `_unhandled_input` boot.gd:49）；文案与视频流在 `scenes/boot.tscn` |
| 窗口缩放/1440×900 适配 | `scripts/main.gd:637 fit_ui()` |
| 全局键位表（WASD/Tab/M/E/F/Q/R/Y/N/U…） | `scripts/main.gd:510 setup_inputs()`；游戏内按键语义分发在 `main.gd:1567 _unhandled_input()` 与 `main.gd:1717 _input()` |
| 标题页菜单 | `main.gd:878 show_title()`（菜单数组 main.gd:897-898 `entries/actions`） |
| 登录/注册/游客、云存档页 | `main.gd:286 show_account()`、`main.gd:337 show_storage()`；存档切换 `main.gd:326 switch_profile()` |
| P2P 房间页 / 服务器房间页 / IP 直连页 | `main.gd:449 show_p2p_rooms()` / `main.gd:434 show_server_rooms()` / `main.gd:1302 show_network()` |
| 设置（音量三条滑杆/全屏） | `main.gd:3303 show_settings()`，音量总线 main.gd:3294-3306 |
| 暂停菜单/离开对局 | `main.gd:4476 pause_menu()` |
| 帮助手册/制作组 | `main.gd:3308` / `main.gd:3324` |
| HUD 构建/刷新（血蓝条、技能冷却、小队、黎明抉择按钮、交互提示） | 布局 `main.gd:1267 on_started()`；每帧刷新 `main.gd:2102 update_hud()`；救援/城门/撤离/封印/宝箱提示 main.gd:1844-1876 |
| 底部道具栏（1/2/3 槽） | 绘制 `main.gd:1706 draw_hud_item_bar()`；使用规则 `main.gd:1756 apply_item_slot()` + `Catalog.slot_operable` |
| 背包界面总入口（Tab） | `main.gd:3634 show_inventory()` → 魔境转 `rogue_inventory.gd:52 draw()`、远征转 `extraction_inventory.gd:26 draw()`、营地转 `camp_pack.gd:49 draw()` |
| 魔境扩展的表现入口（abcbaaf 新增） | 房间面板 `main.gd:3872 rogue_room_panel()`、事件三选一 `main.gd:3837 rogue_event_panel()`、每日种子页 `main.gd:3909 show_rogue_seed_page()`、成长树 `main.gd:3980 show_growth_tree()` |
| 拖拽子系统（拿起/落点预览/金框红框/R 旋转） | `main.gd:2245 start_drag()`、`main.gd:2222 release_drag()`、预演 `main.gd:3335 drag_target_rect()`（合法性真正判定在 `session.gd:2131 resolve_drop`）、旋转 `main.gd:2102 rotate_selected()` |
| 双击装备/Ctrl 智能点击/一键收纳 | `main.gd:2597 double_click_equip()` / `main.gd:2096,2117 ctrl_click_item()/ctrl_click_worn()` / `main.gd:4130 auto_store_loot()` |
| F 键兜底链（倒地自救→拾取→搜索→急救针） | `main.gd:1620-1650`；搜索窗 `main.gd:2077 open_search()` |
| 伤害红屏/提示 toast/结算页 | `main.gd:3171 flash_damage_feedback()` / `main.gd:3234 notify()` / `main.gd:3079 on_finished()`（奖励入库+隐藏角色招募 main.gd:3083-3109） |
| 哥特按钮/格子控件（图标随 R 旋转） | `scripts/gothic_button.gd`（slot 绘制 gothic_button.gd:68-98，旋转 80-87） |
| 物品图标解析（图集裁切） | `scripts/ui_art.gd:14 icon()`；16 基础图标表 `KINDS` ui_art.gd:5 |
| 装饰控件（分割线/封印法阵/标题粒子） | `scripts/ui_ornament.gd:19 _draw()` |

### B. 存档与物品数据

| 功能 | 文件:锚点 |
|---|---|
| **存档唯一写入点**（原子写 %APPDATA%/…/profile.json） | `scripts/profile.gd:216 save_profile()`；读档清洗 `profile.gd:53 apply_data()` |
| 次元口袋/背包柜/**仓库**的存档形状 | `profile.gd:136 sanitize_storage()`、`profile.gd:435 sanitize_warehouse()`（⚠️ 仓库已是 **15×15 真网格容器** + `warehouse_spill` 溢出暂存，旧扁平数组自动升级）、进局负载 `profile.gd:212 storage_payload()` |
| **穿戴装备持久化**（撤离写回 / 阵亡清空） | 存档字段 `profile.gd:497 empty_loadout()`、清洗 `profile.gd:500 sanitize_loadout()`（形状与逐槽校验在 `catalog.gd:650 clean_loadout()`）；结算取回 `session.gd:4209 saved_loadout()` |
| 仓库容量与「只计一次价值」 | `catalog.gd:240 WAREHOUSE_GRID=15×15`；入库 `profile.gd:399 bank_item()` / 指格入库 `profile.gd:386 bank_item_at()` / 结算批量入库 `profile.gd:450 bank_carried_items()`；累计战利品价值 `profile.gd:348 credit_loot_value()`（靠物品自带 `valued` 标记去重，见 §11.16） |
| 家园产物作为真实掉落物（塞背包→口袋→落地） | `profile.gd:569 receive_product()`（先 `bags[0]` 再 `pocket`，返回装不下的余量）、`profile.gd:545 product_count()`（按实例 `count` 累加背包/口袋/仓库网格+溢出区）、`profile.gd:558 spend_product()`（烹饪/交易真扣实例）、`profile.gd:592 migrate_home_stock()`（一次性把旧 `home.stock` 计数迁进仓库，在 `apply_data()` 末尾 `sanitize_storage()` 之后调用） |
| 肉鸽成长 / 每日记录的存档清洗 | `profile.gd:160 sanitize_growth()`、`profile.gd:177 sanitize_daily()`（常量 `Daily` profile.gd:17、`MAX_DAILY_RECORDS` profile.gd:21） |
| 等级/经验/天赋升级/仓库入库/出售 | `profile.gd:238 level()`、`profile.gd:241 upgrade()`、`profile.gd:450 bank_carried_items()`、`profile.gd:748 sell_items()`（按下标，网格项与溢出项同一索引空间） |
| 整备台装备购买（差价结算/换装销毁旧件） | `profile.gd:546 buy_gear()`；价格表 `catalog.gd:202 GEAR_PRICES=[180,420,300]`、安全读取 `catalog.gd:197 gear_of()`（`data.gear=-1` = 未装备） |
| 隐藏角色「墓煜」解锁（护身符结局） | `profile.gd:107-136`（`RECRUIT_HEROES={"muyu":3}` profile.gd:32） |
| **物品/武器/装备总数据表** | `scripts/catalog.gd`：物品 `ITEMS` catalog.gd:17；17 把野战武器 `WEAPONS` catalog.gd:147；4 把角色临时武器 `STARTER_WEAPONS` catalog.gd:177（⚠️ `STARTER_BASE=17` catalog.gd:176 必须等于 WEAPONS.size()，tests/systems.gd 断言）；装备 `GEAR` catalog.gd:183；**整备台价格 `GEAR_PRICES` catalog.gd:193**；六档品质加成数组 catalog.gd:209-215；54 件藏品分组表 catalog.gd:95-121 |
| 背包品质（白3×3→红8×8）/容器排版/堆叠/装箱算法 | `catalog.gd:234 BAG_TIERS`、装箱核心 `catalog.gd:525-560`（overlaps/can_place/insert）、自动收纳管线 `catalog.gd:943 place_arrival()` / `catalog.gd:967 eviction_order()` / `catalog.gd:1275 fill()` |
| **物品槽位清洗**（存档 loadout / 道具栏 / 仓库入库共用） | `catalog.gd:615 clean_slot_entry()`、`catalog.gd:628 clamp_entry()`（`SAVED_ITEM_KEYS` catalog.gd:223，新字段必须加进这张表才会过存档） |
| 新增武器/装备/物品的操作顺序 | 见 §5 速查表「新增内容」行 |

### C. 权威模拟核心（session.gd，3822 行）

| 功能 | 文件:锚点 |
|---|---|
| 联机生命周期（ENet 24872、专用服务器票券） | `scripts/session.gd`：端口 session.gd:31；host/join session.gd:128/142；专用服 session.gd:179/191；票券校验 session.gd:259 validate_ticket() |
| 动作总线（所有交互的唯一入口） | `session.gd:1675 perform()`——heal/dash/skill/bag_*/equip/use/search/pickup/raid_choice 全在这；rogue_* 由 session.gd:1618 直通 `roguelike.choose()`。⚠️ **`perform()` 开头 `if not running: return`**：营地没有权威会话，营地里的存储编辑一律走 `camp_storage.gd`（见 §4.G），不要指望 `session.action()` |
| 玩家数值（伤害公式/防御/抗性/掉落率/属性补正） | `session.gd:465 weapon_scaling()`、`session.gd:508 weapon_damage()`、`session.gd:441 stat_defense()`、`session.gd:455 stat_resistance()`、`session.gd:461 enemy_drop_chance()`；肉鸽补正 `rogue_equipment_stat()` session.gd:438、`rogue_damage_pool()` session.gd:469、`rogue_mods()` session.gd:477 |
| 移动/奔跑/闪避 | `session.gd:2843 move_player()`（调用点在 session.gd:2684）、常量 session.gd:34-36（闪避时长/距离/奔跑倍率） |
| 攻击三连击/武器技/弹丸生成 | `scripts/session.gd:3396 attack()`、`session.gd:3445 release_weapon_art()`、`session.gd:3542 release_strike()`；战技事件携带 attack_kind、width、radius，飞行弹体保留具体武器与强化快照 |
| 伤害结算中枢（韧性/格挡/硬直/击退/hitstop） | `session.gd:3586 damage_enemy()` |
| 弹丸飞行/链电/陨石落点 | `session.gd:4037 update_bullets()` |
| 大招（雪璃治疗/死灵法师魂收+冥火地带全套常量） | `session.gd:2436 release_ultimate()`、死灵常量块 session.gd:2481-2498（NECROMANCER/FIRE_*/BURN_*/SOUL_REAP_*） |
| 理智/血晶气味/威胁度/环境刷怪 | 理智+血晶气味 `session.gd:2685-2698`；威胁度公式 `session.gd:2624`；环境刷怪 `session.gd:2629-2632` |
| **血潮缩圈**（数值） | `session.gd:2788 safe_center()`、`session.gd:2791 safe_radius()`；开始时间 `session.gd:51 SHRINK_START=180s` |
| 搜索容器（F 逐件浮出） | `session.gd:931-979`（`begin_search()` / `advance_search()` / `search_seconds()`） |
| 死亡散包/撤离带入/口袋保护 | `session.gd:819 spill_storage()`、结算 `session.gd:4154 settle()`；**穿戴装备同背包**：撤离保留穿着（写回 loadout，`session.gd:4209 saved_loadout()`）、阵亡散落并清空存档 loadout |
| 据点守军锁定/清剿宝箱 | `session.gd:3882 resolve_site_defeat()` |
| 王城进出（全队集合/双地图状态机/骑士奖励） | `session.gd:3702 travel_city()`、奖励 `session.gd:3755 knight_reward()` |
| 失乡骑士 AI 与出招 | `session.gd:3754 update_knight()`、`session.gd:3852 start_knight_attack()` |
| 隐藏结局触发（三钟+护身符+女王死） | 判定/触发 `session.gd:2772-2774`；`session.gd:2819 bells_lit()`、`session.gd:2822 seal_bell()`、`session.gd:2849 carries_amulet()`、`session.gd:2836 hidden_ending_ready()`（常量 `BELL_SEALS` session.gd:2814） |
| 快照序列化（联机同步什么） | `session.gd:1546 snapshot` RPC（组包在 session.gd:1530）；闯关特效直传 session.gd:1527-1529（visual_effects/visual_missiles） |
| 存档触发点 | session 只发 `finished` 信号；**真正落盘在 `main.gd:3079 on_finished()` → `main.gd:3109 save_profile()`**（肉鸽结算补存 main.gd:3114） |

### D. 三日远征（搜打撤主模式）

| 功能 | 文件:锚点 |
|---|---|
| 三天状态机/黎明 Boss 生成/跨天恢复/遗赠 | `scripts/expedition.gd`：常量 expedition.gd:6-53（Boss 名/血 1650/3100/5500、REWARDS、隐藏 Boss 9200）；`prepare_day` expedition.gd:60；`victory` expedition.gd:196；黎明抉择 `choose` expedition.gd:290 |
| 三大主线 Boss + 无名赤月 + 隐藏 Boss「冥火尸王·墓玥」招式 | `expedition.gd:412 cast_boss()`（23 招，match 分支 439-536）、`expedition.gd:566 cast_hidden()`；危险区判定 `expedition.gd:314 update_hazards()`、`expedition.gd:345 hazard_contains()` |
| 地图守护者抽取（弱/强池→三种 Boss 模块） | `expedition.gd:100 spawn_map_guardians()` |
| 缩圈视觉（血雾 Shader） | `scripts/blood_tide.gd`（挂接 battlefield.gd:52，setup 调用 battlefield.gd:61）+ `resources/blood_tide.gdshader` |
| 边境大地图（9600×7200、六地貌、18 据点、3 封印、4 撤离点、6 野外箱、河流三桥） | `scripts/ruins.gd`：常量 ruins.gd:4-15；`generate` ruins.gd:38（海岸 55/撤离点 56/地貌 58/桥 72/据点 75-81/道路 100/箱 165-179，落表 ruins.gd:179）；碰撞 `blocked` ruins.gd:239、`move` ruins.gd:260 |
| 王城室内图 | `scripts/royal_city.gd`（extends Ruins；GATE/BOSS royal_city.gd:4-5，墙 royal_city.gd:23） |
| 战术地图 M / 小地图 | 绘制在 `battlefield.gd:477 draw_map()`（路点/过滤器 `_input` battlefield.gd:576，路点 580-583、过滤器 586）；世界底图 `world_art.gd:103 atlas()` |

### E. 魔境闯关（肉鸽模式）

| 功能 | 文件:锚点 |
|---|---|
| 五层七区闯关主控（路线/刷怪波/圣坛/宝箱/商店/出口/结算） | `scripts/roguelike.gd`：开局 `reset` roguelike.gd:91；房间生成 `enter` roguelike.gd:249；刷怪 `spawn_wave` roguelike.gd:325；清场奖励 `clear_room` roguelike.gd:470；三选一奖励池 `reward_offers` roguelike.gd:516；装备/换装 `equip` roguelike.gd:712；出口选择 `exit_choices` roguelike.gd:844 |
| 横版地图（地面碰撞/岩浆/出口 UV/分叉口路口广场） | `scripts/rogue_map.gd`（extends Ruins；地面清单来自 `assets/rogue/regions/ground-manifest.json`，区域键规则 `region_key` rogue_map.gd:54；**分叉口 = 一整块可走路口广场**：`fork_junction()` rogue_map.gd:128 把直行路与斜向路之间的地面并进 `floor_polygon`，见 §11.43） |
| 守层者（固定五层主线，8 身份×7 招仍保留）与小怪导弹/毒圈权威判定 | `scripts/rogue_combat.gd`：招式表 `MOVES` rogue_combat.gd:24-82；`begin_skill` rogue_combat.gd:308；zone 判定 `tick` rogue_combat.gd:451 |
| 40 种小怪×2 技能 AI/支援/受击吸收 | `scripts/rogue_minions.gd`（NAMES/ROLES/LOADOUTS rogue_minions.gd:3-21，release rogue_minions.gd:161） |
| 玩家普攻/战技结算（闯关版） | `scripts/rogue_actions.gd`（`start_art` rogue_actions.gd:13、`normal` rogue_actions.gd:132） |
| 闯关战场渲染（相机/角色/敌人血条/预警弧/出口） | `scripts/rogue_field.gd`（相机死区 rogue_field.gd:16，`_draw` rogue_field.gd:157） |
| 闯关美术装载（HD 图集裁切/图标） | `scripts/rogue_art.gd`（图集清单 rogue_art.gd:81）+ 背景 `rogue_backdrop.gd` |
| 敌方特效层（不产生伤害） | `scripts/rogue_enemy_vfx.gd` + 守层者专属 `scripts/rogue_boss_effects.gd` |
| 跳跃姿态帧 | `scripts/rogue_jump_frames.gd`（数据 `assets/rogue/build/jump-manifest.json`，**已入库**；由 `tools/index_rogue_jump_art.py` 生成） |
| **路线图界面（M / P1）**（按节点图画的"本层路线 + 已走 + 可选出口"） | `scripts/rogue_map_screen.gd`（**纯函数 `layout()` rogue_map_screen.gd:68**，只读 session、可被 headless 直接断言；绘制 `draw_map()` :287；图例 `legend()` :274；区域名与标记 `_room_name()` :246 / `_room_mark()` :255；未知道具名 `UNKNOWN_NAME` :35；几何常量 :427-433）。接线：`main.gd:55` preload、`main.gd:297` 实例化、`main.gd:299` 初始隐藏、`main.gd:2349` 与战役地图共用 `field.map_open`、`main.gd:832` 离页收起 |
| **扩展：地图图谱**（节点/边/流派分类/图签名） | `scripts/rogue_graph.gd`（`kinds` :44、`node` :48、`neighbors` :56、签名 `signature` :64） |
| 扩展：房间类型（锻炉/赌局/镜厅）与进入门槛 | `scripts/rogue_rooms.gd`（`KINDS` :23、`appears_at` :80、`context_of` :86）+ 房间界面 `scripts/rogue_room_ui.gd`（`handled` :32、`action_for` :36、`title` :48） |
| 扩展：随机事件（奖励/代价） | `scripts/rogue_events.gd`（事件表 `table` :70、楼层池 `floor_pool` :84） |
| 扩展：诅咒（上限与投放权重） | `scripts/rogue_curses.gd`（`MAX_CURSES=4` :22、表 `table` :60、`find` :72） |
| 扩展：每日种子（同一天全局同种子） | `scripts/rogue_daily.gd`（种子前缀 `PREFIX` :27、`today` :47、`normalize_date` :57） |
| 扩展：局外成长树（点数/购买） | `scripts/rogue_growth.gd`（`BASE_PER_ROOM` :32、`tree` :164、`can_buy` :190、`buy` :195） |
| 扩展：词条变体（稀有度/极性/文案） | `scripts/rogue_variants.gd`（`TABLE` :34、`table` :148、`bounds` :166）+ 文案模型 `scripts/rogue_ui_model.gd`（`variant_line` :39、`curses_text` :63） |
| 扩展的接线点（main.gd 只做转发） | `main.gd:46-51`（preload RogueUi/RogueGrowth/RogueGraph/RogueRoomUi 等）、`main.gd:3469/3488`（房间 UI 分发）、`main.gd:1207`（诅咒标签绘制） |

### F. 构筑系统（252 项：48 武器/72 装备/96 天赋/24 铭刻/12 核心）

| 功能 | 文件:锚点 |
|---|---|
| **构筑内容数据**（白值/文本/流派） | **`resources/rogue_build_content.json`**（252 条，由 `tools/build_rogue_content.py` 从 ROGUE-BUILD-SYSTEM-DESIGN.md 表格编译）；运行时加载器 `scripts/rogue_content.gd`（WEAPON_BASE=600 rogue_content.gd:3，ID 查询 `entry` rogue_content.gd:16） |
| 构筑规则引擎（属性/伤害/天赋/锻造/连招） | `scripts/rogue_build.gd:122 stat()`；`scripts/rogue_build.gd:454 hit_multiplier()`；`scripts/rogue_build.gd:540 hit_event()`；`scripts/rogue_build.gd:762 action_event()`；`scripts/rogue_build.gd:994 activation_reason()`；`scripts/rogue_build.gd:1015 legal_talents()`；`scripts/rogue_build.gd:1067 management()`；`scripts/rogue_build.gd:1116 award()`；`scripts/rogue_build.gd:1291 add_experience()` |
| **引魂召唤 · 灵体索敌**（主人点名 > 主人大圈 > 灵体小圈 > 待命） | 射程150 / 大圈300 / 小圈166.7 / 停靠127.5；1秒/次、2实体与0.16P总预算保留。`scripts/rogue_build.gd:332 summon()`；`scripts/rogue_build.gd:339 soul_free_slot()`；`scripts/rogue_build.gd:347 soul_idle_point()`；`scripts/rogue_build.gd:358 soul_pick()`；`scripts/rogue_build.gd:371 soul_step()`；`scripts/rogue_build.gd:877 tick()`；`scripts/rogue_build.gd:1162 floor_enter()`。`tests/rogue_summons.gd` 31项；T086成功Q立即瞄准锁3秒。 |
| 闯关装备/铭刻定义与品质缩放 | `scripts/rogue_equipment.gd`（`value` 缩放 rogue_equipment.gd:21；被动效果实际在 rogue_build.gd 内联） |
| 构筑管理页（Tab→构筑：天赋/属性/锻造/连招/图鉴） | `scripts/rogue_build_ui.gd:57 build()`；`scripts/rogue_build_ui.gd:23 restore_scroll()`；`scripts/rogue_build_ui.gd:93 talents()`；`scripts/rogue_build_ui.gd:118 attribute_sheet()`；`scripts/rogue_build_ui.gd:135 forge()`；`scripts/rogue_build_ui.gd:179 combos()`；加点保持滚动和条目位置。 |
| 252 项图标 | `scripts/rogue_build_art.gd`（索引 `assets/rogue/build/atlas-manifest.json`，**已入库**；由 `tools/index_rogue_build_art.py` 生成） |
| 闯关行囊界面 | `scripts/rogue_inventory.gd` + 格子控件 `scripts/rogue_inventory_socket.gd` |
| 三选一奖励弹窗 | `scripts/rogue_reward_ui.gd`（交互协议对应 roguelike.gd:795 `selection_action`） |
| **派生链预览（U1 / 行囊内按 V）**（只读展示连招派生链、天赋、锻造/铭刻门槛，**不消耗随机数、不写会话**） | `scripts/rogue_build_preview.gd`（纯函数 `layout()` rogue_build_preview.gd:163、`talent_lines()` :260、`title_line()` :279、绘制 `draw_preview()` :319、面板几何 :58-72、收起按钮 `_build_close_button()` :128）。接线：`main.gd:59` preload、`main.gd:304` 实例化、`main.gd:1626` 显隐、`main.gd:1868` 热键分发、`main.gd:4815 _rogue_preview_toggle()`、`main.gd:310` 的 `closed` 信号（字符串连接，改信号名要一起改） |

### G. 远征背包/库存界面

| 功能 | 文件:锚点 |
|---|---|
| 搜打撤背包面板（双网格/搜索窗/装备栏/背包柜） | `scripts/extraction_inventory.gd`（presentation only，经 host=main.gd 调工厂；`draw` extraction_inventory.gd:26） |
| **共用格子渲染**（对局面板与营地面板同一套外观） | `scripts/item_tile.gd:22 tile()`——图集空格、品质描边、旋转、×数量都在这里；两个面板都调它，改外观只改这一处 |
| 品质描边格子控件 | `scripts/extraction_inventory_socket.gd`（图集 `assets/ui/extraction-slot-atlas-v1.png` 等） |
| **营地「远征行囊 / 守夜人仓库」面板（Tab）** | 界面 `scripts/camp_pack.gd:52 draw()`（三栏：`worn_kit` :90 / `carried` :152 / `vault` :167，注册 `host.grids`/`equip_zones`/`cabinet_zones`）；**面板自己铺一整块 `shield`（`camp_pack.gd:47`，`MOUSE_FILTER_STOP` 全屏）挡掉面板下方的营地按钮**（`camp_pack.gd:68 CampPackShield`，参照 `home_screen.gd` 的全屏 STOP 根节点）；背板占位图 `assets/ui/camp-pack-vault-v1.png`（由 `tools/make_camp_pack_backdrop.gd` 复用旧面板拼出，待替换） |
| **营地面板的"谁在接鼠标"判据**（⚠️ 别只写 `inventory_open`） | `main.gd:1704 bag_mouse_live()` 是唯一的判据：`page_name=="game"` 且会话在魔境模式时**才**把袋控器让给 `rogue_inventory`。`raid.mode` 一旦是 roguelike 就会**整个会话保持**（从魔境回营地也是），所以判据必须绑页面：早期写法 `if session.roguelike.active(session): return` 会让"从魔境回营地后的行囊面板"整片点不动（按钮还能点，因为 Button 不走 `_input`）。`main.gd:1647 _input()` 第一句与它同源 |
| **营地存储编辑规则**（营地无 session 权威时的唯一编辑口） | `scripts/camp_storage.gd:81 drop()`（拖拽分发）→ `:140 vault_in()` / `:164 vault_out()` / `:193 vault_move()` / `:207 vault_equip()` / `:274 socket_out()` / `:287 socket_to_vault()` / `:322 unwear_bag()`（脱下背包要先腾空，装不下就拒绝）/ `:405 stow_worn()` / `:412 stow_socket()`；**每次改动即时 `:28 persist()` 写档** |
| **营地双击规则**（营地双击是"存储动词"，不是战斗动词） | `scripts/camp_storage.gd:635 quick_equip()` → `:503 socket_for()`（装备找自己的槽位：`bag`/`weapon`/`gearN`/`charm0-1`）→ 槽位空走 `drop()`，槽位被占走 `:519 swap_worn()`（**换下来的那件落回对方原来那格仓库格**，落不下就整体拒绝；背包换装走 `:563 swap_pack()`）；非装备走 `:485 auto_store()`（**先背包**，背包放不下才进仓库）。入口 `main.gd:2703 double_click_equip()` 在营地转到这里；**营地双击永远不填快捷栏，`[1][2][3]` 只能拖进去** |
| **卸下规则**（双击装备位 / `Ctrl`+左键 / `F` 是一条；面板「卸」字是另一条，**故意不同**） | 分发 `main.gd:2222 take_off_worn()`（`main.gd:2202 zone_type()`/`main.gd:2209 zone_index()` 把槽位名翻成 `(type,index)`）；**手势**：营地走 `scripts/camp_storage.gd:393 stow_socket()` → `:451 take_off()`（**背包 → 仓库**），对局/肉鸽走 `session.gd:2331 unequip_stow()` → `session.gd:2800 stow_worn()`（**只认背包 + 金及以上才允许口袋**），先 `session.gd:2403 take_off_fits()` 干跑预检，不满足就 `main.gd:1176 notice_popup()` 弹中上提示、**不触发**；**面板「卸」字**：`main.gd:4181 unequip_slot()` → `session.gd:2525 unequip_item()` → `stow_equipment()`（**放不下就掉在脚边**）。⚠️ 两种兜底不同是约定，别统一，见 README「稀有度与自动收纳判定」 |
| **物品快速收纳的稀有度规则**（单一真源，⚠️ 别自己写阈值） | `catalog.gd:689 POCKET_TIER := 4` + `catalog.gd:712 high_quality()`（品质表 `catalog.gd:218 QUALITY_KEYS` = white/green/blue/purple/gold/red 0–5）：**次元口袋只对金及以上算"有地方放"**。用它的地方：`stow_worn`（手势卸下）、`stow_equipment`（换装归位）、`camp_storage.stash()`（互换落点）、`auto_store`（搜刮，**刻意例外**）。手动拖拽不受限（`main.gd:2857 is_pocket_item()` 恒 true）。规范原文见 `README.md`「稀有度与自动收纳判定」 |
| **槽位拖拽与互换**（装备位/道具栏；营地与对局**同一条规则**） | 唯一实现在 `session.gd`：`socket_entry()` :2374（读）/ `set_socket_entry()` :2384（写）/ `clear_socket()` :2397（清）/ `swap_sockets()` :2410（槽↔槽互换）＋ `socket_wants()` :2393（只有同类槽位收）；`slot_number()` :2368 是 `slot0` 与 `slot:0` 两套拼法的唯一翻译口（直接 `substr(4)` 会把 `slot:1` 读成 0）。营地只多包一层 pack 槽例外：`scripts/camp_storage.gd:440 socket_entry()` / `:298 socket_clear()` / `:320 socket_to_socket()`。拖拽起点接线在 `main.gd:1717 _input()` 内（**装备位命中测试 :1473，必须排在网格 `grid_at()` 之前**）；松手分发 `main.gd:2893 release_drag()`（worn → `worn_equip` / `worn_drop`，**面板之外松手不掉地上**）；`main.gd:3474 held_item()` 用 `session.socket_entry()` 取手上的那件 |
| **换装被替下的旧件落点**（对局与营地共用） | `session.gd stow_equipment()`：背包 →（金及以上才）口袋 → 都没有则 `drop_loose()` **单件落在脚边、显示成装备本身**（`ground_drop()` 形状，`F` 一按拾回；**不是可搜索的掉落包**） |
| **堆叠搬运：左键整叠 + 右键分堆**（两种手势刻意不同，别合并） | **左键**＝整条目移动（`camp_storage.gd vault_in()`/`vault_out()`、`session.gd move_between()` 都是整条目；左键拖动 / `Ctrl`+左键 / 双击一律把堆叠物当整体）。**右键**＝分堆手势：按住即把整个条目拿在手上（`main.gd:2481 start_whole_carry()`；单件物品就是一个上限 1、不显示徽标的堆叠物，所以对装备同样成立），按住期间每次左键只在鼠标那一格放 1 个（`main.gd:2377 carry_place_one()` → `main.gd:2627 carry_seat()` → 营地 `camp_storage.gd:309 camp_carry_units()` / 对局 `session.gd:2091 carry_unit()`），松开右键把剩下的交给鼠标所在容器（`main.gd:2546 carry_finish()` → `camp_storage.gd:335 camp_carry_finish()` / `session.gd:2110 carry_finish_units()`）。落座规则单一实现：`catalog.gd:868 place_units_in()`（瞄准格 → 最近的同类未满堆 → 最近的空格），**且刻意不调 `compact_arrivals()`**，所以刚放下的那格不会被重新打包搬走（这就是"锁住那一格"）。**源容器只在单位真的落地后才被扣**，所以放不下的那部分从没离开原堆——"放回原处"因此是免费且无损的（`to==from` 直接 no-op）；只有松手在面板外才真的丢地上。取消 `main.gd:2532 cancel_carry()`（面板内空白 / Esc）只收回**还没落地**的部分；落点预检 `main.gd:2578 carry_would_place()`（在副本上干跑），手上那件由 `main.gd held_item()` 按 `drag.blank` 出图 |
| **堆叠上限：按类配置，只此一表** | `catalog.gd:734 STACK_LIMITS` 是单一真源：`medicine` 急救针 / `ammo` 弹药匣 = 3，其余可堆叠物（crystal/scrap/charm/bait/六类产物/三种种子）= 5，不在表里＝上限 1＝不可堆叠。`catalog.gd:741 max_stack()` 读它，`catalog.gd:758 stacks()` 由它派生（两者不可能分叉）。**上限只管"怎么堆"，不管"读几个"**：`catalog.gd:753 units_of_item()` 与 `profile.gd:583 product_count()` / `profile.gd:596 spend_product()` / `profile.gd:648 sell_product()` 一律用真实 count——夹到上限会让 6 件一叠只算 5 件、多出来的尾巴永远卖不掉 |
| **降低堆叠上限不毁档** | `catalog.gd:927 split_over_limit()` 把超限堆拆成同类的另一格；仓库溢出进 `warehouse_spill`（`profile.gd:435 sanitize_warehouse()`），背包/口袋在 `profile.gd:136 sanitize_storage()` 里一次性归一（不是每次进图都重算）。`catalog.gd:638 clamp_entry()` 给 count 加了一道宽上限（`catalog.gd:748 STACK_ENTRY_CAP`），防止手改存档让拆分器去铺百万件 |
| **旋转（中键 / R）挤位** | 中键＝旋转（`main.gd _input`，**右键已让给"拿起"**）；肉鸽面板右键是它自己的菜单（`rogue_inventory.gd`），未动。原地转得下就只转这一件（`session.gd rotate_item()` / `camp_storage.gd rotate()` 先试普通移动）；转不下时 `rotate_with_displacement()`：核心是 `catalog.gd tidy_around()`——**先给被旋转的那一件落座**，其余按 `tidy()` 的方式重排，**真正放不下的作为 spill 返回**，调用方按 **仓库 → 快捷栏 → 背包 → 地上** 消化（`session.gd slot_receive()` = 塞进第一个空快捷栏）。⚠️ **被旋转物绝不能是丢的那个**（用户硬要求），改这个函数前先看 `tests/systems.gd` 的不变量测试 |
| **丢弃区 / 面板边界**（面板内不动，面板外才丢） | 每个面板登记自己的整块背板：`camp_pack.gd host.drop_region=Rect2(PANEL_AT,PANEL_SIZE)`、`extraction_inventory.gd host.drop_region=Rect2(36,28,1368 if search else 907,828)`，并在 `main.gd show_inventory()` 开头清空。判定 `main.gd drag_outside()`；毛玻璃提示 `main.gd frost_texture()`（背板降采样→放大当模糊，`static frost_cache` 只算一次）+ `set_frost()`/`update_frost_art()`，贴图节点在 `build_drag_nodes()`；`reparent_drag_nodes()` 按 **毛玻璃→框→图标** 的顺序抬层。松手分发 `release_drag()` / `camp_release_drag()`：**面板内空白 = 什么都不做**，面板外 = 丢地上（对局 `bag_drop to world`、营地 `camp_drop_on_floor()`） |
| **营地地面掉落 + F 拾取**（内存态，不进存档） | 数据 `camp_activities.gd drops`，两种记录混放：产物 `{node,kind,units,at}`、物品 `{node,entry,at}`（**读之前必须先问 `drop.has("entry")`**，否则 `_update_markers()` 会报 `Invalid access to key 'kind'`）；掉落 `drop_item()` / `drop_entry()`、节点 `drop_node()`、上限 `GROUND_ITEM_CAP := 60` + `trim_drops()`；离开/回营地 `stash_drops()` / `restore_drops()`（由 `camp_screen.gd set_active()` 调用，**节点释放、数据保留**）；F 拾取 `camp_screen.gd KEY_F` → `pick_up_nearby()` → `item_receiver`（`main.gd ensure_camp()` 接成 `camp_accept_ground_item()`，背包 → 口袋，满了拒绝并留在原地）；地面提示文案 `camp_screen.gd _update_markers()` |
| **背包槽拖拽 + 脱下背包的算法** | 背包槽是拖拽起点（`main.gd _input()` 内，与其余装备位同一分支）；拖到仓库走 `camp_storage.gd socket_to_vault()`（`from=="bag"`）→ `unwear_bag()`：换上 3×3 制式包（`Catalog.DEFAULT_BAG_KEY`），旧包内容按 `keep_order()` **从最珍贵的开始塞**，**塞不下的 `to_floor()`**（`static spill_sink`，`main.gd ensure_camp()` 接成 `camp_drop_on_floor()`），旧包本身按 `to_vault` 进仓库或落地。**拖到背包/口袋格或槽位一律拒绝**（`drop_on_grid`/`drop_on_socket` 的 `from=="bag"` 分支）。排序算法与 0.2 ms 预算见 `tests/camp_keep_order.gd` |
| **搜刮箱是双向的**（背包物品 + 身上装备都能拖进去） | 拖入要把网格名翻译成容器：`main.gd release_drag()` 里 `"loot" → "loot:<_loot_index>"`（背包/口袋走 `session.gd move_between()` 的 `to.begins_with("loot:")` 分支——**这条分支曾经是死代码，没有任何调用者**；身上装备走 `session.gd move_worn_to_loot()`：`place_arrival` 落座、塞不下整段拒绝、身上那格最后才清空）。放不下 = 拒绝（红框），不落地 |
| 拖放落点合法性/换包/旋转的权威判定 | `session.gd:2088 resolve_drop()`、`session.gd:1804 move_between()`、装备 `session.gd:2202 equip_item()`、道具栏 `session.gd:2139 slot_put()`、卸下 `session.gd:2338 clear_worn_slot()`、**落点预检 `session.gd:2440 container_accepts()`**（答"这个格子能不能放"；`session.gd:2424 container_receive()` 只答"这个容器能不能放"，两者别混用；不落一物的干跑版 `session.gd:2834 container_would_receive()`）（营地复用这些纯 `p` 变更函数，规则不会两套） |
| **拖拽预览逐帧跟手** | `main.gd:2503 sync_drag()`；`main.gd:1389` 有 `if page_name!="game" or not session.running: return` 的对局早退，营地必须在早退**之前**单独调用一次（`_process` 内 `if camp_pack_open: ...`），漏掉这句营地预览就会**冻在按下的位置**不跟鼠标 |
| **营地面板不会自己重绘** | `main.gd:3634 show_inventory()` 是唯一重绘入口，而 `_process` 的签名刷新在对局早退之后，营地根本跑不到；所以**任何改了营地存储的代码都要自己 `show_inventory()`**（`double_click_equip()`、`camp_apply()`、`camp_release_drag()` 都这么做），另外 `_process` 里 `camp_signature()`（`main.gd:907`）会兜底一帧 |
| 道具栏三插槽 | `session.gd:341-364`（`empty_item_slots` :341 / `item_slots` :349 / `item_slot` :358 / `set_item_slot` :364） |
| 营地面板接线（Tab/拖拽分支/按钮） | `main.gd:886 show_camp_pack()`、`main.gd:939 toggle_camp_pack()`、`main.gd:2340 camp_release_drag()`、`main.gd:2326 cabinet_zone_at()`、`main.gd:928 camp_bank_all()`、`main.gd:1149 camp_unwear_bag()`；营地按键 `camp_screen.gd:672 KEY_TAB→pack_requested`、`camp_screen.gd:670 KEY_F 只拾取地上的产物` |
| 交易行（网格多选出售） | `scripts/economy_screen.gd:357 sell()`（二次确认）、`:148 refresh()`（15×15 格子 + 溢出暂存行 `:179 spill_shelf()`）、`:127 click_cell()`、`:268 MarketGrid`（只负责报格子） |

### H. Boss 系统

**调用链**：`session.gd:3-6` 引入 Choreography/Tactics/Presentation/enemy_bodies → 敌人分发那一段在 `session.gd:3385-3410`（首领类走 expedition / wild_bosses；小首领走 dragon / wild / mini；type≥5 走 Ecology；type4 走 session 自己的骑士 AI）。

| Boss/模块 | 数据/招式位置 |
|---|---|
| **编排招式库**（20 身份 ×4~7 招，所有 Boss 的招式先走这里） | `scripts/boss_choreography.gd`：`MOVES` boss_choreography.gd:7-29；`TIMELINE_BASE` boss_choreography.gd:32；逐身份 match `start` boss_choreography.gd:49-474（bell :79 / thorn :93 / queen :106 / knight :123 / hidden :143 / mirror :162 / ember :177 / moon :193 / earth :204 / storm :220 / abyss :231 / dragon :244 / 肉鸽五守护者 :259-391 / rq_bell :392 / rq_earth :411 / rq_abyss :430） |
| **失乡骑士 6 招数值** + 观察-反应 AI + 架势防御/破防 | `scripts/boss_tactics.gd`（`KNIGHT_MOVES` boss_tactics.gd:10-17；`blocks/absorb` boss_tactics.gd:82-99） |
| 伤害形状唯一几何契约 | `scripts/boss_geometry.gd`（⚠️ 新形状需**四处同步**：boss_geometry.gd + expedition.gd:357 + `resources/boss_damage_shape.gdshader`（halo 外壳与 `contains()` 同界）+ `resources/boss_projectile_shell.gdshader`） |
| 葬钟圣座(day1)/荆棘猎王(day2)/血潮女王(day3) 数值与 legacy 招式 | `scripts/expedition.gd:6-13` + `expedition.gd:438-540` |
| 无名赤月（final_form 7600 血） | `expedition.gd:178-195` |
| 隐藏 Boss 冥火尸王·墓玥 | `expedition.gd:43-48` 常量、`spawn_hidden` expedition.gd:236、`HIDDEN_MOVES` expedition.gd:422、`cast_hidden` expedition.gd:566 |
| 镜墓纺女/余烬司祭 | `scripts/mini_bosses.gd`（数值 :5-8，招式编排优先） |
| 裂地钻兽/雷骸巨鸟/吞月渊蛇（含终局 abyss_final） | `scripts/wild_bosses.gd`（数值 :5-7，招式 :87-185，掉落 :194-218） |
| 霜骨古龙 | `scripts/dragon_boss.gd`（数值 :5-7，招式 :53-100，掉落 :113-125） |
| 肉鸽五守护者 | `scripts/rogue_combat.gd:23-83`（`NAMES` :23 / `MOVES` :24-83 / `CHOREO_KEYS` :20；另有 3 个 R14 守层者各 5~7 招） + 编排表 boss_choreography.gd:259-391 与 boss_choreography.gd:392-449（rq_bell/rq_earth/rq_abyss） |
| Boss 身体图集/姿态 | `scripts/boss_frames.gd`（KEYS/SPECIAL_KEYS boss_frames.gd:4/6；⚠️ SPECIAL_KEYS 顺序被 enemy_body.gd:35、boss_cinematic.gd:75、boss_hud.gd:70 按下标硬引用，另有同序 7 项的 `SPECIAL_BOSS_ART` battlefield.gd:31-38，**只能追加到表尾**） |
| Boss HUD（血条/阶段/降临立绘/黎明抉择面板） | `scripts/boss_hud.gd:11 _draw()` |
| 侧边立绘演出 | `scripts/boss_cinematic.gd`（`TITLES` 标题表 :21；特殊标题分支 :80） |
| 演出事件总线/音效 cue 命名 | `scripts/boss_presentation.gd`（`cue` boss_presentation.gd:31；隐藏 Boss 主题复用 HIDDEN_KIND boss_presentation.gd:6） |
| Boss 表现总控（震屏/预警/蓄力跟随） | `scripts/boss_vfx.gd`（事件时长 boss_vfx.gd:56，矢量预警 `hazard` boss_vfx.gd:129） |
| Boss 实体渲染（判定域=视觉域三层） | `scripts/boss_damage_visual.gd` + 出生方式 `scripts/boss_effect_staging.gd` + 可见性规则 `scripts/boss_effect_language.gd` |
| 17 身份×4 motif 美术表/主题色 | `scripts/boss_effect_art.gd`（⚠️ 颜色表按 KEYS.find 索引，加身份必须同步加色：`KEYS` boss_effect_art.gd:4、`color()` boss_effect_art.gd:62 与色表 boss_effect_art.gd:64）+ 素材 `assets/bosses/imagegen/` |
| 实体贴图接触点 | `scripts/boss_entity_contacts.gd` |

### I. 怪物生态（野外怪）

| 功能 | 文件:锚点 |
|---|---|
| 17 种怪物数值表（血量/伤害/前摇/掉落/地区池） | `scripts/ecology.gd:5-19`（POOLS/HEALTH/ATTACK_DAMAGE/WINDUP/DROP_CHANCE 等） |
| 12+ 种特化攻击 AI（俯冲/冲锋/环弹/地刺…）与移动 | `ecology.gd:62 update()`；⚠️ type 0-3 四种基础怪的近战/弹幕结算在 `session.gd:3404-3416`（type1 弹幕 3411-3413、近战 hurt 3414-3415；类型分发 session.gd:3390-3394），不在 ecology |
| 怪物图集清单与 12 帧姿态 | `scripts/enemy_frames.gd:4-8`（NAMES/FILES/HEIGHTS/COLORS；4×3 图集脚底对齐 210px） |
| 命中体（sprite↔判定映射/悬浮怪/俯冲） | `scripts/enemy_body.gd`（悬浮怪名单 :44，Boss 分支 :30-41） |
| 据点栖息区/难度缩放 | `ecology.gd:21 block_at()`、`ecology.gd:14-17` 各 SCALE 表 |

### J. 战场与地图渲染（2.5D）

| 功能 | 文件:锚点 |
|---|---|
| 战场主渲染（相机跟随/震屏/角色与怪物 billboard/预警/伤害数字/夜幕） | `scripts/battlefield.gd`（_process battlefield.gd:109；角色绘制 `actor` battlefield.gd:319；怪物预警 `monster` battlefield.gd:408；特殊 Boss 立绘索引 `SPECIAL_BOSS_ART` battlefield.gd:31） |
| **武器挂点/地面投影契约**（一切特效的锚） | `battlefield.gd:742 weapon_effect_socket()`、`battlefield.gd:744 ground_transform()`——新特效必须遵守，否则 tests/weapon_stroke_stability.gd 失败 |
| 3D 场景层（正交相机/地砖/墙/桥/湖/宝箱开盖/billboard 池） | `scripts/world_3d.gd`（rebuild world_3d.gd:165；精灵俯视压缩补偿 world_3d.gd:254） |
| 2D 地形底图与战术地图绘制 | `scripts/world_art.gd`（atlas world_art.gd:103；王城夜景 `city_terrain` world_art.gd:132） |
| CC0 模型库运行时（KayKit/Quaternius，shader 着色/包围盒） | `scripts/scene_assets.gd`（registry scene_assets.gd:5；宝箱开盖 chest_state scene_assets.gd:88） |
| 建筑占地表（**碰撞与显示共用同一矩形**） | `scripts/scene_asset_layout.gd:5 building()`（被 ruins.gd:16 与 world_3d.gd:6 共同消费） |

### K. 战斗特效（ImageGen 管线）

| 功能 | 文件:锚点 |
|---|---|
| 特效编排总控（事件→贴图特效/伤害数字/死灵法印/剑雨/敌方弹幕） | `scripts/combat_visuals.gd`（事件入口 `event` combat_visuals.gd:148；剑雨布局 `blade_layout()` combat_visuals.gd:501；与服务端判定共形 `patch_local_rect` combat_visuals.gd:475；敌方弹幕可读性常量 combat_visuals.gd:300-318、绘制 `draw_enemy_bolt()` combat_visuals.gd:363） |
| 刀光/突刺/蓄力/连招/大招 | `scripts/stylized_vfx.gd:55 emit()`、`stylized_vfx.gd:111 event()`、`stylized_vfx.gd:271 advance()`；释放固定在世界坐标，蓄力跟随；圆斩围绕身体并读取实际 height；光束起点捕获为局部坐标。**⚠️ 特效原点=角色自身，与近战判定框普遍不重合（详见 §11.54）：圆环战技异常、多数近战刀光末端 ≠ 攻击范围最远处，玩家会感觉"实际范围不符"。本轮（2026-10-08）经用户拍板只登记、暂不改。** |
| 69 把武器身份与实际招式选图 | `scripts/weapon_vfx.gd:34 profile()`；`scripts/weapon_mechanics.gd:3 normal_role()` 与 projectile_role()/strike_role()/burst_role() 从实际 family/pattern/spell/attack_kind 选图；飞行弹体 `combat_visuals.gd:661 draw_run_projectile()`；角色确认派生 `rogue_build.gd:1239 hero_effect()` |
| 按用途制作的 ImageGen 方图（50 张原图留档） | `scripts/weapon_image_art.gd:73 stamp_mechanic()` 从 assets/combat/imagegen-mechanics/manifest.json 读取原始 RGBA 与有效墨迹边界；mechanic_source() 选择各轮新版，重刃 v3、双刃 v3、震地 v2、重刃终结 v2 已接入；出手、弹体、光束与爆发分开；旧图保留来源记录 |
| 全部武器逐项视觉验收 | `tests/weapon_full_visual_audit.gd` 生成 69 页四角色核对图与 coverage.json；`tests/weapon_full_matrix.gd` 验证全部武器、四角色、八方向、两模式、三播放时刻与真实战技姿势；报告 WEAPON-FULL-AUDIT.md，浏览入口 build/weapon-full-audit/index.html |
| 强化/品质快照与核心确认事件 | `scripts/rogue_build.gd:80 visual_state()`、`rogue_build.gd:211 core_visual()`；session.gd 的 weapon_visual_state() 处理远征品质；出手时冻结状态传给弹丸/爆炸/连锁/命中；+2 核心 I、+3 角色连招、+4 核心 II、+5 角色连招增强，详见 WEAPON-IMAGE-VFX.md |
| CPU 粒子（1400 上限/21 武器材质物理/双通道渲染） | `scripts/combat_particles.gd`（WEAPON_STYLES combat_particles.gd:7；材质参数 spawn combat_particles.gd:42） |
| 粒子批量渲染（MultiMesh 光晕 + 三角数组几何） | `scripts/particle_glow_batch.gd` + `scripts/particle_geometry_batch.gd` |
| 兼容图与角色/核心索引 | `scripts/vfx_library.gd:55 texture()` 保留旧方图入口；普通武器主表现走 weapon_mechanics.gd 与 weapon_image_art.gd 的 mechanic_texture()，角色/核心继续使用自己的素材 |
| 特效显现动效（UV 揭示：sweep/rise/radial） | `scripts/effect_motion.gd` |
| 招式语义→视觉族/材质 | `scripts/effect_semantics.gd` |
| Shader 能量形态层（form 0-9） | `scripts/energy_bursts.gd` + `resources/energy_burst.gdshader` |
| ImageGen 动作帧清单加载 | `scripts/generated_attacks.gd`（清单 `assets/combat/generated-attacks/manifest.json`，实际两套：`bosses/`、`heroes/`） |
| **攻击前摇提示**（前摇填充/四层描边/倒计时/释放爆闪，与弹幕同色） | `scripts/attack_telegraph.gd`（`TINT` :20、`edge` :94、`hatch` :107、`sparks` :116、`disc` :127、`burst` :145、`countdown` :157、`paint` :174）；接线 `battlefield.gd:49` 实例化 + `battlefield.gd:431 telegraph.paint()`；弹体同色 `combat_visuals.gd:21` + `combat_visuals.gd:689 Telegraph.tint()`；口径见 ATTACK-TELEGRAPH.md |
| 21 把武器右键战技数值表 | `scripts/weapon_arts.gd:6 MOVES`（闯关武器经 `rogue_content.weapon(index).art` 覆盖 weapon_arts.gd:30） |

### L. 角色动画与语音/大招

| 功能 | 文件:锚点 |
|---|---|
| 四角色分帧中枢（攻击/移动图集/挂点/远程帧） | `scripts/character_frames.gd`（挂点 BLADE_TIPS/STAFF_TIPS/RUNE_TIPS character_frames.gd:154-178；BOW/RIFLE_SOCKETS :262-273；3D 实验开关 `USE_FEIYUE_3D=false` character_frames.gd:11） |
| 体型地标常量（统一头高 26px/脚底锚点） | `scripts/character_metrics.gd`（ATTACK/MOVEMENT 表 :10-53） |
| 持械待机网格变形（呼吸/重心） | `scripts/character_idle.gd`（节奏档案 PROFILES character_idle.gd:7） |
| 待机帧库/3D 广告牌池 | `scripts/character_idle_frames.gd`（manifest assets/combat/idle/）+ `scripts/character_idle_billboards.gd` |
| 大招全屏 CG（台词/推镜/与语音时长联动） | `scripts/ultimate_cinematic.gd`（台词 INVOCATIONS :5-26；语音时长读取 :98；impact_time=1.872 :42） |
| 角色语音槽（优先级/冷却/4 空间位） | `scripts/hero_voice.gd`（数据 assets/audio/voices/voice-manifest.json；大招三段 hero_voice.gd:145-172） |

### M. 音频

| 功能 | 文件:锚点 |
|---|---|
| 音效总管（24 战斗声部/UI/脚步/Boss 音频/大招音轨/对白压低） | `scripts/sound.gd`（cue 变体与音量表 sound.gd:5-17；Boss 音频回退 sound.gd:109；播放调度与优先级 `play` sound.gd:152；脚步系统 update_world sound.gd:251） |
| 32 首曲目/场景自动选曲/1.8s 交叉淡化 | `scripts/music.gd`（世界选曲 `set_world` music.gd:41；曲目清单 assets/audio/music/music-manifest.json） |
| 音频总线布局 | `resources/audio_bus.tres`（project.godot:24 引用；Master/Combat/Ambience/Cinematic/Interface/Dialogue/Music） |

### N. 营地与家园

**链路**：`main.gd:918 ensure_camp()` 创建 `camp_screen.gd`（唯一实例化点，信号驱动）→ 其内部组装 `camp_site.gd`（3D 地图）+ `home_screen.gd` + `home_map.gd` + `camp_activities.gd` + `fishing_meter.gd`。营地站点点击 → `main.gd:998 on_camp_station()` 分发（warehouse→行囊面板聚焦仓库、market→交易行、forge→锻炉、launch→出发、rogue→魔境报名…）。**Tab 打开远征行囊**（`camp_screen.gd:672` → `main.gd:939 toggle_camp_pack()`）。**HUD「出发」按钮**走 `main.gd:988 camp_departure()`：站在闸门/传送门时进对应站点，否则按当前模式直接进（`on_camp_station("launch"/"rogue")`）——它以前只 `say()` 一句提示，而提示画在行囊面板底下，看起来就是"点了没反应"。

| 功能 | 文件:锚点 |
|---|---|
| 营地界面外壳（HUD/设施列表/输入/名册/出发） | `scripts/camp_screen.gd`（设施分组 camp_screen.gd:343；按键 `_unhandled_input` camp_screen.gd:619；**F 只拾取脚下掉落物** camp_screen.gd:665（整备台不再占 F 键）；**Tab 打开远征行囊** camp_screen.gd:672 → 信号 `pack_requested` camp_screen.gd:18；面板挡屏时 Tab/Esc 走 `dismiss_requested` camp_screen.gd:22；marker 层 F 提示 camp_screen.gd:731）；右键蓄力直达站点 camp_screen.gd:545） |
| 营地 3D 地图（可行走碰撞/遮挡淡化/站点定义/雷暴程序生成与运行时合成音效） | `scripts/camp_site.gd`（可行走边界 `is_walkable` camp_site.gd:169-178（边界矩形 :170）；**十设施站点表 `_build_stations` camp_site.gd:936-960**；作物显示 refresh_crops camp_site.gd:544；闪电 strike camp_site.gd:1350） |
| 世界内农事/垂钓动作状态机（动画播完才结算） | `scripts/camp_activities.gd`（`farm` camp_activities.gd:145；垂钓四阶段 `update_fishing`；收获/钓鱼溢出 → `spill_overflow()` camp_activities.gd:253 落地为 Sprite3D 掉落物 `drop_item()` :263，`has_drop_near()` :278 / `pick_up_nearby()` :296 供 F 优先拾取） |
| 钓鱼时机条 UI | `scripts/fishing_meter.gd:9 _draw()`；装配与容差（fine 档）在 camp_screen.gd:135-140 / 513-517 |
| **家园规则层**（作物/鱼/料理价格表、离线生长、战斗加成） | `scripts/homestead.gd`（CROPS/FISH/MEALS homestead.gd:3-17；离线生长 `remaining` homestead.gd:86；**收获即掉落物**：tend 收获分支 `receive_product` homestead.gd:123、钓鱼 `catch_fish` :175 均把产物塞背包/口袋，装不下的量记入 `take_overflow()` :30 交营地落地；`cook()` :135 与 `catch_fish` 用 profile 实例计数，`home.sell()` 已退役改走交易行；**被 session.gd:295 引用**，加成 `meal_id/bonus` homestead.gd:176-181 经 session.gd:306-307 进入玩家、落库 session.gd:317；开局扣餐食 `consume_started` homestead.gd:146，调用点 main.gd:1119-1120） |
| 家园商店/厨房面板 | `scripts/home_screen.gd`（build_shop home_screen.gd:75；“出售”页现在是**真出售**：每张卡「卖 1 / 全部出售」，走 `profile.gd sell_product()`；「持有 ×N」仍读 `profile.product_count()`，跨容器语义未变；build_kitchen home_screen.gd:106 食材进度按背包/口袋/仓库实例计数） |
| **商店"卖出真删仓库实体"** | 存储层唯一实现 `profile.gd sell_product(kind, units)`：**先扣仓库实体格**（整堆卖光 `warehouse_remove()` 真腾格、部分卖就地改 `count`；网格与 spill 共享索引空间一并覆盖），仓库不够才扣口袋/背包；跳过 `provision` 补给（与交易行 `market_value` 规则一致）；按目录单价付币、写 `trade_history`、唯一落盘点 `save_profile()`；返回 `{sold, coins, missing}`。`product_count()`（持有口径）**未动**。**买入已实体化**（`homestead.gd buy()` :77）：种子/鱼饵先进仓库（`warehouse_deposit`）、满则退随身背包（`profile.gd deposit_backpack()` :583，**不进次元口袋**）、都满则余量入 `overflow` 交 `home_screen.gd buy_report()` :76 掉营地地上 + `notice_popup` 提示（全额扣款、永不丢件）；播种/抛竿改扣实体（`homestead.gd plant()` :116 / `cast()` :172 走 `spend_product()`）；旧档 seeds/bait 计数器由 `profile.gd migrate_home_seeds_bait()` :720 一次性迁进仓库（零丢件） |
| **交易行（晨钟交易行）** | `scripts/economy_screen.gd`：**左侧上下两块货架、各自带滚动条**（仓库 15×15 在上、血月背包在下）；选择是**跨两块的一个索引空间**（`vault_entries()`/`bag_entries()` 构建、`split()` 归属）；出售分两条路——仓库 `Profile.sell_items()`、背包 `camp_storage.gd sell_backpack(profile,session,p,indices) -> {"coins","count"}`（整叠一起卖、`provision` 拒卖、按 `Catalog.item_value()*units` 付币、索引**从后往前**删以免位移）；`CATEGORIES` 里的"背包"**已删除并入"武器与装备"**。共享滚动配方抽在 `scripts/ui_scroller.gd`（Godot 的 `ScrollContainer` 不重排手放格子、会压住最右列，故按 `ui_skin` 既有做法：容器内放一个全高 `Control`、滚动条留在边框留白里）。格子仍由 `item_tile.gd` 画 |
| 家园导览地图（从真实几何绘制/点击传送） | `scripts/home_map.gd`（`class MapCanvas` home_map.gd:119，`_draw()` home_map.gd:125） |
| 营地建筑层（CC0 圣堂模块/可进出书屋/城墙） | `scripts/home_architecture.gd`（model home_architecture.gd:12；house home_architecture.gd:52） |
| 家园图标/皮肤图集/动作帧 | `scripts/home_art.gd:1-18` + `scripts/home_ui_skin.gd`（108 行）+ `scripts/home_activity_frames.gd:1-24`（数据 `assets/home/animations/manifest.json`；动作帧实例化点 camp_site.gd:91） |

### O. 经济与角色属性

| 功能 | 文件:锚点 |
|---|---|
| 仓库/交易行界面（分类/搜索/批量/禁售标记） | `scripts/economy_screen.gd` —— **交易行专用网格窗口**：点格子多选、二次确认出售（`sell()` economy_screen.gd:251、格子绘制 `refresh()` :148、溢出暂存行 `spill_shelf()` :179）；格子里程碑来自 `profile.gd:748 sell_items()`（按下标），估价 `catalog.gd:436 market_value`。仓库侧已并入营地行囊面板（`main.gd:1074 show_economy()` 里 `market=false` 会转 `show_camp_pack(true)`） |
| **整备台（付费买断三件出战装备）** | UI `main.gd:1139 show_camp()` + 购买 `main.gd:1176 buy_camp_gear()`；钱规则 `profile.gd:546 buy_gear()`（差价结算、换装销毁旧件、买不起不改动）；买不起的居中偏上提示 `main.gd:1198 notice_popup()` |
| 锻炉 UI（七属性加点/出战预览/天赋升级） | `main.gd:1213 show_camp_forge()` |
| **七属性规则**（成长曲线/补正 grades） | `scripts/attributes.gd`（KEYS/GRADES attributes.gd:5-11；`growth` attributes.gd:34；派生 `hp_bonus` attributes.gd:41 / `max_mana` :44 / `resistance` :47 / `discovery` :50 / `scaling` :53，共 :41-57） |

### P. 联机、账号与服务器

**三层联机拓扑**：IP 直连（UDP 24872）→ P2P 打洞（HTTPS 信令 + 自建 STUN 3478）→ 专用服务器（Godot headless 房间进程池 24900-24915）。

| 功能 | 文件:锚点 |
|---|---|
| ENet 主机/加入/专用服/票券/快照 RPC | `session.gd`（见 §4.C 首行） |
| P2P 房间/自研 STUN(RFC 8489)/打洞/12s 失败切专用服 | `scripts/p2p_service.gd`（create_room p2p_service.gd:75；STUN parse p2p_service.gd:150；fallback_to_server p2p_service.gd:278） |
| 账号/登录/游客/云存档 REST 客户端（409 版本冲突） | `scripts/online_service.gd`（API 端点表见 online_service.gd + p2p_service.gd；api_url 读 `game.cfg [server]` online_service.gd:18-24） |
| **服务器**（Python 3.10+ 纯标准库，HTTP API + SQLite + 内置 STUN + Godot 房间进程池） | `server/app.py`（端点分发 app.py:251-405；房间 dedicated_room app.py:197）、`server/room.gd`（每房间一个无窗口 Godot 权威进程）、`server/docker_entrypoint.py`（`ROOM_PORT_START/STUN_PORT` docker_entrypoint.py:12-14） |
| 服务器部署文档 | 根目录 `SERVER.md`（裸机/源码）、`server/DOCKER.md`（容器离线镜像）；`compose.yaml`+`Dockerfile`+`.env.example`+`server/Caddyfile.docker`（另有 `server/Caddyfile.example`） |
| 联机 UI（创建房间/房间号/准备/出发） | `main.gd`：服务器房间页 `show_server_rooms` main.gd:406、P2P 房间页 `show_p2p_rooms` main.gd:421、创建/加入 `connect_p2p_room` main.gd:438、ENet host/join main.gd:937-950、房间号与邀请复制 main.gd:1074/1097、准备出发 main.gd:1095；账号页 `show_account` main.gd:286 |

### Q. 着色器总表（resources/ 与 shaders/）

连接道路材质：resources/story_connection.gdshader，由story_environment.connection_material配置相邻区域两套PBR并沿道路混合；路心/泥土路肩使用顶点色，不能用固定满幅石板。


| Shader | 用途 | 加载者 |
|---|---|---|
| blood_tide.gdshader | 世界空间血雾缩圈 | scripts/blood_tide.gd:17 |
| boss_damage_shape.gdshader | Boss 地面伤害域（与 CPU contains() 同界） | scripts/boss_damage_visual.gd:6 |
| boss_entity_birth.gdshader | Boss 实体出生揭示 | scripts/boss_damage_visual.gd:10 |
| camp_occluder.gdshader / camp_vignette.gdshader | 营地遮挡体 / 屏幕暗角 | camp_site.gd:56 / camp_screen.gd:158 |
| combat_glow.gdshader | 加法混合发光层 | combat_visuals.gd:58、boss_cinematic.gd:27、ultimate_cinematic.gd:61 |
| damage_vignette.gdshader | 受击红晕 | main.gd:223 |
| energy_burst.gdshader | 程序化能量形态 form 0-9 | energy_bursts.gd:3、camp_site.gd:19 |
| home_ground.gdshader / home_water.gdshader | 家园草地/水面 | camp_site.gd:463 / camp_site.gd:605 |
| particle_glow_batch.gdshader | MultiMesh 粒子双圆光晕 | particle_glow_batch.gd:3 |
| scene_asset.gdshader | 场景道具着色（叶片染色/空置灰化） | scene_assets.gd:4 |
| story_ground.gdshader / story_stone.gdshader / story_water.gdshader | 故事连续地面混合、石木建筑与微弱河面波纹 | `story_environment.gd:3 GROUND`、`story_environment.gd:4 STONE`、`story_environment.gd:5 WATER` |
| story_occlusion / story_foliage / story_mist / story_contact_shadow.gdshader | 渐进遮挡、草叶、局部雾和坡地接触阴影 | story_asset_kit.gd、story_environment.gd、story_world.gd |
| storm_bolt.gdshader / storm_sky.gdshader | 营地闪电带/雷暴天幕 | camp_site.gd:18 / camp_site.gd:17 |
| stylized_texture.gdshader | 武器主体直通原图着色；厚度来自14张重新生成的原图，移除旧扩边 shader | stylized_vfx.gd:41 |
| weapon_edge_glow.gdshader | 饱和色边缘辉光与亮芯（局部透明边缘采样） | stylized_vfx.gd:35 |
| boss_projectile_shell.gdshader | Boss 弹幕外壳（飞行体可读性/朝向） | scripts/boss_damage_visual.gd:11 |
| shaders/hero_hair_motion.gdshader | 发梢位移（仅离线烘帧工具用，非运行时） | tools/bake_hero_walk_v4.gd、tools/preview_hero_hair.gd |

---

### R. 开发者模式

**本类包含**（只对开发者可见的东西，正式游玩一律不出现）：
- **R.1 互动半径表** —— 游戏中每一处"走到多近才能按键"的**唯一真值表**（提示出现 = 一定能按键）。
- **R.2 判定框总览** —— 用代码级开关把各类范围框叠加画出来的引擎（M0/M1 已落地）。
**跨类指引**：这里列的每一条都对应 §4.A–§4.Q 里某个系统的判定；**改任何判定半径，先来 R.1 登记，再去对应系统改代码**（两边必须同源）。完整路线图（战斗/搜打撤/肉鸽/营地/UI 五组判定框的清单与里程碑）在工作区上一层 `任务.md`。

#### R.1 互动半径表（提示出现 = 一定能按键）

> **单一真值原则**：所有战斗/魔境/搜打撤互动半径常量唯一定义在 `session.gd:89-97`（`GATE_RADIUS` 85 / `RESCUE_RADIUS` 75 / `EXIT_RADIUS` 83 / `SHRINE_RADIUS` 72 / `SEARCH_RADIUS` 80 / `DROP_RADIUS` 70 / `CHEST_RADIUS` 85 / `LOOT_RADIUS` 80 / `FORK_RADIUS` 64）；营地交互半径常量定义在 `camp_activities.gd:9-12`（`PLOT_RADIUS` 155 / `PIER_RADIUS` 240 / `DROP_RADIUS` 120 / `PIER_AT`）。提示出现的距离必须严格等于按下生效的距离。

| 交互 | 提示在哪 | 提示条件 | 判定在哪 | 判定条件 | 状态 |
|---|---|---|---|---|---|
| 营地 10 个设施（按 E） | `camp_screen.gd:749` `"[E] %s"` | `station_at()` 命中 | `camp_screen.gd:691 interact()` → `camp_site.gd:1556 station_at()` | 距离 < `stations[].radius` | ✅ 同源（**数据字段** `camp_site.gd:936-960`：250/215/215/205/265/230/200/170/170/170） |
| 营地设施名牌（地标层） | `camp_screen.gd:739-741`（地名可见范围）、`:788 StationMarker._draw()` | 圈外只画暗名；进圈才出光环与按键 | 同上 | < `station.radius`（最小 170） | ✅ 已对齐（圈外地名变暗且不带按键字样，进圈出光环与[E]） |
| 田畦 播种/浇水/收获 | `camp_screen.gd:750-753` → `camp_activities.gd:139 plot_hint()` | `nearest_plot()` 命中 | `camp_activities.gd:140 interact()`→`farm()`，`:155` 复查 | 距离 ≤ `PLOT_RADIUS` (155) | ✅ 同源（常量 `camp_activities.gd:8`） |
| 栈桥 抛竿（[E]/[Space]） | `camp_screen.gd:755` | `camp_activities.gd:123 at_pier()` | `camp_activities.gd:186 cast()`、`camp_screen.gd:656` | `at_pier()`：DOCK 内且距 `PIER_AT` < `PIER_RADIUS` (240) | ✅ 同源（常量 `camp_activities.gd:9`） |
| 家园 地面拾取（[F]） | `camp_screen.gd:667` | `has_drop_near()` ≤ `DROP_RADIUS` (120) | `camp_screen.gd:677` → `nearest_drop` / `pick_up_nearby()` | 同 `DROP_RADIUS` (120) | ✅ 同源（常量 `camp_activities.gd:10`） |
| 搜打撤 城门（长按 E 1.5s） | `main.gd:2161` | 距 portal < `session.GATE_RADIUS` (85) 且 `can_travel()` | `session.gd:3649` | 同 `session.GATE_RADIUS` (85) + `party_at_gate()` | ✅ 同源常量 |
| 搜打撤 城门世界标签 | `battlefield.gd:182 key_hint()` + `:201` | 相机 < 1500 且玩家 < `GATE_RADIUS` (85) 出 `[E]` | `session.gd:3649` | 玩家距城门 < `GATE_RADIUS` (85) | ✅ 已对齐（远处纯地名，进圈才出 [E]） |
| 搜打撤 撤离点（长按 E 4s） | `main.gd:2165` | 距 exit < `session.EXIT_RADIUS` (83) | `session.gd:3659` | 同 `session.EXIT_RADIUS` (83) | ✅ 同源常量 |
| 搜打撤 撤离点世界标签 | `battlefield.gd:182 key_hint()` + `:218` | 相机 < 1500 且玩家 < `EXIT_RADIUS` (83) 出 `[E] 撤离` | `session.gd:3659` | 玩家 < `EXIT_RADIUS` (83) | ✅ 已对齐（远处纯地名，进圈才出 [E]） |
| 搜打撤 封印（长按 E 3s） | `main.gd:2169` | 距 shrine < `session.SHRINE_RADIUS` (72) | `session.gd:3665` | 同 `session.SHRINE_RADIUS` (72) | ✅ 同源常量 |
| 搜打撤 救援队友（长按 E 3s） | `main.gd:2158` | 距倒地队友 < `session.RESCUE_RADIUS` (75) | `session.gd:3653` | 同 `session.RESCUE_RADIUS` (75) | ✅ 同源常量 |
| 搜打撤 箱子搜索（[F]/[H]） | `main.gd:2176`（用 `session.SEARCH_RADIUS`=80 决定显示） | 容器距玩家 < `SEARCH_RADIUS` (80) | `main.gd:1985` → `session.gd:994 search_target` | 距离 < `SEARCH_RADIUS` (80)（中途离开宽限 `SEARCH_RANGE`=86，`session.gd:85`） | ✅ 已对齐（消除 70~80 反向不一致） |
| 搜打撤 世界标签（箱/掉落/背包） | `battlefield.gd:182 key_hint()` + `:239/:264/:271` | 相机 < 1500 且玩家 < `SEARCH_RADIUS` (80) / `DROP_RADIUS` (70) 出按键 | `session.gd:974/984/1000` | 玩家 < `SEARCH_RADIUS` / `DROP_RADIUS` | ✅ 已对齐（远处纯地名，进圈才出按键） |
| 魔境 开宝箱（[E]） | `main.gd:2096`、`main.gd:5207`、`rogue_room_ui.gd:227`、`rogue_field.gd:145` | 玩家距 chest ≤ `session.CHEST_RADIUS` (85) | `session.gd:3634` → `roguelike.gd:727 loot_interact()` | 距 chest ≤ `session.CHEST_RADIUS` (85) | ✅ 已对齐（按判定圈动态显示 [E]，远处为叙述句） |
| 魔境 掉落拾取（[E]） | `main.gd:2096`、`rogue_field.gd:124-133` | 玩家距 drop < `session.LOOT_RADIUS` (80) 且过落地延迟/归属门 | `roguelike.gd:738` | 距离 < `session.LOOT_RADIUS` (80) | ✅ 已对齐（三道门与判定完全镜像） |
| 魔境 分叉选路（按住 E） | `main.gd:2096/4953/5211`、`rogue_room_ui.gd:227`、`rogue_field.gd:185` | `x > fork_start` 且距 exit ≤ `session.FORK_RADIUS` (64) | `session.gd:3637` / `roguelike.gd:1346` | 同 `session.FORK_RADIUS` (64) | ✅ 已对齐（按判定圈动态显示 [E]，远处为叙述句） |
| 魔境 救援队友（长按 E 2.5s） | `main.gd:2140-2148`（救援者）与 `:2138`（倒地者） | 救援者 active 且距倒地者 ≤ `session.RESCUE_RADIUS` (75) | `roguelike.gd:1484 rescue()` | 救援者距倒地者 ≤ `session.RESCUE_RADIUS` (75) | ✅ 已对齐（救援者近身才出长按 [E] 提示） |
| 收竿 / 魂灯自救 / 倒地自救 | `camp_screen.gd:537`、`main.gd:2138/2145` | 状态机 | 同状态机 | 无距离判定 | ✅ 同源 |

**已修总清单（2026-10-08 落盘验收）**：
1. **营地名牌**：650 仅管地名可见性，`camp_screen.gd:788` 圈外只画暗名；进圈（`< station.radius`）才画完整光环+下箭头+白字。
2. **搜打撤世界标签**（`battlefield.gd:182 key_hint()`）：按玩家真实距离门控按键字样，城门 85 / 撤离 83 / 宝箱 80 / 掉落 70；1500 仅作为相机视距门控。
3. **魔境提示与指路行**（`main.gd:2096/4953/5211`、`rogue_room_ui.gd:227`、`rogue_field.gd:145`）：远处统一为安全叙述句，进入判定距离（85/80/64）才出 [E] 或高亮。
4. **宝箱 HUD**：`main.gd:2176` 由 70 修正为 `session.SEARCH_RADIUS` (80)，与判定圈严格统一。
5. **单真值化**：9 处搜打撤/魔境半径常量收拢至 `session.gd:86-97`；营地半径常量收拢至 `camp_activities.gd:6-12`。

#### R.2 判定框总览（开发者模式，M0/M1 已落地）

| 东西 | 在哪 |
|---|---|
| 覆盖层引擎（只读） | `scripts/dev_ranges.gd`：开关 `dev_ranges.gd:32 enabled()`（环境变量 `CRIMSON_DEV_RANGES`），画框工具 `ring()`/`label()`/`draw_legend()`，第一批 `draw_souls()`/`draw_actors()` |
| 挂载点 | `main.gd:285-290` 起（`rogue_field` 建好后）——**只有开发者模式才 new 这个节点**，正式模式连节点都不创建 |
| 启动脚本 | `开发者模式启动.cmd`（设 `CRIMSON_DEV_RANGES=all` 后 `call 游戏启动.cmd`） |
| 已画出来 | 魔境战场：主人索敌圈 300、灵体索敌圈 166.7 / 射程 150 / 停靠 127.5、主人点名目标、角色地形判定 15、怪物半径、灵体→目标连线；F9 收文字 |
| 待做批次 | 营地（设施交互圈 + "半径/实时距离"文字，`camp_site.gd:1556` 与 `camp_screen.gd:738 site.project()` 是入口）、肉鸽房型地面多边形、搜打撤 3D、UI 热区——清单见工作区上一层 `任务.md` |

### S. 故事模式与连续探索地图

图形任务日志：story_quest_ui（J/人物委托/档案NPC）使用73任务真数据、分类卡片、目标进度与报酬；story_quest_fx响应campaign.quest_event，接取/推进/完成只在真实状态改变时播放，特效不发奖励。tracked/track持久保存追踪ID，HUD读取tracked；tests/story_quests_ui.gd覆盖真实鼠标、E与事件幂等。

战役GUI：`story_screen.gd` 的 `show_items()` / `show_bag()` / `show_growth()`；NPC索引2/4/5分别转锻造、交易、仓库。`story_inventory.gd` 的 `move()` / `equip()` / `buy()` / `forge()` / `craft()` 是唯一规则口，`valid_data()` 校验新实例存档。三人装备镜像写回kits，伙伴伤害也读自己的装备。配套tests/story_items.gd、story_items_ui.gd；制作与操作见docs/rpg/ITEMS-AND-SERVICES.md。

| 功能 | 文件与配套检查 |
|---|---|
| 地区连接、双向副本入口、寻路 | `story_map.gd:23 configure()`、`story_map.gd:147 route()`；tests/story_geography.gd |
| 地形、楼梯、房屋与碰撞 | `story_region.gd:32 build()`、`story_region.gd:268 height_at()`、`story_region.gd:354 building_walls()`；楼梯高度与门洞必须同时影响渲染和移动 |
| 场景摆放、屋顶、灯光、河岸 | `story_environment.gd:38 build()`，`story_world.gd:94 sync_story()`；tests/story_visual.gd |
| Forward+画质、超分与兼容启动 | `graphics_quality.gd:30 apply()`、`graphics_quality.gd:52 configure()`；graphics_settings_ui.gd、Start-Compatibility.cmd |
| Blender模型、PBR与可编辑地编 | story_asset_kit.gd；art/story-environment/opening-master.blend、opening-terrain.blend；scenes/story/*.tscn / *.scn；docs/rpg/FORWARDPLUS-ART-PIPELINE.md |
| 开场室内家具、侧墙与占地 | story_set_dressing.gd / resources/story-opening-dressing.json共享摆放与碰撞；story_region.height_at按室内台基抬脚；story_environment.crafted_details、story_asset_kit.mesh_nodes包含淡出根网格；tools/patch_story_workplaces.gd增量编辑，tools/Bake-Opening.ps1重新烘焙；tests/story_workplaces.gd |
| 不规则洞窟与旧堡副本 | story_region.floor_contains/build_castle、story_environment.cave_shell/castle_shell；story-cave-footprint.json统一地面/移动/寻路/探索图；OUTDOOR-CASTLE.md、tests/story_outdoor_castle.gd；第九区存档上限从章节地图数量读取 |
| 建筑室内地面材质 | story_floor_palette.gd、resources/story_interior_floor.gdshader；城堡/墓室/书库/礼拜堂分流，自然洞窟保留岩土；tools/patch_story_interior_floors.gd仅替换地面/台阶/台基，tests/story_architectural_floors.gd；docs/rpg/INTERIOR-FLOORS.md |
| 第二至第六幕美术/副本 | `scripts/story_act_art.gd:14 configure()`、`scripts/story_act_art.gd:6 terrain()`；story-later-acts.json / story-later-terrain.json；`scripts/story_regional_environment.gd:4 ground()`、`scripts/story_regional_environment.gd:24 walls()`；独立acts-2-6-master.blend、scenes/story/act*-*.tscn；`tests/story_later_acts.gd:12 run()`、tools/Bake-Later-Acts.ps1；docs/rpg/ACTS-2-6-ART.md |
| 副本规模、环路、分区高差、室外非矩形边界 | story_exploration_art.configure / contains / height、story_exploration_environment.terrain / walls / outdoor_edge；story-exploration.json同步模型、通行、导航、敌群、探索图；独立dungeon-master.blend与34新模块；tests/story_exploration.gd；⚠️布局修改后必须更新缓存场景并重烘静态地面 |
| 室外地面、桥头、岸线与虚空边界 | story_surface_geometry.land_pieces / connector_pieces；story_exterior_composition.build / height / river_outline；story_environment.connector_ground / curved_river；tests/story_boundary_surfaces.gd覆盖实际普通/兼容网格、世界偏移和移动轮廓保护；BOUNDARY-SURFACES.md。⚠️Packed数组平移前必须duplicate；静态地面/岸壁改动要重烘，外景要有起伏/装饰；外景不覆盖通路并排除固定GI |
| 副本空间类型与边界语言 | story-exploration.json的layout_family / grade_axis / edge_styles / void_surface；story_exploration_environment.surrounding_geology与墙/栏杆/拱廊/断墙；30区22类型、10—14功能空间，DUNGEON-IDENTITIES.md；tests/story_dungeon_identity.gd和tools/verify_story_dungeon_release.gd检查真实缓存及发布包 |
| 植被缓存与无头制作 | `scripts/story_ground_cover.gd:6 _ready()`；source_mesh / source_transforms保留CPU数据，prepare_capture清空GPU缓冲；story_environment.cover_batch、tools/patch_story_ground_cover.gd；⚠️不得序列化Dummy渲染器的MultiMesh实例缓冲，可能产生遮住整幅画面的巨面 |
| 五幕临时场景试玩 | Preview-Later-Acts.cmd、`scripts/story_screen.gd:82 start()`；显式--preview-story/--story-act/--story-stage，开放五幕传送并禁用保存；tests/story_art_preview.gd |
| 4K渲染与性能验收 | tests/story_render_upgrade.gd、story_4k_benchmark.gd、tools/monitor_story_gpu.py；原始数据在build，正式结果见TEST-REPORT |
| 战役任务、传送激活、分层往返与存档 | `story_campaign.gd:45 load_campaign()`、`story_campaign.gd:309 activate_waypoint()`、`story_campaign.gd:333 use_entrance()`；tests/story_campaign.gd、story_geography.gd |
| 探索地图、UI与输入 | `story_screen.gd:373 show_atlas()`、scripts/story_atlas.gd；tests/story_integration.gd、story_visual.gd |
| 内容编译与本地参考复查 | tools/build_story_content.py、inspect_reference_maps.py、inspect_reference_regions.py、inspect_d2r_scenes.py；范围见docs/rpg/IMPLEMENTATION.md |

## 5. 「我要改 X」速查表

### 玩法规则类

故事地图、任务与NPC → §4.S；连续区域/门洞改 story_map/region，3D场景改 story_environment/world，传送与战役规则改 story_campaign，面板改 story_screen/atlas。不要把故事币、经验或任务写进远征结算。

故事行囊/人物/买卖/锻造 → §4.S、story_inventory/items_ui/item_grid/ui_skin。新入口Preview-Inventory.cmd与Start-Story-GUI.cmd；补丁由pack_story_patch_launcher和build_story_patch_runtime制作，依赖v9底包，不能直接用旧v9启动来验证新GUI。

洞窟轮廓与旧堡 → story-cave-footprint.json / story_region.floor_contains、build_castle / story_environment.cave_shell、castle_shell；地面/移动/探索图必须共享边界，新增区域须同时更新内容编译器和存档区域校验。新增模块在master编辑，已有室外场景用patch_story_outdoors增量追加。

故事美术、画质与闪烁 → graphics_quality/settings_ui、story_asset_kit/environment；模型改opening-master.blend后只导出，地编改scenes/story/*.tscn后运行Bake-Opening.ps1。楼梯/平台由结构网格画顶面，基础地形必须裁去同一区域；小树阻挡在story_region.add_prop统一处理。

第二至第六幕美术/不同题材副本 → story_act_art / story_regional_environment / story-later-acts.json / story-later-terrain.json。新模型改acts-2-6-master.blend，export_story_models.py带--source局部导出；新场景改act*-*.tscn后用Bake-Later-Acts.ps1。JSON占地/轮廓与缓存场景成对更新，不可只改一边；地图ID、任务、传送存档不随美术改名。

副本空旷、方形边界、独立高台 → story-exploration.json与story_exploration_art / story_exploration_environment。30副本、19室外区域共享轮廓与高程；动布局必须更新对应场景/GI/兼容缓存。Build-Exploration-Scenes.ps1与Bake-Exploration-Scenes.ps1支持按幕制作；Preview-Dungeons.cmd打开v6临时副本试玩。

副本像同一套房间换位置 → DUNGEON-IDENTITIES.md与author_dungeon_identities.py（首次制作，禁止自动重放）；正常编辑story-exploration.json。墓甬道/岩腔/庭院翼楼/环塔/扇形剧场/设备大厅/船坞跨槽分别组织；grade_axis控制X/Y高差，edge_styles逐段控制墙/断墙/栏杆/拱廊/岩壁/开放边。Build/Bake-Exploration-Scenes.ps1加-DungeonsOnly只更新30区；Preview-Dungeons.cmd打开v7并可选择具体地图。保留地图ID、任务和存档入口。

营地家具与进屋遮挡 → story-opening-dressing.json / story_set_dressing.gd / story_region / story_environment；带footprint的家具移动时同步JSON与可编辑场景。相机方向墙为Side组，固定烘焙排除Side/Front/Roof。prepare_reveal与reveal都要处理MeshInstance3D根本身，不能只遍历子节点。新增模块在master编辑后可指定export_story_models.py --assets局部导出。

| 需求 | 主要文件 | 配套（测试/文档/工具） |
|---|---|---|
| 调远征三天时长/跨天恢复/黎明 Boss 数值 | expedition.gd:6-93 + session.gd:50-51（:50 一天时长、:51 缩圈开始） | tests/expedition*.gd；EXPEDITION.md |
| 改主线 Boss/隐藏 Boss 招式 | boss_choreography.gd（编排）+ expedition.gd:424-614（legacy） | tests/boss_choreography.gd；BOSS-REWORK.md |
| 调骑士数值/格挡 | boss_tactics.gd（KNIGHT_MOVES :10）+ `session.gd:4324 KNIGHT_MOVES`（招式表用在 :3845 与 :3905） | tests/boss_tactics.gd |
| 加新 Boss（身份） | boss_choreography.gd `MOVES` + boss_effect_art.gd（`KEYS` :4 / `MOTIFS` :6 / `color()` 色表 :55-57，按 KEYS 索引）+ assets/bosses/imagegen/ + boss_frames.gd `SPECIAL_KEYS`（**追加表尾**，`COLORS` 在 boss_frames.gd:9）+ boss_presentation.gd cue + boss_hud.gd 颜色/阶段 | tests/boss_*；BOSS-REWORK.md |
| 调缩圈数值/时序 | session.gd:51、2788-2802（safe_center/safe_radius/final_radius） | tests/expedition.gd；视觉另改 blood_tide.gdshader |
| 调理智/气味/威胁度/刷怪 | session.gd:2624-2632、2688-2696、3247-3319 | tests/ecology.gd |
| 改掉落（宝箱/敌人/据点/骑士） | session.gd:1312 chest_loot / 1328 enemy_loot / 3342 resolve_site_defeat / 3740 knight_reward | tests/systems.gd；BALANCE.md |
| 加新野外怪物 | enemy_frames.gd:4-8 四表 + ecology.gd:5-19 六表 + ecology.gd update() 新分支 + assets/enemies/ 4×3 图集（脚底 210px）+ 悬浮怪名单 enemy_body.gd:44 | tests/enemies.gd、ecology.gd；ENEMY-UPDATE.md |
| 加营地设施 | camp_site.gd:936-960 站点表 + 建模函数 + camp_screen.gd:343 分组 + main.gd:754 on_camp_station 分支 | tests/camp*.gd；HOMESTEAD.md |
| 改家园数值（作物/鱼/料理/价格） | homestead.gd:3-17 + buy/fish_key；图标 home_art.gd | tests/homestead.gd |
| 改种子/鱼饵买入落点（仓库→背包→落地） | `homestead.gd buy()` :77 / `plant()` :116 / `cast()` :172 + `profile.gd deposit_backpack()` :583 / `migrate_home_seeds_bait()` :720 + `home_screen.gd buy_report()` :76 | tests/homestead.gd、homestead_ui.gd、camp_activities.gd |
| 改七属性曲线 | attributes.gd（⚠️ `clean(value, budget := 623)` attributes.gd:16 的预算要与 `point_budget` 同步） | tests/attributes.gd |
| 改结算奖励/XP | session.gd:4154 settle()；入库 main.gd:3389 | tests/systems.gd |
| 改隐藏结局/招募墓煜 | expedition.gd:236-288 + session.gd:2750-2775（隐藏判定 :2774）+ profile.gd:27-32、81-95 + main.gd:3100-3108 | tests/hidden_ending.gd；HIDDEN-ENDING.md |
| 改王城（布局/进出/珍藏） | royal_city.gd + `session.gd:4222 receive_results()`（portal_position :3759 / travel_city :3768） | tests/city.gd；CITY-UPDATE.md |
| 改边境地图布局 | ruins.gd（⚠️ 改地形后必须重跑 `tools/export_world_layout.gd` + `tools/bake_world_art.py`，见 MAP-UPDATE.md:37-39） | tests/map.gd |
| 改闯关流程（房间/出口/商店/奖励） | roguelike.gd | tests/roguelike*.gd、rogue_build_progression.gd |
| 改闯关地图/换背景图/分叉口碰撞 | `rogue_map.gd` + `assets/rogue/regions/ground-manifest.json`（⚠️ 分叉口不许再退回"两条走廊并起来"的写法：`fork_junction()` 负责把路口补平成广场，见 §11.43） | tests/roguelike_routes.gd（含"岔口到两个门口无隐形墙"的全地图断言）、tests/roguelike_geometry.gd |
| 改肉鸽图谱 / 房间类型 / 事件 / 诅咒 | rogue_graph.gd、rogue_rooms.gd + rogue_room_ui.gd、rogue_events.gd、rogue_curses.gd | tools/run_rogue_gate.ps1；**先读契约** output/ROGUE-CONTRACTS.md |
| 改肉鸽**路线图界面**（M 键那张图：列宽/行距/节点画法/图例） | `scripts/rogue_map_screen.gd`（数据全在 `layout()` :68，绘制在 `draw_map()` :287，几何常量 :427-433）+ `main.gd:2349` 显隐 | 暂无专属测试（`layout()` 是纯函数，可直接 headless 断言）；`tests/rogue_ui_visual.gd` 只覆盖 HUD 文案 |
| 改**派生链预览**（行囊内 V：连招链/天赋/锻造铭刻门槛） | `scripts/rogue_build_preview.gd`（`layout()` :163、`draw_preview()` :319）+ `main.gd:4992 _rogue_preview_toggle()` | 暂无专属测试；⚠️ 它是**只读**面板：不许 `session.action()`、不许消耗 `s.rng`（见文件头铁律） |
| 改每日种子 / 局外成长 | rogue_daily.gd、rogue_growth.gd | tests/rogue_daily.gd、tests/rogue_growth.gd |
| 改词条变体与相关 UI 文案 | rogue_variants.gd + rogue_ui_model.gd | tests/rogue_variants.gd、tests/rogue_ui.gd |
| 改攻击前摇提示 / 敌方弹幕 | 权威侧 `session.gd:2940-2947`（蓄力时长写入 + "windup" 广播）；表现层 `scripts/attack_telegraph.gd` + `resources/boss_projectile_shell.gdshader` | tests/attack_telegraph_visual.gd、tests/roguelike_attack_timing.gd；tools/verify_enemy_bolt_readability.gd；ATTACK-TELEGRAPH.md |
| 交接前跑全量测试 / 肉鸽门禁 | tools/run_all_tests.ps1、tools/run_rogue_gate.ps1 | output/TEST-BASELINE.md |
| 用 / 扩展开发者判定框总览（想看某系统的范围框） | `scripts/dev_ranges.gd`（加一个 `draw_xxx()`，框的半径一律引用原系统常量）+ 挂载 `main.gd:285-290` | 开关 `开发者模式启动.cmd`（`CRIMSON_DEV_RANGES=all`）；批次清单见工作区上一层 `任务.md` |

### 构筑系统类

| 需求 | 主要文件 | 配套 |
|---|---|---|
| 改构筑数值（白值/等级数组文本） | resources/rogue_build_content.json（由 tools/build_rogue_content.py 从设计文档表格编译） | tests/rogue_build_balance.gd、rogue_build_system.gd |
| 新增天赋/铭刻/核心 | JSON 条目 + rogue_build.gd 效果钩子（stat :117 / hit_multiplier :435 / hit_event :517 / action_event :735）+ 图标 atlas-manifest | tools/index_rogue_build_art.py；tests/rogue_build_rules.gd |
| 新增闯关武器 | JSON weapons[] + weapon_arts.gd:30（战技覆盖）+ rogue_actions.gd 分支 + rogue_build.gd 武器分支表 :496-659（14 处 `if w==…`）+ `match w:` :609 | tools/verify_rogue_build.ps1 |
| 改锻造/铭刻购买规则 | rogue_build.gd management :798-845 + rogue_build_ui.gd forge :106 | tests/rogue_build_system.gd |
| 改三选一/游商/圣坛 | roguelike.gd:516-554、665-711（原 :268-481 现在是 enter/spawn_wave/clear_room） | tests/rogue_chest_rewards.gd |

### 物品/背包类

| 需求 | 主要文件 | 配套 |
|---|---|---|
| **改营地行囊/仓库面板**（格子大小、栏位、按钮、背板） | `scripts/camp_pack.gd`（几何常量 :28-40，三栏 `worn_kit`/`carried`/`vault`）+ 背板图 `assets/ui/camp-pack-vault-v1.png`（重新生成：`Godot_…console.exe --headless --path . --script tools/make_camp_pack_backdrop.gd`） | tests/camp_pack.gd、tests/camp_pack_input_visual.gd（真鼠标：面板挡不挡得住下面的按钮/格子还能不能点）；改完跑 `--preview-camp-pack --capture` 出图 |
| **面板格子点不动 / 点面板却触发了下面的按钮** | 先看 §11.44（`main.gd:1704 bag_mouse_live()` 的页面判据）与 §11.45（面板自己的全屏 `shield` + `camp.input_blocked`） | tests/camp_pack_input_visual.gd（窗口化；把修复回退掉会红 7 项） |
| **改营地存储规则**（跨区搬运、穿脱、入库/取出、脱下背包） | `scripts/camp_storage.gd`（分发 `drop()` :81，各分支见 §4.G）——**规则一律复用 session 的纯 `p` 变更函数**，不要在这里重写一遍装箱 | tests/camp_storage.gd（51 项） |
| **改仓库尺寸/容量/溢出行为** | `catalog.gd:240 WAREHOUSE_GRID`；清洗与迁移 `profile.gd:435 sanitize_warehouse()`、溢出暂存 `profile.gd:435 spill_item()`；入库 `bank_item()`/`bank_item_at()`/`bank_carried_items()` | tests/economy.gd（含 225 格满仓、溢出、旧档迁移） |
| **改「累计战利品价值」口径** | `profile.gd:348 credit_loot_value()` + 物品字段 `valued`（`catalog.gd:223 SAVED_ITEM_KEYS`） | tests/economy.gd `lifetime_tally()` |
| **改装备持久化/结算语义**（撤离保留、阵亡清空） | `session.gd:4209 saved_loadout()` + `main.gd:4264 on_finished()`（写回 `profile.data.loadout`）+ `session.gd:853 spill_storage()` | tests/economy.gd `settlement()`；改完必须同步 §11.8 |
| **新增野战武器**（远征） | ① catalog.gd:147 WEAPONS ② catalog.gd:225 WEAPON_ICONS ③ weapon_arts.gd:6 MOVES ④ 特殊法术在 session.gd release_strike/update_bullets 加分支 ⑤ ⚠️ 若 WEAPONS.size() 变化，同步 `STARTER_BASE`（catalog.gd:176） | tests/systems.gd（STARTER_BASE 断言）、combat.gd |
| 新增装备/背包品质 | catalog.gd:183 GEAR / :234 BAG_TIERS + 品质数组 catalog.gd:209-215 + session.gd:1298 CACHE_QUALITY_WEIGHTS | tests/systems.gd |
| 新增普通物品/藏品 | catalog.gd:17 ITEMS + 藏品分组表 :95-121（⚠️ `NEW_COLLECTIBLES` catalog.gd:115 只能追加，影响存档序号） | tests/collectibles.gd；COLLECTIBLES.md |
| **改动物品快速收纳/落点判定**（双击装备、双击卸下、一键收纳、换装归位） | 先读 `README.md`「稀有度与自动收纳判定」：**次元口袋只对金及以上算有效空间**，单一真源 `catalog.gd:712 high_quality()`（⚠️ 禁止硬编码阈值）。落点分发 `session.gd:2861 stow_equipment()` / `session.gd:2800 stow_worn()`、营地 `scripts/camp_storage.gd:451 take_off()` / `:590 stash()` | tests/systems.gd（稀有度与口袋）、tests/camp_storage.gd `take_off_rules()` |
| **加一条"点一下/双击做某事"的手势** | 先看 `main.gd:1717 _input` 的**分派顺序**：道具栏 → 装备位（`worn_zone_at()`，在网格之前）→ 背包柜 → 网格。手势实现完必须让面板重绘（营地要自己调 `show_inventory()`，见 §11.20） | tests/camp_pack.gd、tests/inventory_panels.gd |
| 改拖拽/旋转/双击装备手感 | 对局内 `main.gd:2878 start_drag` / `:1733 rotate_selected` / `:2311 release_drag`；营地同一控制器但落点走 `main.gd:2424 camp_release_drag`（合法性判定在 session.gd:1883） | tests/ui.gd、tests/camp_pack.gd |
| **改营地双击规则**（非装备进背包 / 装备换装互换 / 快捷栏只能拖入） | `scripts/camp_storage.gd:635 quick_equip()`（`socket_for` :471 → `swap_worn` :487 / `swap_pack` :531 / `auto_store` :453）；入口 `main.gd:2703 double_click_equip()` | tests/camp_storage.gd `double_click_rules()` |
| **拖动预览不跟鼠标 / 冻结在原地** | 先看 `main.gd:1389` 的对局早退是否把 `sync_drag()` 挡在门外：营地必须在早退**之前**调一次（见 §4.G「拖拽预览逐帧跟手」）。其次看 `main.gd:2803 held_size()` 是否对空物品提前返回 | 开窗跑 `tests/camp_pack.gd`（无头窗口只有 64×64，复现不了几何） |
| 加物品图标 | ui_art.gd `icon()`（⚠️ KINDS 顺序=图集网格位置）+ assets/ui/reliquary-transparent.png 或独立 SVG | tests/ui.gd 截图 |

### 表现/音频类

| 需求 | 主要文件 | 配套 |
|---|---|---|
| 加新武器特效 | assets/combat/imagegen-mechanics 按真实用途生成独立方图与 prompts/manifest.json；weapon_mechanics.gd 按招式/弹体选图；weapon_vfx.gd 管身份配色；不用 1:3 长图 | tests/weapon_square_art.gd、weapon_vfx_identity.gd、weapon_vfx_battle.gd、standalone_vfx.gd、all_weapon_mounts.gd |
| 改强化与核心的视觉反馈 | rogue_build.gd 的 visual_state()/core_visual() + session.gd 快照传递 + stylized_vfx.gd/weapon_vfx.gd 播放；核心必须在真实机制执行后发事件 | tests/weapon_vfx_progression.gd、weapon_upgrade_visual.gd、weapon_vfx_identity.gd |
| 改刀光/蓄力/连段表现 | stylized_vfx.gd + weapon_mechanics.gd + weapon_image_art.gd + weapon_edge_glow.gdshader（⚠️ 真实剑尖与固定轨迹契约；接触点见 mechanic_contact()，新原图选择见 mechanic_source()；不能用拉厚贴图替代原图重做） | tests/weapon_mechanic_contact.gd、weapon_mount_preview.gd、weapon_stroke_directions.gd、weapon_mechanics_visual.gd、weapon_stroke_stability.gd、weapon_vfx_identity.gd |
| 加音效 | assets/audio/<kind>-<i>.wav + sound.gd:5-17 VARIANTS/LEVELS | tools/prepare_library_audio.py；tests/audio.gd |
| 加曲目 | assets/audio/music/<cue>.ogg + music-manifest.json + music.gd:41 set_world 选择逻辑 | tests/music.gd、python tests/scene_music_assets.py |
| 改大招 CG/台词 | ultimate_cinematic.gd:5-26 + assets/combat/ultimate-cg.png | tests/ultimate.gd |
| 改语音 | assets/audio/voices/voice-manifest.json + hero_voice.gd | tools/prepare_free_voices.py；tests/voice_assets.py |
| 改角色动画/体型 | assets/combat/attack-clean-%d.png、movement-%d.png + character_metrics.gd:10-53 地标 | tests/character_scale.gd、movement.gd |
| 改 HUD 布局/文案 | main.gd:1267（布局）+ main.gd:2147（update_hud 刷新） | tests/ui.gd |
| 改按钮/格子视觉 | gothic_button.gd `_draw` | — |
| 改血雾/能量/闪电等 Shader | 对应 .gdshader（§4.Q 表） | 各 *_visual.gd 测试 |

### 联机/部署类

| 需求 | 主要文件 | 配套 |
|---|---|---|
| 改 P2P/打洞逻辑 | p2p_service.gd + session.gd:26-31（端口/变量）、91-101（兜底）、142-151（join） | tests/test_p2p.py、p2p_transport.gd、direct_fallback.gd |
| 改服务器 API | server/app.py | tests/test_server.py、test_attributes_profile.py；SERVER.md |
| 改房间进程行为 | server/room.gd | — |
| 改客户端服务器地址 | game.cfg `[server] api_url`（导出后放 exe 旁覆盖） | online_service.gd:23 |
| 导出 Windows 单文件 exe | export_presets.cfg（embed_pck/script_export_mode=2）→ `Godot_…console.exe --headless --path . --export-release "Windows Desktop" "dist/CrimsonTide.exe"` | README.md「重新打包」 |
| 改导出包含/排除 | export_presets.cfg include/exclude_filter | — || 改**堆叠上限**（哪种物品能叠几个） | `catalog.gd:734 STACK_LIMITS`（`catalog.gd:741 max_stack()` 读它、`catalog.gd:758 stacks()` 由它派生；**别在别处再写一遍阈值**） | `tests/stack_hand.gd` |
| 改**右键分堆 / 逐颗落格**手势 | `main.gd:2372 start_whole_carry()` / `main.gd:2377 carry_place_one()` / `main.gd:2546 carry_finish()`，落座规则 `catalog.gd:868 place_units_in()` | `tests/stack_hand.gd`、`tests/camp_pack.gd` |
| 改**旧档超限堆的处置** | `catalog.gd:927 split_over_limit()` → `profile.gd:435 sanitize_warehouse()` / `profile.gd:136 sanitize_storage()` | `tests/stack_hand.gd`、`tests/economy.gd` |

---

## 6. 数值常量速查（哪里改什么数）

故事物品：story_inventory的BAG为10×6、VAULT为12×10；BASES定义十二种占格及堆叠上限。单件强化上限5，镶嵌80银币/1晶石，回购12件；打造、强化费用在craft/forge_cost，交易库存每幕独立持久。原forged全队强化保留旧档加成，新UI只强化单件。

| 数值 | 位置 |
|---|---|
| 联机端口 24872 / 一天 300s / 缩圈 180s 开始 | session.gd:31 / :50-51 |
| 终圈半径 540(day1-2)/620(day3) | `session.gd:3318 final_radius()` |
| 理智衰减/出圈掉血/气味=血晶×8/38 阈值引怪 | session.gd:2688-2696（血晶×8 :2688、理智衰减 :2690/:2693、出圈掉血 :2692、38 阈值引怪 :2696） |
| 威胁度公式 / 环境刷怪上限 52+2n | session.gd:2624 / 2628 |
| 搜索每件耗时 6 档 [0.55..2.4]s | `session.gd:84 SEARCH_SECONDS_BY_TIER` |
| 宝箱品质权重/背包/装备/武器概率 | session.gd:1218-1227（权重 :1218-1224、三种概率 :1225-1227） |
| 敌人血量/伤害/移速/前摇（野外） | ecology.gd:9-19（前摇 `WINDUP` ecology.gd:11）+ session.gd:3316-3319（血量/伤害/移速倍率） |
| 17 武器伤害/攻速/补正 | catalog.gd:138-156 |
| 六档品质加成（武器伤害 0→72% 等） | catalog.gd:182-188 |
| 英雄基础 hp/speed/clip（4 人） | catalog.gd:8-16 |
| 医疗针 +45HP/+10 理智；弹药匣 +48 | session.gd:1910-1911 / 2604（另一处 :1967） |
| 倒地流血 35s / 复活 40%HP / 三连击倍率 | session.gd:2874 / 3190 / 2909-2910 |
| 死灵法师全套（魂收 150/冥火 66×12 跳/灼烧 6s） | session.gd:2482-2491、2507-2548 |
| 三日 Boss 血量 1650/3100/5500、隐藏 9200、REWARDS 150/300/650 | expedition.gd:8-9、44-45、37 |
| 次元口袋 4×4；背包白3×3→红8×8；堆叠上限 6；紫以上背包占 2×2 | catalog.gd:227 / 234-241 / 718 / 505 |
| **守夜人仓库 15×15（225 格）** + 溢出暂存 | `catalog.gd:240 WAREHOUSE_GRID`；满仓后自动入库只溢出、手动拖入则拒绝（`profile.gd:450 bank_carried_items()` / `profile.gd:399 bank_item()`） |
| **整备台三件装备价格 180 / 420 / 300**（换装按差价、旧件销毁） | `catalog.gd:202 GEAR_PRICES`（顺序=守夜护甲/血月瞄具/渡鸦轻靴）；`data.gear=-1` 表示未装备 |
| **累计战利品价值只计一次**（首件入库时记一次，物品自带 `valued` 标记） | `profile.gd:348 credit_loot_value()`；实时仓库总价值另算 `profile.gd:337 warehouse_value()` |
| 构筑：修为上限 18、锻造 8 点、收藏 12、每级+2 点 | `legal_talents` rogue_build.gd:952 与 `mini(18,cultivation+1)` rogue_build.gd:1041（修为上限 18）、锻造消耗表 `FORGE_COST` rogue_build.gd:6、扣点 `management` rogue_build.gd:1005、roguelike.gd:642（收藏 12）、每级 +2 在 rogue_build.gd:1184 |
| 引魂灵体索敌四档（2026-10-07 二轮缩小后） | `rogue_build.gd:19-27`：射程 150（旧 450 的 1/3）/ 大圈 300（旧 600 的一半，召唤主为原点）/ 小圈 166.7（灵体自身，旧 500 的 1/3）/ 停靠 127.5（射程 85%）/ 转火 CD 0.5 秒；红线：1 秒/次、最多 2 个实体、0.16P 总预算（设计契约 §7.12） |
| 家园作物/鱼/料理价格与时长 | homestead.gd:3-17 |
| 种子/鱼饵买入价与卖出价（**卖恒低于买**） | 买：麦 12 / 萝卜 18 / 草 26、鱼饵 15/5份；卖（`Catalog.ITEMS` value）：wheat_seed 6 / carrot_seed 9 / herb_seed 13 / bait 2（`catalog.gd:99-102`） |
| 产物即掉落物：wheat/carrot/herb/silver/moon/gold 均 1×1、可堆叠（上限见 `catalog.gd:734 STACK_LIMITS`，现为 5）、价值=旧售价 | catalog.gd:88-93（六条新产物表项）+ catalog.gd:734 STACK_LIMITS；图标沿用 home_art.gd |
| 七属性 BASE 10/CAP 99/初始 5 点/成长曲线 | attributes.gd:8-10、34 |
| 粒子上限 1400/特效 96/碎屑 192/能量 64 | combat_particles.gd:5、stylized_vfx.gd:4-5、energy_bursts.gd |
| 营地移速 420（Shift 700） | camp_screen.gd:528 / :539 || 堆叠上限：急救针/弹药匣 **3**，其余可堆叠物 **5**，非堆叠物 1 | catalog.gd:734 STACK_LIMITS（单一真源；`stacks()` 由它派生） |
| 单堆存量硬上限（防手改存档） | catalog.gd:748 STACK_ENTRY_CAP |

---

魔境节奏（2026-10-09）：`scripts/rogue_graph.gd` 的 `build()` 统一保证每层 8～9 房、每条路线至少 6 场战斗（含首领），第 3 区圣坛、第 5 区商店/宝藏，九房层第 7 区可选特殊服务；不再由 `roguelike.gd` 二次改图。`spawn_wave()` 每波普通怪为 [6,6,7,7,8]、精英房另加 2；`room_gold()` 给普通/宝藏 25+10×层、精英额外 15、首领额外 30、服务房 15+5×层。`scripts/rogue_build.gd` 的 `enemy_budget()` 前排血量 [150,240,370,530,740]、远程/支援 [120,190,290,420,590]；只计连接中的 active/down 队友。`award()` 每层前四次战斗补瓶各 10，首次精英再加 5。配套测试 `tests/rogue_map_balance.gd`，完整表见 `BALANCE.md`。

## 7. 测试体系

**运行方式**（逻辑测试加 `--headless`；截图测试去掉它；联机测试加 `--max-fps 60`，房主进程另加 `-- --server`）：

```bash
# GDScript 回归（213 个，自写 check() 计数框架；2.36 万行）
./Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/systems.gd

# 一键全量 / 肉鸽门禁（abcbaaf 起新增，推荐交接前跑）
pwsh -File tools/run_all_tests.ps1
pwsh -File tools/run_rogue_gate.ps1

# Python（服务器/P2P/资产校验）
python tests/test_server.py        # 内部会拉起真实 Godot 房间进程
python tests/test_p2p.py
python tests/audio_assets.py       # 音效库信号级校验
python tests/voice_assets.py       # 语音清单校验
python tests/scene_music_assets.py # 曲目清单校验
```

- **四大支柱**：`tests/systems.gd`（规则回归+种子地图）、`tests/combat.gd`（战斗回归）、`tests/ui.gd`（真实输入事件全 UI 流程+截图到 build/）、`tests/network.gd`（本机 2/4 进程联机）。
- **命名规律**：`tests/<系统名>.gd` 测 `scripts/<系统名>.gd`；`*_network.gd` 联机同步；`*_visual.gd` 开窗截图；`rogue_*.gd` 是肉鸽扩展各系统的回归。改哪个脚本就跑对应测试；构筑系统一键链：`tools/verify_rogue_build.ps1`。
- **⚠️ 要真鼠标的测试必须叫 `*_visual`**：`tools/run_all_tests.ps1` 只把 `*_visual` / `ui` / `hybrid_vfx_preview` 当"开窗用例"，其余一律 `--headless`。无头运行里 `Input.warp_mouse()` 不生效、`Viewport.get_mouse_position()` 不会跟着 `parse_input_event()` 走，所以**任何靠真实点击的用例在无头下必红**——`tests/item_bar.gd` 就是例子（开窗 49/0，无头 19 失败；该用例尚未改名，属已知缺口）。照 `tests/item_bar.gd` / `tests/camp_pack_input_visual.gd` 的写法：先 `calibrate_mouse()` 标定，再 `warp_mouse` + 送 `position`/`global_position`。
- **验证台账**：`TEST-REPORT.md`（按日期记录每轮项数与结果）。
- **本机实测的既有红（2026-10-07，均与本轮改动无关；换机器/换提交可能不同，别照抄成"必须红"）**：`tests/camp_modes.gd` 1 项（`confirmed purchases charged once on start`，金币对不上）、`tests/rogue_inventory.gd` 10 项、`tests/ui.gd` 30 项、`tests/rogue_ui.gd` 1 项、`tests/rogue_hooks_roguelike.gd` 1 项（HUD 按钮实例复用，§12.6 登记过）、`tests/roguelike_art.gd` 在本机写 `res://assets/rogue/atlas-regions.json` 被拒（`FileAccess` 错误码 12）后不再打印汇总——它只跑地图那一半是 15/15。判定方法：拿 `git show HEAD:<file>` 覆盖后重跑同一用例，对比失败数是否一致。
- **⚠️ `tests/ui.gd` 的失败数是 flaky 波动的，不是固定值（2026-10-08 复测）**：同代码同机器连跑开窗实测在 **8 / 1 / 0 / 4** 之间跳（详见 §11.49）。所以别用某一次的失败数当门禁基线——要多跑几次数波动范围；也别据此相信"换 1440×900 就全绿"的旧结论。当前拖拽/背包两处真鼠标失败用兜底保绿（`ui.gd:368`、`:381`），根治方案写在 §11.49。

## 8. 工具链与素材管线（tools/）

战役GUI素材在assets/story/items，提示词见GENERATION.md/generation-prompts.json，区域由实际像素范围定义。v10增量发布先export-patch对v9，再pack_story_patch_launcher与build_story_patch_runtime；v10.exe、Inventory-v10.pck、v9.exe需同放dist。新exe内嵌小引导包，避开旧模板禁用--main-pack的问题。

| 类别 | 代表脚本 | 说明 |
|---|---|---|
| 构筑内容编译 | `build_rogue_content.py` | 从 ROGUE-BUILD-SYSTEM-DESIGN.md 表格编译出 `resources/rogue_build_content.json`（252 条），**改构筑表格先改 md 再重跑** |
| 图集索引生成 | `index_rogue_build_art.py`、`index_character_idle.py`、`index_home_animations.py` 等 | 生成对应 manifest JSON（assets/**/*manifest*.json） |
| 音频准备 | `prepare_music.py`、`prepare_library_audio.py`、`prepare_free_voices.py`、`prepare_boss_audio.py`、`prepare_ultimate_audio.py` 等 | Suno/CC0/Spaland 素材母带 → assets/audio/；凭据只走环境变量 |
| 音乐计划 | `generate_scene_music.py` + `resources/scene_music_plan.json` | 每场景一首 Suno 曲目的提示词计划与提交 |
| 素材生成 | `generate_enemy_art.py`、`build_minimax_*`、`collectible_image_prompts.py` | ImageGen/MiniMax 提示词与图集 |
| 地图烘焙 | `export_world_layout.gd`（GD）→ `bake_world_art.py` | **改 ruins.gd 地形后必须重跑**，否则 3D 贴图与碰撞错位 |
| 故事美术生产 | export_story_models.py / export_story_terrain.py / Bake-Opening.ps1 | Blender只导出不覆盖，Godot编辑后重烘焙；详见FORWARDPLUS-ART-PIPELINE.md |
| 图标/打包 | `make_icon.gd`、`package_server.py`、`fetch_export_templates.py`、`fetch_scene_assets.py` | exe 图标；服务器离线镜像包；模板/CC0 素材抓取（SHA-256 校验） |
| 素材预览 / 烘焙（GD） | `bake_standalone_vfx.gd`、`pack_ranged_imagegen.gd`、`pack_rogue_animations.gd`、`prepare_boss_art.gd`、`prepare_ecology_art.gd`、`prepare_nocturne_art.gd`、`preview_rogue_boss_body.gd`、`preview_collectibles.gd`、`preview_hero_hair.gd`、`play_hero_animation_preview.gd`、`preview_hero_registration.gd`、`inspect_home_town.gd` | 图集打包 / 立绘合帧 / 角色与 Boss 立绘预览；一律 `Godot_…console.exe --headless --path . --script tools/<名>.gd` 跑，产物落在 `build/`、`output/` |
| 守卫 | `check_class_cache.ps1` | `游戏启动.cmd` 调用：git pull 后全局类缓存过期会导致黑屏，自动 headless --import 重建 |
| 全量测试 / 门禁 | `run_all_tests.ps1`、`run_rogue_gate.ps1` | 交接前跑；肉鸽门禁覆盖图谱/事件/诅咒/每日/成长/房间 UI 的回归 |
| 前摇 / 弹幕校验 | `verify_enemy_bolt_readability.gd`、`preview_enemy_bullets.gd`、`measure_bolt_blobs.py`、`measure_bolt_core.py`、`measure_alpha_bbox.py` | 攻击前摇提示与敌方弹幕可读性的可复现验证、预览与量测 |
| 路牌自检 | `verify_anchors.py` | `python tools/verify_anchors.py --guide PROJECT-GUIDE.md --root . --summary` 校验全部锚点（见 §12.3） |
| 文档导出 | `make_report_docx.py` | 把专题 md 导出成 docx（汇报用） |
| DPS 量测 | `weapon_dps.gd` | 木桩实测 60s DPS |

**清单文件（可溯源链）**：`assets/audio/library-manifest.json`（114 条音效 cue）、`assets/audio/voices/voice-manifest.json`（4 名角色 × 11 类语音槽）、`assets/audio/music/music-manifest.json`（32 曲目 SHA-256）、`assets/bosses/motion-atlas.json`、`assets/rogue/regions/ground-manifest.json`——对应 Python 校验测试见 §7。

⚠️ `assets/rogue/build/` 下的 `atlas-manifest.json`、`jump-manifest.json` 是生成物，但**已由 `7bbaf04` 开 `.gitignore` 例外并入库**（缺了它们会让全新 clone 编译失败）；内容更新后仍要用 `tools/index_rogue_build_art.py` / `tools/index_rogue_jump_art.py` 重新生成并提交。

**assets/ 子目录速览**：`animation-generated/`（AI 角色动画帧）、`audio/`（音效+music/+voices/+bosses/）、`bosses/`（图集+imagegen/）、`combat/`（角色精灵/攻击帧/idle/ranged-imagegen/feiyue-3d/generated-attacks/imagegen/imagegen-square/imagegen-mechanics 特效）、`enemies/`（每怪一张 4×3 图集）、`home/`、`icons/`（SVG）、`rogue/`（闯关全部素材）、`ui/`、`vendor/`（KayKit/Quaternius CC0 模型）、`video/`、`world/`（地面瓦片+atlas.jpg）。

## 9. 运行、启动与部署

| 文件 | 用途 |
|---|---|
| `游戏启动.cmd` | 转发到 `Start-Game.cmd`，启动前检查类缓存并导入更新的资源；失败时停止启动 |
| `开发者模式启动.cmd` | 与 `游戏启动.cmd` 同一条链，但先设 `CRIMSON_DEV_RANGES=all`：进入开发者模式，画面叠加**判定框总览**（仅开发可见；不设这个环境变量时覆盖层根本不会被创建）。见 `scripts/dev_ranges.gd` 与工作区上一层 `任务.md` |
| `源码版启动.cmd` / `Start-Game.cmd` | 统一源码启动入口；每次先运行资源导入，支持 `--import-only`。解决 pull 后新增特效和角色动画没有本机 `.ctex` 缓存的问题 |
| `Godot_…win64.exe` / `…_console.exe` | 编辑器/跑游戏；控制台版用于一切 headless 测试与服务器进程 |
| `game.cfg` | 客户端 API 地址（当前已配真实域名）；导出后可复制到 exe 旁覆盖 |
| `Dockerfile` + `compose.yaml` + `.env.example` + `server/Caddyfile.docker` | 服务器容器部署（Dockerfile 的 test 阶段即 CI：test_server + test_p2p + systems.gd）；端口 8080(HTTP)/3478(STUN)/24900-24915(房间 UDP) |
| `export_presets.cfg` | Windows 单文件导出（内嵌 PCK、脚本编译 .gdc、排除 server/tests/tools/pv 等） |
| 存档位置 | `%APPDATA%/Godot/app_userdata/血潮守望 · Crimson Tide/profile.json` |

## 10. 根目录文档索引（专题设计文档）

战役GUI与经济：[docs/rpg/ITEMS-AND-SERVICES.md](docs/rpg/ITEMS-AND-SERVICES.md)。原创图标、框架和内部控件材质：[assets/story/items/GENERATION.md](assets/story/items/GENERATION.md)，完整提示词generation-prompts.json；只读参考表元数据reference-inventory-inspection.json。

| 文档 | 主题 | 主要对应代码 |
|---|---|---|
| README.md | 总览/启动/操作/存档 | 全局 |
| docs/rpg/ACTS-2-6-ART.md | 五幕独立美术、84新模型、17套材质、45区烘焙、不同题材副本与临时试玩 | story_act_art / story_regional_environment / story-later-acts.json / story-later-terrain.json；tests/story_later_acts / story_regional_scene_models |
| docs/rpg/DUNGEON-EXPLORATION.md | 30副本15功能空间、环路、多段高程，19室外有机轮廓，34新模块；25旧版/33重制版实际模板研究 | story_exploration_art / story_exploration_environment / story-exploration.json；tests/story_exploration |
| [docs/rpg/README.md](docs/rpg/README.md)、IMPLEMENTATION.md、DUNGEON-IDENTITIES.md、MAP-IMPLEMENTATION-RESEARCH.md、D2R-ENVIRONMENT-RESEARCH.md、RPG-MODE-PLAN.md、STORY.md、QUESTS.md（均在 docs/rpg/） | RPG连续地图重做版：PV背景、六幕营地、南门首图、40主线/24支线/9个人线；本地MPQ/CASC场景研究，连续野外、分层副本、激活传送阵与探索；v7各副本按空间类型重做 | main.gd独立story页面；story_campaign/map/region/environment/world/screen/atlas负责运行。范围和剩余差异见IMPLEMENTATION；TideSession模式仍为expedition/roguelike |
| EXPEDITION.md / ROGUELIKE.md | 远征/闯关玩法与验证 | expedition.gd / roguelike.gd |
| ATTACK-TELEGRAPH.md | 攻击前摇提示（预警可读性、时长与美术口径） | scripts/attack_telegraph.gd |
| output/ROGUE-CONTRACTS.md、output/CONTRACT-CHANGELOG.md、output/ROGUELIKE-EXPANSION-SUMMARY.md、output/R*.md（26 份） | 肉鸽扩展（图谱/事件/诅咒/每日/成长/房间 UI）的契约、变更记录、逐项验收报告与执行计划 | scripts/rogue_graph.gd、rogue_events.gd、rogue_curses.gd、rogue_daily.gd、rogue_growth.gd、rogue_room_ui.gd 等 |
| ROGUE-BUILD-SYSTEM-DESIGN.md（1403 行）| 构筑系统设计全集（数值口径 §3、12 流派 §4、数据结构与脚本接入 §12:804） | rogue_build.gd + JSON |
| ROGUE-BUILD-IMPLEMENTATION.md | 构筑已接入清单与测试汇总 | 同上 |
| ROGUE-EQUIPMENT.md / ROGUE-MINION-DESIGN.md / CHEST-REWARDS.md / EXTRACTION-INVENTORY.md | 早期装备子集/40 小怪 80 招/宝箱奖励协议/远征背包 | rogue_equipment.gd / rogue_minions.gd / roguelike.gd / extraction_inventory.gd |
| BOSS-REWORK.md（总表）/ BOSS-VFX.md / BOSS-EXPANSION.md / BOSS-WILD-EXPANSION.md / BOSS-DRAGON.md / BOSS-ANIMATION.md | Boss 招式 73 招/特效/扩展/异兽/古龙/动画 | boss_choreography.gd 等 |
| ECOLOGY-UPDATE.md / ENEMY-UPDATE.md / NOCTURNE-UPDATE.md / WEAPON-SKILL-ENEMY-BALANCE.md | 野外怪生态/怪物图集/数值平衡 | ecology.gd、enemy_frames.gd |
| COMBAT-UPDATE.md / VFX-REWORK.md / HYBRID-VFX.md / ATTRIBUTES-AND-ARTS.md / RANGED-ANIMATION.md | 战斗动画/特效重做/混合特效/属性战技表/远程动画 | combat_visuals.gd、character_frames.gd、weapon_arts.gd |
| WEAPON-IMAGE-VFX.md / WEAPON-MECHANICS-VFX.md | 实际强化/品质/核心触发；32 张按动作/飞行/命中用途划分的 ImageGen 方图，饱和色辉光与空间契约 | weapon_mechanics.gd、weapon_image_art.gd、rogue_build.gd、stylized_vfx.gd |
| MUSIC.md / ULTIMATE-AUDIO.md / VOICE-SOURCING.md / AUDIO-CREDITS.txt / VOICE-CREDITS.txt | 音乐/大招音频/语音选材/鸣谢 | music.gd、sound.gd、hero_voice.gd |
| CAMP-MAP.md / HOMESTEAD.md / CITY-UPDATE.md / MAP-UPDATE.md / MAP-2-5D.md / WAREHOUSE-AND-MARKET.md / COLLECTIBLES.md / FREE-SCENE-ASSETS.md / ART-DIRECTION.md / UI-ART-UPDATE.md | 营地/家园/王城/大地图/2.5D 分工/仓库/藏品/场景素材/美术方向 | §4.N/J/O 对应文件 |
| SERVER.md / server/DOCKER.md | 服务器裸机与容器部署 | server/app.py |
| HIDDEN-ENDING.md | 隐藏结局（冥火尸王/招募墓煜） | expedition.gd、profile.gd |
| TEST-REPORT.md | 验证台账 | tests/ |
| minimax2live2d.md | 外部素材管线笔记（参考） | tools/ |

## 11. 已知坑与注意事项（改码前必读）

故事GUI契约：先复制验证整次交易/换装再提交，旧档溢出入领取暂存区；新增字段同步valid_item/restore_numeric及往返测试。图标先EXPAND_IGNORE_SIZE再设尺寸，进度条先关百分比再设高度。任务事件仅由真实转换产生，silent加载不播放，通知有上限且离开模式清空。声音总线/应用图标须装入引导包，挂载v9后恢复AudioServer布局，防止发布版bus=-1。

1. **`git status` 里出现 `?? 某目录/` 时先查清再动**：这类目录没进版本库（可能是重复克隆，也可能是本机构建产物）。危害是 `git add .` 会把整个目录当成一个 gitlink 提交进来。处理：① 一切修改只在项目根做；② **禁止 `git add .`**，只 add 你真正改的文件；③ 确认无用后再删除该目录。
2. **`STARTER_BASE=17`（catalog.gd:167）必须等于 WEAPONS.size()**，tests/systems.gd 有断言——增删野战武器后必须同步这个字面量。
3. **藏品序号只追加不插入**：`catalog.gd:124 NEW_COLLECTIBLES` 的顺序就是存档解锁序号（`collectible_index`），中间插入会毁掉玩家存档。
4. **`BossFrames.SPECIAL_KEYS` 顺序被按下标硬引用**（enemy_body.gd:35、boss_cinematic.gd:75、boss_hud.gd:70，另有 battlefield.gd:28-30 的 `SPECIAL_BOSS_ART` 同序），且 `boss_effect_art.gd:55-57` 颜色表按 `KEYS.find` 索引——新增 Boss 身份一律**追加到表尾**并同步颜色表。
5. **Boss 伤害几何三处同步**：新形状要同时改 `boss_geometry.gd`、`expedition.gd:345 hazard_contains()`、`resources/boss_damage_shape.gdshader`，回归看 `tests/boss_damage_geometry.gd`（CPU 与 GPU 必须逐像素一致）。
6. **特效必须走 battlefield.gd:747 `weapon_effect_socket` 挂点契约**，`stroke_tip` 必须等于真实 `tip`，不得按攻击方向另造剑尖；亮刃接触点由 `weapon_image_art.gd:83 mechanic_contact()` 等比映射，`stylized_vfx.gd:368 draw_mechanic()` 不再额外旋转释放刀光。释放类特效仍然"一次捕获、原地淡出"，蓄力才跟随。配套 `tests/weapon_mechanic_contact.gd`、`tests/weapon_stroke_directions.gd`、`tests/weapon_stroke_stability.gd`。
7. **改 ruins.gd 地形后必须重跑烘焙管线**（tools/export_world_layout.gd → tools/bake_world_art.py），否则 3D 表现与碰撞错位。
8. **穿戴装备是存档的一部分**（旧契约「穿上的战利品永不写存档」已作废）：撤离时 `session.gd:4209 saved_loadout()` 把 `p.equipped`/`p.slots` 交回，`main.gd:4264 on_finished()` 写进 `profile.data.loadout`，下一局 `session.gd:662 storage_from_config()` 再穿上；**阵亡**照旧由 `spill_storage()` 散落并写回一个空 loadout。⚠️ 由此**撤离时身上装备不再计入 loot 估值、也不再入库**（否则同一件东西既带着又卖了）；**次元口袋是唯一免死容器**——改动结算/散包逻辑时保持这两条契约。
9. **权威端才做规则**：main.gd/各 UI 只发 `session.action()`；不要在表现层（battlefield/world_3d/combat_visuals 等 "Presentation only" 文件）里写伤害或状态逻辑。**营地是例外但要显式**：营地 `session.running==false`，`perform()` 会直接 return，所以营地的存储编辑全部集中在 `scripts/camp_storage.gd`，并且**只调用 session 的纯 `p` 变更函数**（`move_between`/`equip_item`/`clear_worn_slot`/`slot_put`/`resolve_drop`）——不要在营地面板里重写一套装箱或装备规则。
10. **存档唯一写入点是 profile.gd:216 `save_profile()`**（.tmp + rename 原子写）；其他任何地方直接写 profile.json 都是错的。
11. `output/`、`pv/`、`DEPRECATED-*` 目录不是游戏资源（导出已排除）；`DEPRECATED-character-animations-2026-09-25` 是被否决的 12 帧动画归档，勿复用。
12. 联机测试约定：逻辑测试 `--headless`，画面测试开窗，联机加 `--max-fps 60` 且房主进程带 `-- --server`；正在进行的对局不能迁移服务器（打洞兜底只发生在出发前）。
13. UI 全部由代码构建（main.tscn 是空壳）：改界面 = 改 main.gd / 各 screen 脚本，**不要**试图在编辑器里找节点。
14. **肉鸽扩展有一套契约与验收文档**：动肉鸽行为前先读 `output/ROGUE-CONTRACTS.md` 与 `output/CONTRACT-CHANGELOG.md`（契约在何时被谁改过），逐项验收记录在 `output/R*.md` 与 `output/ROGUELIKE-EXPANSION-SUMMARY.md`；改完跑 `pwsh -File tools/run_rogue_gate.ps1`。
15. **攻击前摇与敌方弹幕可读性有专门的验证工具**（`tools/verify_enemy_bolt_readability.gd`、`tools/measure_bolt_*.py`）：改动前摇/弹幕表现后要重跑，别凭肉眼判断。
16. **「只计一次价值」靠物品自带 `valued` 标记，不靠 uid**：`catalog.gd:223 SAVED_ITEM_KEYS` 必须含 `valued`，否则取出再存入会重复累加 `profile.data.loot_value`；新增物品字段同理——**没进 `SAVED_ITEM_KEYS` 的字段过不了存档**（会被 `clean_container()`/`clean_slot_entry()` 丢掉）。
17. **仓库堆叠只在「同 kind + 同 provision」之间合并**（`profile.gd:334 place_vault_unit()`）：营地补给的 `provision:true` 一旦并进普通堆就可被交易行收走，等于把不可售物资洗成钱。新增可堆叠的「不可售/特殊来源」物品时保持这条。
18. **JSON 读回来是 float**：`apply_data()` 里凡是用「类型相同才导入」那张循环的键，默认值是 int 就永远匹配不上 float（`gear` 就这么踩过：旧档装备全部变成 -1）。改 `profile.gd:53 apply_data()` 时，数值键一律像 `coins/hero/loot_value/gear` 那样显式 `int(...)` 归一。
19. **无头测试必须把 Godot 的 user:// 挪进工作区**：`$env:APPDATA = <工作区>\.testappdata` 后再跑 `Godot_…console.exe --headless`。默认 user:// 落在 %APPDATA%，工作区沙箱会挡住写盘，`save/load` 类断言会**假失败**（`tests/systems.gd` 曾把临时存档写在 `res://tests/` 上，已改到 user://）。`.testappdata/` 已在 `.gitignore` 里。**实测**：不带这条时 `tests/camp_storage.gd` 有 3 项 `save/load` 断言假失败（`FileAccess` 错误码 12 = ERR_FILE_CANT_OPEN），带上就是 66/66。
20. **营地的拖拽预览要「每帧」同步，不能只在 `start_drag`/面板重绘时摆一次**：`main.gd:1389` 有一句 `if page_name!="game" or not session.running: return`，营地正好落在这个早退里，所以 `_process` 末尾的 `sync_drag()` 在营地**根本不会执行**——表现是抓住的物品**冻在按下的那一格**、不跟鼠标（看起来像"手上空了"）。修法是早退前为营地单独调一次；新增任何"对局外也要逐帧跑"的 UI 逻辑都要检查这个早退。
21. **`container_receive()` 与 `container_accepts()` 回答的不是同一个问题**：前者是"这个容器能不能放下"（自己找第一个空位），后者是"**这个格子**能不能放下"。落点预览、仓库取出这类"玩家指了哪一格"的操作必须用后者，否则东西会跑到 (0,0) 去。另外**可堆叠物品（`catalog.gd:734 STACK_LIMITS`：crystal/scrap/medicine/ammo/charm/麦子类）没有第二格可指**，它的落点就是玩家瞄的那一格，别顺手把坐标清掉。
22. **营地的双击是"存储动词"，对局的双击是"战斗动词"**：`main.gd:2703 double_click_equip()` 先分派营地/对局。营地同一个函数里**不能**填快捷栏（`[1][2][3]` 只能拖入），对局内消耗品双击进快捷栏、单击=Ctrl 智能键（消耗品用掉、装备穿上）。加新的双击行为时先问"这在营地里该干什么"。
23. **营地没有"每帧自动重绘"，改了存储必须自己 `show_inventory()`**：`main.gd:1389` 的对局早退让 `_process` 里的签名刷新在营地永远跑不到。漏掉重绘的症状是**面板停在旧画面**——物品看着还在原处、其实状态早变了，再点那格就索引错位、拖动也摸不到东西（"卡住"）。`_process` 里 `camp_signature()` 只兜底一帧，别指望它当接口。
24. **物品自动收纳必须过稀有度规则，且只有一个阈值**：`catalog.gd:712 high_quality()`（`POCKET_TIER := 4` = 金及以上）。**紫及以下不进次元口袋**；判定"有没有地方放"时口袋对它们不算数。旧代码里有两处刻意的例外（`session.gd:1121 auto_store()` 搜刮退袋、`session.gd:2870 stow_equipment()` 换装旧件），那是决定过的，别顺手"统一"掉。规范原文在 `README.md`「稀有度与自动收纳判定」。
25. **装备位（主手/护甲/瞄具/轻靴/饰品）也是拖拽起点**：`_input` 里必须先问 `worn_zone_at()` 再问 `grid_at()`——装备位不是网格，`grid_at()` 会返回空并让整段逻辑提前 return，这正是"装备栏只能点右上角卸下"的老毛病。槽位名有两套拼法（面板注册用 `slot0`、拖拽 id 用 `slot:0`），翻译只能走 `session.gd slot_number()`（直接 `substr(4)` 会把 `slot:1` 也读成 0）。
26. **"拒绝"与"掉地上"是两种口气，同一个动词可以有两种，别擅自统一**：**手势**卸下（双击装备位 / `Ctrl`+左键 / `F`）放不下时**不触发 + 中上提示**（`main.gd:1198 notice_popup()`，装备留在身上）；**面板上的「卸」字**（`session.gd unequip_item()` → `stow_equipment()`）保留旧说法——一定把装备卸下来，放不下就**掉在脚边**。落地一律用 `session.gd:2462 drop_loose()` 的**单件**形状（地上显示成那件装备本身、`F` 拾回），**不要**包成可搜索的掉落包。**穿在身上的东西被拖拽时永远不掉地上**：松手在面板之外只提示一句。
27. **装备位与道具栏的读写只有一份实现，在 `session.gd`**：`socket_entry()` / `set_socket_entry()` / `clear_socket()` / `swap_sockets()` / `socket_wants()` / `slot_number()`。营地（`camp_storage.gd`）只允许包一层"pack 槽"例外（背包是容器不是槽位），**不要**在营地或 UI 里再写一遍"这个槽收不收这件"——两套规则一定会在某次改动后分叉。
28. **面板内空白 ≠ 丢弃**：丢弃区由面板自己登记（整块背板含木框），`drag_outside()` 判定，毛玻璃贴图以 30% 透明度提示。**不要**再用"落点非法就 `to world`"的写法——那会让玩家在格子旁边松手就丢装备（这正是本轮修掉的隐患）。
29. **地面掉落记录有两种形状**（产物 `{kind,units}` / 物品 `{entry}`）：任何遍历 `camp_activities.drops` 的新代码都必须先 `drop.has("entry")` 分支，否则 `.kind` 会直接抛 `Invalid access to key 'kind'`（`_update_markers()` 就这么炸过一次）。
30. **无头探针什么都不打印又占满 CPU 时，先看 `--quit-after` 的解析错误**：`main.gd` 一旦有 Parse Error，`load("main.tscn")` 会给出一个没有脚本的节点，探针里的 `app.session...` 随即报错中断，`quit()` 再也不会被调用，于是 SceneTree 空转——表现为"卡死"，实际只是 main.gd 编译失败。查错一条命令：`godot --headless --path . --quit-after 200`。**另一个假"卡死"来源：被 `job_kill` 杀掉的 pwsh 不会带走它的 Godot 子进程**，残留进程会占满一个核让后面的测试看起来像卡死——先 `Get-Process *Godot* | Stop-Process -Force` 再重跑。
31. **右键分工是刻意的**：营地/对局面板（同一套控制器）**右键＝从堆叠里拿起 1 个**（再右键加 1），**中键＝旋转**，`R` 键一直也能转；**肉鸽面板的右键是它自己的右键菜单**（`rogue_inventory.gd`），别去"统一"它。新面板要用右键前，先确认不撞这两处。
32. **`resolve_drop()` 会就近另找空格**，所以"某一格放不下"≠"旋转失败"：真正触发 `rotate_with_displacement()` 的只有**整个容器都没立足之地**。测试构造"转不动"要用**装满**的容器；另外 `container_free()` 出**负数**说明你手搓的布局本身非法（`ammo` 是 **2×1**，不是 1×1）。
33. **`place_loot()` 会按 `max_stack` 合并同种堆叠**：断言"放进去几件"要用**单位数**，别用条目数（7 个单位可能只剩 2 个条目）。手搓容器条目时**必须带 `x`/`y`**——`CampStorage.persist()` 的存档往返会把缺字段的条目清掉（本轮踩过）。
34. **面板里搬节点要防"挂进自己的后代"**：把手放的格子 `Control` 在两个父级之间移动时，若目标父级是它自己的子孙，Godot 会报 `Can't add child ... cyclic dependency` 并**静默丢掉那一批格子**（本轮交易行的"格子画不出来"就是这么来的，只有 `tests/economy_ui.gd` 的"每格都画出来了"断言抓到了它）。**改滚动/货架装配后必须跑 `tests/economy_ui.gd`。**
35. **调用方与实现在两处时，先跑一次解析自检**：本轮交易行窗口调了 `CampStorage.sell_backpack()` 而这个函数**根本没写**，整窗 `Parse Error`（`Static function not found`）——而 `systems/economy/camp_storage` 全绿，因为它们不加载那个窗口。**动了任何 UI 窗口后，先 `--quit-after 60` 看解析错误，再跑对应 UI 套件**，别只看非 UI 套件来判断"没问题"。

36. **"满屏 CRLF 改动"多半不是文件被写坏，而是本地 `core.autocrlf` 被覆盖过**：本仓库的**提交里一直是 LF**，但工作树是按 Git for Windows 默认 `core.autocrlf=true` 检出的 **CRLF 检出**。一旦 `.git/config` 里出现一条 `core.autocrlf=false`（本地覆盖会压过系统默认），git 就改按字节比较，凡是被碰过 mtime 的文件立刻显示成"整文件改写"（曾量到 `git diff --stat` **9471/6778**，而 `--ignore-cr-at-eol` 只有 **3205/512**）。**先查配置，别去批量转文件**：`git config --show-origin --get core.autocrlf`；想知道"真改动到底有多少"，用 `git diff --ignore-cr-at-eol --stat`，或临时用环境变量覆盖再看（`GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.autocrlf GIT_CONFIG_VALUE_0=true`，不落盘）。只有 `*.cmd` / `*.ps1` 在 `.gitattributes` 里被刻意钉成 `eol=crlf`。
37. **`.godot/` 不可写时 `--import` 会"成功退出但什么都没导入"**：受限沙箱下 `.godot/`、`.godot/imported/`、`.godot/editor/` 全部拒绝写入，而 `godot --headless --path . --import` 照样打印 `[ DONE ]`、exit 0（只在 stderr 留一句 `Cannot save project metadata …`）。后果是**新素材没有 `.ctex` 缓存**，测试里满屏 `Unable to open file: res://.godot/imported/xxx.ctex` → `Art.icon()` 返回 null → 肉鸽门禁一次红 4 例（`rogue_build_rules` 挂死、`rogue_boss_bodies` 146 失败、`roguelike_seven_rooms` 25 失败）。**判定方法**：看 `.godot/imported/` 里最新文件的 mtime 是不是"刚才"，不是就说明没真导入。修法：在放开文件访问下重跑 `--import`（本次 +360 个缓存条目后立刻 3 例转绿）。另外 `--import` 会重写一批**已被跟踪的** `*.import`，但其内容与索引**完全一致**——`git status` 把它们列成 ` M` 而 `git diff` 什么都不报（stat 缓存假象），对这批路径跑一次 `git add -- <paths>` 即可刷新，`git diff --cached` 应当仍为空。
38. **新注册的物品若没有同名图标，`battlefield.gd:81` 会逐条报错**：开局 preload 会对每个 `Catalog.ITEMS` 里**非收藏品**的 kind 执行 `load("res://assets/icons/" + Catalog.kind_icon(kind) + ".svg")`。种植/钓鱼那六类产物（麦/萝卜/月露草/银鳞鲫/月纹鲈/金冠锦鲤）连同种子与鱼饵在 `assets/icons/` 下**没有同名 svg**（背包格子走的是 `home_art.gd` 图集，那边不缺），于是每跑一次测试就多 10 行 `Resource file not found`，且 `loot_icons[kind]` 为 null。**不致命，但会污染所有日志**；补图标、或给 `kind_icon()` 加一条回退路径都能收掉。39. **堆叠上限只管"怎么堆"，不管"读几个"**：`catalog.gd:734 STACK_LIMITS` 决定一种物品一叠能放几个，但**读取与花费必须用真实 count**（`catalog.gd:753 units_of_item()`）。在任何地方把 count `clampi` 到上限，都会让一叠 6 个只算 5 个，而且多出来的尾巴**永远卖不掉也吃不到**——上限从 6 改成 3/5 时这条真的咬过人（`profile.gd warehouse_deposit()` 还因此把超过上限的部分**静默吞掉并返回 0**，`bank_item()` 把 0 读成"全部入库"，连回滚都跳过）。要防手改存档就改 `catalog.gd:638 clamp_entry()` 那道宽上限（`catalog.gd:748 STACK_ENTRY_CAP`），**别在计数处夹**。
40. **"手上没落地的单位其实还在源堆里"是这套手势的地基**：右键拿起只记下 `drag.kind`/`drag.blank`，**源容器一点没动**；每落地一个才从源堆扣一个。所以"放回原处"是免费且无损的 no-op（`to==from` 直接返回 0），也**不要**去实现"松手时把没放下的也搬到目标容器"——那会把整堆散成一地、或者把本来还留在原地的单位丢到地上。只有"松手在面板外"才是真的丢弃。反过来，任何"先扣再放回"的写法都会把这条地基拆掉。
41. **逐颗落格绝对不能调 `compact_arrivals()`**：`catalog.gd:868 place_units_in()` 里刻意没有它。`compact_arrivals()`（`catalog.gd fill()`/`commit_layout()`）会在玩家刚放下一格之后**重新打包整个容器**，把你瞄准的那格搬到别处——这正是"锁住这一格"要防的事。整叠拖动路径（`session.gd move_between()`、`camp_storage.gd vault_units_out()`）可以调它，逐颗手势不行。
42. **`camp_storage.gd vault_units_in()` 会拒绝 `from=="vault"`，这是对的**：那是"从仓库拿进仓库"，`bank_item()` 会先把手上那几件合并回源堆本身，调用处再用 `have-units` 覆盖该格，**会吞掉几件**。放回原处本来就是 no-op，别为了"统一"把这个拒绝删掉。

43. **肉鸽分叉口必须是一整块可走的路口广场，不许再有隐形墙**：可走区域由 `rogue_map.gd:72 configure()` 把「实测地面轮廓」与 `ground-manifest.json` 里的岔路多边形用 `Geometry2D.merge_polygons()`（`rogue_map.gd:104`）合并而成。**只合并那两条路**会在两路之间留下一个楔形留白——它没有任何美术依据，玩家沿直行路斜着走向「斜向」门口时会被它挡住，只能先向上走再向右"找个角度"绕进去（实测 30%~56% 的直线被挡，全部 35 个区域都有）。正确写法是 `rogue_map.gd（历史 fork_junction 实现，现已移除） fork_junction()`：**上界取岔路外沿、下界取地面下沿**，先把路口补平成一块广场再合并，于是两个门口落在同一面右墙上、斜着走就能进门（`tools` 级验证：220 个区域/门口组合的"岔口→门"直线 0% 被挡）。`tests/roguelike_routes.gd` 有全地图断言守着这条，**别把 `fork_junction()` 换回裸的 `merge_polygons(floor_polygon, diagonal)`**。

44. **营地行囊面板"格子点不动、按钮还能点"＝袋控器被页面判据挡在门外**：面板的格子/装备位/背包柜全靠 `main.gd:1717 _input()` 的命中测试驱动，而面板自己的按钮是 Godot `Button`（走 GUI，不经过 `_input`），所以症状永远是"按钮好使、拖拽和双击全死"，而且**日志里一条错误都没有**（不是异常，是早退）。根因是 `_input` 第一句 `if session.roguelike.active(session): return`：`raid.mode` 一旦被设成 roguelike 就**整个会话保持**（`session.gd:1528 begin()` 写入，魔境跑完回营地也不会清），于是"从魔境回营地"这一个再普通不过的状态就能让整个面板失效。判据必须是 `main.gd:1704 bag_mouse_live()`（**绑 `page_name=="game"`**）。**排查口诀**：面板按钮可用 + 无报错 + 格子全死 → 先看 `_input` 的早退判据是不是把营地也算进去了。
45. **面板打开时"下面的东西"要自己挡**（两件事，缺一不可）：①**鼠标**——营地页的 `家园设施` 行、`出发` 按钮、站点标记都画在 overlay **下面**，而面板是普通节点画的、空处没有 Control 接鼠标，点击会穿下去（实测点「主手」会顺带触发同一位置的「晨光菜园」并瞬移角色，点面板右下角会顺带点到「出发」）。修法是面板开头铺一整块 `MOUSE_FILTER_STOP` 的全屏 `shield`（`scripts/camp_pack.gd:47/68`，与 `home_screen.gd` 用全屏 STOP 根节点的做法同源）。②**键盘/世界交互**——`camp_screen.input_blocked` 才是营地自己的冻结开关（走路、E/Q、田块点击都看它），而 `main.gd:1631 _process()` 每帧把它重写成 `modal or camp_pack_open`：**漏掉 `camp_pack_open` 就等于没冻结**（角色会在面板后面走路、还会响应 E）。⚠️ 已知遗留：这条式子也把 `home_ui`/`home_map` 自己设的 `input_blocked` 每帧冲掉（两个页面的**鼠标**由各自的全屏 STOP 根节点挡住，所以玩家看不出来；但 WASD/E/Q 仍会漏到世界里）。要一起收掉就得把这两页也写进这条式子（同时 TAB/ESC 的收尾要补），改动前先问。
46. **HUD 按钮不能只"回答一句提示"**：`camp_screen.gd:435` 的「出发」按钮只发 `launch_requested` → `main.gd:1034 camp_departure()`。它原来只在角色**站在**闸门/传送门时才有动作，否则只 `camp.say()` 一句"走到南侧…再出发"——而面板打开时那句话画在面板底下，玩家只看到"点了没反应"。现在按钮按当前模式直接从任何位置进站（搜打撤 → `on_camp_station("launch")`，魔境 → `on_camp_station("rogue")` 进报名页）；世界里的仪式（走到闸门按 E/Space）原样保留，两条路都进同一批站点函数。

47. **引魂灵体只认「主人的索敌指令」，不自己乱跑**：灵体的每帧决策在 `rogue_build.gd:354 soul_step()`，四级优先：①**主人的指令**（`rogue_build.gd:560 hit_event()`，记指令那行在 :528：主人用普攻/战技/技能打中谁，谁就是指令；T086 冥火指令与墓煜 HC 连招终结的 3 秒硬锁优先于它）——无距离上限地追，怪出大圈、主人后撤也照打，直到它死或主人改指令；②主人大圈 300 内最合适的一只；③灵体自己的小圈 166.7 内最近的一只（低优先自保）；④都没有就回主人身边的待命位（每个灵体有固定槽位偏移，两个不叠在一起）。**转火有 0.5 秒内置 CD**（`SOUL_LOCK_CD`，每个灵体独立）：①→① 的转火要等 CD，②③→① 可以立刻抢占；追击停靠在射程 85%（127.5），被地形卡住 0.6 秒就放弃、`SOUL_UNREACHABLE` 秒后再试（免得在墙前来回抖）。⚠️ **别顺手改伤害**：射程 150、每秒 1 次、最多 2 个实体、总预算 `0.16P×(1+召唤加算池)` 按实体比例分配是设计契约（ROGUE-BUILD-SYSTEM-DESIGN §7.12），本轮只改「索敌与移动」。**半径在二轮按验收反馈缩小**：大圈减半（600→300）、灵体射程与小圈各缩到 1/3（450→150、500→166.7）、停靠与牵引同比（380→127.5、600→300）——想调手感就动 `rogue_build.gd:19-27` 这几个常量。**预览图里那三个圈是测试脚本的开发者覆盖层**（`tests/rogue_summons_visual.gd` 的 `SHOW_RANGES`，默认 false），正式对局不画任何判定圈。回归 `tests/rogue_summons.gd`（无头 27 项；把「记指令 / 追击 / 0.5 秒 CD」三处回退掉会红 9 项）。**写测试的坑**：`spawn_enemy()` 对 radius 25 不通的位置是**静默 return**，随手写个偏移会让两次 spawn 落到同一格、后一次直接不生成（假绿）；木桩一律取 `ruins.lane_center(x)`。

48. **判定框总览（开发者模式）只能"只读"**：`scripts/dev_ranges.gd` 只在环境变量 `CRIMSON_DEV_RANGES` 有值时由 `main.gd:285-290` 创建 —— **正式模式连节点都不建**，不要改成"建了再隐藏"。它只读 `session` 与公开常量，框的半径必须引用原系统常量（例如灵体四档直接读 `Build.SOUL_*`），**不许在覆盖层里抄一份副本**，否则改数值后框会撒谎；不吃 `s.rng`、不参与任何命中判定（与第 9 条同源）。加批次＝在 `dev_ranges.gd` 里加一个 `draw_xxx()`，并把工作区上一层 `任务.md` 清单里对应那行勾掉。⚠️ **营地/家园是 3D**（`camp_site.gd` 的 `UNIT/PITCH/CAMERA_DISTANCE` 投影），搜打撤表现层也是 3D 相机（没有 `camera_offset()`），这两组别在 2D 里硬画。**互动半径一律以 §4.R.1 那张表为唯一真值**：提示出现的距离必须等于按下生效的距离，改任何一处先改表再改代码（2026-10-07 审计出 4 类不一致：营地名牌 650、搜打撤世界标签按相机 1500、魔境常驻提示无距离、宝箱提示 70 vs 判定 80）。

49. **`tests/ui.gd` 真鼠标/真键盘链路是 flaky（时序抖动），不是确定性坐标 bug；已用兜底固化保绿，根治留给后人**：
    - **实测推翻上一交接的定论**。上一份交接（工作区外 `111111.md`）判定"27 条红＝坐标二次缩放、换 1440×900 原生窗口 scale=1 即大量转绿"。**本轮同代码（HEAD `205ea27`）、同机器连跑开窗实测**，失败数是跳动的：**8 → 1 → 0 → 4**（19:11 留档 8；纯环境复跑依次 8、1、0；加诊断探针那次 4）。若真是"每次必 miss"的确定性坐标 bug，失败数应固定，不会归零。→ **定性为 flaky**，触发条件是 `warp_mouse → 下一帧 readback` 的时序竞争 + 进程前台焦点，与 DPI 缩放叠加放大，**不是**单纯的坐标写错。
    - **坐标二次缩放确实存在，但它是"放大抖动"的帮凶、不是"全 miss"的元凶**：实测标定 `mode=3`（全屏 2560×1600），`warp(600,600)` → `get_mouse_position()=(337.5,337.5)`，故测试侧 `mouse_scale≈1.777`（非 1.0）。`main.gd:3382 mouse_point()` 在 `viewport.get_mouse_position()`（已是设计坐标）之上又乘 `root.get_global_transform_with_canvas().affine_inverse()`，与工程 `canvas_items` stretch 叠加，落点有再被缩小一次的嫌疑。但它没让测试"永远全红"——所以别把它当成唯一根因去"修一下就全绿"。
    - **本轮决策（用户拍板）：保留兜底、绿了就行，把 flaky 登记为已知缺口**。`tests/ui.gd` 里两处兜底——`:368` 拖入背包失败退 `app.auto_store_loot(0)`、`:381` 背包内挪格失败退 `app.session.move_between(...)`——是**刻意保留**的：探针实测**同一次运行里 `:368` 那次真链路命中成功、`:381` 那次真链路 miss**，证明真鼠标时好时坏，删兜底就会随机红。`:610 / :630 / :650` 的 `auto_store_loot` 兜底同此。
    - **后人若要根治（勿与功能提交混做）**：需同时处理三件事，缺一不可——① 消除 `mouse_point()` 与 stretch 的二次缩放（先坐实多面板下 `get_mouse_position()` 与 canvas 变换的真实语义）；② 把手势 helper 里"单 `process_frame` 等 readback"改成轮询到光标真到位再点（`item_bar.gd` 已用 `create_timer` 拉开两次拖拽，可参考）；③ 保证测试窗口前台焦点。**根治前，别删这几处兜底。**

50. **`verify_anchors.py --fix` 会静默跳过"在全文出现不止一次"的锚点，别以为它把漂移全清了**：`--fix` 的去重门在 `tools/verify_anchors.py:334 text.count(old) == 1`——同一个 `文件:行号 符号` 字符串只有在**整份路牌里唯一**时才会被改写。合并主线后常有几十个锚点（`perform` / `show_inventory` / `saved_loadout` / `settle` / `double_click_equip` …）在 §3/§4/§5/§11 各章节被反复引用，这些全被跳过，表现为 **`--fix` 跑再多轮 DRIFT 数都不再下降（本轮卡在 26）**。正确做法：`--fix` 跑到收敛后，改用 `python tools/verify_anchors.py --guide PROJECT-GUIDE.md --root . --json`（用 `utf-8-sig` 读，PowerShell `Out-File` 会写 BOM），把每条 DRIFT 的 `实测行号` 建成"旧串→新串"映射，对全文 `str.replace(old,new)`（**不限次数**，一次覆盖所有重复引用），再补区间锚点。本轮 26 处即这样一次清零。⚠️ 别写"再跑一遍 --fix 直到 0"的死循环——它永远到不了 0。

51. **`--fix` 每次都会写出 `PROJECT-GUIDE.md.bak` 备份，这是临时产物，绝不要提交**：备份在 `tools/verify_anchors.py:271 guide_path.with_suffix(... + ".bak")` 生成。上游 `8252812` 曾把它误入库（本轮已 `git rm --cached` 移除，并在 `.gitignore` 加了 `*.bak` 防复发）。看到 `git status` 里有 `.bak` 先确认是不是又被谁 `git add .` 带进来的。

52. **git 网络命令（`fetch` / `push`）不要把 stdout 用管道交给 `Select-Object` 等下游，会假死**：实测把 `git push` 的 stdout 直接 `| Select-String` 会挂住不返回；改成 `git push origin master > 文件 2>&1` 重定向到文件再看，或前台直跑不接管道。另外**被 `job_kill` 杀掉的 pwsh 不会带走它的 `git` / `git-remote-https` 子进程**（与第 30 条 Godot 残留同源），残留进程会占住凭据/锁让后续 `git fetch` 一直卡——卡住先 `Get-Process git,git-remote-https | Stop-Process -Force` 再重跑。GitHub 到本机很慢（数分钟），用 `GIT_TERMINAL_PROMPT=0` + `credential.interactive=false` 走非交互，慢就用后台 job 而不是干等。

53. **工作区常年显示 ` M` 的两个幽灵文件永远不要 `git add`**：`scripts/rogue_backdrop.gd` 与 `tests/direct_fallback.gd` 是 CRLF/归一化导致的 stat-cache 幽灵——`git status` 天天列它们"已修改"，但 `git diff --ignore-cr-at-eol` 对它们是 **0 真实改动**（内容根本没变）。它们是 §11.36 那条 autocrlf 假象的具体实例，也是禁止 `git add .` 最现实的理由：一旦提交就把这俩脏进去。提交一律**显式列自己改的文件路径**（`git add -- 路牌 脚本…`），别 `git add -A` / `git add .`。

54. **近战特效原点=角色自身，与判定框普遍不重合（已知缺口，2026-10-08 用户拍板：本轮只登记、暂不改）**：所有近战/圆斩特效的**生成原点都锚在角色身体**（`stylized_vfx.gd:133 event()` 里 `at=data.p`，圆斩 `emit_mechanic("spin",…,reach,…)` 在 `stylized_vfx.gd:166`），而权威命中判定用的是另一套几何（`enemy_body.gd:124 attack_hit()`），两者口径不同，导致"看到的特效"和"实际打到的范围"经常对不上，玩家体感就是**范围不符**。两类具体表现：
    - **圆环战技（右键 `kind:"circle"`）异常**：判定是**以角色为圆心、半径 = `reach`** 的整圆（`enemy_body.gd:133` 用 `half=PI` 画满圆，半径取 `reach`，例如冥潮仪镰 W023 `rogue_build_content.json` 的 `art.reach=170`）；但绘制阶段 `stylized_vfx.gd:400-413` 的 `body_centered` 分支先按 `bounds=Vector2.ONE*r*2`（身体居中、半径=reach，本应与判定一致），紧接着一段 `if role!="motion_quake" and fx.has("socket_grip")…`（`:406-412`）又把圆**重新以武器握把(grip)为圆心、缩成刀刃长度 `blade_length`**——于是屏幕上是一枚又小又偏到一边的旋涡，而真正会掉血的是围绕身体的一整圈。修法（留给后人）：去掉 `:406-412` 这段 grip 重定心/缩刃，让圆斩保持身体居中 + `reach*2`。⚠️ 该分支同时服务平A的 spin 类武器（`weapon_mechanics.gd:75 body_centered()` 含 `motion_spin/motion_heavy_spin/motion_quake/motion_hammer_spin`），改动会波及平A观感，须重跑 `tests/weapon_mechanics.gd`（`:46` 断言"Full circle follows captured body center"）、`tests/weapon_heavy_strokes.gd`、`tests/weapon_full_matrix.gd`。
    - **多数近战刀光末端 ≠ 攻击范围最远处**：月牙/横扫类贴图的"刀尖"是从角色位置向外画的装饰，判定框（`attack_hit()` 的 cone/thrust 多边形）最远处与贴图末端不重合，月牙常把角色整个包住或明显短于/超出真实 reach。用户实测反馈：这类要"往角色外的方向移动很多"才能对齐实际判定。根治需要把特效末端与 `reach` 建立显式映射（当前 `mechanic_contact()` 只处理接触点、不处理 reach 对齐），属独立批次，勿与功能提交混做。


---

室外外景契约：story_exterior_composition制作25场有起伏、有树岩植被的非通行实地；南门以河道/桥自然分隔。连接shader混合两端材质与路肩，桥下水面连续。patch_story_exterior_landscape仅替换自有外景分组并验证无GI用户；GLB节点清空scene_file_path后再赋owner。六营地静态地面裁回包络后必须Bake-Exploration-Scenes -CampsOnly，保存植被CPU变换再打兼容缓存。最新试玩Preview-Boundaries.cmd与dist/CrimsonTide-ForwardPlus-v9.exe。

## 12. 路牌维护规范（做完一个功能、交接前必做）

新增存储契约：故事物品UI以唯一uid操作；先在副本上验证整次移动/换装/购买，再提交，不允许半扣款。旧档空间不足进入可领取overflow。新增实例字段需同步valid_item/restore_numeric/存档往返测试。TextureRect先设置EXPAND_IGNORE_SIZE再设尺寸，进度条先关闭百分比再设高度，避免内部图标撑破卡片。

> 这份文件是「下一个人 / 下一个 AI」的唯一入口。代码变了而路牌没改，比没有路牌更糟：它会把后来者精准地指到错误的位置。
> **强制要求：一个功能做完、只剩交接之前，必须更新本文件并提交。谁改的代码，谁更新路牌。**

### 12.1 什么时候必须更新

| 触发事件 | 必须更新的位置 |
|---|---|
| 新增 / 删除 / 重命名脚本、场景、shader、数据文件 | §2 目录结构 + §4 对应功能域 + §4.Q（shader）+ §10（若是专题文档） |
| 新增一个功能域（新玩法 / 新系统） | §3 架构链路 + §4 新开一小节 + §5 速查表新增一行 |
| 改数值常量（伤害 / 血量 / 时长 / 概率 / 上限） | §6 对应那一行 |
| 函数 / 常量被移动，行号漂移 >3 行 | §4、§5、§6 中指向它的每个 `文件:行号` |
| 引入「必须成对改」的契约或新坑 | §11 追加一条，并在 §4 对应行用 ⚠️ 标注 |
| 构建产物路径、导出 / 部署方式变化 | §8 工具链、§9 运行与部署 |
| 一个功能收尾 / 一个分支合并前 | §12.6 修订记录追加一行 |

### 12.2 锚点写法规范

1. 一律写成 `` `文件名:行号 符号名()` ``（例：`` `session.gd:2843 move_player()` ``、`` `catalog.gd:185 STARTER_BASE=17` ``）。纯数值 / 纯区间的锚点可以只写行号，但**能写符号名就必须写**——行号会漂，符号名不会。
2. 行号必须是提交前**实测**的（见 §12.3），不要凭记忆或按旧版本推算。
3. 区间锚点只用于连续代码块（如某个常量块），并保证两端都落在该块内。
4. 相对路径一律相对**项目根**（`scripts/…`、`resources/…`、`tests/…`、`server/…`），不要写机器绝对路径（`D:\…` 只允许出现在本节说明里）。
5. 符号名必须用代码里的**真实标识符**（写 `SPECIAL_KEYS`，不要写「特殊键表」），后来者才能直接 grep 到。
6. ⚠️ 只留给「改错会导致测试回归 / 毁存档 / 黑屏」的约束，不要滥用。

### 12.3 交接前自检（1 分钟）

```powershell
# ① 全量锚点校验（退出码 0 = 全部命中；漂移/失效逐条列出）
python tools\verify_anchors.py --guide PROJECT-GUIDE.md --root . --summary
python tools\verify_anchors.py --guide PROJECT-GUIDE.md --root . --limit 300   # 看明细

# ② 抽查你刚动过的符号（把 update_hud 换成你改的名字）
Select-String -Path scripts\session.gd -Pattern '^func update_hud'

# ③ 确认没有把本机差异带进提交（应只看到你自己改的文件）
git status --porcelain
```

再加两条：改完跑对应测试（§7）并在 `TEST-REPORT.md` 记一行；路牌里凡是写了「配套测试」的行，都要保证那个测试文件真实存在且通过。

### 12.4 提交规范

- 只 add 本次真正改动的文件：`git add PROJECT-GUIDE.md scripts\xxx.gd`；**禁止 `git add .`**——工作区常混着未跟踪目录，而且 `git status` 会常年列出上千个 `*.import`、`project.godot` 等"已修改"条目（实测 `git diff` 内容为空，属行尾/归一化噪声），一提交就脏。
- 提交信息：`docs(guide): 更新路牌——<功能域>`；若与代码同一提交，写 `feat(xxx): …（同步 PROJECT-GUIDE.md §4.x/§5/§6）`。
- 在分支上开发时：合并 / 变基主线之后要**重新核对一遍锚点**（主线改过行号，你的锚点可能已经漂了），再合并。合并进主线的那一次提交同样要更新 §12.6。

### 12.5 直接丢给 AI 的提示词（复制即用）

```text
动手前先读项目根目录的 PROJECT-GUIDE.md（项目路牌）：
1. 它按功能域列出了每处代码在哪个文件哪一行。先查 §5「我要改 X 速查表」，再读 §4 对应小节；不要遍历整个项目找代码。
2. 路牌里的 `文件:行号` 基于 git 提交 <commit>。如果你实测的行号漂移超过 3 行，按当前代码改正它，并把锚点写成 `文件:行号 符号名()`。
3. 一个功能做完、只剩交接之前，必须更新 PROJECT-GUIDE.md：
   - §4 对应功能域的表行（新增/改动的文件、入口函数、行号）；
   - §5 新增或调整「我要改 X」一行；
   - §6 若动了数值常量，更新对应行；
   - §11 若引入新的「必须成对改」的约束或坑，追加一条；
   - §12.6 修订记录追加一行（日期 / 提交 / 改了什么）。
4. 提交时只 add 你实际改动的文件，禁止 `git add .`（工作区常混着未跟踪目录和大量行尾差异条目）。
5. 交接说明里写清：改了哪些文件、对应测试是否通过、路牌哪几节被更新。
```

### 12.6 修订记录

2026-10-11（同批提交）：完成故事占格行囊/三人装备/属性专精/仓库/交易买卖回购/单件锻造打造分解镶嵌。原创imagegen图标、框架及九宫切片内部控件覆盖HUD/NPC/日志/地图/暂停。旧档零丢件迁移与原子事务，伙伴读独立装备。v10小运行入口挂载v9地图与物品补丁，画质重启保持入口；长跑仍暂缓。更新§3/4.S/5/6/10及本说明。

2026-10-10（同批提交）：v9采用用户最终要求的实地外景：25场制作起伏和树岩植被，南门增加河道/桥体/河岸；六营地地面裁回包络并重烘GI，连接PBR渐变/路肩保持。实际移动穿过六幕出口，新增背景起伏/非通行装饰与接缝检查。修复GLB保存重复实例化，并在烘焙保存前安全捕获MultiMesh。v9替代v8，长时间跑分暂缓。


2026-10-10（同批提交）：v8修复六幕19区/六营地的可见边界、连接路封边和水面偏移。新增共享多边形几何与真实缓存接缝测试，19区陆地/岸壁重烘，25区GI禁用背景安全更新；任务/存档/小树非实体保持。制作说明BOUNDARY-SURFACES.md，长时间跑分暂缓。


| 日期 | 提交 | 更新内容 |
|---|---|---|
| 2026-10-10 | 见同批提交 | v7重做30副本为空间类型驱动的布局：22类型、不同包络/空间数/高差轴/边界语言，庭院、甬道、岩腔、环塔、扇形剧场与水槽跨桥；新增真实轮廓图集、缓存/发布身份验证与具体地图试玩。更新§4.S/§5/§10；模型库与73任务保留，长跑暂缓。 |
| 2026-10-10 | 见同批提交 | 重做30副本与19室外轮廓，34新Blender模块；共用房间图/空洞/高程/碰撞/敌群/探索图，补全49区GI与临时副本试玩；保留地图ID和73任务，长时间跑分暂缓。详见DUNGEON-EXPLORATION.md及TEST-REPORT。 |
| 2026-10-10 | 见同批提交 | 二至六幕84个新模型、17套新PBR、15份地形、45个可编辑区域与GI烘焙，十种额外副本题材；跨幕释放美术缓存与独立临时试玩入口；地图ID/73任务保持一致，详见ACTS-2-6-ART.md及TEST-REPORT。 |
| 2026-10-10 | （本轮Forward+提交） | 默认Forward+、三档画质与超分；开场Blender模块/PBR/地形、实际GI烘焙、曲岸碰撞、遮挡淡出、人物融合与区域缓存。原始验收和范围见TEST-REPORT、FORWARDPLUS-ART-PIPELINE.md；保留用户PV与旧试玩。 |
| 2026-10-10 | （本轮开场续作） | 12类室内家具、44处场所摆放、共享占地数据与室内台基高度；拆分前景Side墙、修正淡出漏掉根网格；增量场景编辑、指定模型导出、烘焙互斥及文件更新校验。更新§4.S/§5与生产说明；长时间性能验收继续暂缓。 |
| 2026-10-10 | （本地故事实现提交） | 只读解析本地D2R的IDX/BLTE/TVFS，检查23个HD场景样本；补读旧包关卡出口表。故事地图改为每幕连续野外与双向分层副本，另加12层可选洞窟；统一高度、楼梯、进屋屋顶隐藏、前景遮挡、地面混合、河岸、区域地标、寻路、探索图与传送阵激活。战役180、地图647、集成12、图形10检查无失败；独立EXE已重导出，详见docs/rpg/IMPLEMENTATION.md与D2R-ENVIRONMENT-RESEARCH.md。 |
| 2026-10-09 | （本轮文字设计，未提交） | 新增 docs/rpg/ 四份RPG设计文档：按用户PV背景与开局向下出营要求，设计六幕独立营地、40主线、24支线、9个人线及可组合结局；README与§10添加入口。仅文档，尚未新增 story 运行模式。任务编号、标题、依赖无环及本地链接检查通过。 |
| 2026-10-09 | （故事基础实现，未提交） | 只读解析用户本地MPQ地图：36个DS1、16个DT1与六张配置表。新增独立story页面及战役、地图、显示、UI模块，编译73任务全文，接入营地服务、三人战斗、装备专精、存档／战前恢复；原创NPC图集由内置image_gen生成。导出dist/CrimsonTide-Story.exe。规则510、集成12、图形6、原营地32与模式10检查无失败；剩余制作差异见docs/rpg/IMPLEMENTATION.md。 |
| 2026-10-08 | （本轮文档） | **把合并轮踩到的 4 类可规避坑写进规范**：§11 追加 50–53——**50** `verify_anchors --fix` 的去重门（`tools/verify_anchors.py:334` 只改全文唯一锚点，合并后 DRIFT 卡住不再下降是常态，改按 `--json` 报告做**全文替换**清零，`--fix` 死循环到不了 0）；**51** `--fix` 写出的 `.bak` 是临时产物勿提交（上游 `8252812` 曾误入库，已移除并 `.gitignore` 加 `*.bak`）；**52** git 网络命令的 stdout 别接管道（`| Select-Object` 会假死），`job_kill` 留下的 `git`/`git-remote-https` 子进程会卡住后续 fetch，先 `Stop-Process` 再重跑；**53** 两个 CRLF stat-cache 幽灵文件（`scripts/rogue_backdrop.gd`、`tests/direct_fallback.gd`）常年显示 ` M`，永远不要 add——这是禁止 `git add .` 最现实的实例。§12.7 结论同步补"合并后 --fix 修不干净是常态"的指引；上一层工作区 `AGENTS.md` 薄壳加对应硬规则（只放规则 + 指回本节）。锚点全量复跑 DRIFT 0 / WRONG 0。 |
| 2026-10-08 | 1681f7b / 741ab38 / d5badcd | **合并上游 `origin/master`（10 提交 dac2149，镜像试炼 + 武器美术 + 肉鸽修复）与本地 R.1/文档链**：①3 处内容冲突保留双方功能——`scripts/main.gd` 把镜像试炼分支（origin）与 R.1 救援者近身提示循环（HEAD）并成 `elif rogue_combat` 内 if/else + 其后独立 `if p.status=="active"`；`tests/rogue_hooks_roguelike.gd` 取 origin 刷新卡 value-only 复用断言（HEAD 断言的超集，实测 **178 checks / 0 failures**）；`PROJECT-GUIDE.md` 19 冲突块逐一合并，两处 origin 独有描述（§5 attack() 战技携带 attack_kind/width/radius、§11.6 特效挂点 `weapon_effect_socket` + `mechanic_contact`/`draw_mechanic`）按合并后代码回填。②R.1 表整体保留 HEAD 的"已修/已对齐"（本地 c130864 已把半径落进合并后的 session/battlefield/camp_activities），丢弃 origin 侧旧"待修"快照。③合并后全量重锚：`verify_anchors --fix` 三轮 + 手工补 26 处被去重门挡掉的重复锚点，**756 锚点 → OK 494 / DRIFT 0 / WRONG 0 / HINT 262（退出码 0）**。④清理：移除上游误入库的 `PROJECT-GUIDE.md.bak`（8252812 带入），`.gitignore` 加 `*.bak` 防复发。⑤`main.gd` / 测试脚本均 `--check-only` 解析通过。**未跑全量门禁**（`run_all_tests.ps1` / `run_rogue_gate.ps1`），留待 M2 一并跑。 |
| 2026-10-07 | （本批未提交） | 69 把武器逐页人工核对与完整方向 GPU 矩阵；ImageGen 再绘重刃 v3/震地 v2，锤类改为冲击环；战技前摇与精确出手姿势修复；新增全量测试、69 页预览与 WEAPON-FULL-AUDIT.md，同步 §4、§11 与验证记录 |
| 2026-10-07 | （本批未提交） | 武器真实剑尖与亮刃接触点修复，去掉释放旋转漂移、降低过曝、同步实际前摇；ImageGen 重画双刃 v3 和重刃终结 v2；新增真实 GPU 接触测试与角色四方向预览，更新 §5、§11、专题说明与测试台账；试玩 build/CrimsonTide-WeaponTipFixed.exe |
| 2026-10-05 | b034286 | 初版：按功能域建立全项目文件地图（§3–§11） |
| 2026-10-05 | 见同批提交 | 全量锚点审计（476 个锚点，见 §12.7）并修正 11 处错标 / 漂移；新增本§12 维护规范；README 加入口指引 |
| 2026-10-05 | 见同批提交 | 跟随 `abcbaaf`（肉鸽扩展全量接线 + 攻击前摇，179 文件/+17267 行）全量重锚：机械修正 47 处 + 8 章节人工复核（修正 100+ 处漂移/错标）；新增 attack_telegraph、肉鸽七子系统（图谱/事件/诅咒/每日/成长/房间/变体）、房间 UI 与每日/成长页等条目；装入 `tools/verify_anchors.py`；结构数字更新为 102 脚本 / 2.95 万行 |
| 2026-10-06 | （本批未提交） | **营地行囊 + 15×15 网格仓库 + 装备持久化**：新增 `scripts/camp_pack.gd`、`scripts/camp_storage.gd`、`scripts/item_tile.gd`、`tools/make_camp_pack_backdrop.gd`、背板占位图 `assets/ui/camp-pack-vault-v1.png`；§4.B 重写存档行并新增「装备持久化/仓库容量/只计一次价值/整备台购买」4 行，§4.C 结算与动作总线加约束，§4.G 扩成背包全家（对局面板 + 共享格子 + 营地面板 + 营地编辑规则 + 交易行网格），§4.N/§4.O 更新营地按键与整备台，§5 新增 5 行速查，§6 新增 4 行数值，§11 改写第 8/9/10 条并追加 16–19 条（valued 去重、同 provision 才能并堆、JSON float 导入、无头测试 APPDATA）；结构数字更新为 105 脚本 / 193 测试 |
| 2026-10-06 | （本批未提交） | **营地双击规则重做 + 拖动预览冻结修复**：①营地内双击改为"存储动词"——非装备先进背包（背包放不下才进仓库），装备槽位空则穿上、被占则与身上那件互换且**换下来的落回对方原来那格仓库格**，可堆叠物沿用落点；②**营地永远不填快捷栏**（`[1][2][3]` 只能拖入），对局内保留"双击消耗品进快捷栏 / 单击=Ctrl 智能键"；③修 `main.gd:1389` 对局早退把 `sync_drag()` 挡在门外导致**营地拖拽预览冻在原地不跟鼠标**；④修 `pick_item()` 点仓库物品必崩（`session.players[...]["warehouse"]`）、`held_size()` 空物品崩、双击已在背包的物品会**复制**、`profile.data["warehouse"]` 缺失时仓库静默失效；⑤新增 `session.gd:2449 container_accepts()`（"这格能不能放"，与 `container_receive()` 区分）。§4.G 新增「营地双击规则」「拖拽预览逐帧跟手」两行并更新存储规则锚点，§5 新增 3 行速查，§11 追加 20–22 条；全量重锚 514 个锚点（386 OK / 0 DRIFT / 0 WRONG / 128 HINT） |
| 2026-10-06 | （本批未提交） | **双击装备位卸下 + 稀有度收纳规范 + 装备位拖拽**：①`_input` 里装备位命中测试**移到网格之前**（原来被 `grid_at()` 空手早退吃掉，导致"装备栏只能点右上角卸下"），双击/Ctrl+左键/F/「卸」字四条手势统一到 `take_off_worn()`；②卸下规则：**营地 背包→仓库**（`camp_storage.take_off()`）、**对局/肉鸽 只认背包 + 金及以上才允许口袋**（`session.take_off_fits()/stow_worn()`），不满足则 `notice_popup()` 提示且不触发；③写入**稀有度与自动收纳规范**（`README.md` 新增小节 + 上一层 `AGENTS.md` 硬规则）：次元口袋只对金及以上算有效空间，单一真源 `high_quality()`，并记下两处刻意例外；④换装旧件不再包成可搜索掉落包，改 `drop_loose()` 单件落地（地上显示成装备本身、`F` 拾回），`unequip_item()` 由"掉地上"改为**拒绝**；⑤营地装备位成为拖拽起点（`worn_to_socket()` 槽↔槽互换、可拖进背包/仓库），修 `slot0` vs `slot:0` 两套拼法导致的槽位读数错位；⑥修「拖拽预览冻住」「双击后画面不同步」「点仓库物品崩溃」三个 bug。§4.G 新增 5 行、§5 新增 2 行、§11 追加 23–26 条；全量重锚 |
| 2026-10-06 | （本批未提交） | **本轮收尾：面板「卸」字回退 + 对局装备位拖拽 + 槽位规则合并**：①按用户决定**回退**面板「卸」字的"拒绝"口气，恢复"一定卸下、放不下就掉在脚边"（`unequip_slot()` / `unequip_item()` / `stow_equipment()`），手势卸下仍是"不触发 + 中上提示"，并把这条**不对称约定**写进 README 与 §11.26；②**对局也支持装备位拖拽**：会话侧新增唯一实现 `socket_entry()` / `set_socket_entry()` / `clear_socket()` / `swap_sockets()` / `socket_wants()` / `slot_number()`、`move_worn_to()`，动作 `worn_equip` / `worn_drop`；营地侧删掉自写的 socket 读写（`slot_number`/`clear_slot`/`worn_to_socket`/`zone_accepts`/`restore_zone` 全改为委托），§11 追加 27；③松手在面板之外**不掉地上**（穿在身上的东西不冒险）；④测试：`tests/systems.gd` +19（卸下两种口气、单件落地、槽位互换与拒绝、`move_worn_to` 座位与拒绝）、`tests/inventory_panels.gd` 14→23（对局装备位拖拽：进背包 / 进道具栏互换 / 面板外松手不掉地上） |
| 2026-10-06 | （本批未提交） | **本轮第三批：丢弃区/毛玻璃 + 营地地面掉落 + 搜刮箱双向 + 脱下背包算法**：①**丢弃区**：面板登记整块背板（含木框），面板内空白松手**不再丢东西**，拖出面板才丢；进入丢弃区时把**提前渲染并缓存**的毛玻璃背板以 30% 透明度盖上（`frost_texture()` 降采样当模糊，只算一次），松手前就能看出面板已失效。②**营地地面掉落**：拖出面板的东西/脱包溢出/主动丢弃都落在营地地上，**F 拾取直接进角色背包**（满了才进口袋），上限 **60 件**（超出最旧的消失）；**离开营地只留数据、节点全释放，回营地按数据重建**，关闭游戏即丢失（不写存档）。③**搜刮箱变成双向**：修掉 `move_between()` 里那条**没有调用者的 `to="loot:"` 死分支**（现在 `release_drag()` 会把 `"loot"` 翻译成 `"loot:<引用>"`），并新增 `move_worn_to_loot()`，背包物品与身上装备都能拖进箱子，放不下只是拒绝。④**背包槽可拖 + 脱下背包算法**：不再"装不下就拒绝"，改为换上 **3×3 制式包**、内容按 `keep_order()`（**品质优先，同品质比价值÷占格**）从最珍贵开始塞，**塞不下的一律掉在营地地上**。⑤**性能**：该排序实测 **0.145 ms**（预算 0.2 ms，超了就退回"品质→单件售价"）；早期 0.463 ms 全是 `sort_custom` 回调开销，改用 `PackedInt64Array.sort()` 后达标，`tests/camp_keep_order.gd` 常驻守门。⑥测试：`camp_storage` 98、`camp_pack` 31、`camp_activities` 103、`inventory_panels` 28、`camp_keep_order` 3，全 0 失败；§11 追加 28–30 |
| 2026-10-06 | （本批未提交） | **本轮第四批：堆叠搬运（整叠 + 右键拿 N 个）+ 旋转改中键与挤位 + 徽标 + 委派两处 UI**：①**堆叠默认双向整叠**（`camp_storage.gd vault_in()` 原本把 `count` 压成 1）；部分搬运＝**右键拿起 1 个、再右键加 1**，左键点格子放下、面板内空白/Esc 取消、面板外丢地上；**手上的数量只是视图**（`drag.carry`），真正扣减在落地那一刻，所以取消零副作用。②**旋转改鼠标中键**（右键让给"拿起"；肉鸽面板右键是它自己的菜单，未动），并新增**挤位算法**：原地转不下时用 `catalog.gd tidy_around()` 先给被旋转物落座，其他按 `tidy()` 重排、真正放不下的按 **仓库→快捷栏→背包→地上** 消化——**被旋转物永不丢失**（`tests/systems.gd` 有守恒不变量测试）。③**堆叠徽标**改 `#FF9000` 并挪到格子右下角（暂不加粗，项目无 Bold 字体）。④**委派**：`qoder-cn/Qwen3.8-Flash`（能力表：SWE-bench Pro 62.5 / CoWorkBench 73.9 / 1M 上下文；弱项是最重深度推理）并行做「家园商店卖出真实删格」与「交易行卖背包物品 + 上下双滚动 + 分类合并」，**禁止它们碰 main.gd/session.gd/路牌**。⑤测试：`camp_storage` 98→118、`camp_pack` 31→41、`systems` 10847→10853，全 0 失败；§11 追加 31–33 |
| 2026-10-06 | （本批未提交） | **本轮第五批（会话收尾）：家园商店真出售 + 交易行改造进路牌**：①`profile.gd sell_product()` 与 `home_screen.gd` 出售页（「卖 1 / 全部出售」）——**卖出真删仓库实体格**（整堆卖光腾格、部分卖改 `count`），持有口径 `product_count()` 未动；测试 `economy` 139→159、`homestead_ui` 53→59。②交易行 `economy_screen.gd` 重写为**左侧上下两块货架各带滚动条**（仓库 + 血月背包）、删掉"背包"分类并入"武器与装备"，出售分 `Profile.sell_items()`（仓库）与 `camp_storage.gd sell_backpack()`（背包，本批补写）；抽出共享滚动配方 `scripts/ui_scroller.gd`；`tests/economy_ui.gd` 回到 0 failures。③路牌补 §11.34–35（面板搬节点防 cyclic dependency；UI 窗口改完先跑解析自检再跑 UI 套件）并全量重锚 |
| 2026-10-07 | c0cb076 / 4d0110c / 928bdeb | **交接第一轮：行尾真因 + 两笔提交 + 合并上游肉鸽三提交后全量重锚**：①查明"CRLF 污染"真因是 `.git/config` 里一条 `core.autocrlf=false` 本地覆盖压过了系统默认 `true`（提交里一直是 LF，工作树是 CRLF 检出），删掉该覆盖后 `git diff --stat` 从 9471/6778 塌缩到 **3205/512**——**没有改写任何文件**；②按约定式提交拆两笔（`c0cb076` 营地行囊/仓库网格化、产物实体化与装备持久化 + 测试，49 文件；`4d0110c` 文档，3 文件）；③合并 `origin/master`（b6fa3a3 · ea05a1c · 20ede82）为 `928bdeb`：15 个两边都改的文件里 13 个自动合并，`main.gd` 唯一一处内容冲突是"双方在同一位置各插一段"（我方营地拖拽/预览同步代码 + 上游 U1 注释），**两段全部保留**并把注释里过期的行号 1318 更正为 1578；8 个 `.uid`（Godot 生成单值文件）取上游版本，已用 `git grep` 证明全仓库无第二处引用；④合并后全量重锚：`--fix` 自动修 28 处 + 按实测行号手工修 28 处，**552 锚点 → OK 366 / DRIFT 0 / WRONG 0 / HINT 186**；⑤上游把 `assets/rogue/build/` 从占位文件换成真实生成物，TEST-BASELINE §4 点名的"全新 clone 必然编译失败"这一最脆弱环节消失；⑥新增 §11.36–38（autocrlf 覆盖假象、`.godot` 不可写导致 `--import` 静默失败、新物品缺图标）。**已知红（均非本次引入）**：`tests/balance` 6 项（旧 gear 基线同样复现，见 TEST-REPORT 登记）、`tests/rogue_hooks_roguelike` 1 项（上游把该测试扩了 +488 行却没重登记门禁基线，85→176 checks；我方合并 delta 未触碰 `update_rogue_hud`，那一行仍是上游自己的红） |
| 2026-10-07 | 2b8a255 / 7467935 | **右键分堆手势 + 按类堆叠上限 + 图标回退**：①**上限改按类配置**：`catalog.gd:734 STACK_LIMITS` 成为单一真源（急救针/弹药匣 3，其余可堆叠物 5，不在表里＝上限 1），`catalog.gd:758 stacks()` 由它派生、不再另立 `STACK_KINDS`；**计数与花费不再把 count 夹到上限**（夹取会让 6 件一叠只算 5 件、尾巴永远卖不掉），防手改存档改用 `catalog.gd:638 clamp_entry()` 的宽上限。②**右键按住＝分堆手势**：按住拿整叠（单件物品就是一个上限 1 的堆叠物，所以对装备同样成立），按住期间**每次左键只在鼠标那一格放 1 个**，松开右键把剩下的交给鼠标所在容器；落座规则抽成 `catalog.gd:868 place_units_in()` 且**刻意不调 `compact_arrivals()`**（刚放下的那格不会被重新打包搬走＝"锁住那一格"）；**源容器只在单位真的落地后才扣**，所以"放回原处"是免费无损的 no-op，只有松手在面板外才丢地上；**左键完全没动**（左键拖动/`Ctrl`+左键/双击照旧整叠）。③**修掉两处真实吞件**：`profile.gd:375 warehouse_deposit()` 的 clampi 截断（超出部分消失且返回 0，连 `bank_item()` 的回滚都跳过）、`camp_storage.gd:198 vault_units_in()` 的 `from==vault` 自吞。④**降上限不毁档**：新增 `catalog.gd:927 split_over_limit()`，仓库溢出进 `warehouse_spill`、背包与口袋在 `profile.gd:136 sanitize_storage()` 里一次性归一。⑤**图标**：`battlefield.gd:86` 原来对非收藏品绕过 `ui_art.gd:19 TideUIArt.icon()` 直接 load 缺失的 svg（每次 10 行报错），改为统一入口 + 给 `*_seed` 一条"用作物图标"的回退 + 最后一跳先问 `ResourceLoader.exists()`，报错降到 0。⑥**测试**：新增 `tests/stack_hand.gd`（64 检查）覆盖上限表、严格落格、落座顺序、拆堆守恒、两条吞件回归与营地面板端到端手势；`systems`/`camp_storage`/`economy`/`camp_pack` 里按旧上限 6 写的断言随之更新（`camp_storage` 的样例数据从 ammo 换成 crystal——弹药上限已是 3），并修正一条把 crystal 写成 ammo 的过期断言。⑦路牌本身：§4.G 新增三条（分堆手势/上限表/拆堆）、§5 三行速查、§6 两行数值、§11.39–42，并修掉已失效的 `STACK_KINDS` 锚点；全量重锚（`--fix` 28 处 + 按实测行号手工 41 处） |
| 2026-10-07 | （本轮未提交） | **种子/鱼饵买入实体化（C1）**：`homestead.gd buy()` 改先入守夜人仓库、满则退随身背包（`profile.gd deposit_backpack()`，不进次元口袋）、都满则余量掉营地地上 + `notice_popup`（全额扣款、永不丢件）；`plant()/cast()` 改扣真实实体（`spend_product`）；旧档 `home.seeds/home.bait` 由 `profile.gd migrate_home_seeds_bait()` 一次性迁实体（`warehouse_deposit`+`spill_item` 零丢件）；`home_screen.gd` 读 `product_count` + `buy_report()`；`camp_activities`/`camp_screen` 读法同步；`catalog.gd` 注释同步；`tests/homestead` 加"卖<买"与迁移断言。测试全绿（homestead 69 / homestead_ui 59 / camp_activities 103 / economy 161 / camp_storage 118 / camp_pack 45 / systems 10853） |
| 2026-10-07 | （本轮未提交） | **肉鸽分叉口去掉隐形墙（路口改成一整块广场）**：用户实测"直行路斜着走向「斜向」门口会被一堵透明的墙挡住，只能找个角度绕进去"。定位到 `rogue_map.gd configure()` 原来只把「实测地面」与岔路多边形做 `merge_polygons()`，两路之间必然留下一个楔形留白——它没有美术依据，却是一个必须绕行的隐形尖角（全 35 个区域同源，实测岔口→门直线被挡 30%~56%）。修法：新增 `rogue_map.gd（历史 fork_junction 实现，现已移除） fork_junction()`（上界＝岔路外沿、下界＝地面下沿），先把路口补平再合并，两个门口于是落在同一面右墙上、斜着直走即可进门；`top_edge`/`lane_center`/出口 UV/障碍与岩浆生成点全部不变，`fork_polygons` 仍保留原始岔路多边形。测试：`tests/roguelike_routes.gd` 把"斜穿楔形必须被挡"的断言翻转为"岔口→两个门口的直线必须畅通"，并新增 140 项全地图断言（5 层 × 7 区 × 长短房 × 两个门）；地图相关套件全绿（`roguelike_routes` 5235→5375、`roguelike_geometry` 744、`roguelike_ground_bounds` 9427、`roguelike_seven_rooms` 17297、`roguelike_smooth_maps` 1115、`roguelike_exit_alignment` 706、`roguelike_camera` 7、`roguelike_spawn_spacing` 6166，均 0 失败）。§4.E/§5 更新横版地图行、§11 追加 43；顺手把 §12.3 全量锚点校验报出的 31 处旧漂移（`main.gd`/`session.gd`/`profile.gd`/`rogue_build.gd`，含 4 处 WRONG）按实测行号改正，**617 锚点 → OK 410 / DRIFT 0 / WRONG 0 / HINT 207（退出码 0）**。**已知红（非本次引入）**：`tests/roguelike_art.gd` 在本机写 `res://assets/rogue/atlas-regions.json` 失败（`FileAccess` 12 = ERR_FILE_CANT_OPEN，第 22 行，早于任何地图代码），其地图半边已单独复跑 15/15 通过；`tests/roguelike_hd_visual.gd` 在 `spawn_enemy((970,610))` 处空数组（该点在地面上沿外 8.5px，改动前后 `blocked(25)` 完全相同，属旧红） |
| 2026-10-07 | （本轮未提交） | **营地行囊面板三处实测 bug**：①**魔境模式下的营地面板整片失效**——`main.gd _input()` 第一句 `if session.roguelike.active(session): return` 用会话级模式当"这是魔境战斗"的判据，而 `raid.mode` 一旦是 roguelike 就整个会话保持（`session.gd:1528 begin()` 写入，魔境跑完回营地不清），于是"从魔境回营地"后行囊面板的格子/装备位/背包柜全点不动、而面板按钮照常可用（Button 不走 `_input`），日志里一条错都没有。判据改为新函数 `main.gd:1704 bag_mouse_live()`（**绑 `page_name=="game"`**）。②**面板挡不住下面**——面板是普通节点画的，空处没有 Control 接鼠标，点击穿到营地页（实测点「主手」顺带触发同一位置的「晨光菜园」并瞬移角色、点面板右下角顺带点到「出发」）：`camp_pack.gd:47 shield`（`camp_pack.gd:68 CampPackShield`，全屏 `MOUSE_FILTER_STOP`）补上，写法对齐 `home_screen.gd` 的全屏 STOP 根节点；同时 `main.gd:1631 _process()` 的 `camp.input_blocked` 由 `modal` 改成 `modal or camp_pack_open`——否则面板打开时营地照旧走路、照旧响应 E（`camp_screen.input_blocked` 是营地自己的冻结开关，每帧被这行重写）。③**HUD「出发」按钮点了没反应**——`main.gd:988 camp_departure()` 原来只在角色站在闸门/传送门时才有动作，否则只 `say()` 一句提示（面板打开时那句提示画在面板底下，看不见）；现在按钮按当前模式从任何位置进站，世界里的 E/Space 仪式不变。测试：新增窗口化真鼠标回归 `tests/camp_pack_input_visual.gd`（14 项；把三处修复回退掉会红 7 项，含"点面板却瞬移角色""关掉面板后同一点才真的出发"）；`camp_pack` 45 / `camp_storage` 118 / `camp_flow` 32 / `camp_activities` 103 / `homestead` 69 / `homestead_ui` 59 / `inventory_panels` 28 / `final_e2e_roguelike` 120 / `item_bar`（窗口化）49 全 0 失败。**已知红（均非本次引入，已用 HEAD 版 `main.gd` 复现）**：`camp_modes` 1 项（`confirmed purchases charged once on start`，金币对不上）、`rogue_inventory` 10 项、`rogue_ui` 1 项、`rogue_hooks_roguelike` 1 项。§4.G 更新行囊面板行并新增"谁在接鼠标"判据行，§4.N 补 HUD 出发按钮链路，§5 新增两行，§11 追加 44–46 |
| 2026-10-07 | （本轮未提交） | **路牌按当前代码全量刷新 + 补齐两处没登记的实现**：①**未登记文件**——`scripts/rogue_map_screen.gd`（肉鸽路线图 M，纯函数 `layout()` :68 / `draw_map()` :287）与 `scripts/rogue_build_preview.gd`（行囊内 V 的派生链预览，`layout()` :163 / `draw_preview()` :319）此前不在路牌里：§4.E 补路线图行、§4.F 补派生链预览行（含 `main.gd` 的 preload/实例化/显隐/热键接线锚点），§5 补两行速查（并如实写明**两处都没有专属测试**，`layout()` 是纯函数、可直接 headless 断言）。②**结构数字**：`scripts` 105→**112**（3.77 万行）、`tests` 193→**213**（2.36 万行）+6 Python、`tools` 120+→**147**；§7 的 GDScript 用例数同步为 213。③**新增测试约定**（§7）：要真鼠标的用例必须命名 `*_visual`（只有它/`ui`/`hybrid_vfx_preview` 会被 runner 开窗跑；无头下 `warp_mouse` 与 `get_mouse_position` 都不生效），并给出本机实测的既有红清单（`camp_modes` 1 / `rogue_inventory` 10 / `ui` 30 / `rogue_ui` 1 / `rogue_hooks_roguelike` 1 / `roguelike_art` 写盘被拒）与"用 HEAD 版文件复跑对比"的判定法。④§8 补一行"素材预览/烘焙（GD）"代表脚本。⑤§12.7 更新为 2026-10-07 全量审计。全量锚点：**651 个 → OK 431 / DRIFT 0 / WRONG 0 / HINT 220**（退出码 0） |
| 2026-10-07 | （本轮未提交） | **引魂灵体主动索敌（用户实测「召唤出来的灵体不会自己找怪物打」）**：原来灵体只会朝主人走（100/125 px/s），每 1 秒对"自己 450 内有视线的怪"结算一次，优先 T086 锁定目标、否则取最近 —— 从不追怪、也没有"主人打谁就集火谁"。按用户拍板的规则改成四级索敌：①主人的指令（普攻/战技/技能命中过的怪；T086/HC 的 3 秒硬锁优先）无距离上限追击，出大圈也打完；②主人大圈 300（圆心＝主人）；③灵体自己的低优先圈 166.7（圆心＝灵体）；④回主人身边的待命位（1 号左上、2 号右上，两个不叠）。新增 `SOUL_*` 常量、`soul_step()`/`soul_pick()`/`soul_idle_point()`/`soul_free_slot()`/`enemy_by_id()`，`hit_event()` 里把主人的命中记成 `soul_focus`（跳伤与灵体自身伤害走 `depth>0` 已早退，0 伤害不算）；**转火 0.5 秒内置 CD**（每灵体独立，低优先→高优先可立刻抢占）；追击停靠射程 85%（380）、被地形卡住 0.6 秒放弃 1.5 秒后再试。**伤害数值一处没动**（1 秒/次 / 上限 2 个 / 0.16P 预算 = 契约 §7.12）。**同日二轮**：用户验收预览后判定「圈太大」——大圈 600→300（减半）、灵体射程 450→150 与小圈 500→166.7（各 1/3）、停靠 380→127.5、牵引 600→300；预览脚本加 `SHOW_RANGES`（默认 false，正式对局不画判定圈）；测试几何同步收紧后仍 27/0、破坏三处行为红 10 项。测试：新增 `tests/rogue_summons.gd`（无头 27 项；三处行为回退会红 9 项，已用"备份→破坏→复跑→按 sha 还原"验证敏感性）与 `tests/rogue_summons_visual.gd`（真窗口出图 `build/rogue-summons-1-idle/2-seek/3-command/4a-cd/4b-relock.png`，图上把 600/500/450 三个半径与目标连线画出来，日志同步打印每只灵体的 target/tier/switch 以便核对）。§4.F 新增灵体索敌行、§5/§6 补数值、§11 追加 47；`rogue_build.gd` 前部插入代码后把路牌里该文件的旧行号一并重锚（stat/hit_multiplier/hit_event/action_event/legal_talents/management/award/add_experience/hero_effect/visual_state/core_visual/武器分支表/match 表） |
| 2026-10-07 | （本轮未提交） | **灵体索敌半径按验收反馈缩小 + 开发者判定框总览（M0/M1）**：①用户看验收图后判定「圈太大」——大圈 600→**300**（减半）、灵体射程 450→**150** 与索敌圈 500→**166.7**（各 1/3）、停靠 380→**127.5**、牵引 600→**300**（常量都在 `rogue_build.gd:19-27`）；测试几何同步收紧后 `tests/rogue_summons.gd` 仍 27/0、破坏三处行为仍红 10 项。②验收图里那三个圈属于 `tests/rogue_summons_visual.gd` 的开发者覆盖层，新增 `SHOW_RANGES`（**默认 false**）——正式对局不画任何判定圈。③按用户要求立项「开发者判定框总览」：新增 `scripts/dev_ranges.gd`（只读覆盖层，`enabled()` 读 `CRIMSON_DEV_RANGES`；画框工具 + 第一批：灵体四档半径、主人点名目标、角色地形判定 15、怪物半径、目标连线，F9 收文字）、挂载点 `main.gd:282`、启动脚本 `开发者模式启动.cmd`；实测有环境变量时覆盖层被创建并出图 `build/dev-ranges-rogue.png`，**没有时 `DEV_RANGES_CREATED=false`（节点根本不创建）**。④完整判定框清单（战斗 A1-A12 / 搜打撤 B1-B5 / 肉鸽 C1-C8 / 营地 D1-D6 / UI E1-E3）、里程碑 M2-M6、验收标准与已知坑写在**工作区上一层** `D:\dsh\Game\任务.md`（刻意不进版本库，跨多轮对话用）。§4 新增 R 节、§5/§9 补行、§11 追加 48 |
| 2026-10-07 | （本轮未提交） | **取消灵体牵引 + 互动半径审计 + 路牌新增「R. 开发者模式」大类**：①用户拍板**取消牵引距离**（原 `SOUL_LEASH`=300：第②③档追击时离主人超过 300 就往回走，会在主人侧后的怪身上「追一步→回一步」来回抖）——现在第②③档也一路追到停靠 127.5，只有被地形卡住才回主人身边；第②档目标按定义在主人 300 大圈内且每帧重选，出圈自然换目标。**指令接收是全局的**：灵体在远处追别的东西时，主人换点名也立刻生效——新增 4 项断言覆盖（31/0），含"灵体离主人 >300 时仍改打新点名目标并从远处赶回来"。②互动半径审计（子智能体 glm-5.3 只读审计，行号实读核实）：营地 `[E]` 提示本身已与判定同源（`station.radius`），真正不一致的是营地名牌 650、搜打撤世界标签按"相机 1500"、魔境常驻提示无距离、宝箱提示 70 vs 判定 80；全部写进 §4.R.1 的"互动半径表 + 待修总清单"。③路牌按用户拍板的**方案 A** 新增「R. 开发者模式」大类（大类开头写索引与跨类指引），下含 R.1 互动半径表、R.2 判定框总览；**方案 D 的全量重构计划**（大类按模式：营地与家园 / 正式对局(搜打撤+魔境合并) / 表现与音频 / 联机 / 开发者模式）写在工作区上一层 `任务.md`。
| 2026-10-08 | c130864 / 205ea27 / （本轮文档） | **`tests/ui.gd` 真鼠标红：推翻"确定性坐标 bug"定论、改判 flaky、保留兜底固化**：①同代码（HEAD `205ea27`）、同机器开窗连跑实测，失败数**在 8 / 1 / 0 / 4 之间跳动**（19:11 留档 8；纯环境复跑 8→1→0；加诊断探针那次 4）——**不是**上一份交接（工作区外 `111111.md`）说的"坐标二次缩放致 27 条必红、换 1440×900 即全绿"。②实测标定 `mode=3`（全屏 2560×1600），`warp(600,600)`→`get_mouse_position()=(337.5,337.5)`，`mouse_scale≈1.777`（≠1）；坐标二次缩放（`main.gd:3382 mouse_point()` 在 viewport 坐标上又乘 canvas 逆矩阵）确实存在，但它是**放大抖动**的帮凶、非"全 miss"元凶。③兜底探针实测：同一次运行 `:368` 那次真链路命中成功、`:381` 那次真链路 miss，证明真鼠标时好时坏；**用户拍板保留 `ui.gd:368`/`:381` 两处 `auto_store_loot`/`move_between` 兜底保绿，flaky 根治（消除二次缩放 + 手势 readback 改轮询 + 前台焦点）登记为已知缺口留给后人，勿与功能提交混做**。④诊断 print 已还原、工作区无临时改动残留。文档：§7 既有红清单补"ui 失败数 flaky 波动、别当固定基线"；新增 §11.49（含实测数据、对旧定论的推翻、根治三要件）；README「工程与验证」`tests/ui.gd` 行同步标注。锚点：`python tools/verify_anchors.py` 全量 739 → DRIFT 0 / WRONG 0（退出码 0）。**未跑全量门禁**（`run_all_tests.ps1` / `run_rogue_gate.ps1`），留待 M2 后一并跑。 |
| | | |

| 2026-10-08 | 见同批提交 | Boss 出场恢复固定顺序：远征主教→猎王→女王→无名赤月→条件终局；肉鸽 BOSS_ORDER=[0,1,2,3,4]。隐藏战仅在无名赤月倒下后触发；阶段/死亡特效保留 art_key，缺省身份优先 boss_art，死亡清掉旧演出，远征死亡不叠普通怪碎片。回归与旧素材审计结果见 TEST-REPORT.md；可视测试按真实 Boss 图节点进入，避免镜中挑战面板遮挡。 |
| 2026-10-08 | （本轮未提交） | **肉鸽实测三 bug（用户图文报告）**：①**遗落宝藏/游商房"第二个假宝箱"**——`rogue_field.gd` 原在 `room in ["shop","treasure"]` 时把房间标识宝箱/营火贴图（`art.item_icons[11/15]`）画在世界中心 `Vector2(720,lane_center)`，与真 `reward_chest`（能按 E、有交互圈）并排，被误认成第二个无法交互的宝箱。**用户拍板：把该标识移到顶栏标题左侧**。改：删掉 `rogue_field.gd` 世界中心那段（talent 神龛保留）；`main.gd` HUD 新增 `hud.room_marker`（`rogue_icon`，标题 x=550 左侧 518,19，26×26），在 `_update_hud` 肉鸽分支按 `room` 显隐并切 treasure=11/shop=15 图标。②**行囊右键"回收此物品"点不动**——非 bug，是设计：`rogue_sell` 只在 `phase=="rogue_shop"` 生效（`rogue_inventory.gd:302` 按钮门 + `roguelike.gd:1345` 服务端门）。**用户拍板：保留游商限制，但把禁用态做明显**。改：`rogue_inventory.gd` 非游商时把按钮文字改成"回收 · 需到游商处"（原来只有 tooltip + 轻微变灰，看不出是被条件挡住）。③**冥潮仪镰右键圆斩特效与判定框不符**——判定是以角色为心、半径=reach(170) 的整圆，但 `stylized_vfx.gd:406-412` 把圆重定心到握把、缩成刀刃长。**用户拍板：本轮只登记、暂不改**（近战特效原点=角色、与判定普遍不重合是系统性问题）。新增 §11.54 已知缺口 + §4.K 刀光行加 ⚠️ 说明。测试：`rogue_inventory` 34/0、`rogue_room_chests` 75/0、`inventory_panels` 28/0；三脚本 `--check-only` 均 exit 0。 |

| 2026-10-09 | （本轮未提交） | 魔境战斗密度与数值重平衡：节点图统一安排战斗/圣坛/补给/后段特殊分支，移除会话二次覆盖。200 种子×5 层平均战斗 4.102→6.304、最少 3→6；普通怪数量/后期血量、血瓶清场补充、精英/首领奖励和合作人数统计同步调整。新增 `tests/rogue_map_balance.gd` 全路线与实际刷怪验收；专题和测试记录同步更新。 |

| 2026-10-10 | 见同批提交 | 室外/洞窟/灰棘旧堡续作：16个Blender模块、111处共享补充摆放、不规则洞窟统一轮廓与碰撞；新增第一幕第九区旧堡，保留旧地图ID与73个任务，接入战斗/宝箱/传送/存档；实际光照烘焙与4K场景验证，长时间跑分暂缓。导航与生产契约见OUTDOOR-CASTLE.md。 |

| 2026-10-10 | 见同批提交 | 建筑室内铺地修正：独立floor_palette与室内Shader，新增三套2K PBR，城堡/墓室/书库/礼拜堂与野外泥路分离；城堡台阶/台基同步材质并重烘焙，六幕材质选择与5个实机机位覆盖，见INTERIOR-FLOORS.md。 |

### 12.7 最近一次全量审计（2026-10-07）

- **范围**：全文 `文件:行号` 锚点，`tools/verify_anchors.py` 解析出 **675** 个（含区间与裸行号锚点），逐条对代码实测。
- **结果**：**全部通过**——OK 455 / DRIFT 0 / WRONG 0；另有 220 条 HINT（锚点只写了行号、附近才出现符号名，或按设计就容忍 ≤3 行漂移，脚本无法硬校验，建议后续逐步补符号名）。
- **本轮改动**：①肉鸽岔路修复（`rogue_map.gd`）与营地行囊面板三修（`main.gd`/`camp_pack.gd`）重锚 `main.gd` 共 53 处；②引魂灵体索敌（`rogue_build.gd` 前部插入常量与五个函数）把该文件的路牌锚点全部重锚（`stat` 81→117、`hit_multiplier` 259→435、`hit_event` 341→517、`action_event` 544→735、`legal_talents` 746→933、`management` 798→985、`award` 847→1034、`add_experience` 973→1178、`hero_effect` 1008→1126、`visual_state` 55→80、`core_visual` 164→183、武器分支表 :320-327→:496-659、match 表 :423-445→:609）；③新增 §4.E 路线图、§4.F 派生链预览与灵体索敌、§4.R 开发工具与判定框总览、§5 四行、§6 灵体数值、§9 开发者启动、§11.43–48 等条目。**本轮 `main.gd` 又插了 9 行（开发者覆盖层挂载点），全部 `main.gd` 锚点再重锚一次**：`verify_anchors.py --fix` 机械修正 21 处，另有 28 处是「只写短路径」的锚点（工具的 `--fix` 因路径归一化匹配不上），用 `build/probe/fix_bare_anchors.py` 按工具自己的 `--json` 报告逐行改写。上一轮（2026-10-05，基准 `abcbaaf`）的审计记录见 §12.6 对应行。
- **结论**：每次 pull 到含代码变更的提交后，先跑一次 `python tools/verify_anchors.py --guide PROJECT-GUIDE.md --root . --summary`；有 DRIFT / WRONG 就按报告改完再交接。批量修行号可用 `--fix`（只在符号唯一命中时改，并写 `.bak`）。⚠️ **合并主线后 `--fix` 修不干净是常态**——全文重复出现的锚点会被它的去重门跳过、DRIFT 卡住不再下降，此时改按 `--json` 报告做全局替换（见 §11.50）；`--fix` 写出的 `.bak` 是临时产物，已被 `.gitignore` 忽略，勿提交（§11.51）。

### 2026-10-06 本地恢复与同步

肉鸽地图已接入 50 张 ComfyUI 精确三倍图，ground-manifest.json 保存专用房间背景和实测碰撞轮廓；tools/install_rogue_final_maps.py 优先选择三倍图，tools/audit_rogue_final_maps.py 与 tests/roguelike_smooth_maps.gd 验证选图及尺寸。scripts/main.gd 增加面板关闭与重新打开操作，tests/rogue_panel_close.gd 验证关闭行为。相关代码变动后的行号需重新校验。

### 2026-10-06 武器与连段特效

具体武器配色与几何在 weapon_vfx.gd 中统一定义；Catalog.visual_weapon_index 仍负责图标与旧原画兼容，不能用于合并闯关特效身份。派生事件必须携带 combo_route；hero_combo 仅在权威 hero_effect 确认时广播。当前预览为 build/weapon-vfx-48.png、build/weapon-vfx-combos.png 与 build/weapon-image-upgrades.png；图片素材与强化版本试玩为 build/CrimsonTide-WeaponImageVFX.exe，详情见 WEAPON-IMAGE-VFX.md。

### 2026-10-07 本地修改与上游同步补充

- 武器视觉入口：`scripts/weapon_vfx.gd` 管理武器攻击与强化反馈，`scripts/weapon_image_art.gd` 读取透明原画，方形原画清单随导出配置保留。
- Boss 攻击设计与分段特效：`scripts/boss_attack_design.gd`、`scripts/boss_effect_sequence.gd`；设计说明见 `BOSS-ATTACK-DESIGN.md`。
- 肉鸽房间面板保留关闭、重新打开与奖励覆盖后的关闭状态，同时采用上游增量 HUD 和商店回收逻辑。
- 合并验证：Godot 无头导入无解析错误；面板关闭 45、房间宝箱 75、Boss 攻击意图 1592 项检查，均为 0 失败。

### 2026-10-07 武器实际机制与亮度修正

主表现改为 weapon_mechanics.gd 依据实际 family/pattern/spell 和 attack_kind 选图；32 张原始透明方图与完整提示词在 assets/combat/imagegen-mechanics。圆斩中心和高度、光束宽度/端点、爆发落点/半径来自实际事件。预览 build/weapon-mechanics-comparison.png 与 build/weapon-mechanics-motion.gif，试玩 build/CrimsonTide-WeaponMechanics.exe；详见 WEAPON-MECHANICS-VFX.md。

用户澄清要求使用 ImageGen 重做原图：新生成14张 _v2 素材，由 weapon_image_art.gd 的 REDRAWN 映射接入，46张原始RGBA及提示词留档。移除主体扩边shader和细长贴图横截面拉厚，按自然比例显示。原图对照 build/weapon-imagegen-redraw.png，试玩 build/CrimsonTide-WeaponImageRedraw.exe；GPU 直接比较旧/新原图，验证主体亮像素增加至少50%，同时检查圆斩空心/中心/高度和光束挂点。

Boss 顺序入口：`scripts/expedition.gd` 的 `roll_dawn_kind()`；`scripts/rogue_combat.gd` 的 `BOSS_ORDER`、`boss_pool()` 和 `setup_boss()`。条件终局分派位于 `scripts/session.gd` 的 `defeated_boss` 分支：无名赤月存活时不得触发隐藏战。Boss 特效事件必须携带实际 `art_key`，死亡事件不能依赖已从快照移除的敌人。

### 2026-10-08 闯关构筑效果审计

完整清单见 `output/ROGUE-EFFECTS-AUDIT-2026-10-08.md`：252条构筑内容及永久成长/层变数/诅咒/事件/32派生，区分静态接入、动态复现与规则歧义，记录32组待处理问题；本次未修改运行玩法、未重新导出。

武器升级实伤验证入口：`tests/rogue_weapon_upgrade_audit.gd:23 run()`，48把武器的品质、锻造、稳锋、补正及实例绑定共718项检查通过；原始数值在 `output/rogue-weapon-upgrade-audit.json`。定向观察入口：`output/rogue_effect_audit_probe.gd:34 run()`，21场景复现当前异常/歧义，结果在 `output/rogue-effect-audit-observations.json`，不表示问题已经修复。目录重建：`python tools/build_rogue_effect_audit.py`。重点：领取天赋未激活的反馈、变数正倍率截断/负生命重复应用、房间灰烬遗漏永久入库、不同盾来源共用general、联机个人成长数据通道。

### 2026-10-08 构筑效果修复与天赋滚动位置

修复状态见 `output/ROGUE-EFFECTS-FIXES-2026-10-08.md`；前面的审计清单是修复前快照。天赋界面 `scripts/rogue_build_ui.gd:19 remember_scroll()` 与 `scripts/rogue_build_ui.gd:23 restore_scroll()` 保留各页位置，先设置内容范围防止重建当帧闪回顶部，再在布局结束恢复；列表保持收藏顺序。按钮与布局回归在 `tests/rogue_build_scroll.gd:16 run()`（10项）。

个人成长在 `scripts/main.gd:1298 config()` 发送，`scripts/session.gd:535 rogue_growth_mods()` 从玩家开局快照读取；公共敌人预算取队伍成长平均，个人经验、魔晶、治疗、商店及掉落各读自己的树。`scripts/session.gd:118 build_notice()` 为远程玩家发可靠个人反馈。`scripts/rogue_growth.gd:244 grant()` 将房间灰烬和基础结算一起入库，客户端在 `main.gd` 的 `on_finished()` 原report_paid守卫中支付个人可靠结果。

专项 `tests/rogue_effect_fixes.gd:17 run()`（65项）、`tests/rogue_weapon_upgrade_audit.gd:23 run()`（718项）均通过；新增真实ENet个人成长测试 `tests/rogue_growth_network_fixes.gd:17 run()`（房主9/客户端7），原构筑2人/4人联机均通过。累计27415项通过；另有修复前源码副本复现的Boss1001/6、小怪103/1既有失败，详见修复报告，不能把本轮描述为全仓库全绿。此轮未重新导出EXE。

### 2026-10-09 手柄输入与战斗震动

输入与本地震动统一在 `scripts/controller.gd` 的 `setup()` / `handle()` / `tick()` / `combat()`；主界面 `setup_inputs()`、`_input()`、`_process()`、`on_combat_audio()` 接入。营地实际页面名为 `ground`，按键桥接保留营地原有互动、钓鱼、行囊和地图逻辑。两种战斗共用扳机蓄力、摇杆瞄准及动作映射；面板用虚拟鼠标支持拖拽、右键、滚动和旋转。

震动只作用于最后操作的本地手柄：普通出招、实际命中、重击、蓄力、受伤、闪避、大招和装填分别反馈；双马达包络按较强值混合，暂停、失焦和断开时停震。`scripts/profile.gd` 保存 `controller_rumble` / `controller_rumble_strength`；`main.gd` 的 `show_settings()` 提供开关、强度和试震。操作表与验收范围见 `CONTROLLER.md`；自动化入口 `tests/controller.gd` 的 `run()`，实物震感需接手柄验证。

### 2026-10-09 手柄 UI 修复与按键提示

新增 `scripts/controller_ui.gd` 的 `scope()` / `ensure_focus()` / `navigate()` / `activate()` / `back()` / `tick()`：标题、设置、角色/出征页、房间、行囊、奖励、事件与营地子面板采用可见控件焦点；十字键/左摇杆选择，A 确认，B 返回，滑杆左右调节。默认选中标题「开始游戏」，右摇杆仍可切换虚拟光标。虚拟鼠标延后通过 viewport 局部坐标注入，修复事件重入和窗口缩放下的点击失效；`main.gd` 的 `mouse_point()` 读取手柄光标坐标。

上下文提示在独立 CanvasLayer 展示（键鼠操作时隐藏），Xbox/PlayStation 按设备名称选择按钮字样；`prompt_text()` / `convert_prompts()` 更新 HUD 与营地互动文字并可恢复原键鼠文字。两战场的 `input_hint` 回调更新绘制式提示。`rogue_reward_ui.gd` 设置卡牌→领取按钮的焦点路径；`item_tile.gd` 和 `rogue_inventory.gd` 标记可导航物品。专项 `tests/controller_ui.gd` 验证真实标题按钮与实际三选一领取链路，窗口预览由 `tests/controller_ui_visual.gd` 生成。

### 2026-10-09 手柄战斗键位调整

用户指定 RB 轻击、RT 重击、B 点按闪避/长按奔跑、A 跳跃。`controller.gd` 的 `handle_combat()` / `advance_gestures()` / `sprinting()` 处理独立轻重击输入与 B 的 0.25 秒阈值；`setup()` 只移除旧手柄绑定，保留键鼠。互动移到 Y，菜单继续 A 确认/B 返回。`main.gd` 的本地 `sprint` 合并手柄长按状态。

`session.gd` 的 `perform()` 把 `attack_press` 的 `heavy` 意图交给 `weapon_hold_attack.gd` 的 `begin()`；重击点按按 `HEAVY_MIN_RATIO`（0.35）下限走现有重击机制，长按继续增强，键鼠普通点按不变。判定与资源消耗均由权威执行，客户端没有自行改伤害/蓄力时间。`controller_ui.gd` 同步战斗按键提示与互动/跳跃字样。新增 `tests/controller_layout.gd` 的 `run()`：两种模式真实轻重击、B 点按/长按互斥、奔跑移动、面板取消、已有魔境跳跃、失焦取消及键鼠绑定。

### 2026-10-10 第二至第六幕美术扩展

独立acts-2-6-master.blend与84个新GLB、17套新PBR、15份地形、45个可编辑/烘焙区域；五种区域轮廓与十种额外副本题材。story_act_art管理共享渲染/移动数据，story_regional_environment管理新建筑/灯光，world跨幕释放缓存。原地图ID、73任务不变。专题ACTS-2-6-ART.md与tests/story_later_acts.gd同步；长时间性能验收暂缓。

任务GUI补充（2026-10-11，同批提交）：四类任务卡、地点/联系人/逐项目标/报酬、营地接取与HUD持久追踪；加入接取/推进/完成的徽章、光扫、粒子、脚底短光环与音效，检查实际E流程和事件幂等。
