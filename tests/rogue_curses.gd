extends SceneTree
## R9 · 诅咒数据层验收（纯函数 + 状态写入 + 复现性 + 上下限）
const Curses = preload("res://scripts/rogue_curses.gd")
const Build = preload("res://scripts/rogue_build.gd")

var checks := 0
var failures := 0
var sessions: Array=[]

const FORBIDDEN := ["hit_radius", "hit_zone", "hitboxes", "velocity", "v", "p", "bullet", "bullets", "damage"]

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void: call_deferred("run")

func same(a, b) -> bool:
	# JSON 往返会把 int 变成 float，所以这里做"数值等价"的结构比较。
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key): return false
			if not same(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not same(a[i], b[i]): return false
		return true
	if (a is int or a is float) and (b is int or b is float): return is_equal_approx(float(a), float(b))
	return a==b

func fresh(seed: int = 731) -> Dictionary:
	var s=TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	sessions.append(s)
	s.solo({"hero": 0, "mode": "roguelike"})
	s.launch(false, seed)
	return {"s": s, "p": s.players[1]}

func run() -> void:
	# ---------------------------------------------------------------- A. 表结构
	var t: Array=Curses.table()
	check(t.size()>=8, "At least eight curses in the table")
	var seen: Dictionary={}
	var gear_pairs := 0
	for raw in t:
		var row: Dictionary=raw
		check(row.has("id") and row.has("name") and row.has("desc") and row.has("effect") and row.has("boon"), "Curse row carries the frozen keys: "+str(row.get("id", "?")))
		var id := str(row.get("id", ""))
		check(not id.is_empty() and not seen.has(id), "Curse id is unique and non-empty: "+id)
		seen[id]=true
		check(not str(row.get("name", "")).is_empty() and not str(row.get("desc", "")).is_empty(), "Curse has a name and a description: "+id)
		for key in row.get("effect", {}):
			check(str(key) in Curses.EFFECT_KEYS, "Effect key is canonical (%s): %s" % [str(key), id])
			check(str(key) not in FORBIDDEN, "Effect key is not a hit-geometry field: "+str(key))
			check(typeof(row.effect[key]) in [TYPE_INT, TYPE_FLOAT], "Effect value is numeric: "+id)
		var boon: Dictionary=row.get("boon", {})
		var gain := int(boon.get("gold", 0))+int(boon.get("attribute_points", 0))+int(boon.get("gear_reward", 0))
		check(gain>0, "Curse pays a symmetric boon (never punishment only): "+id)
		check(not str(boon.get("desc", "")).is_empty(), "Boon has a readable description: "+id)
		if int(boon.get("gear_reward", 0))>0: gear_pairs+=1
		check(same(JSON.parse_string(JSON.stringify(row)), row), "Curse row survives a JSON round trip: "+id)
	check(gear_pairs>=3, "At least three curses pay out gear")
	check(JSON.stringify(Curses.table())==JSON.stringify(t), "table() is deterministic across calls")
	check(Curses.ids().size()==t.size(), "ids() mirrors the table")
	check(Curses.find("NOPE").is_empty(), "Unknown curse lookup returns empty")
	check(Curses.caps().size()==Curses.EFFECT_KEYS.size(), "Every effect key has a cap")

	# ------------------------------------------------- B. 施加 / 去重 / 上限 / 序号
	var f := fresh(731)
	var s=f.s
	var p=f.p
	check(int(p.get("rogue_curses", []).size())==0, "Curse list starts empty")
	check(Curses.apply(s, p, "CU01"), "Apply a valid curse")
	check(Curses.has(p, "CU01") and int(p.get("rogue_curses", []).size())==1, "Curse recorded on the player")
	check(int(s.raid.get("curse_serial", 0))==1, "curse_serial bumped by one")
	check(not Curses.apply(s, p, "CU01"), "Duplicate curse rejected")
	check(int(s.raid.get("curse_serial", 0))==1, "Rejected duplicate does not bump the serial")
	check(not Curses.apply(s, p, "NOPE"), "Unknown curse rejected")
	check(int(s.raid.get("curse_serial", 0))==1, "Rejected unknown curse does not bump the serial")
	var applied := 1
	for raw in Curses.table():
		if str(raw.id)=="CU01": continue
		if Curses.apply(s, p, str(raw.id)): applied+=1
	check(applied==Curses.MAX_CURSES, "Curse cap is enforced when stacking")
	check(int(p.get("rogue_curses", []).size())==Curses.MAX_CURSES, "Never more than MAX_CURSES on one player")
	check(Curses.count(p)==Curses.MAX_CURSES, "count() ignores duplicates and unknown ids")
	var with_junk: Array=p.rogue_curses.duplicate()
	with_junk.append("NOPE")
	check(Curses.count({"rogue_curses": with_junk})==Curses.MAX_CURSES, "count() ignores unknown ids")

	# ------------------------------------------------- C. 伤害承受 / 减伤池同池
	var f2 := fresh(1733)
	var s2=f2.s
	var p2=f2.p
	check(is_equal_approx(Curses.damage_taken_scale(p2), 1.0), "No curse means no extra damage taken")
	check(is_equal_approx(Curses.defense_penalty(p2), 0.0), "No curse means no defense-pool penalty")
	Curses.apply(s2, p2, "CU01")
	check(is_equal_approx(Curses.damage_taken_scale(p2), 1.15), "CU01 raises damage taken by exactly 15%")
	check(absf(Curses.defense_penalty(p2)-(1.0-1.0/1.15))<0.0001, "Penalty is the same-pool equivalent of the multiplier")
	var scale := Curses.damage_taken_scale(p2)
	var penalty := Curses.defense_penalty(p2)
	for id in ["CU10", "CU02", "CU03"]:
		if not Curses.apply(s2, p2, id): continue
		check(Curses.damage_taken_scale(p2)>=scale-0.0001, "Damage-taken scale never decreases while curses stack")
		check(Curses.defense_penalty(p2)>=penalty-0.0001, "Defense-pool penalty never decreases while curses stack")
		scale=Curses.damage_taken_scale(p2)
		penalty=Curses.defense_penalty(p2)
	check(scale<=1.0+Curses.CAPS.damage_taken+0.0001, "Damage-taken scale respects its cap")
	check(penalty<=Curses.MAX_POOL+0.0001, "Defense-pool penalty respects the pool cap")
	check(absf(penalty-(1.0-1.0/scale))<0.0001, "Penalty and scale stay equivalent after stacking")

	# ------------------------------------------- D. 上下限聚合 + 与既有池同池合成
	var many: Array=[]
	for i in 20: many.append("CU01")
	var agg := Curses.aggregate(many)
	check(is_equal_approx(float(agg.damage_taken), float(Curses.CAPS.damage_taken)), "Aggregate clamps at the damage-taken cap")
	var slow: Array=[]
	for i in 20: slow.append("CU02")
	check(is_equal_approx(float(Curses.aggregate(slow).move_speed), float(Curses.CAPS.move_speed)), "Aggregate clamps at the move-speed cap")
	check(is_equal_approx(float(Curses.aggregate([]).damage_taken), 0.0), "Empty aggregate is neutral")
	check(is_equal_approx(float(Curses.aggregate(["NOPE"]).damage_taken), 0.0), "Unknown ids contribute nothing")
	var expected_scale := 1.0+minf(Curses.CAPS.damage_taken, 0.15*20.0)
	check(is_equal_approx(1.0+float(agg.damage_taken), expected_scale), "Aggregate value feeds the scale exactly")
	var f3 := fresh(991)
	var s3=f3.s
	var p3=f3.p
	var base := float(Build.conditional_defense(s3, p3))
	Curses.apply(s3, p3, "CU01")
	var pooled := clampf(base-Curses.defense_penalty(p3), 0.0, Curses.MAX_POOL)
	check(pooled<=base+0.0001, "Curses only ever reduce the shared defense pool")
	check((1.0-pooled)>=(1.0-base)-0.0001, "Reduced defense never lowers incoming damage")
	check(Build.conditional_defense(s3, p3)==base, "Reading the curse never mutates the build pools")

	# ------------------------------------------------- E. 补偿倍率（对称回报）
	var f4 := fresh(555)
	var s4=f4.s
	var p4=f4.p
	check(is_equal_approx(Curses.reward_scale(s4), 1.0), "Uncursed team gets the baseline reward scale")
	check(is_equal_approx(Curses.personal_reward_scale(p4), 1.0), "Uncursed player gets the baseline personal scale")
	Curses.apply(s4, p4, "CU01")
	check(Curses.reward_scale(s4)>1.0, "Curse burden raises the compensating reward scale")
	var last := Curses.reward_scale(s4)
	for raw in Curses.table():
		Curses.apply(s4, p4, str(raw.id))
		check(Curses.reward_scale(s4)>=last-0.0001, "Reward scale never decreases while curses stack")
		last=Curses.reward_scale(s4)
	check(last<=Curses.REWARD_SCALE_CAP+0.0001, "Reward scale respects its cap")
	check(is_equal_approx(last, Curses.REWARD_SCALE_CAP), "Reward scale saturates instead of growing without bound")
	check(is_equal_approx(Curses.personal_reward_scale(p4), Curses.REWARD_SCALE_CAP), "Personal scale saturates too")

	# ------------------------------------------------- F. 复现性 + 1000 样本分布
	var f5 := fresh(4321)
	var s5=f5.s
	s5.rng.seed=20261005
	var counts: Dictionary={}
	for i in 1000:
		var rolled := Curses.roll(s5)
		counts[rolled]=int(counts.get(rolled, 0))+1
	check(counts.size()==Curses.table().size(), "1000 seeded rolls cover every curse")
	var total := 0
	for key in counts: total+=int(counts[key])
	check(total==1000, "Every roll returns a curse id")
	for key in counts:
		check(int(counts[key])>=40 and int(counts[key])<=180, "Seeded distribution stays in range for "+str(key))
	s5.rng.seed=20261005
	var first := Curses.roll(s5)
	s5.rng.seed=20261005
	check(Curses.roll(s5)==first, "Same seed yields the same curse")
	s5.rng.seed=99
	var excluded := 0
	for i in 50:
		if Curses.roll(s5, ["CU01", "CU02"]) in ["CU01", "CU02"]: excluded+=1
	check(excluded==0, "roll() honours the exclude list")
	var owned: Array=[]
	for raw in Curses.table(): owned.append(str(raw.id))
	s5.rng.seed=4242
	check(not Curses.roll(s5, owned).is_empty(), "roll() falls back to the full pool instead of failing")

	# ------------------------------------------------- G. 诅咒房成对发奖
	var f6 := fresh(6060)
	var s6=f6.s
	var p6=f6.p
	for raw in Curses.table():
		var id := str(raw.id)
		p6["rogue_curses"]=[]
		s6.raid["curse_serial"]=0
		p6["rogue_gold"]=60
		p6["build_reward_queue"]=[]
		p6["build_attribute_points"]=0
		var before_gold := int(p6.rogue_gold)
		var before_points := int(p6.build_attribute_points)
		var result: Dictionary=Curses.apply_pair(s6, p6, id)
		check(bool(result.get("applied", false)), "Curse room applies the curse: "+id)
		check(Curses.has(p6, id), "Curse room records the curse: "+id)
		var paid: Dictionary=result.get("boon", {})
		check(int(paid.get("gold", 0))>0 or int(paid.get("attribute_points", 0))>0 or int(paid.get("gear_reward", 0))>0, "Curse room always pays something back: "+id)
		var paid_out := int(p6.rogue_gold)>before_gold or int(p6.build_attribute_points)>before_points or int(p6.build_reward_queue.size())>0
		check(paid_out, "Curse room payout reaches the player: "+id)
		check(not Curses.apply_pair(s6, p6, id).get("applied", true), "Curse room never double-applies the same curse: "+id)
	check(Curses.summary(p6).size()>0, "summary() reports the active curses")
	check(same(JSON.parse_string(JSON.stringify(Curses.summary(p6))), Curses.summary(p6)), "summary() survives a JSON round trip")
	for entry in Curses.summary(p6):
		for key in entry.keys(): check(str(key) not in FORBIDDEN, "summary() carries no hit-geometry keys")

	print("ROGUE CURSES: %d checks, %d failures" % [checks, failures])
	for session in sessions: session.queue_free()
	quit(1 if failures>0 else 0)
