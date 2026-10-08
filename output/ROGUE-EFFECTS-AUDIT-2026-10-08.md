# 魔境闯关构筑效果审计（2026-10-08）

> 这是修复前的审计快照。后续修复状态与验收见 [构筑修复说明](ROGUE-EFFECTS-FIXES-2026-10-08.md)，下文“待处理”不代表当前源码仍存在该问题。

本次只核查源码与运行结算，未修改玩法数值/天赋实现，也未重新导出EXE。旧发行包是否与源码一致未验证。

## 结论

武器品质、+0～+5锻造和+3补正是真的生效：48把武器的实际伤害结算通过718项专项检查。问题集中在领取后静默未激活、独特被动的范围/首次/间隔/资源来源、变数被覆盖以及联机永久成长数据通道。不能把252条内容记录或图标存在等同于252条效果全部验收完成。

已逐项列出48武器、72装备、96天赋、24铭刻、12武器核心，共252条；另核查14永久成长、18层变数、10诅咒、9事件及32输入派生。以下完整目录中的“已接入”是静态找到执行入口，不等于逐项动态证明所有边界行为；异常标注关联本报告问题编号。21个定向观察全部复现，其中银鸦猎令间隔属于文字歧义；其余静态问题另列。32组问题不等于32个完全无效天赋。

## 武器升级到底加在哪里

`session.weapon_damage = 武器基础伤害 × 品质 × (1+属性补正) × (1+通用攻击池)`。

| 项目 | 实际规则 | 核查 |
|---|---|---|
| 品质 | 白/绿/蓝/紫/金/红：1/1.08/1.16/1.24/1.32/1.40 | 48把全部走damage_enemy验证 |
| 锻造 | 每级通用攻击池+0.03，+5为+0.15，成本1/1/2/2/2 | 48把全部验证+0～+5 |
| 稳锋 | +3后普攻/战技局部攻击池+0.04，Q不吃 | 48把普攻实伤验证；战技分支静态核对 |
| 属性补正升档 | +3后选一个非无补正/非S属性提高一档 | 每把选一个可升档属性实伤验证 |
| 武器核心 | +2可选、+4效果升档，按家族三选一 | 执行入口全核查，部分条件有问题见下 |
| 绑定 | 强化绑定instance_id；休整绑定转移，旧实例+0 | 48把不匹配绑定时实伤回基线验证 |

示例固定测试属性下W001：白色+0实伤61.470，白色+5为70.690，红色+0为86.058，+3稳锋为69.461。该测试是隔离暴击/状态/被动累积的固定单次结算，不是角色默认伤害或实战DPS。

+5不一定让最终总伤害再乘1.15：它与已有通用攻击加算共池。锻造升级不会自动提高武器品质，也不提高装备品质。转移锻造时会清空武器核心与补正分支，必须重新选择；品质则留在物品本身。界面“每层最多提升一级”实际上实现为等级不得高于层数，落后等级能在同一层补升多级，宜改成“上限为当前层数”。

## 实际玩法与预算

开局选择白色武器；普通清场/首领/宝藏箱给个人装备选择，灵契圣坛给天赋收藏与自动尝试激活。第二层首座圣坛给的是T类流派核心，WC武器核心在锻造页+2选择，两者不同。

修为最多18、激活最多8项、流派核心最多1项。进阶需同流派普通天赋；核心需该流派非核心等级投资至少2。天赋只有build_talents中的等级才会进入战斗，build_library仅是收藏；取到卡不保证激活。天赋升级也耗修为，未激活收藏最多12项。取卡失败原因应明确提示。

局内属性由打怪经验升级及宝箱灵晶获得：升级+2，普通/精英/首领经验2/6/20；灵晶20%/50%且每层最多2次。永久属性与英雄基础值叠加；40/70后边际降低。生命/集中力/耐力分别影响上限生命、法力、抗性；四项伤害属性只按对应武器补正产生伤害，给无对应补正的属性加点不会提高该武器伤害。安全区可分配、每层可重置一次，不能把升级经验误当作已分配属性。

状态按主人分组，出血/灼烧/冰缓/感电上限5，标记1。额外机制以P计算，刻意不吃普通攻击局部A加成；DoT每0.5秒结算。直击条件池上限60%、暴击率上限35%、额外回蓝4/秒、退蓝35%实际支出、5秒受疗15%生命/被动自疗10%、总护盾35%生命/最长6秒。这些预算会使部分叠加收益封顶，属于已实现的限制，不应直接归为失效；护盾来源混用则是额外错误。

## 问题清单

P1优先处理无效果/奖励丢失/错误数据通道与明显规则漏洞；P2处理范围、窗口和描述对齐。

### A01 · P1 · 所有进阶/核心天赋领取反馈

动态复现。apply_offer_reason把天赋收入build_library后调用activate，但忽略false；前置/修为/8槽/单核心限制失败仍返回成功。实际进阶T007领取成功但build_talents无此ID，战斗当然不生效。奖励领取必须区分已激活和仅收藏，并显示具体原因。

入口：`scripts/roguelike.gd:776` `apply_offer_reason()`。

### A02 · P1 · 血月/静滞的敌人伤害修正

动态复现。enemy_budget读取合并后的enemy_damage却clamp到[-0.95,0]，正向增伤被截成0；无成长时血月+15%、静滞+8%缺失。若同时有成长减敌伤，正变数还会抵消成长减益而非独立正确生效。实际攻击读的正是该build_damage_scale。

入口：`scripts/rogue_build.gd:1096` `enemy_budget()`。

### A03 · P1 · 变数生命覆盖/重复应用

动态复现。setup_boss先应用变数并置variant_stats_applied=true，enemy_budget覆盖hp/max_hp时合并enemy_hp只保留负值；顽石+20%首领加成丢失，标记阻止补应用。普通怪setup_minion未传s，enemy_budget已应用负变数，update又补乘一次：狂暴应×0.92实际×0.8464；圣佑应×0.90实际×0.81。正变数普通怪在补应用时生效，负变数首领在budget生效一次。

入口：`scripts/rogue_combat.gd:98` `setup_boss()`。

### A04 · P1 · 赌徒/镜像获得的灰烬入库

动态复现。apply_room_delta只增加p.rogue_ash_run；Growth.grant只向profile.ashes加本次基础结算值，未把已有房间灰烬入库。探针已有50房间灰烬，局内总数为基础值+50，永久钱包却只收到基础值。联机入库还需另验。

入口：`scripts/rogue_growth.gd:244` `grant()`。

### A05 · P1 · 余烬守誓代价范围

动态复现。说明自身所有直接伤害×0.88，实际penalty只在normal分支；右键和Q不付这项代价，反伤例外倒是正确。

入口：`scripts/rogue_build.gd:440` `hit_multiplier()`。

### A06 · P1 · 晨光裁敌加伤范围

动态复现。治疗成功确实授予healed=10/15%，但只在normal分支读取和消耗。右键/Q完全不吃下次直击加伤，也不消耗它。

入口：`scripts/rogue_build.gd:440` `hit_multiplier()`。

### A07 · P1 · 星泉共鸣对Q的加成

动态复现。法术判断包含ctx.kind==skill，所以高蓝Q也获得18%条件加伤；内容表明确写不加Q伤害。

入口：`scripts/rogue_build.gd:440` `hit_multiplier()`。

### A08 · P1 · 冥火指令锁定目标

动态复现。U事件仅授予soul_order伤害加成，未授予soul_target。现有灵体继续追soul_focus/自动目标；hero_skill命中后更新focus不等于立即按瞄准锁3秒。不能把墓煜角色连招中的soul_target实现算给T086。

入口：`scripts/rogue_build.gd:740` `action_event()`。

### A09 · P1 · 星环落地减蓝耗

动态复现。落地授予landing_cost要求air_attacks>0，只空中右键成功不会触发；描述是跳跃施法成功。landing_cost还在首次任意普攻命中后删除，支付后空挥则保留，资源消耗时机也不统一。

入口：`scripts/rogue_build.gd:835` `tick()`。

### A10 · P2 · 寂冬裂晶触发时机

动态复现。普通怪叠满冰缓立即proc，然后才经历stagger；应为冻结结束追加伤害。Boss满层立即触发符合说明，不能一起后移。

入口：`scripts/rogue_build.gd:288` `add_status()`。

### A11 · P2 · 冻结被动共用错误计时

动态复现。三个效果没有各自8秒ready，而是跟随build_cc_until。T040把硬控间隔减为6秒/E038减为7秒时，它们也能6/7秒再触发，违背各自8秒描述。

入口：`scripts/rogue_build.gd:288` `add_status()`。

### A12 · P2 · 闪避追击缺4秒间隔

动态复现。每次D直接授予dodge_strike/dodge_window，没有4秒ready；约2秒闪避再次获得加成。T075和I020自身都明写4秒，W005也没有对应计时键。

入口：`scripts/rogue_build.gd:740` `action_event()`。

### A13 · P2 · 银月细剑非首次攻击

动态复现。W005读取持续2秒的dodge_window，首次攻击后不删除；窗口内第二次及后续普攻也加16%。

入口：`scripts/rogue_build.gd:440` `hit_multiplier()`。

### A14 · P2 · 雷翼轻甲窗口缩水

动态复现。文本3秒，实际复用dodge_window=2秒；2.5秒普攻不能叠感电。

入口：`scripts/rogue_build.gd:522` `hit_event()`。

### A15 · P2 · 断誓锁甲家族限制缺失

动态复现。受击授予通用counter，所有家族normal都读；法杖也吃20%加伤。应单独限定重刃，不能顺便限制T069共享counter。

入口：`scripts/rogue_build.gd:714` `incoming()`。

### A16 · P2 · 血棘绑腿遗漏战技/Q

动态复现。说明直击自己的出血目标后减伤，实际放在if normal；右键/Q命中不触发。E010的同类冰缓减伤放在normal外，能正常覆盖直击。

入口：`scripts/rogue_build.gd:522` `hit_event()`。

### A17 · P2 · 盟约旗扣多人时自触发

动态复现。实际自己art无论单人多人都回蓝，同时也监听其他队友；文本仅单人允许自身art触发。

入口：`scripts/rogue_build.gd:522` `hit_event()`。

### A18 · P2 · 泉眼回响进度溢出

动态复现。只有ready成功分支才扣40并钳制39，冷却期间继续扣蓝可留下80等超阈值进度。应在每次累计时处理上限和单次储存。

