# R11 · 每日挑战 / 种子分享（`RogueDaily`）交付记录

- 轮次：**R11**（文件名所有权集合 **F / W6**）
- 日期：2026-10-05
- 只新建两个文件，**未修改任何既有源码、未修改任何既有文档、未 `git commit`、未新增 autoload、未跑 `--import`**。

## 0. 交付物

| 文件 | 行数 | SHA256 前 16 位 | 说明 |
| --- | --- | --- | --- |
| `scripts/rogue_daily.gd` | 253 | `99EAF121D7CC44F2` | 每日种子 / 分享串 / 每日记录，纯函数数据层 |
| `tests/rogue_daily.gd` | 220 | `78C792E07D60CC7D` | 132 checks / 0 failures |
| `output/R11-DAILY-SEED.md` | — | — | 本文件 |

`git status --porcelain -- scripts tests` 里属于本轮的只有 `?? scripts/rogue_daily.gd` 与 `?? tests/rogue_daily.gd`；
其余条目全部是并发轮次（W1 的 `roguelike.gd`/`session.gd`/`profile.gd`、W7 的 8 个表现层文件、R3/R4/R8/R9 的新文件）。

## 1. 原始验收输出

```
> Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/rogue_daily.gd
ROGUE DAILY 132 checks / 0 failures
EXIT=0
```

覆盖矩阵（对应派单 ①–⑦）：

| # | 断言组 | 样本量 | 结果 |
| --- | --- | --- | --- |
| ① | 同一日期重复抽取一致；相邻 1000 天种子零碰撞；非法日期 → 0 | 1000 次重复 + 1000 天 + 9 个非法输入 | 全通过 |
| ② | `encode` → `parse_seed` 往返恒等；越界种子不可分享 | 1000 个种子 + 5 个边界 | 全通过 |
| ③ | 非法 / 截断 / 超长 / 非十六进制 / 校验位错 / 前缀错 / 全零体 | 12 个畸形串 + 1 个篡改校验位 + 1 个全零体 | 全通过（`is_valid=false`、`parse_seed=0`、无崩溃无异常） |
| ④ | 大小写、首尾空白、中间空白、十进制粘贴、`#` 前缀 | 12 条 | 全通过 |
| ⑤ | `today()`=本地、`utc_today()`=UTC、`global_daily_seed()` 只由 UTC 日期派生、种子不读系统时钟 | 8 条 | 全通过 |
| ⑥ | 每日记录：空记录 / 当天 / 隔天 / 连胜中断 / 脏数据 / 纯函数不改原字典 / 日期位移与闰年 | 30 条 | 全通过 |
| ⑦ | 固定种子可复现：`launch(false,X)` 两次 → `seed_value`、节点图 `signature`、`exit_choices()`、首个三选一候选池全部相同 | 5 条（2 个真实 `TideSession`） | 全通过 |

⑦ 用的是**真实会话**（`TideSession.new()` + `solo({"hero":0,"mode":"roguelike"})` + `launch(false,seed)`），断言 `RogueGraph.signature(RogueGraph.build(seed,1))` 相同、`exit_choices()` 与 `reward_offers(s,3,"gear",p)` 的字符串表示相同 —— 即契约 §1 的「`seed_value` 必须全队一致」在实现层成立。

## 2. 回归（同一轮内实测，`--headless --path . --script`）

| 测试 | 实测 | 与 R1 基线 | 判定 |
| --- | --- | --- | --- |
| `tests/rogue_daily.gd`（本轮新增） | **132 / 0** | — | 本轮交付 |
| `tests/rogue_wiring.gd` | **117 / 0** | R2 交付时 113/0 | 迁移后仍 0 failures |
| `tests/rogue_variants.gd` | **495 / 0** | R8 交付 495/0 | 一致 |
| `tests/rogue_graph.gd` | **83608 / 0** | R4 交付 83608/0 | 一致 |
| `tests/rogue_curses.gd` | **218 / 0** | — | 一致 |
| `tests/rogue_events.gd` | **484 / 0** | — | 一致 |
| `rogue_build_growth` | **4066 / 0**（宝箱样本 `[204, 498]`） | 4066/0（`[213,500]`） | 0 failures，样本仍在宽区间 `140–261/420–581` 内 |
| `rogue_build_system` | **440 / 0** | 440/0 | 一致 |
| `systems` | **10812 / 0** | 10812/0 | 一致 |
| `expedition` | **79 / 0** | 79/0 | 一致 |

