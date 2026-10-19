extends RefCounted
## 雷霆十二式 · 局内能力成长（run-only）。
##
## 规则（2026-10-19 用户拍板）：
##   * 能力只从“每 3 级”的升级弹窗产出，普通战斗宝箱不再出能力；
##   * 每次弹窗从 3 个不同能力里选 1 个；
##   * 同名能力最多获取 3 次（1 解锁 + 2 次强化），满 3 次后移出池；
##   * 全局没有获取上限；12 式全部满级后，后续每 3 级的里程碑直接折算魔晶；
##   * 不占天赋槽、不耗修为，本局结束清除。
##
## 战斗侧只问本文件的静态函数，不复制第二份数值。

const MAX_RANK := 3
const TRACKS := [
	{"id":"AB01","key":"attack","name":"连锁雷","action":"普攻","icon":"T001","color":"ff8358",
		"ranks":[
			{"text":"普攻周期 -4%；第三段引雷 0.12P，弹向 1 名敌人。"},
			{"text":"普攻周期 -6%；引雷 0.18P，弹向 1 名敌人。"},
			{"text":"普攻周期 -8%；引雷 0.24P，弹向 2 名敌人。"}]},
	{"id":"AB02","key":"art","name":"过载","action":"战技","icon":"T057","color":"83b9ef",
		"ranks":[
			{"text":"战技伤害 +10%，冷却 -6%，蓝耗 -5%。"},
			{"text":"战技伤害 +16%，冷却 -10%，蓝耗 -8%。"},
			{"text":"战技伤害 +22%，冷却 -14%，蓝耗 -12%。"}]},
	{"id":"AB03","key":"ultimate","name":"雷狱","action":"奥义","icon":"T094","color":"d9b578",
		"ranks":[
			{"text":"奥义伤害 +10%；落点留下 2 秒雷狱，每秒 0.08P。"},
			{"text":"奥义伤害 +16%；雷狱 3 秒，每秒 0.12P。"},
			{"text":"奥义伤害 +22%；雷狱 3.5 秒，每秒 0.16P。"}]},
	{"id":"AB04","key":"dodge","name":"雷影","action":"闪避","icon":"T074","color":"8fd8bd",
		"ranks":[
			{"text":"闪避冷却 -6%，距离 +4%，完美窗口 +0.02 秒。"},
			{"text":"闪避冷却 -10%，距离 +8%；闪避结束雷影剑气 0.18P。"},
			{"text":"闪避冷却 -14%，距离 +12%；雷影剑气 0.26P。"}]},
	{"id":"AB05","key":"flask","name":"雷血","action":"血瓶","icon":"T092","color":"c8a0b4",
		"ranks":[
			{"text":"血瓶回复 +6%；饮下获 4% 护盾；下一发普攻引雷 0.12P。"},
			{"text":"回复 +10%；护盾 7%；引雷 0.20P。"},
			{"text":"回复 +14%；护盾 10%；引雷 0.28P。"}]},
	{"id":"AB06","key":"crit","name":"鹰眼","action":"暴击","icon":"T021","color":"ffd479",
		"ranks":[
			{"text":"暴击率 +3%，暴击伤害 +10%。"},
			{"text":"暴击率 +6%，暴击伤害 +20%。"},
			{"text":"暴击率 +9%，暴击伤害 +30%。"}]},
	{"id":"AB07","key":"guard","name":"铁壁","action":"防御","icon":"T066","color":"a8c4d8",
		"ranks":[
			{"text":"常驻减伤 +3%。"},
			{"text":"常驻减伤 +5%。"},
			{"text":"常驻减伤 +7%。"}]},
	{"id":"AB08","key":"speed","name":"逐风","action":"移速","icon":"T042","color":"9fe0c8",
		"ranks":[
			{"text":"移动速度 +6。"},
			{"text":"移动速度 +10。"},
			{"text":"移动速度 +14。"}]},
	{"id":"AB09","key":"summon","name":"引魂","action":"召唤","icon":"T081","color":"c3a6ff",
		"ranks":[
			{"text":"每 5 次普攻召唤 1 只灵体，持续 4 秒，每秒 0.05P。"},
			{"text":"每 4 次普攻召唤 1 只灵体，持续 5 秒，每秒 0.07P。"},
			{"text":"每 3 次普攻召唤 1 只灵体，持续 6 秒，每秒 0.09P。"}]},
	{"id":"AB10","key":"burn","name":"烬印","action":"灼烧","icon":"T025","color":"ff9b56",
		"ranks":[
			{"text":"普攻附加 1 层灼烧，间隔 2 秒；对灼烧目标伤害 +4%。"},
			{"text":"普攻附加 1 层灼烧，间隔 1.5 秒；对灼烧目标伤害 +7%。"},
			{"text":"普攻附加 2 层灼烧，间隔 1 秒；对灼烧目标伤害 +10%。"}]},
	{"id":"AB11","key":"frost","name":"霜印","action":"冰缓","icon":"T033","color":"9fd8ff",
		"ranks":[
			{"text":"普攻附加 1 层冰缓，间隔 2 秒；对冰缓目标伤害 +4%。"},
			{"text":"普攻附加 1 层冰缓，间隔 1.5 秒；对冰缓目标伤害 +7%。"},
			{"text":"普攻附加 2 层冰缓，间隔 1 秒；对冰缓目标伤害 +10%。"}]},
	{"id":"AB12","key":"shock","name":"感电","action":"雷印","icon":"T041","color":"ffe08a",
		"ranks":[
			{"text":"普攻附加 1 层感电，间隔 2 秒；对感电目标伤害 +4%。"},
			{"text":"普攻附加 1 层感电，间隔 1.5 秒；对感电目标伤害 +7%。"},
			{"text":"普攻附加 2 层感电，间隔 1 秒；对感电目标伤害 +10%。"}]},
]

