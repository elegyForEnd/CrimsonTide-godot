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
- **引擎**：Godot 4.7.2（GL Compatibility 渲染），GDScript 单语言，共约 2.95 万行 `scripts/*.gd`（102 个脚本）。
- **三种玩法**：
  1. **三日远征（搜打撤）**——主模式：边境大地图搜刮、缩圈、黎明 Boss、王城、血潮女王、隐藏结局；
  2. **魔境闯关（肉鸽）**——五层七区横版闯关、252 项构筑（48 武器/72 装备/96 天赋/24 铭刻/12 核心）；
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
   ├─ scripts\                 ← 全部游戏逻辑（102 个 .gd，UI/逻辑均由代码构建）
   ├─ resources\               ← 16 个 .gdshader + rogue_build_content.json + scene_music_plan.json + audio_bus.tres
   ├─ shaders\                 ← hero_hair_motion.gdshader（仅离线烘帧用）
   ├─ assets\                  ← 全部美术/音频/模型资源（见 §8.4）
   ├─ tests\                   ← 191 个 GDScript 回归测试 + 6 个 Python 测试
   ├─ tools\                   ← 120+ 素材/音频/索引/门禁脚本（Python 为主）
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
             → UltimateCinematic(大招CG) → camp_screen(营地, main.gd:701 ensure_camp())
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

`session.gd:208 select_mode()` 分派 `campaign`（搜打撤）与 `rogue`（魔境）。两模式共用：
- 同一个 `TideSession`（session.gd:78-82 同时持有 roguelike/expedition/mini_bosses/wild_bosses/dragon_boss 实例）；
- 库存类动作在 `session.gd:1595 perform()` 里分派：魔境把库存动作移交 `roguelike`，远征走本文件存储区；
- 魔境七子系统（abcbaaf 新增）在 `roguelike.gd:4-17` 预载：Variants / NodeGraph / Curses / Events / Rooms / Growth / Daily；
- 背包 UI：main.gd:2477 `show_inventory()` 分支转交 `rogue_inventory.gd`（魔境）或 `extraction_inventory.gd`（远征）。

---

## 4. 功能域指引

### A. 应用骨架与全站 UI

| 功能 | 文件:锚点 |
|---|---|
| 开场忠告/PV/跳过 | `scripts/boot.gd`（忠告 boot.gd:24，按键跳过 `_unhandled_input` boot.gd:49）；文案与视频流在 `scenes/boot.tscn` |
| 窗口缩放/1440×900 适配 | `scripts/main.gd:476 fit_ui()` |
| 全局键位表（WASD/Tab/M/E/F/Q/R/Y/N/U…） | `scripts/main.gd:482 setup_inputs()`；游戏内按键语义分发在 `main.gd:1384 _unhandled_input()` 与 `main.gd:1264 _input()` |
| 标题页菜单 | `main.gd:878 show_title()`（菜单数组 main.gd:897-898 `entries/actions`） |
| 登录/注册/游客、云存档页 | `main.gd:286 show_account()`、`main.gd:337 show_storage()`；存档切换 `main.gd:326 switch_profile()` |
| P2P 房间页 / 服务器房间页 / IP 直连页 | `main.gd:421 show_p2p_rooms()` / `main.gd:406 show_server_rooms()` / `main.gd:922 show_network()` |
| 设置（音量三条滑杆/全屏） | `main.gd:3303 show_settings()`，音量总线 main.gd:3294-3306 |
| 暂停菜单/离开对局 | `main.gd:3282 pause_menu()` |
| 帮助手册/制作组 | `main.gd:3308` / `main.gd:3324` |
| HUD 构建/刷新（血蓝条、技能冷却、小队、黎明抉择按钮、交互提示） | 布局 `main.gd:1110 on_started()`；每帧刷新 `main.gd:1579 update_hud()`；救援/城门/撤离/封印/宝箱提示 main.gd:1664-1696 |
| 底部道具栏（1/2/3 槽） | 绘制 `main.gd:1706 draw_hud_item_bar()`；使用规则 `main.gd:1756 apply_item_slot()` + `Catalog.slot_operable` |
| 背包界面总入口（Tab） | `main.gd:2477 show_inventory()` → 魔境转 `rogue_inventory.gd:52 draw()`、远征转 `extraction_inventory.gd:42 draw()` |
| 魔境扩展的表现入口（abcbaaf 新增） | 房间面板 `main.gd:3556 rogue_room_panel()`、事件三选一 `main.gd:3521 rogue_event_panel()`、每日种子页 `main.gd:3593 show_rogue_seed_page()`、成长树 `main.gd:3664 show_growth_tree()` |
| 拖拽子系统（拿起/落点预览/金框红框/R 旋转） | `main.gd:1994 start_drag()`、`main.gd:2009 release_drag()`、预演 `main.gd:2274 drag_target_rect()`（合法性真正判定在 `session.gd:1865 resolve_drop`）、旋转 `main.gd:1544 rotate_selected()` |
| 双击装备/Ctrl 智能点击/一键收纳 | `main.gd:1869 double_click_equip()` / `main.gd:1890,1909 ctrl_click_item()/ctrl_click_worn()` / `main.gd:2950 auto_store_loot()` |
| F 键兜底链（倒地自救→拾取→搜索→急救针） | `main.gd:1437-1464`；搜索窗 `main.gd:1519 open_search()` |
| 伤害红屏/提示 toast/结算页 | `main.gd:3171 flash_damage_feedback()` / `main.gd:3234 notify()` / `main.gd:3079 on_finished()`（奖励入库+隐藏角色招募 main.gd:3083-3109） |
| 哥特按钮/格子控件（图标随 R 旋转） | `scripts/gothic_button.gd`（slot 绘制 gothic_button.gd:68-98，旋转 80-87） |
| 物品图标解析（图集裁切） | `scripts/ui_art.gd:14 icon()`；16 基础图标表 `KINDS` ui_art.gd:5 |
| 装饰控件（分割线/封印法阵/标题粒子） | `scripts/ui_ornament.gd:19 _draw()` |

### B. 存档与物品数据

