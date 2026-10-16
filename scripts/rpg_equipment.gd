extends RefCounted
## Pure campaign equipment rules. Saved rolls are values, never re-rolled on load.
const DATA_PATH := "res://resources/rpg_equipment.json"
const QUALITY := ["朴素","附魔","珍稀","套装","暗金"]
const COLORS := [Color("dbd5c6"),Color("88c4eb"),Color("efd66b"),Color("79d88d"),Color("d69b55")]
const CAPS := {"damage_pct":60.0,"hp_pct":40.0,"crit":45.0,"crit_damage":100.0,"haste":30.0,"cooldown":35.0,"speed":20.0,"reduction":30.0,"resist":50.0,"leech":6.0,"boss_damage":40.0,"execute":35.0,"skill_damage":50.0,"splash":35.0,"bleed":35.0,"slow":35.0,"vulnerable":20.0,"stagger":25.0,"charge":50.0,"regen":4.0,"kill_heal":25.0,"dodge_barrier":50.0,"dash_damage":60.0,"third_hit":70.0,"low_guard":25.0,"potion":40.0,"escort_guard":30.0}
static var _data: Dictionary={}

static func data() -> Dictionary:
	if _data.is_empty(): _data=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data

static func definition(id: String) -> Dictionary:
	for a in data().affixes:
		if a.id==id: return a
	return {}

static func unique(id: String) -> Dictionary:
	for u in data().uniques:
		if u.id==id: return u
	return {}

static func roll(item: Dictionary, rng: RandomNumberGenerator, act: int, source: String = "field", hero: int = 0) -> void:
	if not item.get("slot","") in ["blade","armor","charm"]: return
	act=clampi(act,1,6)
	item.affix_revision=1; item.affixes=[]; item.unique_id=""; item.set_id=""; item.reforges=0; item.locked=false; item.rune=""; item.origin="第%d幕 · %s" % [act,{"field":"遭遇","chest":"探索宝箱","boss":"首领战利品","craft":"营地打造"}.get(source,source)]
	var q := clampi(int(item.quality),0,4)
	item.quality=q
	if q==4:
		var pool: Array=data().uniques.filter(func(u): return int(u.act)==act and u.slot==item.slot and (int(u.hero)<0 or int(u.hero)==hero))
		if pool.is_empty(): item.quality=2; q=2
		else:
			var u: Dictionary=pool[rng.randi_range(0,pool.size()-1)]
			item.unique_id=u.id; item.name=u.name
	if q==3:
		item.set_id=data().sets[act-1].id
		item.name=data().sets[act-1].name+" · "+str(item.name)
	var available: Array=data().affixes.filter(func(a): return item.slot in a.slots and int(a.act)<=act)
	var groups: Array=[]
	var count: int=[0,2,4,2,3][q]
	for i in count:
		var pool: Array=available.filter(func(a): return not a.group in groups)
		if pool.is_empty(): break
		var a: Dictionary=pool[rng.randi_range(0,pool.size()-1)]
		groups.append(a.group)
		var low := float(a.min)+float(a.step)*(clampi(int(item.tier),1,6)-1)
		var high := low+float(a.span)
		item.affixes.append({"id":a.id,"value":rng.randi_range(ceili(low*10),floori(high*10))/10.0})
	if q in [1,2] and not item.affixes.is_empty(): item.name=str(definition(item.affixes[0].id).name)+" · "+str(item.name)

static func quality_roll(rng: RandomNumberGenerator, act: int, source: String) -> int:
	var r := rng.randf()
	if source=="boss": return 4
	if source=="craft": return 2 if r<.3 else 1
	if r<((.03 if act==1 else .08) if source=="chest" else (.008 if act==1 else .025)): return 4
	if r<(.22 if source=="chest" else .10): return 3
	if r<(.55 if source=="chest" else .30): return 2
	if r<(.95 if source=="chest" else .75): return 1
	return 1 if source=="chest" else 0