static func track(key: String) -> Dictionary:
	for entry in TRACKS:
		if str(entry.key)==key: return entry
	return {}

static func track_by_id(id: String) -> Dictionary:
	for entry in TRACKS:
		if str(entry.id)==id: return entry
	return {}

static func rank(p: Dictionary, key: String) -> int:
	var ranks: Variant=p.get("build_abilities",{})
	if not (ranks is Dictionary): return 0
	return clampi(int((ranks as Dictionary).get(key,0)),0,MAX_RANK)

static func has(p: Dictionary, key: String, level: int) -> bool:
	return rank(p,key)>=level

static func rank_text(key: String, level: int) -> String:
	var entry := track(key)
	var ranks: Array=entry.get("ranks",[])
	return str(ranks[clampi(level-1,0,ranks.size()-1)].get("text","")) if not ranks.is_empty() else ""

static func offer_for(p: Dictionary, key: String) -> Dictionary:
	var entry := track(key)
	if entry.is_empty(): return {}
	var next := rank(p,key)+1
	if next>MAX_RANK: return {}
	return {
		"ability_id":str(entry.id),"ability_key":key,"ability_action":str(entry.action),
		"ability_track":str(entry.name),"rank":next,"name":str(entry.name),
		"desc":rank_text(key,next),"tier":0,"price":0,
		"icon_id":str(entry.icon),"color":str(entry.color),
	}

static func next_offers(p: Dictionary) -> Array:
	var offers: Array=[]
	for entry in TRACKS:
		if rank(p,str(entry.key))<MAX_RANK: offers.append(offer_for(p,str(entry.key)))
	return offers

## 从所有“未满 3 次”的能力里无放回抽 3 个不同项。返回的是 1..MAX_RANK 的下一阶。
static func roll_offers(s, p: Dictionary, count: int = 3) -> Array:
	var pool := next_offers(p)
	var offers: Array=[]
	for i in mini(count,pool.size()):
		var at: int=s.rng.randi_range(0,pool.size()-1)
		offers.append(pool.pop_at(at))
	return offers

static func total_rank(p: Dictionary) -> int:
	var total := 0
	for entry in TRACKS: total+=rank(p,str(entry.key))
	return total

static func is_maxed(p: Dictionary) -> bool:
	return total_rank(p)>=MAX_RANK*TRACKS.size()

# --- 战斗数值（唯一读取口） -----------------------------------------------------

static func attack_interval(p: Dictionary) -> float:
	return 1.0-[0.0,0.04,0.06,0.08][rank(p,"attack")]

static func chain_ratio(p: Dictionary) -> float:
	return [0.0,0.12,0.18,0.24][rank(p,"attack")]

static func chain_count(p: Dictionary) -> int:
	return [0,1,1,2][rank(p,"attack")]

static func art_cdr(p: Dictionary) -> float:
	return [0.0,0.06,0.10,0.14][rank(p,"art")]

static func art_mana(p: Dictionary) -> float:
	return [0.0,0.05,0.08,0.12][rank(p,"art")]

