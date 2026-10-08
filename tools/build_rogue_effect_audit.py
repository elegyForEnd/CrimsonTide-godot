"""Rebuild the 2026-10-08 source audit catalog; does not modify gameplay data."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = json.loads((ROOT / "resources/rogue_build_content.json").read_text(encoding="utf-8"))
sources = {}
for path in (ROOT / "scripts").glob("*.gd"):
    function = "文件常量"
    rows = []
    for line, text in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        match = re.match(r"(?:static )?func (\w+)", text)
        if match:
            function = match[1]
        if not text.lstrip().startswith("#"):
            rows.append((line, function, text))
    sources[path.name] = rows

def anchor(file, function):
    line = next((n for n, fn, text in sources[file] if fn == function), 1)
    return f"`scripts/{file}:{line}` `{function}()`"

def evidence(entry):
    id = entry["id"]
    prefix = "WC" if id.startswith("WC") else id[0]
    number = int(id[len(prefix):])
    lookup = {"T":r"(?:rank|r|aura)", "E":"gear", "I":"engraving", "WC":"core"}.get(prefix)
    found = []
    if lookup:
        regex = re.compile(rf"\b{lookup}\([^,\n]+,\s*{number}(?:\s*[,\)]|==)")
        for file, rows in sources.items():
            for line, fn, text in rows:
                if regex.search(text):
                    found.append((file, fn, line))
    if prefix == "T" and number in [1, 9, 17]:
        found.append(("rogue_build.gd", "hit_multiplier", 461))
    if prefix == "T" and number in [25, 33, 41]:
        found.append(("rogue_build.gd", "hit_event", 570))
    if prefix == "T" and number in [90,91]:
        found.append(("rogue_build.gd", "stat", 126 if number==90 else 128))
    if prefix == "I" and number in [5, 6, 7, 8]:
        found.append(("rogue_build.gd", "hit_event", 632))
    if prefix == "W":
        found.extend([("rogue_actions.gd", "normal", 134), ("rogue_actions.gd", "resolve_art", 96)])
        specific = {33:("session.gd","move_player"),34:("session.gd","damage_enemy"),42:("rogue_actions.gd","normal"),44:("session.gd","spell_burst"),45:("session.gd","move_player")}
        if number in specific:
            file, fn = specific[number]
            found.append((file, fn, next(n for n,f,t in sources[file] if f==fn)))
        for n, fn, text in sources["rogue_build.gd"]:
            if re.search(rf"\bw\s*==\s*{number}\b|^\s*{number}(?:,\d+)*\s*:", text):
                found.append(("rogue_build.gd", fn, n))
    unique = {}
    for file, fn, n in found:
        unique.setdefault((file, fn), n)
    return "；".join(f"`{file}:{n}` {fn}" for (file,fn),n in list(unique.items())[:5]) or "数据属性入口；需进一步单项动态验收"

# IDs, severity, evidence level, observation and implementation location.
ISSUES = [
 ("A01", "P1", "动态复现", ["T007"], "所有进阶/核心天赋领取反馈", "apply_offer_reason把天赋收入build_library后调用activate，但忽略false；前置/修为/8槽/单核心限制失败仍返回成功。实际进阶T007领取成功但build_talents无此ID，战斗当然不生效。奖励领取必须区分已激活和仅收藏，并显示具体原因。", "roguelike.gd", "apply_offer_reason"),
 ("A02", "P1", "动态复现", [], "血月/静滞的敌人伤害修正", "enemy_budget读取合并后的enemy_damage却clamp到[-0.95,0]，正向增伤被截成0；无成长时血月+15%、静滞+8%缺失。若同时有成长减敌伤，正变数还会抵消成长减益而非独立正确生效。实际攻击读的正是该build_damage_scale。", "rogue_build.gd", "enemy_budget"),
 ("A03", "P1", "动态复现", [], "变数生命覆盖/重复应用", "setup_boss先应用变数并置variant_stats_applied=true，enemy_budget覆盖hp/max_hp时合并enemy_hp只保留负值；顽石+20%首领加成丢失，标记阻止补应用。普通怪setup_minion未传s，enemy_budget已应用负变数，update又补乘一次：狂暴应×0.92实际×0.8464；圣佑应×0.90实际×0.81。正变数普通怪在补应用时生效，负变数首领在budget生效一次。", "rogue_combat.gd", "setup_boss"),
 ("A04", "P1", "动态复现", [], "赌徒/镜像获得的灰烬入库", "apply_room_delta只增加p.rogue_ash_run；Growth.grant只向profile.ashes加本次基础结算值，未把已有房间灰烬入库。探针已有50房间灰烬，局内总数为基础值+50，永久钱包却只收到基础值。联机入库还需另验。", "rogue_growth.gd", "grant"),
 ("A05", "P1", "动态复现", ["T072"], "余烬守誓代价范围", "说明自身所有直接伤害×0.88，实际penalty只在normal分支；右键和Q不付这项代价，反伤例外倒是正确。", "rogue_build.gd", "hit_multiplier"),
 ("A06", "P1", "动态复现", ["T095"], "晨光裁敌加伤范围", "治疗成功确实授予healed=10/15%，但只在normal分支读取和消耗。右键/Q完全不吃下次直击加伤，也不消耗它。", "rogue_build.gd", "hit_multiplier"),
 ("A07", "P1", "动态复现", ["T056"], "星泉共鸣对Q的加成", "法术判断包含ctx.kind==skill，所以高蓝Q也获得18%条件加伤；内容表明确写不加Q伤害。", "rogue_build.gd", "hit_multiplier"),
 ("A08", "P1", "动态复现", ["T086"], "冥火指令锁定目标", "U事件仅授予soul_order伤害加成，未授予soul_target。现有灵体继续追soul_focus/自动目标；hero_skill命中后更新focus不等于立即按瞄准锁3秒。不能把墓煜角色连招中的soul_target实现算给T086。", "rogue_build.gd", "action_event"),
 ("A09", "P1", "动态复现", ["WC010"], "星环落地减蓝耗", "落地授予landing_cost要求air_attacks>0，只空中右键成功不会触发；描述是跳跃施法成功。landing_cost还在首次任意普攻命中后删除，支付后空挥则保留，资源消耗时机也不统一。", "rogue_build.gd", "tick"),
 ("A10", "P2", "动态复现", ["T038"], "寂冬裂晶触发时机", "普通怪叠满冰缓立即proc，然后才经历stagger；应为冻结结束追加伤害。Boss满层立即触发符合说明，不能一起后移。", "rogue_build.gd", "add_status"),
 ("A11", "P2", "动态复现", ["T037","E009","E062"], "冻结被动共用错误计时", "三个效果没有各自8秒ready，而是跟随build_cc_until。T040把硬控间隔减为6秒/E038减为7秒时，它们也能6/7秒再触发，违背各自8秒描述。", "rogue_build.gd", "add_status"),
 ("A12", "P2", "动态复现", ["T075","I020","W005"], "闪避追击缺4秒间隔", "每次D直接授予dodge_strike/dodge_window，没有4秒ready；约2秒闪避再次获得加成。T075和I020自身都明写4秒，W005也没有对应计时键。", "rogue_build.gd", "action_event"),
 ("A13", "P2", "动态复现", ["W005"], "银月细剑非首次攻击", "W005读取持续2秒的dodge_window，首次攻击后不删除；窗口内第二次及后续普攻也加16%。", "rogue_build.gd", "hit_multiplier"),
 ("A14", "P2", "动态复现", ["E011"], "雷翼轻甲窗口缩水", "文本3秒，实际复用dodge_window=2秒；2.5秒普攻不能叠感电。", "rogue_build.gd", "hit_event"),
 ("A15", "P2", "动态复现", ["E006"], "断誓锁甲家族限制缺失", "受击授予通用counter，所有家族normal都读；法杖也吃20%加伤。应单独限定重刃，不能顺便限制T069共享counter。", "rogue_build.gd", "incoming"),
 ("A16", "P2", "动态复现", ["E054"], "血棘绑腿遗漏战技/Q", "说明直击自己的出血目标后减伤，实际放在if normal；右键/Q命中不触发。E010的同类冰缓减伤放在normal外，能正常覆盖直击。", "rogue_build.gd", "hit_event"),
 ("A17", "P2", "动态复现", ["E048"], "盟约旗扣多人时自触发", "实际自己art无论单人多人都回蓝，同时也监听其他队友；文本仅单人允许自身art触发。", "rogue_build.gd", "hit_event"),
 ("A18", "P2", "动态复现", ["T055"], "泉眼回响进度溢出", "只有ready成功分支才扣40并钳制39，冷却期间继续扣蓝可留下80等超阈值进度。应在每次累计时处理上限和单次储存。", "rogue_build.gd", "spend_event"),
 ("A19", "P1", "动态复现", ["T094","T096","I021","WC005"], "不同护盾来源相互覆盖", "大量shield调用省略source，全部写general；两种4%/6%来源实际合为6%，而非共用35%上限下合为10%。Q原盾、T094、T096、I021、WC005等互相覆盖或延长持续时间，违背不同来源分别刷新。", "rogue_build.gd", "shield"),
 ("A20", "P2", "动态观察/规则歧义", ["T024"], "银鸦猎令22%是否受3秒间隔", "额外22%条件伤害对每次标记攻击都生效，只有跳击受3秒ready。当前文字把22%与跳击写在同一句末尾，容易理解为整体ICD；需明确两者是否共用间隔后再改数值。", "rogue_build.gd", "hit_multiplier"),
 ("A21", "P2", "静态确认", ["E008"], "烛火祭袍持续上限", "文本说刷新最多5秒，实现所有灼烧延长统一min(6,...)；E008与T026/E035/I011组合可超5秒。先统一装备和全局上限的设计。", "rogue_build.gd", "add_status"),
 ("A22", "P2", "静态确认", ["E018","E055"], "移动惩罚描述不一致", "E018只在轻刃active_attack无条件把.8改1.0，没有检查闪避后2秒，且不作用于重刃；E055代码仅pending_strike前摇时减罚，不覆盖整个挥击。W015的-30%则通过重刃默认.7实现，不是未实现。", "session.gd", "move_player"),
 ("A23", "P2", "静态确认", ["E060"], "烛影灰履没有铺闪避路径", "D开始只在起点field一次，非沿闪避轨迹；两处火点上限由全局build_fields.size>=2控制，和E036/T032/Q区域共享，两块其它区域存在时鞋子被动直接失效。", "rogue_build.gd", "action_event"),
 ("A24", "P2", "静态确认", ["T079","E070","WC007"], "一次性窗口及间隔不统一", "T079用整个dodge_window，无首个右键消费标记；E070跟随perfect全局3秒而非自身5秒；WC007装填加速5秒后过期，文本说持续到一次装填，且任意闪避授予而非只在滑射后。", "rogue_build.gd", "perfect"),
 ("A25", "P2", "静态确认", ["T028","E007"], "敌方灼烧抗性未消费", "T028/E007在roguelike岩浆分支读取；敌人持续区域统一hurt(...,direct,element)，没有敌方burn/DoT对应的专用抗火消费点。岩浆减伤确实有效，但不能据此声称敌方灼烧抗性已完成。", "roguelike.gd", "tick"),
 ("A26", "P2", "静态确认", ["T029"], "烛火蔓延可再次传播", "killed允许dot击杀，传播施加的burn没有来源/不可传播标记；后继burn杀敌仍可重新经过同一个传播分支。需要单独标记传播来源，保持原生灼烧击杀正常。", "rogue_build.gd", "killed"),
 ("A27", "P2", "静态确认", [], "锈蚀/天启作用于所有输出", "变数文本普攻-10%/+15%，damage_enemy对所有kind（含战技/Q/proc/DoT/召唤）乘player_damage，不检查attack。同键还被永久成长猎杀本能使用，不能直接全局限制这个键。", "session.gd", "damage_enemy"),
 ("A28", "P2", "静态确认", [], "群狼精英率不是概率", "+12%通过round(delta/.12)转换成精英房固定多1名，只在elite房执行；普通房不因此出现精英。需把描述改为实际的固定精英数，或实现真实概率。", "roguelike.gd", "spawn_wave"),
 ("A29", "P2", "静态确认", [], "法杖折光CM14缺独立120单位修正", "识别ADS并有标签/分段，但start_art/resolve_art没有法杖route1的目标点修正逻辑；仍用通用aim_point。不能把序列识别通过当作该派生特性实现。", "rogue_actions.gd", "start_art"),
 ("A30", "P2", "静态确认", [], "升空共享冷却绕过寂冬契约", "resolve_art升空分支硬写build_cc_until=elapsed+8，未读取T040/E038；冻结和升空虽共享字段，但缩短硬控间隔的配置不能统一生效。是否要让装备同时缩短升空需设计确认。", "rogue_actions.gd", "resolve_art"),
 ("A31", "P2", "静态确认", [], "补正升档没有在属性页展示", "Build.grades参与真实weapon_scaling，属性页补正文案却用Catalog.scaling_text原始表，不显示+3升档后的等级；玩家可能看起来没有升级效果。", "rogue_build_ui.gd", "attribute_sheet"),
 ("A32", "P1", "静态确认/联机待动态验证", [], "永久成长以房主数据作用全队", "session.rogue_mods固定读session.profile_data；reset开局钱包和刷新也是同一meta给全体玩家，没有按玩家成长数据。客户端自己的购买只本地保存，无法成为权威数值输入；专用服无profile时成长全零。单机生效不能代表多人每个人买的都生效。", "session.gd", "rogue_mods"),
]

intro = """# 魔境闯关构筑效果审计（2026-10-08）

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

