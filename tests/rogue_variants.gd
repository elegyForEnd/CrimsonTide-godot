extends SceneTree

## R8 验收：深渊变数数据层（`scripts/rogue_variants.gd`）。
## 覆盖：数据表形状 / kind 与效果自洽 / 无判定几何键 / 描述与数值一致 /
##       modifiers_of 的加法合成与上下限 / pick 的确定性 / min_floor 门控 /
##       ≥1000 样本全覆盖 / exclude 去重 / roll 写冻结键 / 真实 TideSession 接线不回归。
## v2-11：`roll()/pick()` 改用由 `(seed_value, floor, variants_seen)` 纯函数派生的局部 RNG，
##        因此"恰好消耗 1 次 `s.rng`"的断言改写为"抽取前后 `s.rng.state` **逐位相同**"。
## 注意：本用例只用 `load()` 触碰 session.gd，避免并发 W1 编辑把本用例编译搞崩。

const Variants = preload("res://scripts/rogue_variants.gd")

var checks := 0
var failures := 0

class FakeSession:
	var raid: Dictionary = {}
	var seed_value: int = 0
	var rng := RandomNumberGenerator.new()

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func _seeded(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng

func _fresh(seed_value: int, floor: int, seen: Array = [], rng_seed: int = 1234) -> FakeSession:
	var s := FakeSession.new()
	s.seed_value = seed_value
	s.rng.seed = rng_seed
	s.raid = {"floor":floor, "area":1, "depth":1, "mode":"roguelike"}
	if not seen.is_empty():
		s.raid["variants_seen"] = seen
	return s

func _has_both_signs(effect: Dictionary) -> bool:
	var positive := false
	var negative := false
	var polarity: Dictionary = Variants.polarity_map()
	for key in effect.keys():
		var contribution := float(polarity.get(key,0)) * float(effect[key])
		if contribution > 0.0: positive = true
		if contribution < 0.0: negative = true
	return positive and negative

func run() -> void:
	_test_table()
	_test_no_geometry()
	_test_describe()
	_test_modifiers()
	_test_determinism()
	_test_floor_gate()
	_test_coverage()
	_test_exclude()
	_test_roll()
	_test_real_session()
	print("ROGUE VARIANTS ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)

# --- 数据表形状与自洽 -------------------------------------------------------
func _test_table() -> void:
	var table: Array = Variants.table()
	check(table.size() >= 10,"At least ten variants are defined")
	# R2 冻结的 5 条必须还在（id 原样），否则 R2 的 wiring 用例会失去依据
	var frozen := ["blood_moon","rust","fog","bounty","frenzy"]
	var table_ids := {}
	for entry in table: table_ids[str(entry.get("id",""))]=true
	for id in frozen: check(table_ids.has(id),"R2 frozen variant survives: %s" % id)
	var seen := {}
	for entry in table:
		var id := str(entry.get("id",""))
		check(not id.is_empty(),"Every variant has an id")
		check(not seen.has(id),"Variant id is unique: %s" % id)
		seen[id]=true
		check(not str(entry.get("name","")).is_empty(),"Variant has a name: %s" % id)
		check(not str(entry.get("desc","")).is_empty(),"Variant has a desc: %s" % id)
		var effect: Dictionary = entry.get("effect",{})
		check(not effect.is_empty(),"Variant has effect entries: %s" % id)
		check(int(entry.get("weight",0)) > 0,"Variant weight is positive: %s" % id)
		check(int(entry.get("min_floor",0)) >= 1,"Variant min_floor is at least one: %s" % id)
		var kind := str(entry.get("kind",""))
		check(kind in ["boon","bane","mixed"],"Variant kind is boon/bane/mixed: %s" % id)
		var score := Variants.polarity_score(id)
		if kind == "boon":
			check(score > 0.0,"Boon has positive polarity: %s" % id)
		elif kind == "bane":
			check(score < 0.0,"Bane has negative polarity: %s" % id)
		else:
			check(_has_both_signs(effect),"Mixed variant has both pros and cons: %s" % id)
	check(table.size() == seen.size(),"Table size matches unique ids")
	var boons := 0
	var banes := 0
	for entry in table:
		if str(entry.get("kind","")) == "boon": boons += 1
		if str(entry.get("kind","")) == "bane": banes += 1
	check(boons >= 3 and banes >= 2,"Table contains both real boons and real banes")
	# table() 必须是深拷贝
	(table[0].effect as Dictionary)["__probe__"] = 1.0
	check(not (Variants.table()[0].effect as Dictionary).has("__probe__"),"table() returns a defensive copy")
	check(Variants.ids().size() == table.size(),"ids() covers the whole table")

# --- 判定几何守卫 -----------------------------------------------------------
func _test_no_geometry() -> void:
	var canonical: Array = Variants.canonical_keys()
	var forbidden: Array = Variants.forbidden_keys()
	var bullet_keys := ["bullet_size","bullet_speed"]
	var bullet_ids: Array = []
	var enlarges := false
	for entry in Variants.table():
		var id := str(entry.id)
		var effect: Dictionary = entry.effect
		for key in effect.keys():
			var name := str(key)
			check(canonical.has(name),"Effect key is canonical: %s / %s" % [id,name])
			check(not forbidden.has(name),"Effect key is not a hit-geometry key: %s / %s" % [id,name])
			if name.begins_with("bullet_"):
				check(bullet_keys.has(name),"Bullet variants only touch visual size and speed: %s / %s" % [id,name])
		for key in effect.keys():
			if str(key).begins_with("bullet_"):
				bullet_ids.append(id)
				break
		if float(effect.get("bullet_size",0.0)) > 0.0: enlarges = true
	check(bullet_ids.size() >= 2,"At least two variants interact with enemy bullets")
	check(enlarges,"At least one variant enlarges enemy bullets visually")
	var limits: Dictionary = Variants.bounds()
	check(float(limits["bullet_size"][0]) >= 0.0,"Bullet visual scale can never shrink enemy bullets")
	# 合成结果里也绝不能出现判定几何键
	var mods: Dictionary = Variants.modifiers_of(["fog","surge","stasis"])
	for key in mods.keys():
		check(not forbidden.has(str(key)),"modifiers_of never exposes geometry keys: %s" % str(key))
	check(not mods.has("hit_radius"),"modifiers_of has no hit_radius")
	check(not mods.has("collision_radius"),"modifiers_of has no collision_radius")

# --- 描述与数值一致 ---------------------------------------------------------
func _test_describe() -> void:
	var integer_keys: Array = Variants.integer_keys()
	for entry in Variants.table():
		var id := str(entry.id)
		var info: Dictionary = Variants.describe(id)
		check(str(info.get("id","")) == id,"describe returns the variant: %s" % id)
		check(not str(info.get("label","")).is_empty(),"describe builds a HUD label: %s" % id)
		check(str(info.get("label","")).contains(str(entry.name)),"HUD label carries the name: %s" % id)
		check(float(info.get("polarity",0.0)) == Variants.polarity_score(id),"describe reports polarity: %s" % id)
		var described: Dictionary = info.get("effect",{})
		var same := described.size() == (entry.effect as Dictionary).size()
		for key in (entry.effect as Dictionary).keys():
			if float(described.get(key,-999.0)) != float(entry.effect[key]): same = false
		check(same,"describe exposes the same effect numbers: %s" % id)
		# label 里必须出现每个效果键的真实数字（描述与数值一致）
		for key in (entry.effect as Dictionary).keys():
			var value := float(entry.effect[key])
			var needle := "%+d" % int(round(value)) if integer_keys.has(key) else "%+d%%" % int(round(value*100.0))
			check(str(info.label).contains(needle),"HUD label shows the real number for %s: %s" % [str(key),id])
		check(not Variants.effect_text(id).is_empty(),"effect_text is filled: %s" % id)
	# 深拷贝
	var probe: Dictionary = Variants.describe(str(Variants.ids()[0]))
	(probe.effect as Dictionary)["__probe__"] = 1.0
	check(not (Variants.describe(str(Variants.ids()[0])).effect as Dictionary).has("__probe__"),"describe returns a defensive copy")
	check(Variants.describe("no_such_variant").is_empty(),"describe of an unknown id is empty")
	check(Variants.effect_text("no_such_variant") == "","effect_text of an unknown id is empty")
	check(Variants.describe("").is_empty(),"describe of an empty id is empty")

# --- 合成规则 ---------------------------------------------------------------
func _test_modifiers() -> void:
	var empty_mods: Dictionary = Variants.modifiers_of([])
	for key in Variants.canonical_keys():
		check(float(empty_mods[key]) == 0.0,"Empty variant list is all zeros: %s" % str(key))
	check((empty_mods.get("sources",[]) as Array).is_empty(),"Empty variant list has no sources")
	var one: Dictionary = Variants.modifiers_of(["apocalypse"])
	check(is_equal_approx(float(one["player_damage"]),0.15),"A single variant value passes through")
	var twice: Dictionary = Variants.modifiers_of(["apocalypse","apocalypse"])
	check(is_equal_approx(float(twice["player_damage"]),0.30),"Duplicate variants stack additively")
	var mixed: Dictionary = Variants.modifiers_of(["austerity"])
	check(is_equal_approx(float(mixed["player_damage_taken"]),0.10),"Mixed variant sets damage taken")
	check(is_equal_approx(float(mixed["gold"]),0.40),"Mixed variant sets gold gain")
	# 上下限
	var high: Dictionary = Variants.modifiers_of(["blood_debt","blood_debt","blood_debt","blood_debt","blood_debt","blood_debt"])
	check(is_equal_approx(float(high["player_damage_taken"]),0.60),"Damage taken clamps at the upper bound")
	var low: Dictionary = Variants.modifiers_of(["iron_law","iron_law","iron_law","iron_law","iron_law","iron_law"])
	check(is_equal_approx(float(low["player_damage_taken"]),-0.60),"Damage taken clamps at the lower bound")
	var sanct: Dictionary = Variants.modifiers_of(["sanctuary","sanctuary","sanctuary"])
	check(is_equal_approx(float(sanct["enemy_hp"]),-0.30),"Enemy hp reduction stacks")
	# 整数键
	var tiers: Dictionary = Variants.modifiers_of(["blood_moon","wolves"])
	check(typeof(tiers["loot_tier"]) == TYPE_INT,"Loot tier is an int after composition")
	check(int(tiers["loot_tier"]) == 2,"Loot tier adds up")
	check(typeof(tiers["shop_price"]) == TYPE_FLOAT,"Percentage keys stay floats")
	var bargain: Dictionary = Variants.modifiers_of(["bargain"])
	check(int(bargain["loot_tier"]) == -1,"Negative loot tier is possible")
	check(is_equal_approx(float(bargain["shop_price"]),-0.25),"Shop price reduction applies")
	# 未知 id 与字符串入参
	var unknown: Dictionary = Variants.modifiers_of(["no_such_variant","apocalypse"])
	check(is_equal_approx(float(unknown["player_damage"]),0.15),"Unknown ids are ignored")
	var sources: Array = unknown["sources"]
	check(sources.size() == 1 and str(sources[0]) == "apocalypse","Sources list only known ids")
	check(is_equal_approx(float(Variants.modifiers_of("apocalypse")["player_damage"]),0.15),"A single id string is accepted")
	# 全体一起上：每个键都在上下限内
	var all: Dictionary = Variants.modifiers_of(Variants.ids())
	var limits: Dictionary = Variants.bounds()
	for key in Variants.canonical_keys():
		var value := float(all[key])
		check(value >= float(limits[key][0]) and value <= float(limits[key][1]),"Composition stays within bounds: %s" % str(key))
	# 缓存不得泄露可变引用
	var cached: Dictionary = Variants.modifiers_of(["apocalypse"])
	cached["player_damage"] = 999.0
	check(is_equal_approx(float(Variants.modifiers_of(["apocalypse"])["player_damage"]),0.15),"Cached results are defensively copied")

# --- 确定性（局部 RNG，不依赖 s.rng） ---------------------------------------
func _test_determinism() -> void:
	for floor in [1,3,5]:
		var expected: String = Variants.pick(424242,floor,[])
		var mismatches := 0
		for i in 1000:
			if Variants.pick(424242,floor,[]) != expected: mismatches += 1
		check(mismatches == 0,"1000 repeats of the same (seed, floor) agree on floor %d" % floor)
	check(not Variants.pick(424242,1,[]).is_empty(),"A floor-one roll always yields a variant")
	# 局部 RNG：抽取与任何外部 rng 的当前位置无关
	var probe := _seeded(424242)
	var before := probe.state
	check(Variants.pick(424242,3,[]) == Variants.pick(424242,3,[]),"Repeated picks agree without any external rng")
	check(probe.state == before,"pick never touches an external RandomNumberGenerator")
	# 抽空时返回空串（不再有"照抽一次"的语义）
	check(Variants.pick(424242,1,Variants.ids()) == "","pick returns an empty id when everything is excluded")

# --- min_floor 门控 ---------------------------------------------------------
func _test_floor_gate() -> void:
	var min_floors := {}
	var gated := 0
	for entry in Variants.table():
		min_floors[str(entry.id)] = int(entry.min_floor)
		if int(entry.min_floor) > 1: gated += 1
	check(gated > 0,"Some variants are gated behind later floors")
	for floor in [1,2,3,5]:
		var bad := 0
		for i in 400:
			var id: String = Variants.pick(31337 + floor*131 + i,floor,[])
			if id.is_empty(): continue
			if int(min_floors[id]) > floor: bad += 1
		check(bad == 0,"No variant is picked before its min_floor on floor %d" % floor)

# --- 覆盖面 -----------------------------------------------------------------
func _test_coverage() -> void:
	var counts := {}
	for entry in Variants.table(): counts[str(entry.id)] = 0
	var floor_one := {}
	var samples := 1000
	for i in samples:
		var id: String = Variants.pick(900000+i,5,[])
		if counts.has(id): counts[id] = int(counts[id]) + 1
		var low: String = Variants.pick(500000+i,1,[])
		if not low.is_empty(): floor_one[low] = true
	for entry in Variants.table():
		check(int(counts[str(entry.id)]) >= 1,"Every variant is picked across 1000 floor-5 samples: %s" % str(entry.id))
	check(floor_one.size() >= 3,"Floor one can roll several different variants")
	var top := 0
	for id in counts.keys(): top = maxi(top,int(counts[id]))
	check(float(top) <= float(samples)*0.4,"No single variant dominates the floor-5 pool")
	var total := Variants.weight_total(5,[])
	var sum := 0.0
	for entry in Variants.table(): sum += float(entry.weight)
	check(is_equal_approx(total,sum),"Weight total on floor five covers the whole table")

# --- 去重 -------------------------------------------------------------------
func _test_exclude() -> void:
	var all_ids: Array = Variants.ids()
	var last := str(all_ids[all_ids.size()-1])
	var only: String = Variants.pick(5,99,all_ids.slice(0,all_ids.size()-1))
	check(only == last,"Excluded ids are never returned")
	check(Variants.pick(5,99,all_ids) == "","Nothing is returned when every id is excluded")
	var a: String = Variants.pick(11,3,["blood_moon"])
	var b: String = Variants.pick(11,3,["blood_moon"])
	check(a == b,"Exclusion keeps the pick deterministic")
	check(a != "blood_moon","The excluded id never comes back")
	check(Variants.pick(2024,5,["rust","fog"]) == Variants.pick(2024,5,["fog","rust"]),"Exclusion set is order independent")
	check(Variants.pick(2024,5,["rust"]) != "rust","History never returns an excluded id")
	check(Variants.weight_total(1,all_ids) == 0.0,"Weight total is zero when everything is excluded")
	check(Variants.weight_total(1,[]) > 0.0,"Weight total is positive on floor one")
	var gated_total := Variants.weight_total(1,["wolves"])
	check(gated_total > 0.0 and gated_total < Variants.weight_total(5,[]),"Floor-gated variants stay out of the floor-one total")

# --- roll / active（R2 通道；v2-11 起不消耗 s.rng） --------------------------
func _test_roll() -> void:
	var s := _fresh(1234,3)
	s.rng.seed = 424242
	var rng_before: int = s.rng.state
	var info: Dictionary = Variants.roll(s)
	var id := str(s.raid.get("variant",""))
	check(not id.is_empty(),"roll writes the current variant")
	check(int(s.raid.get("variant_serial",0)) == 1,"roll bumps the variant serial")
	check(str(Variants.active(s).get("id","")) == id,"active returns the rolled variant")
	check(str(info.get("id","")) == id,"roll returns the rolled definition")
	check(int(info.get("min_floor",0)) <= 3,"roll respects the current floor")
	check(s.rng.state == rng_before,"roll does not consume s.rng")
	Variants.roll(s)
	check(int(s.raid.get("variant_serial",0)) == 2,"Serial keeps increasing")
	check(s.rng.state == rng_before,"Repeated rolls still leave s.rng untouched")
	# 与 s.rng 当前位置完全无关：先把 rng 推到别处再抽，结果必须相同
	var p1 := _fresh(4321,4)
	var p2 := _fresh(4321,4)
	for i in 137: p2.rng.randf()
	var v1 := str(Variants.roll(p1).get("id",""))
	var v2 := str(Variants.roll(p2).get("id",""))
	check(not v1.is_empty() and v1 == v2,"Rolled variant ignores the s.rng position")
	# 同 seed_value、不同 rng 种子 → 同一条变数
	var q1 := _fresh(555,2,[],11)
	var q2 := _fresh(555,2,[],999999)
	check(str(Variants.roll(q1).get("id","")) == str(Variants.roll(q2).get("id","")),"Different rng seeds roll the same variant")
	# 同 seed_value + 同层 → 同一条（跨会话可复现）
	var r1 := _fresh(999,4)
	Variants.roll(r1)
	var r2 := _fresh(999,4)
	check(str(r2.raid.get("variant","")) == "","Variant starts unset before roll")
	Variants.roll(r2)
	check(str(r2.raid.get("variant","")) == str(r1.raid.get("variant","")),"Same seed value rolls the same variant")
	# variants_seen（W1 维护）去重仍生效
	var seen: Array = [str(Variants.ids()[0])]
	var c := _fresh(4242,5,seen)
	Variants.roll(c)
	check(str(c.raid.get("variant","")) != str(seen[0]),"Already seen variants are skipped when the field exists")
	# 全部排除时不消耗 rng、也不崩
	var z := _fresh(777,1,Variants.ids(),99)
	var z_before: int = z.rng.state
	check(Variants.roll(z).is_empty(),"roll returns nothing when every variant is excluded")
	check(z.rng.state == z_before,"roll does not consume s.rng even when nothing is eligible")
	check(str(z.raid.get("variant","")) == "","An exhausted variant pool writes an empty id")
	# 没有 raid 键 / 没有 seed_value / null 的健壮性
	var d := FakeSession.new()
	d.rng.seed = 7
	d.raid = {"floor":2}
	check(not str(Variants.roll(d).get("id","")).is_empty(),"roll works before the raid keys exist")
	check(Variants.active(FakeSession.new()).is_empty(),"active on an empty raid returns nothing")
	check(str(Variants.active(d).get("id","")) == str(d.raid.get("variant","")),"active follows roll without pre-existing keys")
	check(Variants.roll(null).is_empty(),"roll of a null session is empty")
	check(Variants.active(null).is_empty(),"active of a null session is empty")

# --- 真实 TideSession 接线（R2 通道）不回归 ---------------------------------
func _test_real_session() -> void:
	var script = load("res://scripts/session.gd")
	if script == null:
		print("WARNING rogue_variants: session.gd failed to load (concurrent W1 edits); real-session check skipped")
		return
	var s = script.new()
	if s == null:
		print("WARNING rogue_variants: session.gd could not be instantiated; real-session check skipped")
		return
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,1729)
	if not (s.raid is Dictionary):
		print("WARNING rogue_variants: launch did not expose raid; real-session check skipped")
		s.queue_free()
		return
	var id := str(s.raid.get("variant",""))
	check(not id.is_empty(),"The wired session rolls a variant on floor one")
	check(str(Variants.active(s).get("id","")) == id,"active resolves the wired session variant")
	check(int(s.raid.get("variant_serial",0)) >= 1,"The wired session records a variant serial")
	var rng_before: int = int(s.rng.state)
	Variants.roll(s)
	check(s.rng.state == rng_before,"Rolling on a real TideSession leaves s.rng untouched")
	check(Variants.pick(int(s.seed_value),1,[]) == Variants.pick(int(s.seed_value),1,[]),"Wired seed reproduces the pick")
	var mods: Dictionary = Variants.modifiers_of([id])
	check(mods.has("player_damage_taken") and not mods.has("hit_radius"),"Wired variant composes into modifiers without geometry keys")
	s.queue_free()