static func art_damage(p: Dictionary) -> float:
	return [0.0,0.10,0.16,0.22][rank(p,"art")]

static func art_windup(p: Dictionary) -> float:
	return [0.0,0.0,0.04,0.08][rank(p,"art")]

static func ultimate_cdr(p: Dictionary) -> float:
	return [0.0,0.06,0.10,0.14][rank(p,"ultimate")]

static func ultimate_damage(p: Dictionary) -> float:
	return [0.0,0.10,0.16,0.22][rank(p,"ultimate")]

static func ultimate_radius(p: Dictionary) -> float:
	return [0.0,0.04,0.08,0.12][rank(p,"ultimate")]

static func ultimate_field_duration(p: Dictionary) -> float:
	return [0.0,2.0,3.0,3.5][rank(p,"ultimate")]

static func ultimate_field_ratio(p: Dictionary) -> float:
	return [0.0,0.08,0.12,0.16][rank(p,"ultimate")]

static func ultimate_awakened(p: Dictionary) -> bool:
	return rank(p,"ultimate")>0

static func dodge_cdr(p: Dictionary) -> float:
	return [0.0,0.06,0.10,0.14][rank(p,"dodge")]

static func dodge_distance(p: Dictionary) -> float:
	return 1.0+[0.0,0.04,0.08,0.12][rank(p,"dodge")]

static func perfect_window(p: Dictionary) -> float:
	return 0.12+[0.0,0.02,0.02,0.02][rank(p,"dodge")]

static func perfect_strike(p: Dictionary) -> float:
	return [0.0,0.0,0.0,0.0][rank(p,"dodge")]

static func dodge_awakened(p: Dictionary) -> bool:
	return rank(p,"dodge")>=2

static func dodge_counter(p: Dictionary) -> float:
	return [0.0,0.0,0.18,0.26][rank(p,"dodge")]

static func flask_heal(p: Dictionary) -> float:
	return [0.0,0.06,0.10,0.14][rank(p,"flask")]

static func flask_cd(p: Dictionary) -> float:
	return 2.5-[0.0,0.2,0.35,0.5][rank(p,"flask")]

static func flask_shield(p: Dictionary) -> float:
	return [0.0,0.04,0.07,0.10][rank(p,"flask")]

static func flask_charge(p: Dictionary) -> float:
	return [0.0,0.12,0.20,0.28][rank(p,"flask")]

static func flask_awakened(p: Dictionary) -> bool:
	return rank(p,"flask")>0

static func crit_chance(p: Dictionary) -> float:
	return [0.0,0.03,0.06,0.09][rank(p,"crit")]

static func crit_damage(p: Dictionary) -> float:
	return [0.0,0.10,0.20,0.30][rank(p,"crit")]

static func guard(p: Dictionary) -> float:
	return [0.0,0.03,0.05,0.07][rank(p,"guard")]

static func move_speed(p: Dictionary) -> float:
	return [0.0,6.0,10.0,14.0][rank(p,"speed")]

static func summon_every(p: Dictionary) -> int:
	return [0,5,4,3][rank(p,"summon")]

static func summon_ratio(p: Dictionary) -> float:
	return [0.0,0.05,0.07,0.09][rank(p,"summon")]

static func summon_seconds(p: Dictionary) -> float:
	return [0.0,4.0,5.0,6.0][rank(p,"summon")]

static func status_stacks(p: Dictionary, key: String) -> int:
	return [0,1,1,2][rank(p,key)]

static func status_icd(p: Dictionary, key: String) -> float:
	return [0.0,2.0,1.5,1.0][rank(p,key)]

static func status_bonus(p: Dictionary, key: String) -> float:
	return [0.0,0.04,0.07,0.10][rank(p,key)]

# --- 展示辅助 -----------------------------------------------------------------

static func pips(p: Dictionary, key: String) -> String:
	var level := rank(p,key)
	var marks: Array=[]
	for i in MAX_RANK: marks.append("◆" if i<level else "◇")
	return "".join(marks)

static func status_line(p: Dictionary, key: String) -> String:
	var entry := track(key)
	if entry.is_empty(): return ""
	var level := rank(p,key)
	return "%s %s · %s" % [str(entry.name),pips(p,key),rank_text(key,level) if level>0 else "未获取"]

static func next_line(p: Dictionary, key: String) -> String:
	var offer := offer_for(p,key)
	return "下一阶：%s" % str(offer.get("desc","")) if not offer.is_empty() else "已满 3 次 · 不再出现"
