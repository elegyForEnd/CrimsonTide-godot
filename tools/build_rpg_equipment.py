"""Author the campaign-only equipment catalog; no external assets or dependencies."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
stats = {
    "damage": "固定伤害", "hp": "固定生命", "damage_pct": "伤害", "hp_pct": "最大生命",
    "crit": "暴击率", "crit_damage": "暴击额外伤害", "haste": "普通攻击速度", "cooldown": "战技冷却缩减",
    "speed": "移动速度", "reduction": "全伤害减免", "resist": "本幕异质伤害抗性", "leech": "命中汲取生命",
    "boss_damage": "对首领伤害", "execute": "对低于30%生命敌人伤害", "skill_damage": "战技伤害",
    "splash": "普攻溅射伤害", "bleed": "3秒裂伤总伤害", "slow": "寒意减速", "vulnerable": "易伤增幅",
    "stagger": "普通敌人硬直几率", "charge": "协同充能效率", "regen": "每秒回复生命", "kill_heal": "击败回复生命",
    "dodge_barrier": "闪避后3秒护盾", "dash_damage": "闪避后下一次普攻伤害", "third_hit": "每第三次普攻伤害",
    "low_guard": "低于35%生命时额外减伤", "potion": "药剂治疗量", "escort_guard": "同行者伤害减免",
}
percent = [k for k in stats if k not in ["damage", "hp", "regen", "kill_heal", "dodge_barrier"]]
affixes = []


def aff(id, name, stat, low, span, step, slots="blade armor charm", act=1, group=None):
    affixes.append(dict(id=id, name=name, stat=stat, min=low, span=span, step=step,
                        slots=slots.split(), act=act, group=group or stat))


aff("keen", "锐利", "damage", 2, 4, 1.5, "blade charm")
aff("vital", "蓄光", "hp", 8, 12, 3, "armor charm")
aff("fervor", "炽志", "damage_pct", 3, 5, 1, "blade charm")
aff("oak", "坚韧", "hp_pct", 3, 5, 1, "armor charm")
aff("precise", "准星", "crit", 3, 4, .7, "blade charm")
aff("cruel", "锐痛", "crit_damage", 8, 10, 2, "blade charm", 2)
aff("swift", "疾刃", "haste", 3, 5, .8, "blade")
aff("lucid", "清明", "cooldown", 3, 5, .8, "charm robe".replace("robe", "armor"))
aff("wayfarer", "远行", "speed", 2, 3, .5, "armor charm")
aff("bulwark", "壁垒", "reduction", 2, 3, .5, "armor")
aff("conduit", "隔潮", "resist", 5, 6, 1, "armor charm")
aff("thirst", "饮晶", "leech", .5, .7, .15, "blade charm", 2)
aff("regicide", "逆冠", "boss_damage", 4, 6, 1, "blade charm", 2)
aff("mercy", "终裁", "execute", 4, 6, 1, "blade", 2)
aff("invocation", "祷锋", "skill_damage", 4, 6, 1, "blade charm")
aff("echo", "余震", "splash", 5, 7, 1, "blade", 3)
aff("wound", "裂痕", "bleed", 5, 7, 1, "blade", 2)
aff("winter", "霜息", "slow", 5, 6, 1, "blade charm", 2)
aff("expose", "剥印", "vulnerable", 2, 3, .4, "blade", 3)
aff("impact", "震慑", "stagger", 3, 5, .8, "blade", 2)
aff("chorus", "共鸣", "charge", 4, 6, 1, "blade charm")
aff("renew", "回春", "regen", .3, .4, .1, "armor charm")
aff("reclaim", "余烬", "kill_heal", 2, 3, .7, "blade armor")
aff("veil", "留光", "dodge_barrier", 5, 7, 1.5, "armor charm")
aff("pursuit", "逐影", "dash_damage", 6, 8, 1.5, "blade charm", 2)
aff("cadence", "三叠", "third_hit", 8, 10, 2, "blade", 3)
aff("resolve", "不屈", "low_guard", 3, 4, .7, "armor", 2)
aff("apothecary", "药师", "potion", 5, 7, 1, "armor charm")
aff("convoy", "护送", "escort_guard", 4, 5, 1, "armor charm")
aff("barbed", "棱刺", "damage", 5, 3, 1.7, "blade", 4, "damage")
aff("hearth", "余温", "hp", 16, 10, 4, "armor", 4, "hp")
aff("discipline", "定心", "cooldown", 5, 4, .9, "charm", 4, "cooldown")

sets = []
set_rows = [
    ("lamplighter", "雾桥守灯人", {"hp": 24, "escort_guard": 10}, {"regen": 1.2, "dodge_barrier": 16}),
    ("testimony", "灰页证言", {"cooldown": 10, "resist": 12}, {"skill_damage": 22, "charge": 16}),
    ("oath", "断星旧誓", {"crit": 8, "boss_damage": 10}, {"third_hit": 35, "low_guard": 10}),
    ("unbound", "解契之手", {"hp_pct": 10, "reduction": 6}, {"vulnerable": 8, "leech": 2}),
    ("homeward", "逆潮归航", {"speed": 8, "escort_guard": 15}, {"dodge_barrier": 28, "dash_damage": 35}),
    ("dawn", "共同黎明", {"boss_damage": 14, "resist": 18}, {"charge": 25, "skill_damage": 25, "regen": 1}),
]
for act, (id, name, two, three) in enumerate(set_rows, 1):
    sets.append({"id": id, "name": name, "act": act, "2": two, "3": three})

uniques = []


def unique(act, hero, slot, name, title, effect, mods):
    uniques.append(dict(id=f"a{act}-{slot}-{hero}", act=act, hero=hero, slot=slot,
                        name=name, title=title, effect=effect, mods=mods))


weapons = [
    [("未熄的桥火", "守灯", "击败敌人回复生命，战技更强。", {"kill_heal": 8, "skill_damage": 12}),
     ("借来的晨光", "灯芯", "缓慢恢复生命；帮助同行者抵御攻击。", {"regen": 1.2, "escort_guard": 12}),
     ("无人署名的路标", "开路", "闪避后的下一次普通攻击得到增幅。", {"dash_damage": 28, "speed": 5})],
    [("判词背面的名字", "异议", "提高对首领伤害与暴击率。", {"boss_damage": 18, "crit": 7}),
     ("灰页不焚", "复诵", "缩短战技冷却并增加战技伤害。", {"cooldown": 12, "skill_damage": 18}),
     ("证人仍在呼吸", "划证", "普通攻击使敌人裂伤，3秒造成额外伤害。", {"bleed": 22, "haste": 8})],
    [("山口最后一班岗", "旧誓", "每第三次命中的普攻增伤，命中汲取生命。", {"third_hit": 40, "leech": 1.5}),
     ("断星测距灯", "星散", "普通攻击溅射附近可见敌人，命中附寒意。", {"splash": 22, "slow": 16}),
     ("捕猎索的断端", "追猎", "闪避后普攻更强，对濒危敌人增伤。", {"dash_damage": 32, "execute": 18})],
    [("契印拆解刀", "拆契", "命中施加4秒易伤；伤害会转化少量生命。", {"vulnerable": 10, "leech": 2}),
     ("拒绝量身的灯架", "逆缝", "闪避生成短时护盾，提升药剂治疗量。", {"dodge_barrier": 30, "potion": 20}),
     ("未送出的针线", "拆线", "裂伤与暴击相互补足，保留行动速度。", {"bleed": 24, "crit_damage": 25, "speed": 4})],
    [("逆流船首", "破浪", "普攻溅射并提高命中硬直几率；首领免硬直。", {"splash": 28, "stagger": 18}),
     ("七人渡灯", "返航", "同行者减伤；闪避护盾保护当前操作者。", {"escort_guard": 22, "dodge_barrier": 32}),
     ("断缆之后", "离港", "更快普攻为协同技提供更多充能。", {"haste": 18, "charge": 24})],
    [("转刃的黎明", "共同终结", "增加首领伤害与协同充能，仍需解除母晶机制。", {"boss_damage": 25, "charge": 25}),
     ("无需王冠的晨星", "守约", "强化战技、恢复与异质抗性。", {"skill_damage": 25, "regen": 1.5, "resist": 15}),
     ("第三张回程票", "归队", "每第三次普攻爆发，暴击造成更多伤害。", {"third_hit": 45, "crit_damage": 30, "crit": 7})],
]
for act, row in enumerate(weapons, 1):
    for hero, (name, title, effect, mods) in enumerate(row):
        unique(act, hero, "blade", name, title, effect, mods)

armor_names = ["医棚门前的外衣", "查封线下的衬衣", "卸下军徽的披风", "不合尺寸的礼服", "盐蚀救生衣", "留给明天的守衣"]
charm_names = ["缺角蜡印", "夹在灰页里的花", "停走的信站表", "剪开的契印环", "有编号的船票", "不会传位的冠屑"]
armor_effects = [
    ("医棚余温", "离开医棚仍能缓慢回复生命，药剂带来更多治疗。", {"regen": .8, "potion": 16, "hp": 14}),
    ("不燃衬里", "抵御焚书礼堂的异质伤害，并缩短战技冷却。", {"resist": 18, "reduction": 5, "cooldown": 6}),
    ("卸甲不退", "濒危时获得额外减伤，同时提高反击的暴击率。", {"low_guard": 16, "crit": 6, "hp_pct": 8}),
    ("拒绝缝合", "命中汲取生命并缓慢自愈，持续作战无需追逐击杀。", {"leech": 1.5, "regen": 1.3, "reduction": 6}),
    ("七人共渡", "闪避生成护盾，同时帮助同行者抵御红潮。", {"dodge_barrier": 30, "escort_guard": 18, "resist": 10}),
    ("守到天明", "低生命减伤与闪避护盾相互补足，提高协同充能。", {"low_guard": 14, "dodge_barrier": 28, "charge": 18}),
]
charm_effects = [
    ("蜡封余香", "强化药剂与微量恢复，减少早期追缉中的补给压力。", {"potion": 20, "regen": .5, "charge": 8}),
    ("花押异议", "命中留下易伤证印，战技可以更频繁使用。", {"vulnerable": 6, "cooldown": 10}),
    ("第三声报时", "每第三次命中的普通攻击得到额外增幅。", {"third_hit": 28, "crit_damage": 18}),
    ("自行解扣", "以更充裕的生命施展更强的战技。", {"hp_pct": 12, "skill_damage": 20}),
    ("回程在手", "移动与闪避后的反击更强，同时保护同行者。", {"speed": 8, "dash_damage": 28, "escort_guard": 12}),
    ("拒绝继位", "专注攻击首领并为三人协同积蓄力量。", {"boss_damage": 20, "charge": 25, "low_guard": 8}),
]
for act in range(1, 7):
    unique(act, -1, "armor", armor_names[act - 1], *armor_effects[act - 1])
    unique(act, -1, "charm", charm_names[act - 1], *charm_effects[act - 1])

runes = {
    "ember": {"name": "赤棱晶", "base": "gem_ember", "mods": {"blade": {"bleed": 12}, "armor": {"low_guard": 8}, "charm": {"crit": 5}}},
    "rime": {"name": "霜心晶", "base": "gem_rime", "mods": {"blade": {"slow": 12}, "armor": {"resist": 12}, "charm": {"cooldown": 7}}},
    "gale": {"name": "羽纹晶", "base": "gem_gale", "mods": {"blade": {"haste": 7}, "armor": {"speed": 5}, "charm": {"dash_damage": 18}}},
    "light": {"name": "导光晶石", "base": "crystal", "mods": {"blade": {"charge": 12}, "armor": {"escort_guard": 10}, "charm": {"regen": .6}}},
}
chapters = [
    {"act": 1, "name": "雾桥追缉", "threat": "修院弩阵、囚车护送", "element": "physical", "focus": "生命、药剂、护送与闪避，先教生存，再教词缀。"},
    {"act": 2, "name": "灰页审判", "threat": "焚书礼堂、宣判隔断", "element": "fire", "focus": "异质抗性与战技；装备不能跳过三道宣判隔断。"},
    {"act": 3, "name": "断星山口", "threat": "伏击、矿坑、维恩重盾", "element": "frost", "focus": "单体暴击、低血守护；重盾仍要引向断柱。"},
    {"act": 4, "name": "王庭拆契", "threat": "麻醉阀、承重手术偶", "element": "venom", "focus": "续航、易伤；易伤不能抵消机关无敌与阶段血线。"},
    {"act": 5, "name": "逆潮归航", "threat": "红潮、七人救援、舰队", "element": "tide", "focus": "位移、护盾和护送减伤；潮水不能靠击杀吸血解决。"},
    {"act": 6, "name": "赤月终局", "threat": "六翼、母晶、三人协作", "element": "blood", "focus": "首领伤害、协同与抗性；保留三人机关和最终转刃。"},
]
payload = dict(revision=1, stats=stats, percent_stats=percent, affixes=affixes,
               uniques=uniques, sets=sets, runes=runes, chapters=chapters)
(ROOT / "resources/rpg_equipment.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"equipment catalog: {len(affixes)} affixes, {len(uniques)} uniques, {len(sets)} sets, {len(runes)} runes")