static func item_mods(item: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for a in item.get("affixes",[]):
		var d := definition(str(a.id))
		if not d.is_empty(): result[d.stat]=float(result.get(d.stat,0))+float(a.value)
	var u := unique(str(item.get("unique_id","")))
	for key in u.get("mods",{}): result[key]=float(result.get(key,0))+float(u.mods[key])
	var rune: String=str(item.get("rune",""))
	if item.get("socket",false) and data().runes.has(rune):
		var mods: Dictionary=data().runes[rune].mods[item.slot]
		for key in mods: result[key]=float(result.get(key,0))+float(mods[key])
	return result

static func set_counts(worn: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for item in worn.values():
		var id := str(item.get("set_id",""))
		if id!="": result[id]=int(result.get(id,0))+1
	return result

static func modifiers(worn: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for item in worn.values():
		var mods := item_mods(item)
		for key in mods: result[key]=float(result.get(key,0))+float(mods[key])
	var counts := set_counts(worn)
	for s in data().sets:
		for threshold in [2,3]:
			if int(counts.get(s.id,0))<threshold: continue
			for key in s[str(threshold)]: result[key]=float(result.get(key,0))+float(s[str(threshold)][key])
	for key in CAPS:
		if result.has(key): result[key]=clampf(float(result[key]),0,float(CAPS[key]))
	return result

static func mod_text(mods: Dictionary) -> String:
	var lines := PackedStringArray()
	for key in mods:
		lines.append("%s +%s%s" % [data().stats.get(key,key),str(snappedf(float(mods[key]),.1)),"%" if key in data().percent_stats else ""])
	return " / ".join(lines)

static func description(item: Dictionary) -> String:
	if not item.has("affix_revision"): return ""
	var lines := "\n【随机词缀】\n"
	for a in item.affixes:
		var d := definition(a.id)
		var low := float(d.min)+float(d.step)*(clampi(int(item.tier),1,6)-1)
		lines+="%s：%s  [%.1f–%.1f]\n" % [d.name,mod_text({d.stat:a.value}),low,low+float(d.span)]
	var u := unique(item.unique_id)
	if not u.is_empty(): lines+="【独有 · %s】%s\n%s\n" % [u.title,u.effect,mod_text(u.mods)]
	for s in data().sets:
		if s.id==item.set_id: lines+="【%s】\n2件：%s\n3件：%s\n" % [s.name,mod_text(s["2"]),mod_text(s["3"])]
	if item.get("socket",false) and data().runes.has(str(item.get("rune",""))): lines+="镶嵌 %s：%s\n" % [data().runes[item.rune].name,mod_text(data().runes[item.rune].mods[item.slot])]
	return lines+"来源：%s · 重铸%d次%s\n" % [item.origin,item.reforges," · 已锁定" if item.locked else ""]

static func valid(item: Dictionary) -> bool:
	if not (item.get("quality") is int or item.get("quality") is float) or int(item.quality)<0 or int(item.quality)>4: return false
	if not item.has("affix_revision"):
		return not item.has("affixes") and not item.has("unique_id") and not item.has("set_id") and not item.has("rune") and int(item.get("quality",0))<=2
	if item.affix_revision!=1 or not item.slot in ["blade","armor","charm"] or not item.get("affixes") is Array: return false
	if not item.get("locked") is bool or not item.get("origin") is String: return false
	if not (item.get("reforges") is int or item.get("reforges") is float) or float(item.reforges)!=int(item.reforges) or int(item.reforges)<0 or int(item.reforges)>20: return false
	for key in ["unique_id","set_id","rune"]:
		if not item.get(key) is String: return false
	var q := int(item.quality)
	if item.affixes.size()!=[0,2,4,2,3][q]: return false
	var groups: Array=[]
	for a in item.affixes:
		if not a is Dictionary or not a.get("id") is String or not (a.get("value") is int or a.get("value") is float): return false
		var d := definition(a.id)
		if d.is_empty() or not item.slot in d.slots or d.group in groups: return false
		var low := float(d.min)+float(d.step)*(clampi(int(item.tier),1,6)-1)
		if not is_finite(float(a.value)) or float(a.value)<low-.01 or float(a.value)>low+float(d.span)+.01: return false
		groups.append(d.group)
	var u := unique(item.unique_id)
	if q==4:
		if u.is_empty() or u.slot!=item.slot: return false
		var base_heroes := {"sword":0,"staff":1,"dagger":2,"plate":0,"robe":1,"coat":2}
		if int(u.hero)>=0 and int(base_heroes.get(item.base,-1))!=int(u.hero): return false
	elif item.unique_id!="": return false
	var set_found: bool=data().sets.any(func(s): return s.id==item.set_id)
	if (q==3 and not set_found) or (q!=3 and item.set_id!=""): return false
	if item.rune!="" and (not item.socket or not data().runes.has(item.rune)): return false
	return true