**新增失败 = 0。** 按派单未把 `rogue_build_progression` / `roguelike_seven_rooms` / `roguelike_routes` 当门禁（R5 正在改口径）；`rogue_build_rules` / `rogue_build_pack` 为基线豁免项，未跑。

## 3. 契约 §5 签名核对

| 契约签名 | 实现 | 状态 |
| --- | --- | --- |
| `static func today() -> String` | 同签名，返回 `Time.get_date_string_from_system(false)` | ✅ 逐字一致 |
| `static func seed_for(date_string: String) -> int` | 同签名；同天同值、跨天不同值、非法 → `0` | ✅ 逐字一致 |
| `static func parse_seed(text: String) -> int` | 同签名；非法 → `0`，不崩不抛 | ✅ 逐字一致 |

`class_name RogueDaily` + `extends RefCounted` ✅；无副作用、无 `s` 依赖、不消耗 `s.rng`、不用全局 `randi()/randf()` ✅。

**追加的纯函数**（契约允许"只追加"）：

| 函数 | 语义 |
| --- | --- |
| `utc_today() -> String` | UTC 日期串（见 §4 时区裁决） |
| `normalize_date(text) -> String` | 各种日期写法 → `YYYY-MM-DD`；非法 → `""` |
| `is_date_string(text) -> bool` | 是否可规整为合法日期 |
| `host_daily_seed() -> int` / `global_daily_seed() -> int` | `seed_for(today())` / `seed_for(utc_today())` |
| `encode(seed) -> String` | 种子 → 分享串（越界 → `""`） |
| `is_valid(text) -> bool` | 分享串语法 + 校验位 |
| `record_key(date) -> String` | `"daily:YYYY-MM-DD"`；非法 → `""` |
| `normalize_record(value) -> Dictionary` | 脏输入 → `{"best":int,"plays":int}`；不可识别 → `{}` |
| `played_on(records, date)` / `best_on(records, date)` | 只读查询 |
| `apply_result(records, date, score) -> Dictionary` | **纯函数**：返回新记录字典，不改入参 |
| `streak_ending_at(records, date, max_lookback := 400) -> int` | 以某天结尾的连续打卡天数 |
| `shift_date(date, days) -> String` | 日期 ± 天（跨年、闰年正确） |
| 常量 | `PREFIX/ALPHABET/HEX_DIGITS/MAX_SEED/CHECK_SALT/MIN_YEAR/MAX_YEAR/RECORD_PREFIX/MAX_LOOKBACK` |

## 4. 时区语义（契约原文 vs 派单口径的裁决）

- 契约 §5 写的是 `today()` = **房主本地时间**；派单备注写的是「UTC 日期 → 种子、同一 UTC 时刻在不同本地时区下同一种子」。两者只在"用哪个日期"上有分歧。
- **裁决（不违反冻结签名，全部以追加方式实现）**：
  1. `today()` 严格按契约 = 本地日期；`host_daily_seed()` 由它派生。
  2. 追加 `utc_today()` / `global_daily_seed()`：跨时区一致的"全球每日"用 UTC 日期派生，**由房主算好随 `begin` RPC 下发**，客户端永不自行计算（契约 §1）。
  3. `seed_for()` 只依赖**日期字符串本身**（自己实现的 32 位 FNV-1a，取码点，不依赖 `hash()` 跨版本稳定性），所以"同一字符串 → 同一种子"在任意时刻、任意进程、任意时区都成立 —— 测试 ⑤ 用"重复调用一致 + 与 `Time.get_date_string_from_system(true)` 对齐"把这条钉死。
- **接线要求**：无论用 `host_daily_seed()` 还是 `global_daily_seed()`，都必须在房主侧算完后下发（`seed_value`），并让 `raid.daily=true`；**禁止**各客户端按本地日期各算一份。

## 5. 种子分享串格式（冻结规格）

```
CT-XXXXXXXX-C
 │   │       └── 1 位校验字符，取自 ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
 │   │           （Crockford base32：剔除易混的 I / L / O / U），check = ALPHABET[(Σnibble + 7) % 32]
 │   └────────── 8 位大写十六进制，数值 = 种子的低 31 位
 └────────────── 固定前缀 "CT-"
```