入口：`scripts/rogue_build.gd:257` `spend_event()`。

### A19 · P1 · 不同护盾来源相互覆盖

动态复现。大量shield调用省略source，全部写general；两种4%/6%来源实际合为6%，而非共用35%上限下合为10%。Q原盾、T094、T096、I021、WC005等互相覆盖或延长持续时间，违背不同来源分别刷新。

入口：`scripts/rogue_build.gd:221` `shield()`。

### A20 · P2 · 银鸦猎令22%是否受3秒间隔

动态观察/规则歧义。额外22%条件伤害对每次标记攻击都生效，只有跳击受3秒ready。当前文字把22%与跳击写在同一句末尾，容易理解为整体ICD；需明确两者是否共用间隔后再改数值。

入口：`scripts/rogue_build.gd:440` `hit_multiplier()`。

### A21 · P2 · 烛火祭袍持续上限

静态确认。文本说刷新最多5秒，实现所有灼烧延长统一min(6,...)；E008与T026/E035/I011组合可超5秒。先统一装备和全局上限的设计。

入口：`scripts/rogue_build.gd:288` `add_status()`。

### A22 · P2 · 移动惩罚描述不一致

静态确认。E018只在轻刃active_attack无条件把.8改1.0，没有检查闪避后2秒，且不作用于重刃；E055代码仅pending_strike前摇时减罚，不覆盖整个挥击。W015的-30%则通过重刃默认.7实现，不是未实现。

入口：`scripts/session.gd:3318` `move_player()`。

### A23 · P2 · 烛影灰履没有铺闪避路径

静态确认。D开始只在起点field一次，非沿闪避轨迹；两处火点上限由全局build_fields.size>=2控制，和E036/T032/Q区域共享，两块其它区域存在时鞋子被动直接失效。

入口：`scripts/rogue_build.gd:740` `action_event()`。

### A24 · P2 · 一次性窗口及间隔不统一

静态确认。T079用整个dodge_window，无首个右键消费标记；E070跟随perfect全局3秒而非自身5秒；WC007装填加速5秒后过期，文本说持续到一次装填，且任意闪避授予而非只在滑射后。

入口：`scripts/rogue_build.gd:703` `perfect()`。

### A25 · P2 · 敌方灼烧抗性未消费

静态确认。T028/E007在roguelike岩浆分支读取；敌人持续区域统一hurt(...,direct,element)，没有敌方burn/DoT对应的专用抗火消费点。岩浆减伤确实有效，但不能据此声称敌方灼烧抗性已完成。

入口：`scripts/roguelike.gd:492` `tick()`。

### A26 · P2 · 烛火蔓延可再次传播

静态确认。killed允许dot击杀，传播施加的burn没有来源/不可传播标记；后继burn杀敌仍可重新经过同一个传播分支。需要单独标记传播来源，保持原生灼烧击杀正常。

入口：`scripts/rogue_build.gd:1222` `killed()`。

### A27 · P2 · 锈蚀/天启作用于所有输出

静态确认。变数文本普攻-10%/+15%，damage_enemy对所有kind（含战技/Q/proc/DoT/召唤）乘player_damage，不检查attack。同键还被永久成长猎杀本能使用，不能直接全局限制这个键。

入口：`scripts/session.gd:3522` `damage_enemy()`。

### A28 · P2 · 群狼精英率不是概率

静态确认。+12%通过round(delta/.12)转换成精英房固定多1名，只在elite房执行；普通房不因此出现精英。需把描述改为实际的固定精英数，或实现真实概率。

入口：`scripts/roguelike.gd:377` `spawn_wave()`。

### A29 · P2 · 法杖折光CM14缺独立120单位修正

静态确认。识别ADS并有标签/分段，但start_art/resolve_art没有法杖route1的目标点修正逻辑；仍用通用aim_point。不能把序列识别通过当作该派生特性实现。

入口：`scripts/rogue_actions.gd:13` `start_art()`。

### A30 · P2 · 升空共享冷却绕过寂冬契约

静态确认。resolve_art升空分支硬写build_cc_until=elapsed+8，未读取T040/E038；冻结和升空虽共享字段，但缩短硬控间隔的配置不能统一生效。是否要让装备同时缩短升空需设计确认。

入口：`scripts/rogue_actions.gd:95` `resolve_art()`。

### A31 · P2 · 补正升档没有在属性页展示

静态确认。Build.grades参与真实weapon_scaling，属性页补正文案却用Catalog.scaling_text原始表，不显示+3升档后的等级；玩家可能看起来没有升级效果。

入口：`scripts/rogue_build_ui.gd:89` `attribute_sheet()`。

### A32 · P1 · 永久成长以房主数据作用全队

静态确认/联机待动态验证。session.rogue_mods固定读session.profile_data；reset开局钱包和刷新也是同一meta给全体玩家，没有按玩家成长数据。客户端自己的购买只本地保存，无法成为权威数值输入；专用服无profile时成长全零。单机生效不能代表多人每个人买的都生效。

入口：`scripts/session.gd:496` `rogue_mods()`。

## 残留接口与设计未完成项

- 旧BOONS五祝福没有生产发放点，行囊旧祝福页也无入口，属于被新版天赋替代后的兼容残留；不应当成可获得的新加成。
- rogue_equipment.damage_multiplier/tick/spent/hit为旧空接口，生产没有调用，真正被动在rogue_build及session/roguelike等处。不要为了“让空接口有效”再接一次，容易重复吸血/伤害。
- 16条家族输入路线与16条角色路线均有识别代码，已有测试主要证明输入识别/冷却，而非每项几何、落地时机和动画效果。CM14的专用修正缺失已列A29。角色hero_effect有伤害、状态、盾/治疗和魂指令；需要逐条实际操作验证。
- 设计文档的30秒安全靶区、新锻造等级的逐步教学/终式回放未找到对应完整生产流程；现有连招手册/只读预览不能当成已完成这些教学。
- 32角色/家族连招未对真实操作容错、帧率及网络延迟逐项验收；本报告没有把这部分说成已全通过。

## 全量252项目录

下表原文取当前运行JSON。代码入口行号是本次源码位置；未改动运行脚本。天赋领取问题A01适用于所有需前置/预算的卡片，而非只有示例T007。装备还会通过rogue_equipment.value/total提供数据表中的HP/MP/移速/攻击/防御/暴击基础属性。

### 48武器