| 功能 | 文件:锚点 |
|---|---|
| **存档唯一写入点**（原子写 %APPDATA%/…/profile.json） | `scripts/profile.gd:177 save_profile()`；读档清洗 `profile.gd:45 apply_data()` |
| 次元口袋/背包柜/仓库的存档形状 | `profile.gd:110 sanitize_storage()`、`profile.gd:221 sanitize_warehouse()`、进局负载 `profile.gd:173 storage_payload()` |
| 肉鸽成长 / 每日记录的存档清洗 | `profile.gd:133 sanitize_growth()`、`profile.gd:150 sanitize_daily()`（常量 `Daily` profile.gd:17、`MAX_DAILY_RECORDS` profile.gd:21） |
| 等级/经验/天赋升级/仓库入库/出售 | `profile.gd:208 level()`、`profile.gd:211 upgrade()`、`profile.gd:241 bank_carried_items()`、`profile.gd:267 sell_items()` |
| 隐藏角色「墓煜」解锁（护身符结局） | `profile.gd:77-106`（`RECRUIT_HEROES={"muyu":3}` profile.gd:32） |
| **物品/武器/装备总数据表** | `scripts/catalog.gd`：物品 `ITEMS` catalog.gd:17；17 把野战武器 `WEAPONS` catalog.gd:138；4 把角色临时武器 `STARTER_WEAPONS` catalog.gd:168（⚠️ `STARTER_BASE=17` catalog.gd:167 必须等于 WEAPONS.size()，tests/systems.gd 断言）；装备 `GEAR` catalog.gd:174；六档品质加成数组 catalog.gd:182-188；54 件藏品分组表 catalog.gd:86-112 |
| 背包品质（白3×3→红8×8）/容器排版/堆叠/装箱算法 | `catalog.gd:201 BAG_TIERS`、装箱核心 `catalog.gd:492-528`（overlaps/can_place/insert）、自动收纳管线 `catalog.gd:772-1023`（place_arrival/eviction_order） |
| 新增武器/装备/物品的操作顺序 | 见 §5 速查表「新增内容」行 |

### C. 权威模拟核心（session.gd，3822 行）

| 功能 | 文件:锚点 |
|---|---|
| 联机生命周期（ENet 24872、专用服务器票券） | `scripts/session.gd`：端口 session.gd:31；host/join session.gd:128/142；专用服 session.gd:179/191；票券校验 session.gd:239 validate_ticket() |
| 动作总线（所有交互的唯一入口） | `session.gd:1595 perform()`——heal/dash/skill/bag_*/equip/use/search/pickup/raid_choice 全在这；rogue_* 由 session.gd:1599 直通 `roguelike.choose()` |
| 玩家数值（伤害公式/防御/抗性/掉落率/属性补正） | `session.gd:465 weapon_scaling()`、`session.gd:508 weapon_damage()`、`session.gd:441 stat_defense()`、`session.gd:455 stat_resistance()`、`session.gd:461 enemy_drop_chance()`；肉鸽补正 `rogue_equipment_stat()` session.gd:438、`rogue_damage_pool()` session.gd:469、`rogue_mods()` session.gd:477 |
| 移动/奔跑/闪避 | `session.gd:2843 move_player()`（调用点在 session.gd:2684）、常量 session.gd:34-36（闪避时长/距离/奔跑倍率） |
| 攻击三连击/武器技/弹丸生成 | `session.gd:2890 attack()`、`session.gd:2936 release_weapon_art()`、`session.gd:2998 release_strike()`（法术 spell 分支 3023-3039；pierce 在 release_weapon_art 内 session.gd:2970） |
| 伤害结算中枢（韧性/格挡/硬直/击退/hitstop） | `session.gd:3041 damage_enemy()` |
| 弹丸飞行/链电/陨石落点 | `session.gd:3480 update_bullets()` |
| 大招（雪璃治疗/死灵法师魂收+冥火地带全套常量） | `session.gd:2436 release_ultimate()`、死灵常量块 session.gd:2481-2498（NECROMANCER/FIRE_*/BURN_*/SOUL_REAP_*） |
| 理智/血晶气味/威胁度/环境刷怪 | 理智+血晶气味 `session.gd:2685-2698`；威胁度公式 `session.gd:2624`；环境刷怪 `session.gd:2629-2632` |
| **血潮缩圈**（数值） | `session.gd:2788 safe_center()`、`session.gd:2791 safe_radius()`；开始时间 `session.gd:51 SHRINK_START=180s` |
| 搜索容器（F 逐件浮出） | `session.gd:869-917`（`begin_search()` / `advance_search()` / `search_seconds()`） |
| 死亡散包/撤离带入/口袋保护 | `session.gd:779 spill_storage()`、结算 `session.gd:3591 settle()` |
| 据点守军锁定/清剿宝箱 | `session.gd:3324 resolve_site_defeat()` |
| 王城进出（全队集合/双地图状态机/骑士奖励） | `session.gd:3675 travel_city()`、奖励 `session.gd:3713 knight_reward()` |
| 失乡骑士 AI 与出招 | `session.gd:3727 update_knight()`、`session.gd:3810 start_knight_attack()` |
| 隐藏结局触发（三钟+护身符+女王死） | 判定/触发 `session.gd:2772-2774`；`session.gd:2819 bells_lit()`、`session.gd:2822 seal_bell()`、`session.gd:2827 carries_amulet()`、`session.gd:2836 hidden_ending_ready()`（常量 `BELL_SEALS` session.gd:2814） |
| 快照序列化（联机同步什么） | `session.gd:1546 snapshot` RPC（组包在 session.gd:1530）；闯关特效直传 session.gd:1527-1529（visual_effects/visual_missiles） |
| 存档触发点 | session 只发 `finished` 信号；**真正落盘在 `main.gd:3079 on_finished()` → `main.gd:3109 save_profile()`**（肉鸽结算补存 main.gd:3114） |

### D. 三日远征（搜打撤主模式）

| 功能 | 文件:锚点 |
|---|---|
| 三天状态机/黎明 Boss 生成/跨天恢复/遗赠 | `scripts/expedition.gd`：常量 expedition.gd:6-53（Boss 名/血 1650/3100/5500、REWARDS、隐藏 Boss 9200）；`prepare_day` expedition.gd:60；`victory` expedition.gd:196；黎明抉择 `choose` expedition.gd:290 |
| 三大主线 Boss + 无名赤月 + 隐藏 Boss「冥火尸王·墓玥」招式 | `expedition.gd:424 cast_boss()`（23 招，match 分支 439-536）、`expedition.gd:566 cast_hidden()`；危险区判定 `expedition.gd:314 update_hazards()`、`expedition.gd:357 hazard_contains()` |
| 地图守护者抽取（弱/强池→三种 Boss 模块） | `expedition.gd:114 spawn_map_guardians()` |
| 缩圈视觉（血雾 Shader） | `scripts/blood_tide.gd`（挂接 battlefield.gd:52，setup 调用 battlefield.gd:61）+ `resources/blood_tide.gdshader` |
| 边境大地图（9600×7200、六地貌、18 据点、3 封印、4 撤离点、6 野外箱、河流三桥） | `scripts/ruins.gd`：常量 ruins.gd:4-15；`generate` ruins.gd:38（海岸 55/撤离点 56/地貌 58/桥 72/据点 75-81/道路 100/箱 165-179，落表 ruins.gd:179）；碰撞 `blocked` ruins.gd:239、`move` ruins.gd:260 |
| 王城室内图 | `scripts/royal_city.gd`（extends Ruins；GATE/BOSS royal_city.gd:4-5，墙 royal_city.gd:23） |
| 战术地图 M / 小地图 | 绘制在 `battlefield.gd:477 draw_map()`（路点/过滤器 `_input` battlefield.gd:576，路点 580-583、过滤器 586）；世界底图 `world_art.gd:103 atlas()` |

