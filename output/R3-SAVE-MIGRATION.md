# R3 —— 存档迁移与服务端兼容（实测记录）

工作目录：`D:\game\CrimsonTide-godot`　引擎：`Godot_v4.7.2-stable_win64_console.exe`（不在 PATH）
原始日志：`build\r3\migration.out.txt`、`build\r3\validate_profile.out.txt`、`build\r3\regress\<test>.log`

本轮改动的文件（`git status` 取证，只有这两个是本轮的）：

| 文件 | 状态 | 说明 |
| --- | --- | --- |
| `scripts/profile.gd` | M（+42 / −4） | 契约 §4.1 的迁移语义：**修掉「version 不符就静默丢档」**、落盘永远写 version 1、新增 `sanitize_growth()` |
| `tests/rogue_profile_migration.gd` | 新增 | 113 checks / 0 failures |

---

## 1. 动了什么，为什么

### 1.1 `apply_data()`：不再因为 `version` 不符而整段跳过（**这是本轮的核心修复**）

旧实现是 `if parsed is Dictionary and parsed.get("version",0) == 1:` —— 条件不成立时**整段跳过**，
`data` 保持构造函数默认值，紧接着 `sanitize_storage()` 用默认值把它"洗白"。
此时内存里已是一份全新档，**下一次 `save_profile()` 会把磁盘上的老档覆盖成默认档（静默丢档）**。
触发路径都是真实存在的：手改过的存档、其它分支写出的档、`main.gd:381 profile.apply_data(cloud)`（云端数据）。

新实现：只要是 Dictionary 就按 `typeof` 逐键导入，**唯独不导入 `version`**，函数末尾强制 `data["version"]=1`。
即"**能读的都读回来，但永远只认/只写 version 1**"。代价：若将来真出现语义不同的 v2 格式，
它会被按 v1 语义读取（并把未知键丢弃、落盘重写为 v1）。权衡上是可接受的——另一种选择（跳过）在本项目里等于丢档，
而 `server\app.py:409` 本来就拒绝非 1 版本上传，v2 只可能来自本地手改。

`coins/xp/runs/extracts/hero/gear/best` 那条 float→int 纠正列表里加入了 `ashes`（契约 §4.1 要求），
否则 `ashes` 会被 JSON 读成 `17.0`。

### 1.2 `sanitize_growth()`（新增）：灰烬与成长树的脏值闸门

在 `sanitize_storage()` 与 `save_profile()` 里各调一次：

- `ashes`：非 int/float → 0；负数 → 0（`maxi(0,...)`）。**没有上限钳制**（见 §4 风险）。
- `growth`：不是 Dictionary → `{}`；逐项只保留 **int/float 且 > 0** 的等级，键统一 `str()` 化。
  **逐节点等级上限不在这里做**——那属于 `RogueGrowth.tree()`（W6 / R12）。

### 1.3 `save_profile()`：落盘前强制 `data["version"]=1`

保证"**磁盘上永远是 version 1**"这条不变量，即使有人把内存里的 `data.version` 改成 3。

---

## 2. 边界实测行为表（`tests\rogue_profile_migration.gd`，113 checks / 0 failures）

| 输入 | 实测行为 | 判定 |
| --- | --- | --- |
| 老档 v1、无 `ashes`/`growth` | 旧字段逐项保留（数值/字符串/浮点/布尔/天赋/解锁/背包全部逐条断言），`ashes==0`(int)、`growth=={}` | ✅ 契约 §4.2-1 |
| 老档 → `save_profile()` → `load_profile()` | 回环后逐字段不变，磁盘 JSON 里 `version==1`、含 `ashes`/`growth`；`ashes==17` 仍是 int，`growth.ash_vein==2` | ✅ 契约 §4.2-2 |
| `version:2`（coins 777 / xp 1234 / runs 9） | **不丢档**：全部导入，`version` 归一为 1；再 存→读 仍是 777、仍是 1 | ✅ 契约 §4.2-3 |
| 缺 `version` 键 | 归一为 1，其余字段照常导入 | ✅ |
| `version:"1"`（字符串） | 不污染 `data.version`（仍是 int 1），其余字段照常导入 | ✅ |
| `null` / `"junk"` / `[]` / `42` / `true` | 不崩，`data` 保持默认（coins 160 / ashes 0 / growth {}），`version` 仍 1 | ✅ |
| `ashes:50.0` | → int `50`（走 float→int 纠正列表） | ✅ 契约 §4.1 |
| `ashes:"50"` | → **0**（typeof 不匹配 → 不导入；`sanitize_growth` 兜底为 0） | 实测，可接受 |
| `ashes:-5` | → 0 | ✅ |
| `ashes:1e12` | → int `1000000000000`，**无上限** | 见 §4 风险 |
| `ashes:[1,2]` | → 0（`sanitize_growth` 的非数值兜底） | ✅ |
| `growth` = 数组 / `null` / 字符串 / 数字 | 一律 `{}` | ✅ |
| `growth` = `{a:2, b:-3, c:"x", d:1.9, e:0}` | 实测 `{"a":2,"d":1}`：负数丢、非数值丢、0 丢、float 截断 | 实测 |
| `coins:"999"` | → **160**（新档默认值；typeof 不匹配 → 不导入，脏值不覆盖默认） | 实测 |
| 内存里手改 `data.version=3` + `growth={ash_vein:2,broken:-4,junk:"x"}` + `ashes="17"` → `save_profile()` | 磁盘：`version==1`、`growth=={"ash_vein":2}`、`ashes==0`；再读回来 `version==1`、`ashes` 是 int | ✅ 契约「永远写 1」 |