| ID/名称 | 运行描述 | 结论 | 执行入口 |
|---|---|---|---|
| W001 绯红单手剑 | 第三段普攻加 1 层出血，单目标每根一次；战技：绯红回旋·环，倍率2.0，蓝耗16.0，CD5.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:615` hit_event；`rogue_build.gd:1152` hero_effect |
| W002 鸦喙刺剑 | 仅宽 26 的直线突刺；未命中不积连击；穿透后续 ×0.70；战技：鸦喙穿心，倍率2.1，蓝耗16.0，CD5.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:1162` hero_effect |
| W003 回环弯刀 | 周身圆斩；第二目标起 ×0.70，保留第三段倍率；战技：回环风轮·环，倍率1.8，蓝耗18.0，CD5.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:1167` hero_effect |
| W004 血棘双刃 | 每第 3 次攻击命中加出血 2 层；基础连击第三段改为 ×1.20；战技：血棘刺绣，倍率2.2，蓝耗18.0，CD5.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:616` hit_event |
| W005 银月细剑 | 闪避后 2 秒内第一次普攻条件加伤 +16%，ICD 4 秒；战技：银月返刃，倍率2.0，蓝耗16.0，CD5.0 | 部分不符：A12/A13 | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:501` hit_multiplier |
| W006 烛影短刀 | 自己攻击带灼烧目标时条件加伤 +10%，不自带灼烧；战技：烛影掠火，倍率2.1，蓝耗16.0，CD5.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:502` hit_multiplier |
| W007 星霜佩剑 | 普攻命中加冰缓 1 层，ICD 0.8 秒；战技：星霜刺庭，倍率1.8，蓝耗18.0，CD5.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:617` hit_event |
| W008 鸣电军刀 | 第三段加感电 2 层；战技：鸣电突进，倍率2.0，蓝耗18.0，CD5.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:618` hit_event |
| W009 断誓直剑 | HP<50% 时普攻条件加伤 +14%；不增加回复；战技：断誓裁决，倍率2.1，蓝耗18.0，CD6.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:503` hit_multiplier |
| W010 镜花曲剑 | 每第 4 次普攻命中，在原目标追加 0.15P，ICD 2 秒；战技：镜花折返·环，倍率1.9，蓝耗18.0，CD5.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:619` hit_event |
| W011 葬铃仪剑 | 右键成功施放后 3 秒内下一次普攻命中回 3 蓝，ICD 5 秒；战技：葬铃归声，倍率2.0，蓝耗16.0，CD5.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:620` hit_event |
| W012 黑曜戒律剑 | 普攻基础破势 +4；第三段不再 ×1.4，改 +20 破势；战技：黑曜审判，倍率2.3，蓝耗20.0，CD6.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:613` hit_event |
| W013 破晓双手剑 | 对 HP≥90% 的目标普攻条件加伤 +12%；战技：破晓震荡，倍率1.8，蓝耗22.0，CD6.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:504` hit_multiplier |
| W014 断潮巨刃 | 140° 宽扇面；第 2 目标起 ×0.70，击退 60；战技：断潮开山，倍率1.7，蓝耗24.0，CD6.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art |
| W015 裂地重剑 | 圆形普攻；第 2 目标起 ×0.65，移动施放速度 -30%；战技：裂地崩震·圆，倍率1.8，蓝耗24.0，CD7.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art |
| W016 熔炉巨锤 | 普攻命中加灼烧 2 层；命中最多 3 人；战技：熔炉倾覆·圆，倍率1.7，蓝耗26.0，CD7.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:621` hit_event |
| W017 霜骨战斧 | 对冰缓≥3 层目标普攻条件加伤 +15%；战技：霜骨破庭，倍率1.8，蓝耗24.0，CD6.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:505` hit_multiplier |
| W018 雷骸重剑 | 普攻加感电 2 层，ICD 1.5 秒；战技：雷骸落罚，倍率1.7，蓝耗24.0，CD6.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:622` hit_event |
| W019 血狱斩首刃 | 普攻首次命中出血≥3 层目标消耗 1 层，追加 0.18P，ICD 2 秒；战技：血狱落冠，倍率1.8，蓝耗26.0，CD7.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:623` hit_event |
| W020 星陨石槌 | 普攻破势从 35 提至 50；自身挥击移速 -40%；战技：星陨断层·圆，倍率1.6，蓝耗26.0，CD7.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:610` hit_event |
| W021 余烬壁刃 | 一次实际受击后下一次普攻命中得 4% 护盾/3 秒，ICD 6 秒；战技：余烬回城，倍率1.8，蓝耗22.0，CD6.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:624` hit_event |
| W022 风暴战戟 | 前方窄扇面 70°；命中距离≥150 时条件加伤 +10%；战技：风暴折旗，倍率1.7，蓝耗24.0，CD6.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:506` hit_multiplier |
| W023 冥潮仪镰 | 击杀合格敌人得 1 灵魂，上限 3；下次右键消耗全部，每魂追加 0.08P；战技：冥潮迁葬·圆，倍率1.6，蓝耗22.0，CD6.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:658` hit_event |
| W024 无名王剑 | HP≤35% 的目标普攻条件加伤 +14%；对其他目标无额外效果；战技：无名终誓，倍率1.9，蓝耗26.0，CD7.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:507` hit_multiplier |
| W025 守夜步枪 | 装填完后首发加标记，首发不吃该标记；战技：银鸦齐射，倍率2.4，蓝耗16.0，CD5.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:625` hit_event |
| W026 暮羽长弓 | 穿 2 人，后续 ×0.60；战技：暮羽追魂·贯，倍率2.0，蓝耗18.0，CD5.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art |
| W027 血棘连弩 | 同目标连续 3 次普攻命中加出血 1 层，换目标清计数；战技：血棘攒射，倍率2.4，蓝耗18.0，CD5.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:626` hit_event |
| W028 烬鸦火铳 | 普攻加灼烧 1 层，ICD 0.8 秒；战技：烬鸦引火，倍率2.1，蓝耗20.0，CD6.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:627` hit_event |
| W029 霜月猎弓 | 普攻加冰缓 1 层，ICD 1 秒；战技：霜月封喉·贯，倍率1.9，蓝耗20.0，CD6.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:628` hit_event |
| W030 雷翼卡宾枪 | 每第 4 次普攻命中加感电 2 层；战技：雷翼点射，倍率2.3，蓝耗18.0，CD5.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:629` hit_event |
| W031 黑曜长枪 | 单弹；站立≥0.8 秒后普攻条件加伤 +12%，移动/闪避重计；战技：黑曜定裁·贯，倍率1.8，蓝耗22.0，CD6.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:508` hit_multiplier |
| W032 镜轨双铳 | 第 5 次普攻命中向距目标≤150 的另 1 敌追加 0.20P，ICD 2 秒；战技：镜轨交叉，倍率2.2，蓝耗18.0，CD5.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:630` hit_event |
| W033 逐风短弓 | 边移动边攻击的移速惩罚减半；不额外加伤；战技：逐风三羽，倍率2.2，蓝耗16.0，CD5.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`session.gd:3318` move_player |
| W034 断誓穿甲枪 | 对敌方护盾伤害 +30%，对生命无额外加成；战技：断誓破甲·贯，倍率1.9，蓝耗20.0，CD6.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`session.gd:3522` damage_enemy |
| W035 葬铃灵弩 | 每第 4 次普攻命中回 2 蓝，ICD 2 秒；战技：葬铃送行，倍率2.1，蓝耗18.0，CD5.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:632` hit_event |
| W036 晨曦信号枪 | 右键命中给自身与距自己≤220 的最低血盟友各 3% 护盾/3 秒，ICD 8 秒；战技：晨曦引路，倍率2.0，蓝耗20.0，CD6.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:660` hit_event |
| W037 星辉法杖 | 普攻单体；每第 4 次普攻根命中追加 0.12P，ICD 3 秒；战技：星辉贯流·线，倍率2.0，蓝耗18.0，CD5.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:633` hit_event |
| W038 赤陨法杖 | 半径 100 爆炸，第 2 目标起 ×0.60；加灼烧 1 层，ICD 1 秒；战技：赤陨坠星，倍率1.6，蓝耗26.0，CD7.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art |
| W039 霜针短杖 | 冰针加冰缓 1 层，ICD 0.7 秒；弹速 1050；战技：霜针暴雨·散，倍率2.4，蓝耗16.0，CD5.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:628` hit_event |
| W040 鸣雷之杖 | 最多跳 2 次，距离 160，后续 ×0.45/0.30；首目标加感电 1 层；战技：鸣雷连锁，倍率1.8，蓝耗22.0，CD6.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:634` hit_event |
| W041 月弧法杖 | 穿 3 人，后续 ×0.65/0.45；战技：月弧三叠·线，倍率1.9，蓝耗20.0，CD6.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art |
| W042 曦光棱镜杖 | 瞬时直线最多 4 人，后续 ×0.65/0.45/0.30；战技：曦光裁决·线，倍率1.8，蓝耗24.0，CD6.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art |
| W043 烬羽散华杖 | 5 枚火羽，同目标总计最多 1.48D；根命中加灼烧 1 层，ICD 0.8 秒；战技：烬羽燎原·散，倍率2.0，蓝耗20.0，CD6.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art |
| W044 虚涡法杖 | 半径 90 爆炸，第 2 目标起 ×0.60；拉拽普通怪最多 35；战技：虚涡塌缩，倍率1.7，蓝耗24.0，CD6.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`session.gd:4038` spell_burst |
| W045 蚀月长枪杖 | 穿 4 人，后续 ×0.60/0.40/0.25；蓄力中移速 -35%；战技：蚀月破界·线，倍率1.5，蓝耗28.0，CD7.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`session.gd:3318` move_player |
| W046 血契仪杖 | 首次命中加出血 1 层，ICD 1 秒；不是吸血武器；战技：血契书庭，倍率1.8，蓝耗20.0，CD6.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:635` hit_event |
| W047 冥庭唤魂杖 | 4 次普攻命中同目标后召 1 灵体/4 秒，每 1 秒 0.04P，ICD 6 秒；计入召唤总上限；战技：冥庭点名，倍率1.7，蓝耗22.0，CD6.5 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:636` hit_event |
| W048 晨钟祈愿杖 | 右键命中后自身回复 2% HP，ICD 8 秒，受战斗治疗预算；战技：晨钟赦光，倍率1.8，蓝耗20.0，CD6.0 | 已接入（静态核对） | `rogue_actions.gd:134` normal；`rogue_actions.gd:96` resolve_art；`rogue_build.gd:664` hit_event |

### 72装备