### E. 魔境闯关（肉鸽模式）

| 功能 | 文件:锚点 |
|---|---|
| 五层七区闯关主控（路线/刷怪波/圣坛/宝箱/商店/出口/结算） | `scripts/roguelike.gd`：开局 `reset` roguelike.gd:91；房间生成 `enter` roguelike.gd:249；刷怪 `spawn_wave` roguelike.gd:325；清场奖励 `clear_room` roguelike.gd:470；三选一奖励池 `reward_offers` roguelike.gd:516；装备/换装 `equip` roguelike.gd:712；出口选择 `exit_choices` roguelike.gd:844 |
| 横版地图（地面碰撞/岩浆/出口 UV） | `scripts/rogue_map.gd`（extends Ruins；地面清单来自 `assets/rogue/regions/ground-manifest.json`，区域键规则 `region_key` rogue_map.gd:56） |
| 守层者（8 身份×7 招＝5 常规+2 二阶段）与小怪导弹/毒圈权威判定 | `scripts/rogue_combat.gd`：招式表 `MOVES` rogue_combat.gd:24-82；`begin_skill` rogue_combat.gd:308；zone 判定 `tick` rogue_combat.gd:451 |
| 40 种小怪×2 技能 AI/支援/受击吸收 | `scripts/rogue_minions.gd`（NAMES/ROLES/LOADOUTS rogue_minions.gd:3-21，release rogue_minions.gd:161） |
| 玩家普攻/战技结算（闯关版） | `scripts/rogue_actions.gd`（`start_art` rogue_actions.gd:13、`normal` rogue_actions.gd:132） |
| 闯关战场渲染（相机/角色/敌人血条/预警弧/出口） | `scripts/rogue_field.gd`（相机死区 rogue_field.gd:16，`_draw` rogue_field.gd:157） |
| 闯关美术装载（HD 图集裁切/图标） | `scripts/rogue_art.gd`（图集清单 rogue_art.gd:81）+ 背景 `rogue_backdrop.gd` |
| 敌方特效层（不产生伤害） | `scripts/rogue_enemy_vfx.gd` + 守层者专属 `scripts/rogue_boss_effects.gd` |
| 跳跃姿态帧 | `scripts/rogue_jump_frames.gd`（数据 `assets/rogue/build/jump-manifest.json`，**已入库**；由 `tools/index_rogue_jump_art.py` 生成） |
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
| 构筑规则引擎（属性合成/伤害倍率/天赋激活/锻造/铭刻/连招/跳跃/血瓶） | `scripts/rogue_build.gd`（1015 行）：连招表 `CM_ROUTES/HC_ROUTES` rogue_build.gd:8-9；综合属性 `stat` rogue_build.gd:81；**伤害倍率 `hit_multiplier` rogue_build.gd:259**；命中触发 `hit_event` rogue_build.gd:341；连招识别 `action_event` rogue_build.gd:544；天赋合法性 `legal_talents` rogue_build.gd:746；管理入口（加点/锻造/铭刻）`management` rogue_build.gd:798；成长发放 `award` rogue_build.gd:847；经验 `add_experience` rogue_build.gd:973 |
| 闯关装备/铭刻定义与品质缩放 | `scripts/rogue_equipment.gd`（`value` 缩放 rogue_equipment.gd:21；被动效果实际在 rogue_build.gd 内联） |
| 构筑管理页（Tab→构筑：天赋/加点/锻造/连招手册/图鉴） | `scripts/rogue_build_ui.gd`（五子页 rogue_build_ui.gd:37-176） |
| 252 项图标 | `scripts/rogue_build_art.gd`（索引 `assets/rogue/build/atlas-manifest.json`，**已入库**；由 `tools/index_rogue_build_art.py` 生成） |
| 闯关行囊界面 | `scripts/rogue_inventory.gd` + 格子控件 `scripts/rogue_inventory_socket.gd` |
| 三选一奖励弹窗 | `scripts/rogue_reward_ui.gd`（交互协议对应 roguelike.gd:665 `selection_action`） |

### G. 远征背包/库存界面

| 功能 | 文件:锚点 |
|---|---|
| 搜打撤背包面板（双网格/搜索窗/装备栏/背包柜） | `scripts/extraction_inventory.gd`（presentation only，经 host=main.gd 调工厂；`draw` extraction_inventory.gd:42） |
| 品质描边格子控件 | `scripts/extraction_inventory_socket.gd`（图集 `assets/ui/extraction-slot-atlas-v1.png` 等） |
| 拖放落点合法性/换包/旋转的权威判定 | `session.gd:1865 resolve_drop()`、`session.gd:1777 bag_key_of()`、`session.gd:1786 move_between()`、装备 `session.gd:2169 equip_item()` |
| 道具栏三插槽 | `session.gd:335-366`（`empty_item_slots` :335 / `item_slots` :343 / `item_slot` :352 / `set_item_slot` :358） |

### H. Boss 系统

**调用链**：`session.gd:3-6` 引入 Choreography/Tactics/Presentation/enemy_bodies → 敌人分发 `session.gd:3370-3395`（raid_boss→expedition/wild_bosses；mini_boss→dragon/wild/mini；type≥5→Ecology；type4→session 自己的骑士 AI）。

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
| **武器挂点/地面投影契约**（一切特效的锚） | `battlefield.gd:695 weapon_effect_socket()`、`battlefield.gd:692 ground_transform()`——新特效必须遵守，否则 tests/weapon_stroke_stability.gd 失败 |
| 3D 场景层（正交相机/地砖/墙/桥/湖/宝箱开盖/billboard 池） | `scripts/world_3d.gd`（rebuild world_3d.gd:165；精灵俯视压缩补偿 world_3d.gd:254） |
| 2D 地形底图与战术地图绘制 | `scripts/world_art.gd`（atlas world_art.gd:103；王城夜景 `city_terrain` world_art.gd:132） |
| CC0 模型库运行时（KayKit/Quaternius，shader 着色/包围盒） | `scripts/scene_assets.gd`（registry scene_assets.gd:5；宝箱开盖 chest_state scene_assets.gd:88） |
| 建筑占地表（**碰撞与显示共用同一矩形**） | `scripts/scene_asset_layout.gd:5 building()`（被 ruins.gd:16 与 world_3d.gd:6 共同消费） |

