# R8b · 变数抽取改为局部 RNG（契约 CHANGE-LOG v2-11）

- **改动文件**：
  - `scripts/rogue_variants.gd`（SHA256 前 16 位 `B942481904273698`，18 条变数）
  - `tests/rogue_variants.gd`（SHA256 前 16 位 `97DAB7FF663ED343`）
- **未改动**：`tests/rogue_wiring.gd`（**实测无需任何口径更新**，见 §3）、`scripts/roguelike.gd`（W1b 正在改）、
  `scripts/session.gd`、`scripts/ecology.gd`、G 集合、`scripts/rogue_combat.gd`、任何既有 `.md`。
- **每步语法检查**：`--headless --check-only --script <file>` 两个文件均 `exit 0`。

---

## 1. 改动点（行号）与派生种子公式

`scripts/rogue_variants.gd`：

| 位置 | 改动 |
| --- | --- |
| 第 6-19 行（头部纪律注释） | 改为「`roll()` **完全不消耗 `s.rng`**：抽取前后 `s.rng.state` 逐位不变」 |
| **第 248 行** | 新增 `static func _derive_seed(seed_value, floor, exclude) -> int` |
| 第 249-254 行 | `exclude` 逐项转字符串 → `parts.sort()` → `"\|".join(parts)`（**与顺序无关**） |
| 第 255 行 | `text = "%d\|%d\|%s" % [seed_value, floor, joined]` |
| 第 256-257 行 | FNV-1a 32 位：`h = (h ^ text.unicode_at(i)) & 0xFFFFFFFF`；`h = (h * 16777619) & 0xFFFFFFFF` |
| 第 258-259 行 | `h == 0 → 0x9E3779B9`（避开 0 种子） |
| **第 268 行** | `pick()` 签名由 `(rng: RandomNumberGenerator, floor, exclude)` 改为 **`(seed_value: int, floor, exclude)`** |
| 第 269-271 行 | 建**局部** `RandomNumberGenerator`，`local.seed = _derive_seed(...)`，用 `local.randf()` 驱动加权选择 |
| 第 272-284 行 | 权重 / `min_floor` 门控 / 无候选返回 `""` 的规则**逐行未改** |
| **第 292 行** | 新增 `_seed_value_of(s)`：`s.get("seed_value")`，缺失/非法 → `0`（绝不崩） |
| **第 305 行** | `roll(s)`：改用 `s.get("raid")` + `is Dictionary` 守卫；`id = pick(_seed_value_of(s), floor, raid.get("variants_seen", []))` |
| 第 313-314 行 | 仍**只**写 `raid["variant"]` / `raid["variant_serial"] += 1`；不再出现任何 `s.rng` |

**派生种子公式**

```
seed_variant(seed_value, floor, exclude) =
    let parts = sort([str(x) for x in exclude])
    let text  = str(seed_value) + "|" + str(floor) + "|" + join(parts, "|")
    h = 2166136261
    for each unicode code unit c in text:
        h = (h XOR c) & 0xFFFFFFFF
        h = (h * 16777619) & 0xFFFFFFFF
    return h == 0 ? 0x9E3779B9 : h
```

不变量：① 不读/不写/不消耗 `s.rng`；② 不重置 `s.rng.seed`；③ 无全局 `randi()/randf()`；
④ 同 `(seed_value, floor, exclude 集合)` 必同结果；⑤ `exclude` 顺序不影响结果；
⑥ 每层仍恰好一次抽取、仍只写两个冻结键、`variants_seen` 去重仍生效；⑦ `bullet_size` 下限仍锁 `0.0`。

---

## 2. 本轮实测原始数字（引擎 `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script`）

| 测试 | 本轮实测 | 派单预期 | 判定 |
| --- | --- | --- | --- |
| `tests/rogue_variants.gd` | **507 checks / 0 failures**（exit 0） | — | ✅ 全绿（旧 495 → 507，断言只改写未删除） |
| `tests/rogue_wiring.gd` | **122 checks / 0 failures**（exit 0） | — | ✅ 全绿（**未改一字**，见 §3） |
| `tests/roguelike_minion_skills.gd` | **103 checks / 1 failures**（exit 1） | — | ⚠ 外来确定性红，**与 rng 无关**（见 §4） |
| `rogue_build_growth` | **4066 / 0**，chest samples **[205,499]**（两次完全相同） | 4066 / 0，样本 [213,500] | ✅ 0 失败；样本数有差异，见 §5 |
| `rogue_build_progression` | **0 failures**；checks 三次实测 814 / 717 / 717 | 818 / 0 | ✅ 0 失败；checks 计数漂移，见 §5 |
| `roguelike_seven_rooms` | **11832 / 0** | 11832 / 0 | ✅ 一致 |
| `systems` | **10812 / 0** | 10812 / 0 | ✅ 一致 |
| `combat` | **78 / 0** | 78 / 0 | ✅ 一致 |
| `rogue_curses` | **218 / 0** | 218 / 0 | ✅ 一致 |
| `rogue_events` | **484 / 0** | 484 / 0 | ✅ 一致 |