| ID/名称 | 运行描述 | 结论 | 执行入口 |
|---|---|---|---|
| E001 血棘战衣 | 普攻直击吸血 4%，每次最多 2% HP，ICD 2 秒；不计算 DoT | 已接入（静态核对） | `rogue_build.gd:556` hit_event |
| E002 余烬壁垒 | HP<35% 时条件减伤 +15%；离开阈值立即停止 | 已接入（静态核对） | `rogue_build.gd:154` conditional_defense；`rogue_equipment.gd:53` has |
| E003 星纱法袍 | 法力吸收减伤后伤害的 20%，1 蓝吸收 1 伤害，先耗法力再耗临时盾 | 已接入（静态核对） | `rogue_build.gd:717` incoming；`rogue_equipment.gd:54` has |
| E004 晨露护衣 | HP≥80% 时回蓝速度 +25%，受回蓝速度上限 | 已接入（静态核对） | `rogue_build.gd:128` stat；`rogue_equipment.gd:55` has |
| E005 赤刃誓衣 | 5 层出血的敌人被自己直击时 C+12% | 已接入（静态核对） | `rogue_build.gd:480` hit_multiplier |
| E006 断誓锁甲 | 每次实际受击失去≥8% HP 后，下次重刃普攻 C+20%；有效 4 秒，ICD 8 秒 | 部分不符：A15 | `rogue_build.gd:734` incoming |
| E007 熔炉围裙 | 由敌人灼烧和岩浆造成的伤害额外降低 20%；不叠入一般条件减伤，不作用于直接火焰重击 | 部分不符：A25 | `roguelike.gd:512` tick |
| E008 烛火祭袍 | 自己施加的灼烧持续 +1 秒，刷新时上限 5 秒；不提高层数 | 部分不符：A21 | `rogue_build.gd:295` add_status |
| E009 星霜斗篷 | 自己造成冻结后获 6% 护盾/4 秒，ICD 8 秒；Boss 满冰缓同样触发但不冻结 | 部分不符：A11 | `rogue_build.gd:303` add_status |
| E010 霜骨胸铠 | 自己直击冰缓≥3 层敌人后条件减伤 +8%/2 秒，刷新不叠 | 已接入（静态核对） | `rogue_build.gd:549` hit_event |
| E011 雷翼轻甲 | 闪避后下一次普攻命中加感电 2 层，有效 3 秒，ICD 4 秒 | 部分不符：A14 | `rogue_build.gd:592` hit_event |
| E012 雷骸绝缘衣 | 当前 HP 扣除一次敌方直接雷击后得 5% 护盾/4 秒，ICD 8 秒；雷击标签由敌人技能给出 | 已接入（静态核对） | `rogue_build.gd:735` incoming |
| E013 星泉长袍 | MP≥75% 时施法消耗 -10%；结算前判断高蓝，扣蓝后再计算伤害条件 | 已接入（静态核对） | `rogue_build.gd:276` mana_cost |
| E014 空鸣术衣 | MP≤30% 时首次普攻命中回 4 蓝，ICD 3 秒；不是施法前赠蓝 | 已接入（静态核对） | `rogue_build.gd:563` hit_event |
| E015 终焉祭衣 | 右键直击 HP≤30% 目标 C+18%，不强化 Q | 已接入（静态核对） | `rogue_build.gd:476` hit_multiplier |
| E016 黑曜戒甲 | 每 8 秒获得一次守势，下一次敌方直接伤害降低 12%；不作用于 DoT/岩浆 | 已接入（静态核对） | `rogue_build.gd:716` incoming |
| E017 镜轨战袍 | 右键成功扣蓝后 3 秒内下一次普攻追加 0.18P，ICD 6 秒 | 已接入（静态核对） | `rogue_build.gd:772` action_event |
| E018 逐风披肩 | 闪避后 2 秒移速 +18，且近战普攻出手移动惩罚减少 20 个百分点 | 部分不符：A22 | `rogue_build.gd:766` action_event；`session.gd:3334` move_player |
| E019 引魂葬衣 | 自己召唤实体存活时条件减伤 +6%；多实体不叠 | 已接入（静态核对） | `rogue_build.gd:157` conditional_defense |
| E020 冥庭长衣 | 自己合格击杀后得 4% 护盾/4 秒，ICD 6 秒；Boss 直击每 10 秒可替代触发一次 | 已接入（静态核对） | `rogue_build.gd:674` hit_event；`rogue_build.gd:1227` killed |
| E021 晨钟礼服 | 自身施法扣蓝≥12 后，距自己≤240 的最低血角色回复 2% HP，ICD 6 秒；自己可成为目标 | 已接入（静态核对） | `rogue_build.gd:263` spend_event |
| E022 巡夜救援甲 | 救援交互时条件减伤 +15%；单人时血瓶受疗+15%（不增加容量），计入血瓶专用受疗池 | 已接入（静态核对） | `rogue_build.gd:158` conditional_defense；`rogue_build.gd:1241` commit_flask |
| E023 孤星旅袍 | 320 内无其他存活玩家时 A+8%；不是单人专属，远离队友也生效 | 已接入（静态核对） | `rogue_build.gd:125` stat |
| E024 共鸣织甲 | 240 内有其他存活玩家时自身常态减伤 +4%；单人改为最大 HP +10，换模式不补当前 HP | 已接入（静态核对） | `rogue_build.gd:123` stat |
| E025 星泉棱镜 | MP≥70% 时直击 C+12% | 已接入（静态核对） | `rogue_build.gd:486` hit_multiplier |
| E026 祈愿圣印 | 一次实际扣蓝≥12 回复 2% HP，ICD 5 秒 | 已接入（静态核对） | `rogue_build.gd:261` spend_event |
| E027 弑王瞄具 | 对守层者直击 C+16%；小怪和构造物无收益 | 已接入（静态核对） | `rogue_build.gd:487` hit_multiplier |
| E028 终焉沙漏 | 对 HP<30% 目标直击 C+18% | 已接入（静态核对） | `rogue_build.gd:488` hit_multiplier |
| E029 血契针盘 | 普攻命中出血≥3 层的目标，每 4 秒追加出血 1 层 | 已接入（静态核对） | `rogue_build.gd:566` hit_event |
| E030 赤月刻印 | 对出血≥3 层目标暴击率 +6%；仍受暴击率上限 | 已接入（静态核对） | `rogue_build.gd:509` hit_multiplier |
| E031 裂阵楔石 | 重刃普攻的破势积累 +12；不提高伤害 | 已接入（静态核对） | `rogue_build.gd:610` hit_event |
| E032 守誓铁徽 | 自己制造破势窗口时得 6% 护盾/4 秒，ICD 10 秒 | 已接入（静态核对） | `rogue_build.gd:685` add_poise |
| E033 银鸦准星 | 距离≥220 的普攻暴击伤害 +0.10 | 已接入（静态核对） | `rogue_build.gd:514` hit_multiplier |
| E034 猎令罗盘 | 攻击未被自己标记目标，普攻根命中后给标记，ICD 3 秒 | 已接入（静态核对） | `rogue_build.gd:567` hit_event |
| E035 熔心烛台 | 自身灼烧持续 +1 秒，与其他延长累计最多 6 秒 | 已接入（静态核对） | `rogue_build.gd:295` add_status |
| E036 余烬火瓶 | 合格敌人带自身灼烧死亡时，在死亡处留下半径 90/2 秒火圈；每秒 0.06P，ICD 4 秒，最多 3 目标 | 已接入（静态核对） | `rogue_build.gd:1229` killed |
| E037 星霜六棱 | 对冰缓≥3 层目标法术直击 C+12% | 已接入（静态核对） | `rogue_build.gd:482` hit_multiplier |
| E038 寂冬挂钟 | 冻结 ICD 从 8 秒减到 7 秒；全局最低 6 秒，Boss 不获得冻结 | 已接入（静态核对） | `rogue_build.gd:301` add_status |
| E039 雷翼线圈 | 第 4 次普攻根命中追加一次 0.18P 雷击，ICD 2 秒，主目标 1 人 | 已接入（静态核对） | `rogue_build.gd:576` hit_event |
| E040 风眼电容 | 自己消耗感电层触发雷裂后回 4 蓝，ICD 4 秒 | 已接入（静态核对） | `rogue_build.gd:701` reactions |
| E041 空鸣音叉 | MP≤30% 时右键直击 C+16% | 已接入（静态核对） | `rogue_build.gd:477` hit_multiplier |
| E042 镜轨残片 | 战技 CDR+8%，Q 不受益 | 已接入（静态核对） | `rogue_build.gd:129` stat |
| E043 禁咒薄册 | 法杖普攻消耗 -10%，最低 1 蓝；物理/右键/Q 不受益 | 已接入（静态核对） | `rogue_build.gd:278` mana_cost |
| E044 黑曜封印 | 首次从无盾变有盾时，下次普攻 C+14%/3 秒，ICD 6 秒；续盾不触发 | 已接入（静态核对） | `rogue_build.gd:233` shield |
| E045 引魂骨铃 | 召唤总伤害 +10%，该项进入召唤专用加算池，上限 +40% | 已接入（静态核对） | `rogue_build.gd:430` soul_step |
| E046 冥庭令牌 | Q 成功施放时现有灵体持续 +1 秒，每次召唤总延长最多 2 秒 | 已接入（静态核对） | `rogue_build.gd:782` action_event |
| E047 晨钟圣杯 | 自身受疗效果 +10%，最终仍检查共享受疗预算 | 已接入（静态核对） | `rogue_build.gd:200` heal；`rogue_build.gd:1241` commit_flask |
| E048 盟约旗扣 | 240 内队友战技命中时自己回 2 蓝，ICD 5 秒；单人时自己战技命中触发 | 部分不符：A17 | `rogue_build.gd:654` hit_event |
| E049 逐风长靴 | 距离≥220 时普攻 C+12% | 已接入（静态核对） | `rogue_build.gd:462` hit_multiplier |
| E050 踏阵铁靴 | 距离≤100 时近战普攻 C+10% | 已接入（静态核对） | `rogue_build.gd:463` hit_multiplier |
| E051 引魂轻履 | 合格击杀回 4 蓝，ICD 2 秒；守层者普攻命中每 8 秒替代一次 | 已接入（静态核对） | `rogue_build.gd:673` hit_event；`rogue_build.gd:1226` killed |
| E052 逆潮战靴 | HP<50% 时直击 C+12% | 已接入（静态核对） | `rogue_build.gd:489` hit_multiplier |
| E053 赤刃舞履 | 第三段轻刃普攻命中后移速 +20/2 秒，ICD 3 秒 | 已接入（静态核对） | `rogue_build.gd:564` hit_event |
| E054 血棘绑腿 | 直击自身出血目标后条件减伤 +6%/2 秒，ICD 3 秒 | 部分不符：A16 | `rogue_build.gd:565` hit_event |
| E055 破阵重靴 | 重刃挥击时移动速度惩罚减轻 15 个百分点，不提高最大移速 | 部分不符：A22 | `session.gd:3331` move_player |
| E056 裂地钉履 | 受敌方击退距离 -30%；不免疫伤害和地形约束 | 已接入（静态核对） | `boss_choreography.gd:714` modifiers；`rogue_combat.gd:518` tick |
| E057 猎印软靴 | 装填期间移速惩罚减轻 30 个百分点 | 已接入（静态核对） | `session.gd:3333` move_player |
| E058 银鸦伏靴 | 完成装填后 2 秒下一次枪弓普攻 C+18%，ICD 5 秒 | 已接入（静态核对） | `rogue_build.gd:802` reload_event |
| E059 余烬踏鞋 | 岩浆持续伤害 -20%，与熔炉围裙同池加算，上限 -30% | 已接入（静态核对） | `roguelike.gd:512` tick |
| E060 烛影灰履 | 闪避经过的路径留下半径 50 火点/2 秒，每秒 0.04P，ICD 4 秒，最多 2 个火点并存 | 部分不符：A23 | `rogue_build.gd:767` action_event |
| E061 霜镜滑靴 | 闪避距离 +12%，不可越过边界/障碍 | 已接入（静态核对） | `session.gd:3322` move_player |
| E062 寂冬静履 | 自己冻结或使 Boss 达到 5 层冰缓时回 4 蓝，ICD 8 秒 | 部分不符：A11 | `rogue_build.gd:305` add_status |
| E063 雷翼踏板 | 闪避后下一次普攻向主目标追加 0.15P，窗口 2 秒，ICD 4 秒 | 已接入（静态核对） | `rogue_build.gd:594` hit_event |
| E064 风眼云靴 | 受到的移动减速量 -25%；不缩短硬控或取消走位要求 | 已接入（静态核对） | `boss_choreography.gd:712` modifiers；`session.gd:3162` simulate |
| E065 星泉行履 | 最后一次消耗蓝量后额外恢复的等待从 1.5 秒减至 1.2 秒 | 已接入（静态核对） | `session.gd:562` recover_mana |
| E066 空鸣步靴 | 右键成功施放后移速 +24/2 秒，ICD 4 秒 | 已接入（静态核对） | `rogue_build.gd:773` action_event |
| E067 黑曜盾靴 | 闪避结束后得 4% 护盾/2 秒，ICD 6 秒 | 已接入（静态核对） | `rogue_build.gd:882` tick |
| E068 余烬守城靴 | 连续 6 秒未失去 HP 后自然回复 1% HP，ICD 6 秒；战斗治疗子预算有效 | 已接入（静态核对） | `rogue_build.gd:887` tick |
| E069 逐风刻靴 | 闪避基础 CD -8%，计入专用闪避 CDR 池，上限 20% | 已接入（静态核对） | `rogue_build.gd:130` stat |
| E070 夜鸦返履 | 完美闪避后下一次普攻 C+18%/2 秒，ICD 5 秒 | 部分不符：A24 | `rogue_build.gd:705` perfect |
| E071 冥庭巡履 | 召唤实体移动速度 +25%，不加攻击频率或传送穿墙 | 已接入（静态核对） | `rogue_build.gd:400` soul_step |
| E072 晨钟同行靴 | 距离倒地队友≤300 时朝其移动速度 +25；单人时 HP<40% 获移速 +15 | 已接入（静态核对） | `rogue_build.gd:127` stat；`rogue_build.gd:884` tick |