### K. 战斗特效（ImageGen 管线）

| 功能 | 文件:锚点 |
|---|---|
| 特效编排总控（事件→贴图特效/伤害数字/死灵法印/剑雨/敌方弹幕） | `scripts/combat_visuals.gd`（事件入口 `event` combat_visuals.gd:147；剑雨布局 `blade_layout()` combat_visuals.gd:501；与服务端判定共形 `patch_local_rect` combat_visuals.gd:469；敌方弹幕可读性常量 combat_visuals.gd:300-318、绘制 `draw_enemy_bolt()` combat_visuals.gd:361） |
| 刀光/突刺/蓄力/大招贴图（固定轨迹：一次捕获挂点） | `scripts/stylized_vfx.gd`（emit 捕获 stylized_vfx.gd:56；仅蓄力跟随 stylized_vfx.gd:164） |
| CPU 粒子（1400 上限/21 武器材质物理/双通道渲染） | `scripts/combat_particles.gd`（WEAPON_STYLES combat_particles.gd:7；材质参数 spawn combat_particles.gd:42） |
| 粒子批量渲染（MultiMesh 光晕 + 三角数组几何） | `scripts/particle_glow_batch.gd` + `scripts/particle_geometry_batch.gd` |
| **34 张 ImageGen 特效索引**（21 武器/法术/角色专属 PNG） | `scripts/vfx_library.gd`（texture vfx_library.gd:53；朝向修正 LEFT_FACING_WEAPONS vfx_library.gd:37；配色 WEAPON_COLORS vfx_library.gd:6） |
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

**链路**：`main.gd:698 ensure_camp()` 创建 `camp_screen.gd`（唯一实例化点，信号驱动）→ 其内部组装 `camp_site.gd`（3D 地图）+ `home_screen.gd` + `home_map.gd` + `camp_activities.gd` + `fishing_meter.gd`。营地站点点击 → `main.gd:748 on_camp_station()` 分发（warehouse/market→经济页、forge→锻炉、launch→出发、rogue→魔境报名…）。

| 功能 | 文件:锚点 |
|---|---|
| 营地界面外壳（HUD/设施列表/输入/名册/出发） | `scripts/camp_screen.gd`（设施分组 camp_screen.gd:343；按键 `_unhandled_input` camp_screen.gd:609；右键蓄力直达站点 camp_screen.gd:545） |
| 营地 3D 地图（可行走碰撞/遮挡淡化/站点定义/雷暴程序生成与运行时合成音效） | `scripts/camp_site.gd`（可行走边界 `is_walkable` camp_site.gd:169-178（边界矩形 :170）；**十设施站点表 `_build_stations` camp_site.gd:936-960**；作物显示 refresh_crops camp_site.gd:544；闪电 strike camp_site.gd:1350） |
| 世界内农事/垂钓动作状态机（动画播完才结算） | `scripts/camp_activities.gd`（`farm` camp_activities.gd:138；垂钓四阶段 `update_fishing` camp_activities.gd:327） |
| 钓鱼时机条 UI | `scripts/fishing_meter.gd:9 _draw()`；装配与容差（fine 档）在 camp_screen.gd:135-140 / 513-517 |
| **家园规则层**（作物/鱼/料理价格表、离线生长、战斗加成） | `scripts/homestead.gd`（CROPS/FISH/MEALS homestead.gd:3-17；离线生长 `remaining` homestead.gd:86；**被 session.gd:295 引用**，加成 `meal_id/bonus` homestead.gd:176-181 经 session.gd:306-307 进入玩家、落库 session.gd:317；开局扣餐食 `consume_started` homestead.gd:146，调用点 main.gd:1119-1120） |
| 家园商店/厨房面板 | `scripts/home_screen.gd`（build_shop home_screen.gd:75；build_kitchen home_screen.gd:106） |
| 家园导览地图（从真实几何绘制/点击传送） | `scripts/home_map.gd`（`class MapCanvas` home_map.gd:119，`_draw()` home_map.gd:125） |
| 营地建筑层（CC0 圣堂模块/可进出书屋/城墙） | `scripts/home_architecture.gd`（model home_architecture.gd:12；house home_architecture.gd:52） |
| 家园图标/皮肤图集/动作帧 | `scripts/home_art.gd:1-18` + `scripts/home_ui_skin.gd`（108 行）+ `scripts/home_activity_frames.gd:1-24`（数据 `assets/home/animations/manifest.json`；动作帧实例化点 camp_site.gd:91） |

### O. 经济与角色属性

| 功能 | 文件:锚点 |
|---|---|
| 仓库/交易行界面（分类/搜索/批量/禁售标记） | `scripts/economy_screen.gd`（数据操作回调 `bank_carried_items()` profile.gd:241 / `withdraw_item()` profile.gd:257 / `sell_items()` profile.gd:267；禁售标记 economy_screen.gd:132；估价 `catalog.gd:394 market_value`） |
| 锻炉 UI（七属性加点/出战预览/天赋升级） | `main.gd:833 show_camp_forge()` |
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
| storm_bolt.gdshader / storm_sky.gdshader | 营地闪电带/雷暴天幕 | camp_site.gd:18 / camp_site.gd:17 |
| stylized_texture.gdshader | 刀光贴图直通着色 | stylized_vfx.gd:33 |
| boss_projectile_shell.gdshader | Boss 弹幕外壳（飞行体可读性/朝向） | scripts/boss_damage_visual.gd:11 |
| shaders/hero_hair_motion.gdshader | 发梢位移（仅离线烘帧工具用，非运行时） | tools/bake_hero_walk_v4.gd、tools/preview_hero_hair.gd |

---

## 5. 「我要改 X」速查表

### 玩法规则类

