extends RefCounted
## Run-only equipment. Quality scales attributes; passive rules stay readable.
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

static func has(p: Dictionary, passive: String) -> bool:
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

static func damage_multiplier(_p: Dictionary, _e: Dictionary) -> float:
	return 1.0

static func tick(_p: Dictionary, _dt: float) -> void: pass
static func spent(_p: Dictionary, _cost: float) -> void: pass
static func hit(_p: Dictionary, _damage: float, _killed: bool) -> void: pass