### 96天赋

| ID/名称 | 运行描述 | 结论 | 执行入口 |
|---|---|---|---|
| T001 赤刃研磨 | 轻刃普攻 A+6/10/14%；仅普攻局部 A 池，不提高 P | 已接入（静态核对） | `rogue_build.gd:461` hit_multiplier |
| T002 血线缝合 | 每第 3 次普攻根命中追加出血 1/1/2 层，ICD 1.5 秒 | 已接入（静态核对） | `rogue_build.gd:569` hit_event |
| T003 血痕凝视 | 对自身出血≥3 层目标直击 C+6/9/12% | 已接入（静态核对） | `rogue_build.gd:479` hit_multiplier |
| T004 夜行脉搏 | 轻刃第 3 段根命中回 1/2/3 蓝，ICD 2 秒 | 已接入（静态核对） | `rogue_build.gd:558` hit_event |
| T005 凝血护心 | 自己出血 DoT 造成有效伤害后得 3/5% 护盾/3 秒，ICD 6 秒 | 已接入（静态核对） | `rogue_build.gd:929` tick_enemies |
| T006 绯红收割 | 右键命中 5 层出血目标时消耗 3 层，追加 0.30/0.40P，ICD 4 秒 | 已接入（静态核对） | `rogue_build.gd:670` hit_event |
| T007 血焰相拥 | 开启血焰反应；伤害 0.25/0.32P/目标，其余沿第 3 节 | 部分不符：A01 | `rogue_build.gd:690` reactions |
| T008 血契回响 | 自身出血 DoT 伤害 +40%，出血上限仍 5；连续 3 次普攻命中同目标可加出血 1 层，ICD 2 秒；自身直接普攻伤害 -12%（独立代价乘数） | 已接入（静态核对） | `rogue_build.gd:465` hit_multiplier；`rogue_build.gd:572` hit_event；`rogue_build.gd:926` tick_enemies |
| T009 重刃铸锋 | 重刃普攻局部 A+6/10/14%，不提高 P | 已接入（静态核对） | `rogue_build.gd:461` hit_multiplier |
| T010 裂阵重压 | 重刃普攻破势 +6/10/14 | 已接入（静态核对） | `rogue_build.gd:610` hit_event |
| T011 固步蓄锋 | 重刃前摇时条件减伤 +5/8/11%，不提高前摇后防御 | 已接入（静态核对） | `rogue_build.gd:155` conditional_defense |
| T012 破甲楔入 | 对敌方护盾伤害 +15/25/35%；按护盾专用加算池，上限 +60% | 已接入（静态核对） | `session.gd:3535` damage_enemy |
| T013 裂隙追击 | 对处于破势窗口目标直击 C+12/18% | 已接入（静态核对） | `rogue_build.gd:484` hit_multiplier |
| T014 回锤节律 | 重刃普攻命中后下一次右键消耗 -10/15%，有效 4 秒，不可叠 | 已接入（静态核对） | `rogue_build.gd:612` hit_event |
| T015 雷裂断层 | 开启雷裂反应；伤害 0.35/0.45P，其他沿第 3 节 | 已接入（静态核对） | `rogue_build.gd:698` reactions |
| T016 裂阵誓言 | 重刃普攻破势 +25；亲自开启破势窗口回 6 蓝，ICD 12 秒；重刃普攻周期 ×1.12，其他家族不能获得破势 +25 | 已接入（静态核对） | `rogue_build.gd:150` interval；`rogue_build.gd:610` hit_event；`rogue_build.gd:686` add_poise |
| T017 银鸦弹艺 | 枪弓普攻局部 A+6/10/14%，不提高 P | 已接入（静态核对） | `rogue_build.gd:461` hit_multiplier |
| T018 远见瞄准 | 距离≥220 时普攻 C+6/9/12% | 已接入（静态核对） | `rogue_build.gd:462` hit_multiplier |
| T019 稳手装填 | 装填时间 -8/12/16%；所有装填加速池上限 25% | 已接入（静态核对） | `session.gd:3087` reload_player |
| T020 猎人识印 | 普攻根命中后加标记，ICD 4/3.5/3 秒 | 已接入（静态核对） | `rogue_build.gd:568` hit_event |
| T021 处刑精度 | 攻击自身标记目标的暴击率 +8/12% | 已接入（静态核对） | `rogue_build.gd:509` hit_multiplier |
| T022 穿阵余音 | 枪弓普攻穿透/弹跳的后续伤害衰减系数 +0.08/0.12，后续单目标不高于 0.80；不增加穿透数 | 已接入（静态核对） | `rogue_build.gd:283` attenuation |
| T023 银弹储备 | 装填完成后首 2 发普攻命中各回 1/2 蓝，ICD 6 秒（一次解锁这两发，不是逐发 ICD） | 已接入（静态核对） | `rogue_build.gd:645` hit_event；`rogue_build.gd:803` reload_event |
| T024 银鸦猎令 | 消耗自身标记的普攻 C+额外 22%，该次命中后跳向另 1 敌造成 0.20P，ICD 3 秒；距离<160 的枪弓普攻伤害 ×0.85 | 部分不符：A20 | `rogue_build.gd:467` hit_multiplier；`rogue_build.gd:581` hit_event |
| T025 余烬火种 | 每次普攻根命中可加灼烧 1/1/2 层，ICD 1 秒 | 已接入（静态核对） | `rogue_build.gd:570` hit_event |
| T026 燃灯长夜 | 自身灼烧持续 +0.5/1/1.5 秒，累计最长 6 秒 | 已接入（静态核对） | `rogue_build.gd:295` add_status |
| T027 灰烬灼心 | 对自己灼烧目标直击 C+5/8/11% | 已接入（静态核对） | `rogue_build.gd:481` hit_multiplier |
| T028 炉火耐受 | 岩浆/敌方灼烧伤害 -10/15/20%，与专门抗火装备同池，最高 -30% | 部分不符：A25 | `roguelike.gd:512` tick |
| T029 烛火蔓延 | 带自身灼烧目标被合格击杀时，给半径 140 的最多 2 敌各加灼烧 1/2 层，ICD 3 秒；此为死亡事件直接施加，不允许再次传播 | 部分不符：A26 | `rogue_build.gd:1230` killed |
| T030 余烬回温 | 灼烧 DoT 有效伤害后自身回复 1/1.5% HP，ICD 4 秒 | 已接入（静态核对） | `rogue_build.gd:930` tick_enemies |
| T031 燃冰裂响 | 开启燃冰反应，伤害 0.45/0.55P，其他沿第 3 节 | 已接入（静态核对） | `rogue_build.gd:694` reactions |
| T032 余烬王冠 | 自身灼烧每层伤害 +50%；对灼烧≥3 层目标右键命中后留下半径 90 火圈/3 秒，每秒 0.08P，ICD 6 秒；自然回蓝速度 -20%（加入回蓝速度池） | 已接入（静态核对） | `rogue_build.gd:128` stat；`rogue_build.gd:669` hit_event；`rogue_build.gd:927` tick_enemies |
| T033 霜纹刻写 | 普攻根命中加冰缓 1/1/2 层，ICD 1 秒 | 已接入（静态核对） | `rogue_build.gd:570` hit_event |
| T034 冬夜延留 | 冰缓持续 +0.4/0.7/1 秒，所有延长累计上限 4.5 秒 | 已接入（静态核对） | `rogue_build.gd:297` add_status |
| T035 碎镜打击 | 对冰缓≥3 层目标直击 C+6/9/12% | 已接入（静态核对） | `rogue_build.gd:482` hit_multiplier |
| T036 冷静冥想 | 最近 3 秒未失去 HP 时自然回蓝速度 +10/15/20% | 已接入（静态核对） | `rogue_build.gd:128` stat |
| T037 霜壳庇护 | 自己冻结或将 Boss 叠至 5 层冰缓时得 5/8% 护盾/4 秒，ICD 8 秒 | 部分不符：A11 | `rogue_build.gd:304` add_status |
| T038 寂冬裂晶 | 冻结结束或 Boss 5 层冰缓时追加 0.20/0.30P，单主目标，ICD 8 秒 | 部分不符：A10 | `rogue_build.gd:306` add_status |
| T039 冰镜余辉 | 自己触发燃冰反应后获得 4/6% 护盾/3 秒，ICD 4 秒；不自动开启燃冰，需 T031 | 已接入（静态核对） | `rogue_build.gd:697` reactions |
| T040 寂冬契约 | 冻结共享 ICD -2 秒（最低 6 秒）；对 Boss 5 层冰缓的法术直击 C+20%；普攻周期 ×1.10，不免疫任何 Boss 技能 | 已接入（静态核对） | `rogue_build.gd:150` interval；`rogue_build.gd:301` add_status；`rogue_build.gd:483` hit_multiplier |
| T041 雷纹刻写 | 普攻根命中加感电 1/1/2 层，ICD 1 秒 | 已接入（静态核对） | `rogue_build.gd:570` hit_event |
| T042 轻雷步伐 | 移速 +8/12/16 | 已接入（静态核对） | `rogue_build.gd:127` stat |
| T043 电弧寻路 | 自身连锁机制寻敌距离 +15/25/35；不加弹速、数量或穿墙 | 已接入（静态核对） | `rogue_build.gd:578` hit_event |
| T044 风暴定神 | 对感电≥3 层目标暴击率 +4/6/8% | 已接入（静态核对） | `rogue_build.gd:509` hit_multiplier |
| T045 雷脉续航 | 自己消耗感电层触发反应后回 3/5 蓝，ICD 4 秒 | 已接入（静态核对） | `rogue_build.gd:590` hit_event；`rogue_build.gd:701` reactions |
| T046 交错雷链 | 每第 4 次普攻根命中，对另 1 敌追加 0.15/0.22P，范围 180，ICD 2 秒 | 已接入（静态核对） | `rogue_build.gd:577` hit_event |
| T047 电光折返 | 闪避后 2 秒内首次普攻根命中加感电 1/2 层，ICD 4 秒 | 已接入（静态核对） | `rogue_build.gd:593` hit_event |
| T048 雷翼回路 | 感电满 5 层后下次普攻消耗全部，主目标与另 1 敌各 0.35P，ICD 4 秒；最大 HP ×0.90；未找到副目标不把其伤害回给主目标 | 已接入（静态核对） | `rogue_build.gd:147` hp_multiplier；`rogue_build.gd:587` hit_event |
| T049 星池扩容 | MP 上限 +10/16/22，获得时不补蓝 | 已接入（静态核对） | `rogue_build.gd:124` stat |
| T050 清泉呼吸 | 自然回蓝速度 +10/15/20% | 已接入（静态核对） | `rogue_build.gd:128` stat |
| T051 高潮折光 | MP≥70% 时法术直击 C+6/9/12% | 已接入（静态核对） | `rogue_build.gd:485` hit_multiplier |
| T052 精简咒式 | 法杖普攻蓝耗 -5/8/12%，受最低蓝耗 | 已接入（静态核对） | `rogue_build.gd:278` mana_cost |
| T053 施法余辉 | 一次实际扣蓝≥12 后，下次普攻命中回 2/3 蓝，窗口 4 秒，ICD 5 秒；按该次支出最多 35% 退蓝 | 已接入（静态核对） | `rogue_build.gd:262` spend_event |
| T054 星纱缓冲 | MP≥70% 时条件减伤 +6/10% | 已接入（静态核对） | `rogue_build.gd:156` conditional_defense |
| T055 泉眼回响 | 每累计实际扣蓝 40 后得 0.20/0.30P 单目标附击，附在下次普攻，ICD 5 秒；超过阈值最多保留 39 进度，不多次充能 | 部分不符：A18 | `rogue_build.gd:270` spend_event |
| T056 星泉共鸣 | 自然回蓝速度 +25%；MP≥70% 时法术直击 C+18%；右键蓝耗 +15%（与消耗减免合并），不加 Q 伤害 | 部分不符：A07 | `rogue_build.gd:128` stat；`rogue_build.gd:279` mana_cost；`rogue_build.gd:485` hit_multiplier |
| T057 战技研习 | 右键局部 A+8/12/16%，不提高 P | 已接入（静态核对） | `rogue_build.gd:474` hit_multiplier |
| T058 空鸣节拍 | 右键 CDR+4/6/8% | 已接入（静态核对） | `rogue_build.gd:129` stat |
| T059 返蓝刻度 | 右键每次实际消耗退回 8/12/16%，回在命中首次有效目标后，miss 不退，仍受总退蓝 35% | 已接入（静态核对） | `rogue_build.gd:651` hit_event |
| T060 低潮专注 | MP≤35% 时普攻 C+6/9/12% | 已接入（静态核对） | `rogue_build.gd:464` hit_multiplier |
| T061 普攻接力 | 每 4 次普攻根命中，下次右键 C+12/18%，持续 5 秒，只存 1 次 | 已接入（静态核对） | `rogue_build.gd:574` hit_event |
| T062 回响残章 | 右键命中追加 0.16/0.24P，单主目标，ICD 6 秒 | 已接入（静态核对） | `rogue_build.gd:653` hit_event |
| T063 断奏回收 | 右键命中 HP≤30% 目标使剩余 CD -0.4/0.7 秒，每次施放最多一次，受冷却总缩短限制 | 已接入（静态核对） | `rogue_build.gd:657` hit_event |
| T064 空鸣轮转 | 4 次普攻根命中获得“轮转”，下次右键消耗 -20% 且 C+20%，只存 1 次；右键基础 CD ×1.15，空挥也消耗轮转 | 已接入（静态核对） | `rogue_actions.gd:21` start_art；`rogue_build.gd:575` hit_event |
| T065 坚壁锻骨 | HP 上限 +12/20/28；首次激活回复对应 HP 增量，升级只回复该级差值，重配不回复 | 已接入（静态核对） | `rogue_build.gd:123` stat |
| T066 黑铁庇护 | 常态减伤 +3/5/7% | 已接入（静态核对） | `rogue_build.gd:126` stat |
| T067 守势余温 | 获得临时护盾后持续时间 +0.5/0.8/1 秒，全局护盾最长 6 秒，不增加每次容量 | 已接入（静态核对） | `rogue_build.gd:229` shield |
| T068 危城不倒 | HP<35% 时条件减伤 +5/8/11% | 已接入（静态核对） | `rogue_build.gd:154` conditional_defense |
| T069 盾后反击 | 一次敌方直击被护盾吸收后，下次普攻 C+12/18%/3 秒，ICD 5 秒 | 已接入（静态核对） | `rogue_build.gd:730` incoming |
| T070 荆棘归还 | 实际失去≥4% HP 的敌方直击后，对来源敌人返 0.16/0.24P，ICD 3 秒，需≤400 且视线畅通；岩浆/DoT 无效 | 已接入（静态核对） | `rogue_build.gd:736` incoming |
| T071 残火自愈 | HP<40% 时，普攻有效命中回复 1/1.5% HP，ICD 3 秒 | 已接入（静态核对） | `rogue_build.gd:557` hit_event |
| T072 余烬守誓 | 每 8 秒首次敌方直击前获得 10% HP 护盾/4 秒，再结算该直击；自身所有直接伤害 ×0.88，反伤不受罚；护盾不会挡地形必杀 | 部分不符：A05 | `rogue_build.gd:471` hit_multiplier；`rogue_build.gd:715` incoming |
| T073 巡夜轻步 | 移速 +8/12/16，移速总上限为角色基础 +70 | 已接入（静态核对） | `rogue_build.gd:127` stat |
| T074 逐风复步 | 闪避 CD -5/8/12%，闪避 CDR 总池最高 20% | 已接入（静态核对） | `rogue_build.gd:130` stat |
| T075 翻刃瞬息 | 闪避后下一次普攻 C+8/12/16%/2 秒，ICD 4 秒 | 部分不符：A12 | `rogue_build.gd:764` action_event |
| T076 风中呼吸 | 完美闪避回 2/3/4 蓝，ICD 4 秒 | 已接入（静态核对） | `rogue_build.gd:706` perfect |
| T077 无痕屏息 | 完美闪避得 4/6% 护盾/3 秒，ICD 5 秒 | 已接入（静态核对） | `rogue_build.gd:707` perfect |
| T078 追风回斩 | 闪避后 2 秒内第一次近战普攻追加 0.16/0.24P，ICD 4 秒 | 已接入（静态核对） | `rogue_build.gd:595` hit_event |
| T079 反向踏影 | 闪避后首个右键前摇缩短 10/15%，仍最低 0.25 秒，有效 2 秒，不减伤害动画提示长度 | 部分不符：A24 | `rogue_actions.gd:29` start_art |
| T080 风行刻律 | 完美闪避后 3 秒攻速 +25%、直击 C+12%；最大 HP ×0.90；重复触发刷新时长，不叠数值 | 已接入（静态核对） | `rogue_build.gd:147` hp_multiplier；`rogue_build.gd:710` perfect |
| T081 引魂火苗 | 每 5 次普攻根命中召 1 灵体，持续 4/5/6 秒，每秒 0.06P，ICD 6 秒 | 已接入（静态核对） | `rogue_build.gd:579` hit_event |
| T082 冥庭传令 | 召唤加算伤害 +8/12/16%，不进入 A/P 再乘一次 | 已接入（静态核对） | `rogue_build.gd:430` soul_step |
| T083 魂灯续时 | 灵体持续 +0.5/1/1.5 秒，总持续最长 10 秒 | 已接入（静态核对） | `rogue_build.gd:321` summon |
| T084 骨铃回声 | 自己伤害灵体自然结束时回 1/2/3 蓝，ICD 5 秒；手动解散/换装/切区无效 | 已接入（静态核对） | `rogue_build.gd:893` tick |
| T085 灵主共振 | 召唤命中目标后，自己的下次普攻 C+8/12%/3 秒，ICD 3 秒；由独立召唤事件授予，不触发命中链 | 已接入（静态核对） | `rogue_build.gd:434` soul_step |
| T086 冥火指令 | Q 后现有伤害灵体锁定瞄准目标 3 秒，攻击频率不变，该期间召唤加算伤害 +12/18% | 部分不符：A08 | `rogue_build.gd:781` action_event |
| T087 魂幕护卫 | 自己存在灵体时条件减伤 +4/7% | 已接入（静态核对） | `rogue_build.gd:157` conditional_defense |
| T088 冥庭契约 | 每 4 次普攻根命中召 1 契约灵体/6 秒，每秒 0.10P，ICD 6 秒；自己直接普攻伤害 ×0.88；共享两个实体与总 DPS 上限 | 已接入（静态核对） | `rogue_build.gd:466` hit_multiplier；`rogue_build.gd:580` hit_event |
| T089 晨钟体魄 | HP 上限 +10/16/22，MP 上限 +4/6/8，不补资源 | 已接入（静态核对） | `rogue_build.gd:123` stat |
| T090 并肩祷言 | 自身与光环内队友常态减伤 +2/3/4%；单人自己生效 | 已接入（静态核对） | `rogue_build.gd:126` stat |
| T091 清声回潮 | 光环内自己与队友自然回蓝速度 +6/9/12%，同名取最大，单人自己生效 | 已接入（静态核对） | `rogue_build.gd:128` stat |
| T092 救援熟习 | 救援交互耗时 -8/12/16%；单人血瓶受疗+5/8/12%，救援速度加算上限25%，血瓶受疗增益另有30%上限 | 已接入（静态核对） | `roguelike.gd:1482` rescue；`rogue_build.gd:1241` commit_flask |
| T093 祈愿接续 | 自身实际施法扣蓝≥12 后，240 内最低血角色回复 1.5/2% HP，ICD 6 秒，可选择自己 | 已接入（静态核对） | `rogue_build.gd:263` spend_event |
| T094 圣印共护 | Q 成功施放后自己与240内队友各得 4/6% 护盾/3 秒，ICD 12 秒；四份不同来源仍受盾容量上限 | 部分不符：A19 | `rogue_build.gd:778` action_event |
| T095 晨光裁敌 | 自己成功治疗真实缺血量后，下次直击 C+10/15%/4 秒，ICD 5 秒；血瓶/安全房疗养不触发 | 部分不符：A06 | `rogue_build.gd:217` heal |
| T096 晨钟盟约 | 每次实际施法扣蓝≥12，给自身与240内最低血的另一盟友各 4% 护盾/3 秒，ICD 6 秒；单人只给自己；自身受疗 +10%，自身直接伤害 ×0.90 | 部分不符：A19 | `rogue_build.gd:200` heal；`rogue_build.gd:266` spend_event；`rogue_build.gd:472` hit_multiplier；`rogue_build.gd:1241` commit_flask |