| 需求 | 主要文件 | 配套（测试/文档/工具） |
|---|---|---|
| 调远征三天时长/跨天恢复/黎明 Boss 数值 | expedition.gd:6-93 + session.gd:50-51（:50 一天时长、:51 缩圈开始） | tests/expedition*.gd；EXPEDITION.md |
| 改主线 Boss/隐藏 Boss 招式 | boss_choreography.gd（编排）+ expedition.gd:424-614（legacy） | tests/boss_choreography.gd；BOSS-REWORK.md |
| 调骑士数值/格挡 | boss_tactics.gd（KNIGHT_MOVES :10）+ session.gd:3727-3810（KNIGHT_MOVES 用在 :3752） | tests/boss_tactics.gd |
| 加新 Boss（身份） | boss_choreography.gd `MOVES` + boss_effect_art.gd（`KEYS` :4 / `MOTIFS` :6 / `color()` 色表 :55-57，按 KEYS 索引）+ assets/bosses/imagegen/ + boss_frames.gd `SPECIAL_KEYS`（**追加表尾**，`COLORS` 在 boss_frames.gd:9）+ boss_presentation.gd cue + boss_hud.gd 颜色/阶段 | tests/boss_*；BOSS-REWORK.md |
| 调缩圈数值/时序 | session.gd:51、2788-2802（safe_center/safe_radius/final_radius） | tests/expedition.gd；视觉另改 blood_tide.gdshader |
| 调理智/气味/威胁度/刷怪 | session.gd:2624-2632、2688-2696、3247-3319 | tests/ecology.gd |
| 改掉落（宝箱/敌人/据点/骑士） | session.gd:1232 chest_loot / 1310 enemy_loot / 3324 resolve_site_defeat / 3713 knight_reward | tests/systems.gd；BALANCE.md |
| 加新野外怪物 | enemy_frames.gd:4-8 四表 + ecology.gd:5-19 六表 + ecology.gd update() 新分支 + assets/enemies/ 4×3 图集（脚底 210px）+ 悬浮怪名单 enemy_body.gd:44 | tests/enemies.gd、ecology.gd；ENEMY-UPDATE.md |
| 加营地设施 | camp_site.gd:936-960 站点表 + 建模函数 + camp_screen.gd:343 分组 + main.gd:748 on_camp_station 分支 | tests/camp*.gd；HOMESTEAD.md |
| 改家园数值（作物/鱼/料理/价格） | homestead.gd:3-17 + buy/fish_key；图标 home_art.gd | tests/homestead.gd |
| 改七属性曲线 | attributes.gd（⚠️ `clean(value, budget := 623)` attributes.gd:16 的预算要与 `point_budget` 同步） | tests/attributes.gd |
| 改结算奖励/XP | session.gd:3591 settle()；入库 main.gd:3079 | tests/systems.gd |
| 改隐藏结局/招募墓煜 | expedition.gd:236-288 + session.gd:2750-2775（隐藏判定 :2774）+ profile.gd:27-32、81-95 + main.gd:3100-3108 | tests/hidden_ending.gd；HIDDEN-ENDING.md |
| 改王城（布局/进出/珍藏） | royal_city.gd + session.gd:3650-3712（receive_results 3650 / portal_position 3666 / travel_city 3675） | tests/city.gd；CITY-UPDATE.md |
| 改边境地图布局 | ruins.gd（⚠️ 改地形后必须重跑 `tools/export_world_layout.gd` + `tools/bake_world_art.py`，见 MAP-UPDATE.md:37-39） | tests/map.gd |
| 改闯关流程（房间/出口/商店/奖励） | roguelike.gd | tests/roguelike*.gd、rogue_build_progression.gd |
| 改闯关地图/换背景图 | rogue_map.gd + assets/rogue/regions/ground-manifest.json | tests/roguelike_geometry.gd |
| 改肉鸽图谱 / 房间类型 / 事件 / 诅咒 | rogue_graph.gd、rogue_rooms.gd + rogue_room_ui.gd、rogue_events.gd、rogue_curses.gd | tools/run_rogue_gate.ps1；**先读契约** output/ROGUE-CONTRACTS.md |
| 改每日种子 / 局外成长 | rogue_daily.gd、rogue_growth.gd | tests/rogue_daily.gd、tests/rogue_growth.gd |
| 改词条变体与相关 UI 文案 | rogue_variants.gd + rogue_ui_model.gd | tests/rogue_variants.gd、tests/rogue_ui.gd |
| 改攻击前摇提示 / 敌方弹幕 | 权威侧 `session.gd:2922-2929`（`build_strike_windup` 与 "windup" 广播）；表现层 `scripts/attack_telegraph.gd` + `resources/boss_projectile_shell.gdshader` | tests/attack_telegraph_visual.gd、tests/roguelike_attack_timing.gd；tools/verify_enemy_bolt_readability.gd；ATTACK-TELEGRAPH.md |
| 交接前跑全量测试 / 肉鸽门禁 | tools/run_all_tests.ps1、tools/run_rogue_gate.ps1 | output/TEST-BASELINE.md |

### 构筑系统类

| 需求 | 主要文件 | 配套 |
|---|---|---|
| 改构筑数值（白值/等级数组文本） | resources/rogue_build_content.json（由 tools/build_rogue_content.py 从设计文档表格编译） | tests/rogue_build_balance.gd、rogue_build_system.gd |
| 新增天赋/铭刻/核心 | JSON 条目 + rogue_build.gd 效果钩子（stat :81 / hit_multiplier :259 / hit_event :341 / action_event :544）+ 图标 atlas-manifest | tools/index_rogue_build_art.py；tests/rogue_build_rules.gd |
| 新增闯关武器 | JSON weapons[] + weapon_arts.gd:30（战技覆盖）+ rogue_actions.gd 分支 + rogue_build.gd 武器分支表 :320-327（`if w==…`）+ match 表 :423-445 | tools/verify_rogue_build.ps1 |
| 改锻造/铭刻购买规则 | rogue_build.gd management :798-845 + rogue_build_ui.gd forge :106 | tests/rogue_build_system.gd |
| 改三选一/游商/圣坛 | roguelike.gd:516-554、665-711（原 :268-481 现在是 enter/spawn_wave/clear_room） | tests/rogue_chest_rewards.gd |

### 物品/背包类