"""

lines = [intro]
by_id = {}
for id, severity, level, ids, name, detail, file, fn in ISSUES:
    lines.append(f"### {id} · {severity} · {name}\n\n{level}。{detail}\n\n入口：{anchor(file,fn)}。\n\n")
    for item_id in ids:
        by_id.setdefault(item_id, []).append(id)
lines.append("""## 残留接口与设计未完成项

- 旧BOONS五祝福没有生产发放点，行囊旧祝福页也无入口，属于被新版天赋替代后的兼容残留；不应当成可获得的新加成。
- rogue_equipment.damage_multiplier/tick/spent/hit为旧空接口，生产没有调用，真正被动在rogue_build及session/roguelike等处。不要为了“让空接口有效”再接一次，容易重复吸血/伤害。
- 16条家族输入路线与16条角色路线均有识别代码，已有测试主要证明输入识别/冷却，而非每项几何、落地时机和动画效果。CM14的专用修正缺失已列A29。角色hero_effect有伤害、状态、盾/治疗和魂指令；需要逐条实际操作验证。
- 设计文档的30秒安全靶区、新锻造等级的逐步教学/终式回放未找到对应完整生产流程；现有连招手册/只读预览不能当成已完成这些教学。
- 32角色/家族连招未对真实操作容错、帧率及网络延迟逐项验收；本报告没有把这部分说成已全通过。