### 24铭刻

| ID/名称 | 运行描述 | 结论 | 执行入口 |
|---|---|---|---|
| I001 破晓 | 对 HP≥90% 目标直击 C+14% | 已接入（静态核对） | `rogue_build.gd:490` hit_multiplier |
| I002 猎痕 | 对 HP<60% 目标直击 C+10% | 已接入（静态核对） | `rogue_build.gd:491` hit_multiplier |
| I003 荣光 | HP≥80% 时直击 C+10% | 已接入（静态核对） | `rogue_build.gd:492` hit_multiplier |
| I004 空鸣 | MP≤30% 时直击 C+12% | 已接入（静态核对） | `rogue_build.gd:493` hit_multiplier |
| I005 血线 | 每第 4 次普攻根命中加出血 1 层，ICD 2 秒 | 已接入（静态核对） | `rogue_build.gd:632` hit_event |
| I006 烛芯 | 每第 3 次普攻根命中加灼烧 1 层，ICD 2 秒 | 已接入（静态核对） | `rogue_build.gd:632` hit_event |
| I007 霜痕 | 每第 3 次普攻根命中加冰缓 1 层，ICD 2 秒 | 已接入（静态核对） | `rogue_build.gd:632` hit_event |
| I008 雷纹 | 每第 3 次普攻根命中加感电 1 层，ICD 2 秒 | 已接入（静态核对） | `rogue_build.gd:632` hit_event |
| I009 裂阵 | 重刃普攻破势 +10；其他普攻 +3 | 已接入（静态核对） | `rogue_build.gd:610` hit_event |
| I010 银鸦 | 完成装填或施放右键后，下次普攻根命中加标记，ICD 5 秒 | 已接入（静态核对） | `rogue_build.gd:642` hit_event |
| I011 蚀骨 | 自身出血和灼烧持续 +0.5 秒，受各自持续上限 | 已接入（静态核对） | `rogue_build.gd:295` add_status |
| I012 溯泉 | 每 4 次普攻根命中回 2 蓝，ICD 3 秒 | 已接入（静态核对） | `rogue_build.gd:640` hit_event |
| I013 返声 | 右键首次有效命中退其实际消耗的 10%，受总退蓝上限 | 已接入（静态核对） | `rogue_build.gd:651` hit_event |
| I014 回环 | 右键 CDR+5%，不提高 Q | 已接入（静态核对） | `rogue_build.gd:129` stat |
| I015 星耀 | MP≥75% 时法术直击 C+12%，物理无增益 | 已接入（静态核对） | `rogue_build.gd:494` hit_multiplier |
| I016 定星 | 暴击率 +4%；HP<50% 时该增益取消 | 已接入（静态核对） | `rogue_build.gd:509` hit_multiplier |
| I017 狩王 | 对守层者直击 C+12% | 已接入（静态核对） | `rogue_build.gd:495` hit_multiplier |
| I018 终焉 | 对 HP≤25% 目标直击 C+16% | 已接入（静态核对） | `rogue_build.gd:496` hit_multiplier |
| I019 血誓 | HP≤40% 时直击 C+14%，不提供回血 | 已接入（静态核对） | `rogue_build.gd:497` hit_multiplier |
| I020 踏风 | 闪避后首个普攻 C+12%/2 秒，ICD 4 秒 | 部分不符：A12 | `rogue_build.gd:764` action_event |
| I021 盾誓 | 每 8 秒一次，右键成功施放得 4% 护盾/3 秒 | 部分不符：A19 | `rogue_build.gd:774` action_event |
| I022 引魂 | 召唤加算伤害 +8%，不增加数量或持续 | 已接入（静态核对） | `rogue_build.gd:430` soul_step |
| I023 晨祷 | 右键实际扣蓝≥12 后自身回 1% HP，ICD 6 秒 | 已接入（静态核对） | `rogue_build.gd:775` action_event |
| I024 镜轨 | 每第 5 次普攻根命中追加 0.15P，单目标，ICD 3 秒 | 已接入（静态核对） | `rogue_build.gd:641` hit_event |

