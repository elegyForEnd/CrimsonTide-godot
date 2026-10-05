# TRIAGE：三个门禁外红用例（rogue_chest_rewards / rogue_inventory / rogue_equipment）

**一句话结论**：三条全部是**既存的测试夹具过期 / 被桩化的功能**，**不是本轮肉鸽拓展引入的**，也**不会让玩家在正常游玩时崩溃**。
**未修改任何实现文件、未修改任何测试。**

复现（引擎不在 PATH，本机无 `pwsh`，用 `& .\tools\...` 风格调用）：

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit-after 20000 --script tests/<n>.gd
```

原始日志：`build/triage/rogue_chest_rewards.log`、`build/triage/rogue_inventory.log`、`build/triage/rogue_equipment.log`
一次性探针：`build/triage/probe.gd` → `build/triage/probe.log`

---

## 1. `tests/rogue_equipment.gd` — `Invalid access to property or key 'passive'`（:29）

**事实（探针 P2）**
- `Equipment.GEAR = Content.data.gear`；`GEAR[0].keys = [id,name,slot,template,text,hp,mana,speed,damage,defense,crit]` → **没有 `passive`**；`ENGRAVINGS[0].keys = [id,name,tag,text]` → 也没有。
- `resources/rogue_build_content.json` 全文 `"passive"` 出现次数 = **0**。
- `scripts/rogue_equipment.gd` 是 **61 行桩**：`damage_multiplier()` 恒返回 `1.0`，`tick/spent/hit` 全是 `pass`。

**归属：既存（非本轮引入），证据是哈希级**
- `git hash-object scripts/rogue_equipment.gd` = `a8986300fc842debe98131e9001bfb8439503f01` = `git rev-parse HEAD:scripts/rogue_equipment.gd` → **与 HEAD 逐字节相同**；`git ls-files -v` 为 `H`（没有 skip-worktree/assume-unchanged 掩码）。
- `tests/rogue_equipment.gd`、`scripts/rogue_content.gd`、`resources/rogue_build_content.json` 均**不在** `git status` 改动清单里。
- ⇒ 决定这条失败的**三份输入（测试、实现、内容表）全部与 HEAD 一致**，本轮改动不可能造成它。

**玩家影响：无崩溃。** 对 `.passive` 的硬访问只存在于测试；运行时唯一读取处 `scripts/rogue_equipment.gd:41` 用的是 `.get("passive","")`。

**⚠ 但它暴露一个既存的真实功能缺口（不是崩溃，是「装备被动永远不生效」）**
- `scripts/session.gd:547 / :561 / :3461` 真的在查 `RogueEquipment.has(p,"clear_mind" / "last_stand" / "mana_guard")`；
- `has()` 的实现是 `definition(item).get("passive","")==passive`，而数据里没有 `passive` 键 → **这三个装备被动永远不会触发**；
- 加上 `damage_multiplier()` 恒 1.0，装备/铭刻的被动伤害体系等于没有实现。
- 修它需要设计决策（把内容表的 `template`（A1…A5）映射到被动名，或让 `tools/build_rogue_content.py` 补 `passive` 字段），属于重建 72 件装备 + 48 件武器铭刻的被动体系，**超出本次 triage 范围；我没有擅自发明映射或数值**（避免污染平衡与内容生成物）。

---

## 2. `tests/rogue_inventory.gd` — 9 条断言失败 + `Invalid access ... 'rogue_damage'`（:72）

### 根因 A（前 8 条失败）：测试按旧的「药品是可携带物品」建模
- 实现：`scripts/session.gd:643` 在魔境把 `medicine` 映射为 `int(p.flask)/25`；`scripts/rogue_build.gd:19` 把开局 `flask` 设为 **100.0**。
- 探针 P1：`flask=100.0`、`carried_medicine=**4**`、`spend_medicine=**false**`。测试 :26 期望 `==1`（=旧的 25 点药品），实际 4。
- `scripts/session.gd:662` 在魔境对 `spend(p,"medicine")` **恒返回 false**；治疗走 `RogueBuild.commit_flask()`（`flask_time` 提交制，见 `rogue_build.gd:1006-1011`），所以 `s.perform(1,"heal")` 不会消耗药品 → :28/:31/:33/:37 一连串期望连锁失败。

### 根因 B（:72 硬错误）：测试手工构造的 offer 形态已过期
- 测试第 70 行手工塞入 `{"boon":BOONS[0],"name":"test","desc":"","price":0}`；
- `apply_offer`（`scripts/roguelike.gd:633-663`）只认 `attribute_points` / `talent_id` / `flask_refill` / `item`，其余一律 `return false` → 选择未被应用 → `p.rogue_boons` 仍是 `{}` → 第 72 行 `p.rogue_boons.rogue_damage` 报「Invalid access」。
- 探针 P4：`BOONS[0] = {"name":"赤刃誓约","stat":"rogue_damage","value":0.12}`（测试期望的 `stat` 本身是对的），`rogue_boons={}`。

### 归属：既存（非本轮引入）
- `git diff -U0 -- scripts/session.gd` 的改动区间只有：74-77、109-120、435-436、472-507、551-560、1560、2679-2680、3050-3052、3413 —— **`carried`(643)/`spend`(662) 所在的 640–670 区间不在任何 hunk 内**。
- `git diff -U0 -- scripts/rogue_build.gd` 只有**一个** hunk：858 行（R5 的 `award()` 核心发放改动）；`"flask":100.0`（第 19 行）在 HEAD 与工作副本**逐字相同**。
- `apply_offer` 落在 `roguelike.gd` 的未改动区间（hunk 从 `@@ -378 +601,4 @@` 直接跳到 `@@ -471,0 +698,3 @@`，即 602–697 未动）。
- `tests/rogue_inventory.gd` 未列入 `git status`。

### 玩家影响：无崩溃
`scripts/rogue_inventory.gd:125` 用的是安全读取 `p.get("rogue_boons",{}).get(boon.stat,0)`；真实 offer 由 `reward_offers()` 产出并带 `item`/`talent_id`，不会走测试这条手工路径。药品/flask 是**设计变更**（绑定血瓶 100 点、commit 制），不是坏掉的代码。

---

## 3. `tests/rogue_chest_rewards.gd` — 3 条失败 + `reward_drops[0]` 越界（:41）

**根因（探针 P5）**
- `solo`+`launch` 后阶段是 `rogue_prepare`，玩家身上带着**开局三选一武器**的 `rogue_selection`（实测 `category:"starter"`、`id:2`、3 个 offer）；测试从不派发这个选择；
- `loot_interact`（`scripts/roguelike.gd:587`）首行守卫：`if p.status!="active" or not p.get("rogue_selection",{}).is_empty(): return` → **直接返回**；
- 实测：玩家站在箱子正上方 `perform(1,"rogue_loot")` 后 `chest.opened=**false**`、`reward_drops.size()=**0**`；
- 于是 :33（`count==3`）、:36（三个分类）、:39（选择未被占用）三条失败，:41 的 `reward_drops[0]` 越界报错并终止。

**归属：既存（非本轮引入）**
- `rogue_prepare` 阶段在 HEAD `scripts/roguelike.gd:53` 已存在；`starter` 入队与 offer 构造在 HEAD `:49 / :331 / :334` 已存在；
- `loot_interact` 的**首行守卫**在 HEAD `:364` 与工作副本 `:587` **逐字相同**（该函数本轮的改动 hunk 落在属性灵晶掉率那一行 = `chest_drop` 钩子，不是守卫）；
- `tests/rogue_chest_rewards.gd` 未列入 `git status`。
- ⇒ 该用例写于「开局选武器」流程之前，必须先派发 starter 选择才能开箱。

**玩家影响：无。** 守卫语义正确（有待处理的选择时不允许拾取）；真人玩家在准备界面选完武器后 `rogue_selection` 清空，开箱、掉落 3 包（2 名玩家 × weapon/gear）与后续选择流程均按设计走。

---

## 修复决定

- **没有修改任何实现文件**：三条都不是本轮引入，也不是玩家会撞到的运行期崩溃/异常数值；它们是「测试夹具早于设计变更」与「被桩化的功能」。
- **没有修改任何测试**（按要求，交由用户自己测）。
- 唯一真实的玩家可见缺陷是 §1 的「装备/铭刻被动永不生效 + `damage_multiplier≡1.0`」，但它是**既存**的，且修它等于重建整套被动体系（需要 `template`→passive 的映射决策）。建议单独排一轮：先定映射与数值来源（`ROGUE-BUILD-SYSTEM-DESIGN.md` + `tools/build_rogue_content.py`），再改 `scripts/rogue_equipment.gd` 与内容生成器；**不要在 triage 里临时发明映射**。

## 证据清单

| 证据 | 位置 |
|---|---|
| 三个用例原始 stdout/stderr | `build/triage/<test>.log` |
| 一次性探针源码 / 输出 | `build/triage/probe.gd` / `build/triage/probe.log`（P1 flask=100,carried=4 / P2 GEAR 无 passive / P3 clear_room 后 drops=0 / P4 BOONS[0] / P5 箱子守卫原因） |
| HEAD 对照副本 | `build/triage/head-roguelike.gd`、`head-session.gd`、`head-rogue_build.gd`、`head-rogue_equipment.gd` |
| 哈希对照 | `git hash-object scripts/rogue_equipment.gd` == `git rev-parse HEAD:scripts/rogue_equipment.gd` |
| 改动区间表 | `git diff -U0 -- scripts/{session,roguelike,rogue_build}.gd \| Select-String '^@@'` |