- 合法种子域：`[1, 2147483647]`（`MAX_SEED`）。**0 不可分享**，因为 `launch()` 里 `fixed_seed == 0` 表示"随机种子"。
- 越界（`<=0` 或 `> MAX_SEED`）→ `encode()` 返回 `""`；`parse_seed("")` → `0`。
- 解析容错：大小写、首尾空白、中间空白、全角空格；另外接受**直接粘贴的十进制种子**（`1234567`、`#42`）。
- 解析拒绝（一律返回 `0`，不崩不抛）：空串、长度不符、前缀不符、非十六进制、分隔符不符、校验位不在 `ALPHABET`、校验位不匹配、十进制 `0`/负数/超 `MAX_SEED`。
- ⚠ **已发布即不可改**：`ALPHABET`、`HEX_DIGITS`、`CHECK_SALT`、前缀一旦随版本发出去，改动等于作废所有已分享的种子串。
- 碰撞：31 位空间下 1000 天样本的理论碰撞概率约 `1000²/2³² ≈ 0.023%`；实测 1000 个连续日期**零碰撞**。

## 6. 待接线清单（提交者 W6：轮次 R11）

```
- 目标文件: scripts/session.gd
- 目标函数/锚点: launch()(session.gd:1378) 与 begin()(session.gd:1411) / begin.rpc 下发路径
- 期望插入代码: 每日挑战时由房主算 seed 后下发，并写 raid.daily / raid.seed_shared：
    var daily_seed := RogueDaily.global_daily_seed()          # 追加函数，UTC 口径
    launch(false, daily_seed)  →  begin(daily_seed, ...)      # 客户端沿用 begin 收到的 seed
    s.raid["daily"] = true
    s.raid["seed_shared"] = RogueDaily.encode(s.seed_value)
- 依赖的契约: §1「seed_value 必须全队一致」、§2 raid.daily/seed_shared、§5 RogueDaily
- 验收断言: tests/rogue_daily.gd 的「固定种子可复现」+「global_daily_seed 只由 UTC 日期派生」
- 未接线时的临时状态: raid.daily 恒 false、raid.seed_shared 恒 ""，玩法不生效但测试可跑

- 目标文件: scripts/profile.gd
- 目标函数/锚点: _init()(profile.gd:20-23) 的默认 data 字典 / apply_data 的 typeof 匹配(:37-39)
- 期望插入代码: data["daily"] = {}   # 顶层新键，version 保持 1
- 依赖的契约: §4（新增键必须给同类型默认值，否则被静默丢弃）；需先落 CHANGE-LOG v3（见 §7）
- 验收断言: 老档读入 → daily 默认 {}、旧字段不丢；带记录存→读回环不变
- 未接线时的临时状态: 每日记录无处落盘（纯函数可单测）

- 目标文件: scripts/roguelike.gd
- 目标函数/锚点: settle()（唯一结算点，受 raid.ended 守卫）
- 期望插入代码:
    var key := RogueDaily.record_key(RogueDaily.utc_today())
    profile.data["daily"] = RogueDaily.apply_result(profile.data.get("daily", {}), RogueDaily.utc_today(), score)
    （score 口径由 R13/R16 定；建议用"本局通关区数"或"本局魔晶"）
- 依赖的契约: §9.3「结算只有一个出口，只能发一次」
- 验收断言: 连点/连调 settle() 两次不重复计数（plays 只 +1）
- 未接线时的临时状态: 每日记录不落盘

- 目标文件: scripts/main.gd（W2 / R7）
- 目标锚点: 魔境入口与 HUD
- 期望行为: ①"每日挑战"入口用 RogueDaily.global_daily_seed() 起局；
              ②种子输入框用 RogueDaily.parse_seed(text)（无效 → 0 则提示，不得起局）；
              ③"复制种子"用 RogueDaily.encode(s.seed_value)；
              ④显示用 raid.seed_shared（不要在前端重算）；
              ⑤新增动作必须携带并校验 raid.revision（§9.2）
- 未接线时的临时状态: 玩家只能靠固定种子入口，无每日挑战 UI

- 目标文件: scripts/rogue_seed_ui.gd（计划 R11 列出的 UI 文件）
- 状态: **本轮未创建**（派单明确"只新建 rogue_daily.gd + tests"）。若 R7 需要一个纯格式化的 UI 门面，可在 R7 或 R11b 里补，全部只依赖 §5 的静态 API。
```

## 7. 建议的 CHANGE-LOG v3 条目（待契约所有者合并，本轮未改写 `ROGUE-CONTRACTS.md`）