### 12武器核心

| ID/名称 | 运行描述 | 结论 | 执行入口 |
|---|---|---|---|
| WC001 轻刃·追月 | 闪避追击C+8→12%；连续A,A,D,A成功命中后末击前进45→60单位 | 已接入（静态核对） | `rogue_build.gd:599` hit_event；`rogue_build.gd:764` action_event |
| WC002 轻刃·血缝 | 连击第三段加出血1→2层，ICD2秒；升空派生从5层血中消耗2层换0.10→0.16P附击，ICD6秒 | 已接入（静态核对） | `rogue_build.gd:596` hit_event |
| WC003 轻刃·镜舞 | 从空中落地后的首个普攻C+8→12%，窗口2秒；成功完美闪避后回1→2蓝，ICD5秒 | 已接入（静态核对） | `rogue_build.gd:708` perfect；`rogue_build.gd:874` tick |
| WC004 重刃·断层 | 跳跃重砸额外破势+10→16；自身前摇移动惩罚减轻5→10个百分点 | 已接入（静态核对） | `rogue_build.gd:602` hit_event；`session.gd:3331` move_player |
| WC005 重刃·壁锋 | 重刃右键成功命中后得3→5%盾/3秒，ICD8秒；下一次普攻C+6→10% | 部分不符：A19 | `rogue_build.gd:665` hit_event |
| WC006 重刃·雷槌 | 跳跃重砸根命中追加感电1→2层；已解锁雷裂时反应伤害专用加算+8→12% | 已接入（静态核对） | `rogue_build.gd:604` hit_event；`rogue_build.gd:700` reactions |
| WC007 枪弓·鸦返 | 地面闪避后2秒首发C+8→12%；滑射后装填时间-5→8%，持续到一次装填 | 部分不符：A24 | `rogue_build.gd:764` action_event |
| WC008 枪弓·贯星 | 右键贯穿后续衰减系数+0.05→0.08；跃射根命中加标记，ICD5秒 | 已接入（静态核对） | `rogue_actions.gd:111` resolve_art；`rogue_build.gd:606` hit_event |
| WC009 枪弓·刻弹 | A,A,S连段首个右键有效命中退实际蓝耗5→8%；消耗标记时回1→2蓝，ICD4秒 | 已接入（静态核对） | `rogue_build.gd:584` hit_event；`rogue_build.gd:792` action_event |
| WC010 法杖·星环 | 跳跃施法成功后，落地2秒内下一次法杖普攻蓝耗-8→12%；空中法术前摇缩短5→8%，最低0.25秒 | 部分不符：A09 | `rogue_actions.gd:28` start_art；`rogue_build.gd:876` tick；`session.gd:3400` attack |
| WC011 法杖·霜烬 | 空中右键给主目标追加冰缓1→2层，ICD6秒；燃冰反应专用加算伤害+8→12% | 已接入（静态核对） | `rogue_build.gd:667` hit_event；`rogue_build.gd:696` reactions |
| WC012 法杖·灵契 | 角色连招终结后现有灵体延长0.5→1秒，ICD8秒、仍总延长≤2秒；召唤加算伤害+4→8% | 已接入（静态核对） | `rogue_build.gd:430` soul_step；`rogue_build.gd:1176` hero_effect |

## 永久成长、变数、诅咒和事件全量目录

### 14永久成长

| ID | 名称/描述 | 核查 |
|---|---|---|
| coin_purse | 沉甸钱囊 每级开局多带 25 魔晶 | 单机已接入；多人按个人存档未接入，见A32；`scripts/rogue_growth.gd:55` |
| ash_vein | 灰烬矿脉 每级本局结算灰烬 +10% | 单机已接入；多人按个人存档未接入，见A32；`scripts/rogue_growth.gd:60` |
| reroll_charm | 运势护符 每级开局多 1 次商店刷新 | 单机已接入；多人按个人存档未接入，见A32；`scripts/rogue_growth.gd:65` |
| iron_constitution | 铁躯 每级敌人伤害 -3% | 单机已接入；多人按个人存档未接入，见A32；`scripts/rogue_growth.gd:70` |
| hunt_instinct | 猎杀本能 每级我方伤害 +4% | 单机已接入；多人按个人存档未接入，见A32；`scripts/rogue_growth.gd:75` |
| warden_plate | 守望重甲 每级受到伤害 -3% | 单机已接入；多人按个人存档未接入，见A32；`scripts/rogue_growth.gd:80` |
| deep_pockets | 深袋 每级商店价格 -5% | 单机已接入；多人按个人存档未接入，见A32；`scripts/rogue_growth.gd:85` |
| scavenger | 拾荒者 每级宝箱掉落率 +8% | 单机已接入；多人按个人存档未接入，见A32；`scripts/rogue_growth.gd:90` |
| field_medic | 战地医者 每级治疗效果 +8% | 单机已接入；多人按个人存档未接入，见A32；`scripts/rogue_growth.gd:95` |
| swift_boots | 疾行长靴 每级移动速度 +12 | 单机已接入；多人按个人存档未接入，见A32；`scripts/rogue_growth.gd:100` |
| scholar | 博识 每级经验获取 +10% | 单机已接入；多人按个人存档未接入，见A32；`scripts/rogue_growth.gd:105` |
| midas_hand | 点金之手 每级魔晶收入 +10% | 单机已接入；多人按个人存档未接入，见A32；`scripts/rogue_growth.gd:110` |
| hunter_luck | 猎运 每级掉落品质 +1 档 | 单机已接入；多人按个人存档未接入，见A32；`scripts/rogue_growth.gd:115` |
| monster_slaying | 屠戮研习 每级敌人生命 -4% | 单机已接入；多人按个人存档未接入，见A32；`scripts/rogue_growth.gd:120` |

### 18层变数