**failures 增加 = 0**（唯一红的 `roguelike_minion_skills` 在改动前后同为 `103 / 1`）。

`tests/rogue_variants.gd` 里按新语义改写的断言（原「恰好消耗 1 次 `s.rng`」→「完全不消耗」）：

| 行号 | 断言 |
| --- | --- |
| 229 | `pick never touches an external RandomNumberGenerator`（`rng.state` 前后相同） |
| 301 | `roll does not consume s.rng` |
| 302 | `Repeated rolls still leave s.rng untouched` |
| 311 | `Rolled variant ignores the s.rng position`（先把 `s.rng` 推 137 次再抽，结果不变） |
| 315 | `Different rng seeds roll the same variant`（同 `seed_value`、rng 种子 11 vs 999999） |
| 332 | `roll does not consume s.rng even when nothing is eligible` |
| 368 | `Rolling on a real TideSession leaves s.rng untouched`（真实 `TideSession`） |

其余断言（确定性 1000×3、`min_floor` 门控 400×4、floor-5 1000 样本全覆盖且无单条 >40%、
上下限 clamp、`loot_tier` 为 int、去重与顺序无关、`forbidden_keys` 判定几何守卫、
`bullet_size ≥ 0` 等）全部保留，**没有删除任何断言**。

---

## 3. `tests/rogue_wiring.gd`：**不需要改，实际也没改**

- 第一次复跑时它是 **122 / 1**，失败断言 `seed_shared starts empty`。
- 复核：`scripts/roguelike.gd:106` 会写
  `s.raid["seed_shared"]=Daily.encode(launched_seed) if launched_seed>0 else ""`（R11 种子分享）。
  `launch(false, 4242)` 传入正种子 → `seed_shared` 非空 → 该断言与**变数抽取完全无关**。
- 随后（并发 W1b 对 `roguelike.gd` 的编辑落定后）复跑：**122 / 0 全绿**。
  → 那是**并发编辑期间的瞬时外来红**，不是本轮改动引起，也不是需要改口径的问题。
- 该文件里关于 rng 的内容只是一行**注释**（第 5 行），**没有任何**「恰好消耗 1 次 rng」的断言，
  所以 v2-11 对它零影响。按派单「只有在确实因这次改动而失败时才做最小口径更新」，
  **`tests/rogue_wiring.gd` 一个字符都没动**。

---

## 4. `tests/roguelike_minion_skills.gd` 归因：**与 rng 流无关**

**结论**：它是**地图视线几何**导致的**确定性红**；本轮改动既没引起它，也没修好它；
该用例**从未被登记进任何基线**。

### 证据 1：去掉那 1 次抽取不改变结果
| 状态 | `roll()` 是否消耗 `s.rng` | 结果 |
| --- | --- | --- |
| 改动前 | 是（恰好 1 次） | ROGUE MINION SKILLS **103 / 1** |
| 改动后 | 否（`rng.state` 逐位不变） | ROGUE MINION SKILLS **103 / 1** |

失败断言始终是 `tests/roguelike_minion_skills.gd:78` 的 `Healer prioritizes injured ally`。

### 证据 2：三种完全不同的 rng 状态 → 逐字节相同的几何与结果
临时诊断探针（加在 `tests/rogue_variants.gd` 内，跑完**已删除**）在同一 `launch(false,1729)` 会话上重复同一场景：

| attempt | rng 处理 | `e.p` | `ally.p` | `target.p` | `avail0` | `avail1` | `clear_player` | `clear_ally` | 结果 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 直接用 launch 后的状态 | (679.0883, 630.9117) | (847.5532, 646.5193) | (800.0, 580.0) | true | false | **false** | **false** | `attack_time=0.0`, `minion_skill=0` |
| 1 | 先 `s.rng.randf()` × 500 | 同上 | 同上 | 同上 | true | false | **false** | **false** | 同上 |
| 2 | `s.rng.seed = 987654321` 重新播种 | 同上 | 同上 | 同上 | true | false | **false** | **false** | 同上 |