## 3. 服务端兼容（`build\r3\validate_profile_check.py`，`F:\python\python.exe`，8/8 PASS）

直接 import `server\app.py` 调 `validate_profile`（原始输出见 `build\r3\validate_profile.out.txt`）：

```
[PASS] legacy save, no ashes/growth (still accepted)  got=OK
[PASS] save with ashes+growth (what R3 writes)        got=OK
[PASS] unknown top-level keys are tolerated           got=OK
[PASS] version 2 is rejected                          got=400 存档格式错误。
[PASS] missing version is rejected                    got=400 存档格式错误。
[PASS] ashes inside attributes is rejected            got=400 属性格式错误。
[PASS] 1e12 ashes is NOT validated by the server      got=OK
[PASS] string ashes is NOT validated by the server    got=OK
SUMMARY 8/8 probes behaved as documented
```

结论：**不需要改服务端**。`ashes`/`growth` 作为顶层键被放行（`:408-448` 不拒绝未知顶层键）；
`attributes` 的白名单仍然会挡住"把灰烬塞进属性"的做法；非 1 版本被 400 拒绝 —— 这正是"落盘必须恒为 1"的理由。

## 4. 回归（`--headless --path . --script tests/<n>.gd`，门禁只比 failures）

| 测试 | 本轮 | R1 基线 | 判定 |
| --- | --- | --- | --- |
| rogue_profile_migration（新） | 113 / **0** | — | 新增 |
| rogue_wiring | 117 / 0 | 113 / 0 | 一致（+4 来自 R8 数据表扩大） |
| rogue_build_growth | 4066 / 0（样本 [204,498]） | 4066 / 0（样本 [213,500]） | 0 failures，样本仍在宽区间内 |
| rogue_build_system | 440 / 0 | 440 / 0 | 一致 |
| systems | 10812 / 0 | 10812 / 0 | 一致 |
| expedition | 79 / 0 | 79 / 0 | 一致 |
| attributes（**profile 老用户**） | 204 / 0 | — | 全绿 |
| economy（**profile 老用户**） | 78 / 0 | — | 全绿 |
| homestead（**profile 老用户**） | 64 / 0 | — | 全绿 |
| hidden_ending（**profile 老用户**） | 100 / 0 | — | 全绿 |
| camp_activities | 89 / 0 | — | 全绿 |

除上面这些外，所有日志里 `ERROR:` 计数为 0、退出码全为 0。
按派单要求**没有**把 `rogue_build_progression` / `roguelike_seven_rooms` / `roguelike_routes` 当门禁（R5 正在改它们的口径）。
`rogue_build_rules`（缺资产崩溃挂死）与 `rogue_build_pack`（`Missing exported icon W001`）按基线豁免，未跑。

## 5. 待接线清单 / 交给后续轮次

1. **R12（成长树数据层）**：`sanitize_growth()` **不做逐节点等级上限**，只保证"字典、键为字符串、值为正整数"。
   请让 `RogueGrowth` 在 `buy()`/`tree()` 里按节点定义的上限钳制，并保证 `ashes` 只增不减、`buy` 时不得低于 0。
2. **R13（成长树 UI/结算）**：`settle()` 是唯一结算点，`profile.ashes` 只能在那里 +1 次（契约 §9）。
3. **W5（服务端）**：`validate_profile` 对 `ashes`/`growth` **不做任何校验**。当前无害（顶层键、不进 `attributes`），
   但意味着一个手改客户端可以上传离谱的 `ashes`。若将来要做排行榜/经济平衡，建议在 `app.py` 里补一条
   `ashes` 为 0..2^31-1 的整数校验（本轮按派单**没有**改服务端）。
4. **文档**：本实现推翻了契约 §4.1 里"version 不符 → 整段跳过"的描述。契约应补一条 CHANGE-LOG：
   *"`apply_data` 对任意 Dictionary 做尽最大努力导入，`version` 一律归一为 1；跳过式行为已被移除"*。

## 6. 风险与残留

- **`ashes` 无上限、服务端不校验**（见 §5.3）：脏值最大实测到 1e12 仍被接受并落盘。平衡风险由 `RogueGrowth` 承担。
- **`version` 严格性的取舍**：将来若真的引入 v2 格式，本实现会按 v1 语义读取该档并回写为 v1。这是为了消除
  "跳过即丢档"而付出的代价；引入 v2 时必须同时改 `apply_data` 的导入规则与 `app.py:409`。
- **类型不符的字段是丢弃而不是强转**（`ashes:"50"` → 0、`coins:"999"` → 默认值 160）。这是原实现的既有策略
  （`typeof` 匹配才导入），本轮未改动；只对 `ashes` 补了数值纠正与兜底。若希望"字符串数字也认"，需要在
  `apply_data` 里另开一条显式强转规则（未做，避免扩大改动面）。
