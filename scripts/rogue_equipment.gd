extends RefCounted
## Run-only equipment. Quality scales attributes; passive rules stay readable.
##
## 重要（已核实）：**装备/铭刻的被动效果不在这里实现**。运行期唯一实现处是
## `scripts/rogue_build.gd`，用 1 基编号的 `gear(p,N)`（E00N 已装）与
## `engraving(p,N)`（武器 rogue_id == N-1）就地判定；外围接线散落在
## `session.gd`（移速/装填/闪避/减速/回蓝等待）、`roguelike.gd`（岩浆抗性）、
## `rogue_combat.gd` 与 `boss_choreography.gd`（击退/减速抗性）。
## 96 条（E001–E072、I001–I024）逐条实现位置见 output/EQUIPMENT-PASSIVES-AUDIT.md。
## 本文件只负责：定义查询、属性数值与品质缩放、描述文本、装备物品构造。
const RogueBuild = preload("res://scripts/rogue_build.gd")
const Content = preload("res://scripts/rogue_content.gd")
static var GEAR: Array=Content.data.gear
static var ENGRAVINGS: Array=Content.data.engravings

static func definition(item: Dictionary) -> Dictionary:
	var index := int(item.get("rogue_id",-1))
	var pool: Array=ENGRAVINGS if item.get("kind","")=="weapon" else GEAR
	return pool[index] if index>=0 and index<pool.size() else {}

static func make_gear(index: int, tier: int) -> Dictionary:
	index=clampi(index,0,GEAR.size()-1)
	return {"kind":"gear","gear":GEAR[index].slot,"tier":clampi(tier,0,5),"rogue_id":index,"build_id":GEAR[index].id}

static func engrave(item: Dictionary, index: int) -> Dictionary:
	var result := item.duplicate(true)
	result.rogue_id=clampi(index,0,ENGRAVINGS.size()-1)
	return result

static func value(item: Dictionary, stat: String) -> float:
	var base: float=float(definition(item).get(stat,0))
	return roundf(base*(1.0+.10*clampi(int(item.get("tier",0)),0,5))) if stat in ["hp","mana","speed"] else base

static func items(p: Dictionary) -> Array:
	var result: Array=[]
	var equipped: Dictionary=p.get("equipped",{})
	var weapon: Dictionary=equipped.get("weapon",{})
	if not definition(weapon).is_empty() and int(weapon.get("weapon",-1))==int(p.get("weapon",-2)): result.append(weapon)
	for item in equipped.get("gear",[]):
		if item is Dictionary and not definition(item).is_empty(): result.append(item)
	return result

static func total(p: Dictionary, stat: String) -> float:
	var result := 0.0
	for item in items(p): result+=value(item,stat)
	return result

## 历史上这里比对条目上的 `passive` 字段，而内容表从来没有这个字段，于是三个老调用点
## （clear_mind / last_stand / mana_guard）恒为 false，把「被动等于没实现」的假象带进了
## 分诊结论。现在映射到真正的实现处；未知名字仍走数据字段，为将来显式补 passive 键留路。
static func has(p: Dictionary, passive: String) -> bool:
	match passive:
		"last_stand": return RogueBuild.gear(p,2)
		"mana_guard": return RogueBuild.gear(p,3)
		"clear_mind": return RogueBuild.gear(p,4)
	for item in items(p):
		if definition(item).get("passive","")==passive: return true
	return false

static func attributes_text(item: Dictionary) -> String:
	var parts := PackedStringArray()
	for stat in ["hp","mana","damage","defense","speed","rate"]:
		var amount := value(item,stat)
		if amount<=0: continue
		var names := {"hp":"生命","mana":"法力","damage":"攻击","defense":"减伤","speed":"移速","rate":"攻速"}
		parts.append("%s +%d%s" % [names[stat],roundi(amount*100 if stat in ["damage","defense","rate"] else amount),"%" if stat in ["damage","defense","rate"] else ""])
	return " · ".join(parts)

static func description(item: Dictionary) -> String:
	return (str(Catalog.weapon(int(item.weapon)).get("desc",""))+"\n" if item.get("kind","")=="weapon" else attributes_text(item)+"\n")+"独特被动 · "+str(definition(item).get("text",""))

# ---------------------------------------------------------------------------
# LEGACY：保留签名只为兼容 tests/rogue_equipment.gd；scripts/ 下零调用者（已核实）。
# 这四个钩子曾打算做「被动的统一入口」，但真正的实现长期在 rogue_build.gd 里就地完成。
# **不要**把它们接进伤害/结算管线：hit_multiplier 已经算过同一批 C 加成、hit_event 已经
# 算过吸血与击杀回蓝，再调一次就是双重结算。
# ---------------------------------------------------------------------------
static func damage_multiplier(_p: Dictionary, _e: Dictionary) -> float:
	return 1.0

static func tick(_p: Dictionary, _dt: float) -> void: pass
static func spent(_p: Dictionary, _cost: float) -> void: pass
static func hit(_p: Dictionary, _damage: float, _killed: bool) -> void: pass