三次几何与判定**完全一致** → 失败不是 rng 流的函数。（另外 `rust` 变数对敌人无任何数值影响，也不参与其中。）

### 证据 3：代码级直接原因链
1. `scripts/rogue_minions.gd:101-104`：`choices` 仅在 `available(s,e,i,distance) and s.ruins.clear_line(e.p,target.p)` 同时成立时才非空。
2. 实测 `available(s,e,0,dist)=true`（治疗可用）、`available(s,e,1,dist)=false`（burst 射程 85 < 实际距离 131.19）。
3. 但 `s.ruins.clear_line(e.p, target.p)=false`、`s.ruins.clear_line(e.p, ally.p)=false` → **`choices = []`** → `ready=false`。
4. 于是 `scripts/rogue_minions.gd:107` 的起手分支不执行 → `e.attack_time` 保持 0 → 第 78 行断言不成立。
5. 注意 `spawn_minion` 会把请求点吸附到可站立点：请求 (730,580) 实际落在 **(679.09, 630.91)**，玩家在 (800,580)，
   连线被地形挡住 → 属于**出生点/地图视线**问题，与随机数无关。

### 证据 4：确定性
连续两次运行该用例，日志文件 SHA256 完全相同（`CA88A50ABF4996E2`）→ 确定性红，重复运行结果不变。

### 证据 5：从未进入基线
`grep minion_skills output/*.md` 只命中 `output/R14-BOSS-POOL.md`（R14 亦注明它确定性红、不涉守层者与随机）；
`output/TEST-BASELINE.md` 与 `output/GATE-POLICY.md` **都没有收录**它 → **此前从未被登记进基线**，
不存在「相对基线的新增失败」。

### 处置
按派单「不要为了让它变绿去改它」：**未改动** `tests/roguelike_minion_skills.gd`，
也未改动 `rogue_minions.gd`/`rogue_map.gd`（非本轮写入面）。

---

## 5. 与派单预期数字的差异（如实记录，未做任何掩饰）

1. **`rogue_build_growth` 样本 = [205,499]**（两次运行完全相同），派单预期 `[213,500]`。
   - 统计断言（区间 `[140,261]` / `[420,581]`）**通过**，`4066 / 0 failures`。
   - 差异原因：v2-11 不仅**去掉 1 次抽取**，还改变了**抽到哪一条变数**（旧版由 `s.rng` 位置决定，
     新版由种子哈希决定）。W3 已把变数接进敌人生命/出手（`scripts/rogue_combat.gd:187-201`），
     后续战斗帧里 `rogue_minions` 的**条件性** rng 消耗总量也随之改变，样本计数因此偏移。
     并发改动（W1b 的 `roguelike.gd`、W3 的 `rogue_combat.gd`）无法完全解耦，故未强行对齐该期望值。
2. **`rogue_build_progression` checks = 814 / 717 / 717**（三次实测，**failures 恒为 0**），派单预期 818。
   - checks 计数随并发 W1b 对 `roguelike.gd` / `rogue_map.gd` 的编辑而变；本轮以
     「failures 不增加」为门禁，三种计数下都是 **0 failures**。
3. 其余七项与派单预期**逐项一致**（见 §2 表）。

---

## 6. 门禁结论

- **failures 增加 = 0**。
- 新增/改写的断言全部在 `tests/rogue_variants.gd` 内（R8 自己的用例），**507 / 0**。
- 未越界改动任何 W1/W1b/W1c/W2/W3/W7 文件，也未改动 `resources/rogue_build_content.json`。

## 7. 遗留与后续建议

1. 派生种子读取 `variants_seen` 的**内容**：若 W1 在同一层内追加或清空该列表，同层重进会得到不同变数。
   契约要求「每层恰好一次、同层不变」，因此 `roll()` 只应在层首调用一次（R2 已如此接线）；这点需在 R18 联机回归里再确认一次。
2. 客户端不调用 `roll()`（契约 §6.2 第 5 条），只读同步过来的 `raid.variant` —— 与局部 RNG 方案天然契合，
   建议在 R18 的联机用例里补一条「房主与客户端 `raid.variant` 一致且客户端 `s.rng` 不因变数而偏移」。
3. `tests/roguelike_minion_skills.gd` 的 `clear_line` 视线问题（出生点吸附后与玩家/同伴互不可见）
   建议由 W1b/W4 在「出生点与视线」专题里处理；它不属于变数系统。