| 需求 | 主要文件 | 配套 |
|---|---|---|
| **新增野战武器**（远征） | ① catalog.gd:138 WEAPONS ② catalog.gd:189 WEAPON_ICONS ③ weapon_arts.gd:6 MOVES ④ 特殊法术在 session.gd release_strike :2998/update_bullets :3480 加分支 ⑤ ⚠️ 若 WEAPONS.size() 变化，同步 `STARTER_BASE`（catalog.gd:167） | tests/systems.gd（STARTER_BASE 断言）、combat.gd |
| 新增装备/背包品质 | catalog.gd:174 GEAR / :201 BAG_TIERS + 品质数组 catalog.gd:182-188 + session.gd:1218 CACHE_QUALITY_WEIGHTS | tests/systems.gd |
| 新增普通物品/藏品 | catalog.gd:17 ITEMS + 藏品分组表 :86-112（⚠️ `NEW_COLLECTIBLES` 只能追加，影响存档序号） | tests/collectibles.gd；COLLECTIBLES.md |
| 改拖拽/旋转/双击装备手感 | main.gd:1994（start_drag）/1544（rotate_selected）/1869（double_click_equip）（合法性判定在 session.gd:1865） | tests/ui.gd |
| 加物品图标 | ui_art.gd `icon()`（⚠️ KINDS 顺序=图集网格位置）+ assets/ui/reliquary-transparent.png 或独立 SVG | tests/ui.gd 截图 |

### 表现/音频类

| 需求 | 主要文件 | 配套 |
|---|---|---|
| 加新武器特效 | assets/combat/imagegen/weapon_%02d_release.png + vfx_library.gd（配色/朝向）+ combat_particles.gd:7 材质 | tests/standalone_vfx.gd、weapon_effect_direction.gd、all_weapon_mounts.gd |
| 改刀光/蓄力表现 | stylized_vfx.gd（⚠️ 固定轨迹契约） | tests/weapon_stroke_stability.gd |
| 加音效 | assets/audio/<kind>-<i>.wav + sound.gd:5-17 VARIANTS/LEVELS | tools/prepare_library_audio.py；tests/audio.gd |
| 加曲目 | assets/audio/music/<cue>.ogg + music-manifest.json + music.gd:41 set_world 选择逻辑 | tests/music.gd、python tests/scene_music_assets.py |
| 改大招 CG/台词 | ultimate_cinematic.gd:5-26 + assets/combat/ultimate-cg.png | tests/ultimate.gd |
| 改语音 | assets/audio/voices/voice-manifest.json + hero_voice.gd | tools/prepare_free_voices.py；tests/voice_assets.py |
| 改角色动画/体型 | assets/combat/attack-clean-%d.png、movement-%d.png + character_metrics.gd:10-53 地标 | tests/character_scale.gd、movement.gd |
| 改 HUD 布局/文案 | main.gd:1127（布局）+ main.gd:1579（update_hud 刷新） | tests/ui.gd |
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
| 改导出包含/排除 | export_presets.cfg include/exclude_filter | — |

---

## 6. 数值常量速查（哪里改什么数）

| 数值 | 位置 |
|---|---|
| 联机端口 24872 / 一天 300s / 缩圈 180s 开始 | session.gd:31 / :50-51 |
| 终圈半径 540(day1-2)/620(day3) | `session.gd:2796 final_radius()` |
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
| 次元口袋 4×4；背包白3×3→红8×8；堆叠上限 6；紫以上背包占 2×2 | catalog.gd:198 / 201-208 / 627 / 470 |
| 构筑：修为上限 18、锻造 8 点、收藏 12、每级+2 点 | rogue_build.gd:765/854、:6、roguelike.gd:642（收藏 12）、每级 +2 在 rogue_build.gd:979 |
| 家园作物/鱼/料理价格与时长 | homestead.gd:3-17 |
| 七属性 BASE 10/CAP 99/初始 5 点/成长曲线 | attributes.gd:8-10、34 |
| 粒子上限 1400/特效 96/碎屑 192/能量 64 | combat_particles.gd:5、stylized_vfx.gd:4-5、energy_bursts.gd |
| 营地移速 420（Shift 700） | camp_screen.gd:528 / :539 |

---

## 7. 测试体系

**运行方式**（逻辑测试加 `--headless`；截图测试去掉它；联机测试加 `--max-fps 60`，房主进程另加 `-- --server`）：