```
- v3 / 2026-10-05 / R11：追加 ① profile.data 顶层新键 "daily"（Dictionary，默认 {}，
  键 = "daily:YYYY-MM-DD"（RogueDaily.record_key），值 = {"best":int,"plays":int}；
  version 仍为 1，必须在 profile.gd 的 _init() 给同类型默认值）；
  ② RogueDaily 的追加纯函数 utc_today/normalize_date/is_date_string/host_daily_seed/
  global_daily_seed/encode/is_valid/record_key/normalize_record/played_on/best_on/
  apply_result/streak_ending_at/shift_date 与常量 PREFIX/ALPHABET/HEX_DIGITS/MAX_SEED/
  CHECK_SALT/MIN_YEAR/MAX_YEAR/RECORD_PREFIX/MAX_LOOKBACK。
  影响的既有契约条目：§4（新增第 3 个存档键）、§5（追加函数）、§6.2（本模块不消耗 s.rng，无影响）。
```

## 8. 风险

1. **分享串格式不可逆**：`ALPHABET`/`CHECK_SALT`/`HEX_DIGITS` 一旦发布即冻结（见 §5）。
2. **种子不得为 0**：`launch()` 把 `fixed_seed==0` 当"随机"，所以 `seed_for()` 对合法日期恒返回 `[1, MAX_SEED]`；接线时若有人把 `parse_seed()` 的 `0` 直接当种子传给 `launch()`，会静默变成随机局 —— UI 必须先判 `is_valid`/非零。
3. **日期口径必须与记录键一致**：`global_daily_seed()` 用 UTC，`apply_result()` 若用本地日期键，会出现"挑战日 ≠ 打卡日"。建议全局统一 UTC（`utc_today()`）。
4. **存档兼容**：`daily` 是第三个顶层键，必须走 §7 的 CHANGE-LOG，并在 `profile.gd` 给 `{}` 默认值；`server/app.py` 不校验未知顶层键（R1 已复核），无需改服务端。
5. **`daily` 字典会随存档上传**：值只有 `int`，JSON 可序列化 ✅；但记录会随游玩天数增长（每天 2 个 int），长期需考虑裁剪（例如只保留最近 400 天）—— 本轮不做，留给 R13/R16。

## 9. 未做项 / 环境备注

- `scripts/rogue_seed_ui.gd` **未创建**（派单范围限制，见 §6 最后一条）。
- `class_name RogueDaily` **未登记进** `.godot/global_script_class_cache.cfg`：`tools\check_class_cache.ps1 -CheckOnly` 仍报 4 个新类缺失（RogueCurses/RogueEvents/RogueGraph/RogueVariants + 本轮的 RogueDaily）。本轮所有引用都走 `preload("res://scripts/rogue_daily.gd")`，**不依赖类名注册**；R7 若要按裸类名引用，必须先跑一次 `powershell -NoProfile -File tools\check_class_cache.ps1 -ProjectPath .`。按派单要求本轮**没有**跑它（会写 `.godot/` 与大量 `*.import`）。
- `scripts/rogue_daily.gd` 目前没有同名 `.uid` 文件（本轮未跑 `--import`）；按路径 `preload` 不受影响。

## 10. 复现命令

```powershell
$exe = "D:\game\CrimsonTide-godot\Godot_v4.7.2-stable_win64_console.exe"
& $exe --headless --path D:\game\CrimsonTide-godot --script tests/rogue_daily.gd
# 回归
& $exe --headless --path D:\game\CrimsonTide-godot --script tests/rogue_wiring.gd
& $exe --headless --path D:\game\CrimsonTide-godot --script tests/rogue_variants.gd
& $exe --headless --path D:\game\CrimsonTide-godot --script tests/rogue_graph.gd
& $exe --headless --path D:\game\CrimsonTide-godot --script tests/rogue_curses.gd
& $exe --headless --path D:\game\CrimsonTide-godot --script tests/rogue_events.gd
& $exe --headless --path D:\game\CrimsonTide-godot --script tests/rogue_build_growth.gd
& $exe --headless --path D:\game\CrimsonTide-godot --script tests/rogue_build_system.gd
& $exe --headless --path D:\game\CrimsonTide-godot --script tests/systems.gd
& $exe --headless --path D:\game\CrimsonTide-godot --script tests/expedition.gd
```