| ID | 名称/描述 | 核查 |
|---|---|---|
| blood_moon | 血月 敌人伤害 +15% · 掉落品质 +1 档 | 品质/弹速已接入，敌人伤害缺失：A02；`scripts/rogue_variants.gd:35` |
| rust | 锈蚀 普攻 -10% · 商店价格 -30% | 非只普攻，范围扩大：A27；`scripts/rogue_variants.gd:38` |
| fog | 雾障 敌人弹幕更大 · 弹速 -20% | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_variants.gd:41` |
| bounty | 丰饶 魔晶获取 +25% | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_variants.gd:44` |
| frenzy | 狂暴 敌人移速 +12% · 生命 -8% | 负生命变数普通怪重复两次、首领一次：A03；`scripts/rogue_variants.gd:47` |
| starlight | 星辉 星屑落在伤口上，也落在经验里：经验 +30% | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_variants.gd:50` |
| iron_law | 铁律 无形的甲胄覆在守望者身上：受到伤害 -12% | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_variants.gd:53` |
| stasis | 静滞 魔弹更慢，却也更痛：弹速 -25% · 敌人伤害 +8% | 品质/弹速已接入，敌人伤害缺失：A02；`scripts/rogue_variants.gd:56` |
| wolves | 群狼 精英嚎叫此起彼伏：精英出现率 +12% · 掉落品质 +1 档 | 固定精英数量替代出现概率：A28；`scripts/rogue_variants.gd:59` |
| austerity | 苦修 以痛换财：受到伤害 +10% · 魔晶获取 +40% | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_variants.gd:62` |
| surge | 狂潮 魔弹又大又急：弹速 +15% · 弹幕尺寸 +10% | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_variants.gd:65` |
| abundance | 余裕 裂土渗出金屑与星屑：魔晶 +20% · 经验 +20% | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_variants.gd:68` |
| bargain | 议价 游商急着清货：商店价格 -25% · 掉落品质 -1 档 | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_variants.gd:71` |
| apocalypse | 天启 深层的启示让每一击都更重：普攻 +15% | 非只普攻，范围扩大：A27；`scripts/rogue_variants.gd:74` |
| blood_debt | 血债 魔境开始索要利息：受到伤害 +12% | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_variants.gd:77` |
| sanctuary | 圣佑 残破的圣坛仍在庇护靠近它的人：受到伤害 -10% · 敌人生命 -10% | 负生命变数普通怪重复两次、首领一次：A03；`scripts/rogue_variants.gd:80` |
| bedrock | 顽石 魔物的皮壳结成岩石：敌人生命 +20% | 正生命变数普通怪生效、首领被覆盖：A03；`scripts/rogue_variants.gd:83` |
| famine | 饥荒 魔境吞掉了收成：经验 -20% · 魔晶 -15% | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_variants.gd:86` |

### 10诅咒

| ID | 名称/描述 | 核查 |
|---|---|---|
| CU01 | 血蚀 受到的伤害 +15% | 受伤增幅落入减伤池，与简单独立乘数不同；已有专项回归；`scripts/rogue_curses.gd:44` |
| CU02 | 铁枷 移动速度 -18 | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_curses.gd:45` |
| CU03 | 贪婪之握 魔晶收入 -30% | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_curses.gd:46` |
| CU04 | 奸商印记 商店价格 +35% | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_curses.gd:47` |
| CU05 | 空箱咒 宝箱掉落率 -40% | chest_drop作用于属性灵晶概率；不减少装备三选一数量，文案范围应明确；`scripts/rogue_curses.gd:48` |
| CU06 | 干涸 治疗效果 -30% | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_curses.gd:49` |
| CU07 | 破瓶 血瓶容量 -25 | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_curses.gd:50` |
| CU08 | 迷雾 视野 -35% | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_curses.gd:51` |
| CU09 | 迟滞 技能冷却 +25% | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_curses.gd:52` |
| CU10 | 碎盾 受到的伤害 +10%，治疗效果 -15% | 受伤增幅落入减伤池，与简单独立乘数不同；已有专项回归；`scripts/rogue_curses.gd:53` |

### 9事件

| ID | 名称/描述 | 核查 |
|---|---|---|
| EV01 | 血祭石阶 各选项详见运行表 | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_events.gd:22` |
| EV02 | 锈蚀商栈 各选项详见运行表 | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_events.gd:27` |
| EV03 | 迷途魂灯 各选项详见运行表 | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_events.gd:32` |
| EV04 | 拾遗老树 各选项详见运行表 | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_events.gd:37` |
| EV05 | 深渊回声 各选项详见运行表 | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_events.gd:42` |
| EV06 | 贪婪秤盘 各选项详见运行表 | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_events.gd:46` |
| EV07 | 蚀骨温泉 各选项详见运行表 | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_events.gd:51` |
| EV08 | 无名祭坛 各选项详见运行表 | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_events.gd:56` |
| EV09 | 星屑坠地 各选项详见运行表 | 已有消费/发放入口；未逐项动态验收；`scripts/rogue_events.gd:61` |

事件EV01～EV09均走resolve/apply_delta，涵盖魔晶、HP/MP/血瓶、属性、锻造点、诅咒、装备队列；现有rogue_event_completion/event_network仍需要独立执行验证。本次只静态追踪发放链，不把它们记为本次动态通过。

## 32条派生目录

序列来自权威CM_ROUTES/HC_ROUTES。A=攻击、D=闪避、S=战技、U=Q、J=跳跃；不是键盘A/D。输入识别已有565规则回归中的32路线覆盖。推荐武器家族不等于权威限制，角色派生当前仅依据hero、序列、锻造等级与共享冷却判定。

| ID | 对象 | 序列 | 门槛/实效入口 |
|---|---|---|---|
| CM01 | 轻刃 | DA | +0；action_event识别；normal/start_art/resolve_art |
| CM02 | 轻刃 | AADA | +1；action_event识别；normal/start_art/resolve_art |
| CM03 | 轻刃 | >S | +3；action_event识别；normal/start_art/resolve_art |
| CM04 | 轻刃 | JAS | +3；action_event识别；normal/start_art/resolve_art |
| CM05 | 重刃 | DA | +0；action_event识别；normal/start_art/resolve_art |
| CM06 | 重刃 | ADS | +1；action_event识别；normal/start_art/resolve_art |
| CM07 | 重刃 | JA | +0；action_event识别；normal/start_art/resolve_art |
| CM08 | 重刃 | AJS | +3；action_event识别；normal/start_art/resolve_art |
| CM09 | 枪弓 | DA | +0；action_event识别；normal/start_art/resolve_art |
| CM10 | 枪弓 | AADS | +1；action_event识别；normal/start_art/resolve_art |
| CM11 | 枪弓 | JA | +0；action_event识别；normal/start_art/resolve_art |
| CM12 | 枪弓 | JAS | +3；action_event识别；normal/start_art/resolve_art |
| CM13 | 法杖 | DA | +0；action_event识别；normal/start_art/resolve_art |
| CM14 | 法杖 | ADS | +1；action_event识别；normal/start_art/resolve_art；CM14修正缺失见A29 |
| CM15 | 法杖 | JA | +0；action_event识别；normal/start_art/resolve_art |
| CM16 | 法杖 | JAS | +3；action_event识别；normal/start_art/resolve_art |
| HC01 | 绯月 | AADAS | +3；hero_effect，+5增强，共享8秒冷却 |
| HC02 | 绯月 | >SJA | +3；hero_effect，+5增强，共享8秒冷却 |
| HC03 | 绯月 | JAS | +3；hero_effect，+5增强，共享8秒冷却 |
| HC04 | 绯月 | ASU | +3；hero_effect，+5增强，共享8秒冷却 |
| HC05 | 雪璃 | ADS | +3；hero_effect，+5增强，共享8秒冷却 |
| HC06 | 雪璃 | JAS | +3；hero_effect，+5增强，共享8秒冷却 |
| HC07 | 雪璃 | AADS | +3；hero_effect，+5增强，共享8秒冷却 |
| HC08 | 雪璃 | DASU | +3；hero_effect，+5增强，共享8秒冷却 |
| HC09 | 鸦羽 | ADJS | +3；hero_effect，+5增强，共享8秒冷却 |
| HC10 | 鸦羽 | DAAS | +3；hero_effect，+5增强，共享8秒冷却 |
| HC11 | 鸦羽 | AA<>S | +3；hero_effect，+5增强，共享8秒冷却 |
| HC12 | 鸦羽 | JASU | +3；hero_effect，+5增强，共享8秒冷却 |
| HC13 | 墓煜 | ADS | +3；hero_effect，+5增强，共享8秒冷却 |
| HC14 | 墓煜 | AJAS | +3；hero_effect，+5增强，共享8秒冷却 |
| HC15 | 墓煜 | DAAS | +3；hero_effect，+5增强，共享8秒冷却 |
| HC16 | 墓煜 | ASU | +3；hero_effect，+5增强，共享8秒冷却 |

## 验证记录与边界

Godot 4.7.2 headless，当前源码：

| 测试 | 检查 | 失败 |
|---|---:|---:|
| rogue_build_rules | 565 | 0 |
| rogue_build_system | 440 | 0 |
| rogue_build_growth | 4066 | 0 |
| rogue_build_progression | 806 | 0 |
| rogue_passives | 21 | 0 |
| rogue_hooks_session | 44 | 0 |
| rogue_hooks_roguelike | 178 | 0 |
| rogue_growth | 6886 | 0 |
| 本次新增rogue_weapon_upgrade_audit | 718 | 0 |

合计13724检查通过。这说明已有覆盖的行为通过，不抵消本报告定向探针发现的问题。21/21审计观察复现异常或歧义不是“21个修复测试通过”。未跑真实多人、全战斗长时间DPS、渲染视觉以及发行包一致性测试。

可复现：

```powershell
& .\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/rogue_weapon_upgrade_audit.gd
& .\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script output/rogue_effect_audit_probe.gd
python tools/build_rogue_effect_audit.py
```

原始数据：output/rogue-weapon-upgrade-audit.json（48武器数值）、output/rogue-effect-audit-observations.json（21定向观察）。升级测试对状态/暴击/固有附击作了隔离，验证实际damage_enemy中的基础升级结算；不验证每把武器动画、命中几何或所有被动。探针中的直接Build调用用于隔离触发条件，与玩家按键的端到端测试有所区别。

## 修复顺序

1. 先解决A01领取反馈、A02/A03变数倍率、A04灰烬入库、A32联机个人成长数据，再处理明确伤害范围A05～A09和护盾来源A19。
2. 用每项描述中的对象/触发/窗口/首次/ICD/资源池六个字段建立行为用例，补齐A10～A18及A21～A31。先确定A20银鸦猎令间隔含义，不盲改平衡。
3. 修复后保留现有预算上限，更新内容生成源tools/build_rogue_content.py及JSON/设计文档，重新做实际操作、多人和发行包检查。不能仅修改JSON掩盖代码未实现，也不能只修代码让生成器下次重建又覆盖描述。