```bash
# GDScript 回归（191 个，自写 check() 计数框架）
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
- **验证台账**：`TEST-REPORT.md`（按日期记录每轮项数与结果）。

## 8. 工具链与素材管线（tools/）

| 类别 | 代表脚本 | 说明 |
|---|---|---|
| 构筑内容编译 | `build_rogue_content.py` | 从 ROGUE-BUILD-SYSTEM-DESIGN.md 表格编译出 `resources/rogue_build_content.json`（252 条），**改构筑表格先改 md 再重跑** |
| 图集索引生成 | `index_rogue_build_art.py`、`index_character_idle.py`、`index_home_animations.py` 等 | 生成对应 manifest JSON（assets/**/*manifest*.json） |
| 音频准备 | `prepare_music.py`、`prepare_library_audio.py`、`prepare_free_voices.py`、`prepare_boss_audio.py`、`prepare_ultimate_audio.py` 等 | Suno/CC0/Spaland 素材母带 → assets/audio/；凭据只走环境变量 |
| 音乐计划 | `generate_scene_music.py` + `resources/scene_music_plan.json` | 每场景一首 Suno 曲目的提示词计划与提交 |
| 素材生成 | `generate_enemy_art.py`、`build_minimax_*`、`collectible_image_prompts.py` | ImageGen/MiniMax 提示词与图集 |
| 地图烘焙 | `export_world_layout.gd`（GD）→ `bake_world_art.py` | **改 ruins.gd 地形后必须重跑**，否则 3D 贴图与碰撞错位 |
| 图标/打包 | `make_icon.gd`、`package_server.py`、`fetch_export_templates.py`、`fetch_scene_assets.py` | exe 图标；服务器离线镜像包；模板/CC0 素材抓取（SHA-256 校验） |
| 守卫 | `check_class_cache.ps1` | `游戏启动.cmd` 调用：git pull 后全局类缓存过期会导致黑屏，自动 headless --import 重建 |
| 全量测试 / 门禁 | `run_all_tests.ps1`、`run_rogue_gate.ps1` | 交接前跑；肉鸽门禁覆盖图谱/事件/诅咒/每日/成长/房间 UI 的回归 |
| 前摇 / 弹幕校验 | `verify_enemy_bolt_readability.gd`、`preview_enemy_bullets.gd`、`measure_bolt_blobs.py`、`measure_bolt_core.py`、`measure_alpha_bbox.py` | 攻击前摇提示与敌方弹幕可读性的可复现验证、预览与量测 |
| 路牌自检 | `verify_anchors.py` | `python tools/verify_anchors.py --guide PROJECT-GUIDE.md --root . --summary` 校验全部锚点（见 §12.3） |
| 文档导出 | `make_report_docx.py` | 把专题 md 导出成 docx（汇报用） |
| DPS 量测 | `weapon_dps.gd` | 木桩实测 60s DPS |

**清单文件（可溯源链）**：`assets/audio/library-manifest.json`（114 条音效 cue）、`assets/audio/voices/voice-manifest.json`（4 名角色 × 11 类语音槽）、`assets/audio/music/music-manifest.json`（32 曲目 SHA-256）、`assets/bosses/motion-atlas.json`、`assets/rogue/regions/ground-manifest.json`——对应 Python 校验测试见 §7。

⚠️ `assets/rogue/build/` 下的 `atlas-manifest.json`、`jump-manifest.json` 是生成物，但**已由 `7bbaf04` 开 `.gitignore` 例外并入库**（缺了它们会让全新 clone 编译失败）；内容更新后仍要用 `tools/index_rogue_build_art.py` / `tools/index_rogue_jump_art.py` 重新生成并提交。

**assets/ 子目录速览**：`animation-generated/`（AI 角色动画帧）、`audio/`（音效+music/+voices/+bosses/）、`bosses/`（图集+imagegen/）、`combat/`（角色精灵/攻击帧/idle/ranged-imagegen/feiyue-3d/generated-attacks/imagegen 特效）、`enemies/`（每怪一张 4×3 图集）、`home/`、`icons/`（SVG）、`rogue/`（闯关全部素材）、`ui/`、`vendor/`（KayKit/Quaternius CC0 模型）、`video/`、`world/`（地面瓦片+atlas.jpg）。

## 9. 运行、启动与部署

| 文件 | 用途 |
|---|---|
| `游戏启动.cmd` | 推荐源码启动（先跑 check_class_cache.ps1 守卫） |
| `源码版启动.cmd` / `Start-Game.cmd` | 极简源码启动 |
| `Godot_…win64.exe` / `…_console.exe` | 编辑器/跑游戏；控制台版用于一切 headless 测试与服务器进程 |
| `game.cfg` | 客户端 API 地址（当前已配真实域名）；导出后可复制到 exe 旁覆盖 |
| `Dockerfile` + `compose.yaml` + `.env.example` + `server/Caddyfile.docker` | 服务器容器部署（Dockerfile 的 test 阶段即 CI：test_server + test_p2p + systems.gd）；端口 8080(HTTP)/3478(STUN)/24900-24915(房间 UDP) |
| `export_presets.cfg` | Windows 单文件导出（内嵌 PCK、脚本编译 .gdc、排除 server/tests/tools/pv 等） |
| 存档位置 | `%APPDATA%/Godot/app_userdata/血潮守望 · Crimson Tide/profile.json` |

## 10. 根目录文档索引（专题设计文档）

| 文档 | 主题 | 主要对应代码 |
|---|---|---|
| README.md | 总览/启动/操作/存档 | 全局 |
| EXPEDITION.md / ROGUELIKE.md | 远征/闯关玩法与验证 | expedition.gd / roguelike.gd |
| ATTACK-TELEGRAPH.md | 攻击前摇提示（预警可读性、时长与美术口径） | scripts/attack_telegraph.gd |
| output/ROGUE-CONTRACTS.md、output/CONTRACT-CHANGELOG.md、output/ROGUELIKE-EXPANSION-SUMMARY.md、output/R*.md（26 份） | 肉鸽扩展（图谱/事件/诅咒/每日/成长/房间 UI）的契约、变更记录、逐项验收报告与执行计划 | scripts/rogue_graph.gd、rogue_events.gd、rogue_curses.gd、rogue_daily.gd、rogue_growth.gd、rogue_room_ui.gd 等 |
| ROGUE-BUILD-SYSTEM-DESIGN.md（1403 行）| 构筑系统设计全集（数值口径 §3、12 流派 §4、数据结构与脚本接入 §12:804） | rogue_build.gd + JSON |
| ROGUE-BUILD-IMPLEMENTATION.md | 构筑已接入清单与测试汇总 | 同上 |
| ROGUE-EQUIPMENT.md / ROGUE-MINION-DESIGN.md / CHEST-REWARDS.md / EXTRACTION-INVENTORY.md | 早期装备子集/40 小怪 80 招/宝箱奖励协议/远征背包 | rogue_equipment.gd / rogue_minions.gd / roguelike.gd / extraction_inventory.gd |
| BOSS-REWORK.md（总表）/ BOSS-VFX.md / BOSS-EXPANSION.md / BOSS-WILD-EXPANSION.md / BOSS-DRAGON.md / BOSS-ANIMATION.md | Boss 招式 73 招/特效/扩展/异兽/古龙/动画 | boss_choreography.gd 等 |
| ECOLOGY-UPDATE.md / ENEMY-UPDATE.md / NOCTURNE-UPDATE.md / WEAPON-SKILL-ENEMY-BALANCE.md | 野外怪生态/怪物图集/数值平衡 | ecology.gd、enemy_frames.gd |
| COMBAT-UPDATE.md / VFX-REWORK.md / HYBRID-VFX.md / ATTRIBUTES-AND-ARTS.md / RANGED-ANIMATION.md | 战斗动画/特效重做/混合特效/属性战技表/远程动画 | combat_visuals.gd、character_frames.gd、weapon_arts.gd |
| MUSIC.md / ULTIMATE-AUDIO.md / VOICE-SOURCING.md / AUDIO-CREDITS.txt / VOICE-CREDITS.txt | 音乐/大招音频/语音选材/鸣谢 | music.gd、sound.gd、hero_voice.gd |
| CAMP-MAP.md / HOMESTEAD.md / CITY-UPDATE.md / MAP-UPDATE.md / MAP-2-5D.md / WAREHOUSE-AND-MARKET.md / COLLECTIBLES.md / FREE-SCENE-ASSETS.md / ART-DIRECTION.md / UI-ART-UPDATE.md | 营地/家园/王城/大地图/2.5D 分工/仓库/藏品/场景素材/美术方向 | §4.N/J/O 对应文件 |
| SERVER.md / server/DOCKER.md | 服务器裸机与容器部署 | server/app.py |
| HIDDEN-ENDING.md | 隐藏结局（冥火尸王/招募墓煜） | expedition.gd、profile.gd |
| TEST-REPORT.md | 验证台账 | tests/ |
| minimax2live2d.md | 外部素材管线笔记（参考） | tools/ |

## 11. 已知坑与注意事项（改码前必读）

1. **`git status` 里出现 `?? 某目录/` 时先查清再动**：这类目录没进版本库（可能是重复克隆，也可能是本机构建产物）。危害是 `git add .` 会把整个目录当成一个 gitlink 提交进来。处理：① 一切修改只在项目根做；② **禁止 `git add .`**，只 add 你真正改的文件；③ 确认无用后再删除该目录。
2. **`STARTER_BASE=17`（catalog.gd:167）必须等于 WEAPONS.size()**，tests/systems.gd 有断言——增删野战武器后必须同步这个字面量。
3. **藏品序号只追加不插入**：`catalog.gd:106 NEW_COLLECTIBLES` 的顺序就是存档解锁序号（`collectible_index`），中间插入会毁掉玩家存档。
4. **`BossFrames.SPECIAL_KEYS` 顺序被按下标硬引用**（enemy_body.gd:35、boss_cinematic.gd:75、boss_hud.gd:70，另有 battlefield.gd:28-30 的 `SPECIAL_BOSS_ART` 同序），且 `boss_effect_art.gd:55-57` 颜色表按 `KEYS.find` 索引——新增 Boss 身份一律**追加到表尾**并同步颜色表。
5. **Boss 伤害几何三处同步**：新形状要同时改 `boss_geometry.gd`、`expedition.gd:357 hazard_contains()`、`resources/boss_damage_shape.gdshader`，回归看 `tests/boss_damage_geometry.gd`（CPU 与 GPU 必须逐像素一致）。
6. **特效必须走 battlefield.gd:695 `weapon_effect_socket` 挂点契约**，且释放类特效"一次捕获、原地淡出"（stylized_vfx.gd:56-62）——否则 `tests/weapon_stroke_stability.gd` 失败。
7. **改 ruins.gd 地形后必须重跑烘焙管线**（tools/export_world_layout.gd → tools/bake_world_art.py），否则 3D 表现与碰撞错位。
8. **穿上的战利品永不写存档**（"穿或带走，不能 both"，session.gd:307 注释）；**次元口袋是唯一免死容器**——改动结算/散包逻辑时保持此契约。
9. **权威端才做规则**：main.gd/各 UI 只发 `session.action()`；不要在表现层（battlefield/world_3d/combat_visuals 等 "Presentation only" 文件）里写伤害或状态逻辑。
10. **存档唯一写入点是 profile.gd:107**（.tmp + rename 原子写）；其他任何地方直接写 profile.json 都是错的。
11. `output/`、`pv/`、`DEPRECATED-*` 目录不是游戏资源（导出已排除）；`DEPRECATED-character-animations-2026-09-25` 是被否决的 12 帧动画归档，勿复用。
12. 联机测试约定：逻辑测试 `--headless`，画面测试开窗，联机加 `--max-fps 60` 且房主进程带 `-- --server`；正在进行的对局不能迁移服务器（打洞兜底只发生在出发前）。
13. UI 全部由代码构建（main.tscn 是空壳）：改界面 = 改 main.gd / 各 screen 脚本，**不要**试图在编辑器里找节点。
14. **肉鸽扩展有一套契约与验收文档**：动肉鸽行为前先读 `output/ROGUE-CONTRACTS.md` 与 `output/CONTRACT-CHANGELOG.md`（契约在何时被谁改过），逐项验收记录在 `output/R*.md` 与 `output/ROGUELIKE-EXPANSION-SUMMARY.md`；改完跑 `pwsh -File tools/run_rogue_gate.ps1`。
15. **攻击前摇与敌方弹幕可读性有专门的验证工具**（`tools/verify_enemy_bolt_readability.gd`、`tools/measure_bolt_*.py`）：改动前摇/弹幕表现后要重跑，别凭肉眼判断。

---

## 12. 路牌维护规范（做完一个功能、交接前必做）

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

1. 一律写成 `` `文件名:行号 符号名()` ``（例：`` `session.gd:2843 move_player()` ``、`` `catalog.gd:167 STARTER_BASE=17` ``）。纯数值 / 纯区间的锚点可以只写行号，但**能写符号名就必须写**——行号会漂，符号名不会。
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

| 日期 | 提交 | 更新内容 |
|---|---|---|
| 2026-10-05 | b034286 | 初版：按功能域建立全项目文件地图（§3–§11） |
| 2026-10-05 | 见同批提交 | 全量锚点审计（476 个锚点，见 §12.7）并修正 11 处错标 / 漂移；新增本§12 维护规范；README 加入口指引 |
| 2026-10-05 | 见同批提交 | 跟随 `abcbaaf`（肉鸽扩展全量接线 + 攻击前摇，179 文件/+17267 行）全量重锚：机械修正 47 处 + 8 章节人工复核（修正 100+ 处漂移/错标）；新增 attack_telegraph、肉鸽七子系统（图谱/事件/诅咒/每日/成长/房间/变体）、房间 UI 与每日/成长页等条目；装入 `tools/verify_anchors.py`；结构数字更新为 102 脚本 / 2.95 万行 |
| | | |

### 12.7 最近一次全量审计（2026-10-05，基准 abcbaaf）

- **范围**：全文 `文件:行号` 锚点，`tools/verify_anchors.py` 解析出 **432** 个（含区间与裸行号锚点），逐条对代码实测。
- **结果**：**全部通过**——OK 348 / DRIFT 0 / WRONG 0；另有 84 条 HINT（锚点只写了行号、附近才出现符号名，脚本无法硬校验，建议后续逐步补符号名）。
- **本轮改动**：跟随 `abcbaaf` 大提交（179 文件 / +17267 行 / 肉鸽扩展全量接线与攻击前摇）重锚：机械修正 47 处行号 + 8 个章节的人工复核（修正 100+ 处漂移与错标）；新增攻击前摇（`scripts/attack_telegraph.gd`）、肉鸽扩展七子系统（图谱/事件/诅咒/每日/成长/房间/变体）、房间 UI 与每日・成长页、Boss 弹幕外壳 shader、`tools/run_all_tests.ps1`/`run_rogue_gate.ps1` 等条目。
- **结论**：每次 pull 到含代码变更的提交后，先跑一次 `python tools/verify_anchors.py --guide PROJECT-GUIDE.md --root . --summary`；有 DRIFT / WRONG 就按报告改完再交接。

### 2026-10-06 本地恢复与同步

肉鸽地图已接入 50 张 ComfyUI 精确三倍图，ground-manifest.json 保存专用房间背景和实测碰撞轮廓；tools/install_rogue_final_maps.py 优先选择三倍图，tools/audit_rogue_final_maps.py 与 tests/roguelike_smooth_maps.gd 验证选图及尺寸。scripts/main.gd 增加面板关闭与重新打开操作，tests/rogue_panel_close.gd 验证关闭行为。相关代码变动后的行号需重新校验。
