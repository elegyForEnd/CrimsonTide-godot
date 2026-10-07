# 满行囊体验陷阱（full reserve trap）

## 现象（第三方已脚本复现）
备用行囊塞满 12 件时，个人报价的「领取」会被 `equip()` 拒绝，但：
- `apply_offer()` 只返回 `false`，**没有回传原因**；面板上唯一的反馈是一条会飘走的 toast；
- 选择因此一直挂着（奖励没丢，这点是对的），而 `loot_interact()` 的「有未决选择不许拾取」守卫
  让那只报价继续留在原地，**房间推进不了**；
- UI 侧唯一的逃生口是「丢给队友」→ `rogue_selection_drop`，它只在**先选中一张卡**之后才可用，
  文案也不像"放弃"，玩家很容易以为卡死。

## 改动（最小面）

### `scripts/roguelike.gd`
| 行 | 内容 |
|---|---|
| 639 / 644 | `apply_offer()` 保持 `bool` 签名（多处调用方与测试依赖），内部改为 `apply_offer_reason()==""`；新增 `apply_offer_reason()` **返回 "" 或面向玩家的原因** |
| 671 / 678 | 新增 `equip_refusal()`：满行囊时给出**两条明确出路**（Tab 里丢弃后领取 / 按「放弃本次」跳过），其余装备失败给出物品名 |
| 632 | 地面报价拾取失败时同样回传原因（原来只有 `equip` 的 toast） |
| 687 | 任何**新意图**都清掉上一次的拒绝原因；该行在防重放守卫**之后**，过期点击因此保持零副作用 |
| 703 | 新增 `rogue_selection_abandon`：**不需要先选卡**，清空选择并走与成功领取**完全相同**的记账（`next_personal`/`reward_claims`/`finish_rewards`/`revision+=1`），保证房间能推进；**不放地面掉落**——带报价的地面掉落会被 `finish_rewards()` 拦住，等于重建同一个死局 |
| 723-727 | 领取失败时把原因写进 `selection["error"]`，选择**保持打开**（奖励不丢） |
| 858 | 商店购买被拒时也说明原因（原先静默返回） |

### `scripts/rogue_reward_ui.gd`
| 行 | 内容 |
|---|---|
| 19-20 / 133-146 | 新增提示行 `RewardNotice` + 深色底板 `RewardNoticePlate`（压在华丽边框上仍然可读） |
| 215 / 218 | 个人报价的第四格按钮从"放回秘藏"（个人报价被禁用→无路可走）改为 **「放弃本次 · 不领取」**，永远可点；非个人报价保持"放回秘藏"。命名 `RewardAbandon` |
| 247-262 | `_refresh_notice()` / `_process()`：面板不会因拒绝而重建（重建签名只跟 id/version），因此原因**逐帧从 session 读取**（客户端快照会整表替换 `players`，读旧引用会拿不到）；顺带在**点击之前**就把"行囊已满 12 件"警告显示出来 |

硬约束遵守：奖励数值与掉落规则未动、`raid.revision` 守卫与防重放保持、未新增 `s.rng` 消耗、判定几何未动。

## 验证（在"不要测试"指令到达前已完成，结果留档）
- headless `tests/rogue_full_bag.gd` → **22 checks / 0 failures**；
  **负向对照**：临时把 `abandon` 改成空实现 + 不发布原因 → **22/5 failures**（正好是守住新行为的 5 条），随后已还原。
- 视觉 `tests/rogue_full_bag_visual.gd` → **8 checks / 0 failures**，
  截图 `build/rogue-full-bag-notice.png`：深色条上写明「备用行囊已满 12 件 · …或按『放弃本次』跳过」，
  右下角按钮为「放弃本次 · 不领取」。
- 回归（当时）：`rogue_build_progression 727/0`、`rogue_hooks_roguelike 85/0`、`final_e2e_roguelike 120/0`、
  `rogue_ui 163/0`、`rogue_wiring 122/0`、`systems 10812/0`、`roguelike 153/0`、`rogue_build_pack exit 0`。
- 按后续缩范围指令：`tools/run_rogue_gate.ps1` 的那一行登记**已移除**；两个新用例文件仍留在 `tests/`
  （已跑绿、零额外成本），如需清零可直接删除。

## 玩家现在怎么离开这个房间
选不选卡都行——**点右下角「放弃本次 · 不领取」**即可跳过这次秘藏并让房间推进；
想留住奖励就**按 Tab 在行囊里丢弃一件**，再点「领取奖励」；
想把卡让给队友则选中卡后点「丢给队友」（该路径按原设计会留一个地面掉落）。