## 全量252项目录

下表原文取当前运行JSON。代码入口行号是本次源码位置；未改动运行脚本。天赋领取问题A01适用于所有需前置/预算的卡片，而非只有示例T007。装备还会通过rogue_equipment.value/total提供数据表中的HP/MP/移速/攻击/防御/暴击基础属性。

""")
for category, title in [("weapons","48武器"),("gear","72装备"),("talents","96天赋"),("engravings","24铭刻"),("cores","12武器核心")]:
    lines.append(f"### {title}\n\n| ID/名称 | 运行描述 | 结论 | 执行入口 |\n|---|---|---|---|\n")
    for entry in DATA[category]:
        status = "已接入（静态核对）"
        if entry["id"] in by_id:
            status = "部分不符：" + "/".join(by_id[entry["id"]])
        description = entry.get("text",entry.get("desc",""))
        if category == "weapons":
            description += "；战技："+entry["art"]["name"]+"，倍率"+str(entry["art"]["damage"])+"，蓝耗"+str(entry["art"]["mana"])+"，CD"+str(entry["art"]["cooldown"])
        lines.append(f"| {entry['id']} {entry['name']} | {description.replace('|','/')} | {status} | {evidence(entry)} |\n")
    lines.append("\n")

lines.append("## 永久成长、变数、诅咒和事件全量目录\n\n")
for file, title in [("rogue_growth.gd","14永久成长"),("rogue_variants.gd","18层变数"),("rogue_curses.gd","10诅咒"),("rogue_events.gd","9事件")]:
    text = (ROOT / "scripts" / file).read_text(encoding="utf-8-sig")
    pattern = r'"([a-z_]+)":\s*\{\s*"name":\s*"([^"]+)",\s*"desc":\s*"([^"]+)"' if file=="rogue_growth.gd" else r'\{"id":\s*"([^"]+)",\s*"name":\s*"([^"]+)"(?:,\s*"desc":\s*"([^"]+)")?'
    rows = list(re.finditer(pattern,text))
    lines.append(f"### {title}\n\n| ID | 名称/描述 | 核查 |\n|---|---|---|\n")
    for match in rows:
        id, name, desc = match.groups()
        note = "已有消费/发放入口；未逐项动态验收"
        if file=="rogue_growth.gd": note="单机已接入；多人按个人存档未接入，见A32"
        if id in ["blood_moon","stasis"]: note="品质/弹速已接入，敌人伤害缺失：A02"
        if id in ["frenzy","sanctuary"]: note="负生命变数普通怪重复两次、首领一次：A03"
        if id=="bedrock": note="正生命变数普通怪生效、首领被覆盖：A03"
        if id in ["rust","apocalypse"]: note="非只普攻，范围扩大：A27"
        if id=="wolves": note="固定精英数量替代出现概率：A28"
        if id in ["CU01","CU10"]: note="受伤增幅落入减伤池，与简单独立乘数不同；已有专项回归"
        if id=="CU05": note="chest_drop作用于属性灵晶概率；不减少装备三选一数量，文案范围应明确"
        line=text[:match.start()].count("\n")+1
        lines.append(f"| {id} | {name} {desc or '各选项详见运行表'} | {note}；`scripts/{file}:{line}` |\n")
    lines.append("\n")
lines.append("""事件EV01～EV09均走resolve/apply_delta，涵盖魔晶、HP/MP/血瓶、属性、锻造点、诅咒、装备队列；现有rogue_event_completion/event_network仍需要独立执行验证。本次只静态追踪发放链，不把它们记为本次动态通过。

## 32条派生目录

序列来自权威CM_ROUTES/HC_ROUTES。A=攻击、D=闪避、S=战技、U=Q、J=跳跃；不是键盘A/D。输入识别已有565规则回归中的32路线覆盖。推荐武器家族不等于权威限制，角色派生当前仅依据hero、序列、锻造等级与共享冷却判定。

| ID | 对象 | 序列 | 门槛/实效入口 |
|---|---|---|---|
""")
buildtext=(ROOT / "scripts/rogue_build.gd").read_text(encoding="utf-8-sig")
for kind, names in [("CM",["轻刃","重刃","枪弓","法杖"]),("HC",["绯月","雪璃","鸦羽","墓煜"])]:
    routes=json.loads(re.search(rf"const {kind}_ROUTES := (.+)",buildtext)[1])
    for group, routeset in enumerate(routes):
        for i, route in enumerate(routeset):
            gate=3 if kind=="HC" else ([0,1,3,3] if group==0 else [0,1,0,3])[i]
            effect="hero_effect，+5增强，共享8秒冷却" if kind=="HC" else "action_event识别；normal/start_art/resolve_art；CM14修正缺失见A29" if group==3 and i==1 else "action_event识别；normal/start_art/resolve_art"
            lines.append(f"| {kind}{group*4+i+1:02d} | {names[group]} | {route} | +{gate}；{effect} |\n")
lines.append("""
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
& .\\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/rogue_weapon_upgrade_audit.gd
& .\\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script output/rogue_effect_audit_probe.gd
python tools/build_rogue_effect_audit.py
```

原始数据：output/rogue-weapon-upgrade-audit.json（48武器数值）、output/rogue-effect-audit-observations.json（21定向观察）。升级测试对状态/暴击/固有附击作了隔离，验证实际damage_enemy中的基础升级结算；不验证每把武器动画、命中几何或所有被动。探针中的直接Build调用用于隔离触发条件，与玩家按键的端到端测试有所区别。

## 修复顺序

1. 先解决A01领取反馈、A02/A03变数倍率、A04灰烬入库、A32联机个人成长数据，再处理明确伤害范围A05～A09和护盾来源A19。
2. 用每项描述中的对象/触发/窗口/首次/ICD/资源池六个字段建立行为用例，补齐A10～A18及A21～A31。先确定A20银鸦猎令间隔含义，不盲改平衡。
3. 修复后保留现有预算上限，更新内容生成源tools/build_rogue_content.py及JSON/设计文档，重新做实际操作、多人和发行包检查。不能仅修改JSON掩盖代码未实现，也不能只修代码让生成器下次重建又覆盖描述。
""")
output=ROOT / "output/ROGUE-EFFECTS-AUDIT-2026-10-08.md"
output.write_text("".join(lines),encoding="utf-8")
assert sum(len(DATA[k]) for k in ["weapons","gear","talents","engravings","cores"])==252
print(f"Wrote {output}; 252 content rows; {len(ISSUES)} issue groups")
