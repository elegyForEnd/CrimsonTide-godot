extends SceneTree
## R9 · 事件房数据层验收（纯函数结算 + pending_event 生命周期 + 复现性 + 安全边界）
const Events = preload("res://scripts/rogue_events.gd")
const Curses = preload("res://scripts/rogue_curses.gd")

var checks := 0
var failures := 0
var sessions: Array=[]

const FORBIDDEN := ["hit_radius", "hit_zone", "hitboxes", "velocity", "v", "p", "bullet", "bullets", "damage"]
const REQUIRE_KEYS := ["gold", "hp_ratio", "flask", "curse_slots"]

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void: call_deferred("run")

func same(a, b) -> bool:
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

func stage(s, event_id: String) -> void:
	s.raid["pending_event"]={"offer": Events.options_view(Events.find(event_id)), "revision": int(s.raid.get("revision", 0)), "id": event_id}

func run() -> void:
	# ---------------------------------------------------------------- A. 表结构
	var t: Array=Events.table()
	check(t.size()>=6, "At least six events in the table")
	var seen: Dictionary={}
	var curse_options := 0
	for raw in t:
		var event: Dictionary=raw
		var id := str(event.get("id", ""))
		check(event.has("id") and event.has("name") and event.has("floor_min") and event.has("options"), "Event row carries the frozen keys: "+str(id))
		check(not id.is_empty() and not seen.has(id), "Event id is unique and non-empty: "+id)
		seen[id]=true
		check(not str(event.get("name", "")).is_empty(), "Event has a name: "+id)
		check(int(event.get("floor_min", 0))>=1 and int(event.get("floor_min", 0))<=5, "floor_min is inside 1..5: "+id)
		var options: Array=event.get("options", [])
		check(options.size()>=2 and options.size()<=3, "Event offers two or three options: "+id)
		for option in options:
			check(not str(option.get("name", "")).is_empty() and not str(option.get("desc", "")).is_empty(), "Option has name and description: "+id)
			var result: Dictionary=option.get("result", {})
			check(not result.is_empty(), "Option result is never empty (empty would be indistinguishable from invalid): "+id)
			for key in result:
				check(str(key) in Events.DELTA_KEYS and str(key) not in FORBIDDEN, "Result key is canonical and not hit geometry: "+str(key))
			if str(result.get("curse", ""))!="":
				curse_options+=1
				check(str(result.curse) in Curses.ids(), "Event only grants a real curse: "+str(result.curse))
			if option.has("require"):
				for key in option.require: check(str(key) in REQUIRE_KEYS, "Require key is canonical: "+str(key))
			check(typeof(option.get("result", {}).get("gold", 0)) in [TYPE_INT, TYPE_FLOAT], "Result numbers are numeric: "+id)
		check(same(JSON.parse_string(JSON.stringify(event)), event), "Event row survives a JSON round trip: "+id)
	check(curse_options>=3, "At least three options grant a curse")
	check(JSON.stringify(Events.table())==JSON.stringify(t), "table() is deterministic across calls")
	check(Events.ids().size()==t.size(), "ids() mirrors the table")
	check(Events.find("NOPE").is_empty(), "Unknown event lookup returns empty")
	check(Events.floor_pool(1).size()<=Events.ids().size() and Events.floor_pool(1).size()>0, "Floor pool is a non-empty subset")
	check(Events.floor_pool(5).size()==Events.ids().size(), "Floor 5 unlocks every event")

	# ------------------------------------------------- B. 纯函数结算
	for raw in t:
		var id := str(raw.id)
		for i in int(raw.options.size()):
			var first: Dictionary=Events.resolve(id, i)
			var second: Dictionary=Events.resolve(id, i)
			check(not first.is_empty() and same(first, second), "resolve() is pure and non-empty: %s#%d" % [id, i])
			for key in first.keys(): check(str(key) in Events.DELTA_KEYS and str(key) not in FORBIDDEN, "Delta key is canonical: "+str(key))
			check(same(JSON.parse_string(JSON.stringify(first)), first), "Delta survives a JSON round trip: %s#%d" % [id, i])
	check(Events.resolve("NOPE", 0).is_empty(), "Unknown event resolves to nothing")
	check(Events.resolve("EV01", -1).is_empty() and Events.resolve("EV01", 9).is_empty(), "Out-of-range option resolves to nothing")

	# ------------------------------------------------- C. 抽选 / pending_event / revision
	var f := fresh(31337)
	var s=f.s
	s.raid.floor=5
	s.rng.seed=1234
	var rolled: Dictionary=Events.roll_offer(s)
	s.rng.seed=1234
	var again: Dictionary=Events.roll_offer(s)
	check(str(rolled.get("id", ""))==str(again.get("id", "")) and same(rolled.offer, again.offer), "Same seed rolls the same event offer")
	check(not str(rolled.get("id", "")).is_empty(), "Rolled event has an id")
	var offers: Array=rolled.get("offer", [])
	check(offers.size()>=2 and offers.size()<=3, "Offer carries two or three options")
	for view in offers:
		check(view.has("index") and view.has("name") and view.has("desc"), "Offer view exposes index/name/desc")
		check(not view.has("result"), "Offer view never leaks the outcome table")
	check(int(rolled.get("revision", -1))==int(s.raid.revision), "pending_event carries the current raid revision")
	check(Events.pending(s).get("id", "")==rolled.get("id", ""), "pending_event mirrors the roll")
	check(Events.matches_revision(s, int(s.raid.revision)), "matches_revision accepts the live revision")
	check(not Events.matches_revision(s, int(s.raid.revision)+1), "matches_revision rejects a stale revision")

	# ------------------------------------------------- D. 拒绝非法 / 不可用选择
	var f2 := fresh(777)
	var s2=f2.s
	var p2=f2.p
	check(not Events.apply(s2, p2, 0), "apply() with no pending_event returns false")
	stage(s2, "EV01")
	s2.raid["pending_event"]={}
	check(not Events.apply(s2, p2, 0), "apply() with a cleared pending_event returns false")
	stage(s2, "EV02")
	check(not Events.apply(s2, p2, 9), "Out-of-range option is rejected")
	check(str(Events.pending(s2).get("id", ""))=="EV02", "Rejected option keeps pending_event for another pick")
	p2["rogue_gold"]=0
	check(not Events.available(s2, p2, "EV02", 0), "Gold-gated option is unavailable when broke")
	check(Events.available(s2, p2, "EV02", 2), "Free option still available when broke")
	check(not Events.apply(s2, p2, 0), "Broke player cannot take a gold-gated option")
	check(str(Events.pending(s2).get("id", ""))=="EV02", "Failed affordability check keeps pending_event")
	var before_gold := int(p2.rogue_gold)
	var revision_before := int(s2.raid.revision)
	check(Events.matches_revision(s2, revision_before), "Live revision matches before resolving")
	check(Events.apply(s2, p2, 2), "Unaffordable event still allows its free option")
	check(int(p2.rogue_gold)>before_gold, "Free option actually pays out")
	check(Events.pending(s2).is_empty(), "Resolved event clears pending_event")
	check(int(s2.raid.revision)>revision_before, "Resolving an event advances raid.revision")
	check(not Events.matches_revision(s2, revision_before), "Stale revisions are rejected after resolving")
	p2["rogue_gold"]=0
	p2.hp=p2.max_hp*0.1
	check(not Events.available(s2, p2, "EV01", 0), "HP-gated option is unavailable at low health")
	p2.flask=10.0
	check(not Events.available(s2, p2, "EV06", 1), "Flask-gated option is unavailable with an empty flask")
	p2["rogue_curses"]=[]
	for i in Curses.MAX_CURSES: Curses.apply(s2, p2, str(Curses.ids()[i]))
	check(not Events.available(s2, p2, "EV01", 2), "Curse-gated option is unavailable with full curse slots")

	# ------------------------------------------------- E. 1000 样本分布
	var f3 := fresh(8080)
	var s3=f3.s
	s3.raid.floor=5
	s3.rng.seed=555
	var counts: Dictionary={}
	for i in 1000:
		var id := str(Events.roll_offer(s3).get("id", ""))
		counts[id]=int(counts.get(id, 0))+1
	check(counts.size()==Events.table().size(), "1000 seeded rolls cover every event")
	var total := 0
	for key in counts: total+=int(counts[key])
	check(total==1000, "Every roll returns an event id")
	for key in counts: check(int(counts[key])>=50 and int(counts[key])<=200, "Seeded distribution stays in range for "+str(key))

	# ------------------------------------------------- F. 每个选项的安全边界与落地
	var f4 := fresh(2024)
	var s4=f4.s
	var p4=f4.p
	for raw in t:
		var id := str(raw.id)
		for i in int(raw.options.size()):
			p4["rogue_curses"]=[]
			p4["build_reward_queue"]=[]
			p4["build_attribute_points"]=0
			p4["forge_points"]=0
			s4.raid["curse_serial"]=0
			p4["rogue_gold"]=5000
			p4.hp=float(p4.max_hp)*0.9
			p4.mana=float(p4.max_mana)*0.5
			p4.flask=80.0
			stage(s4, id)
			var gold_before := int(p4.rogue_gold)
			var hp_before: float=float(p4.hp)
			var delta: Dictionary=Events.resolve(id, i)
			check(Events.available(s4, p4, id, i), "Rich player can take every option: %s#%d" % [id, i])
			check(Events.apply(s4, p4, i), "Every event option resolves and commits: %s#%d" % [id, i])
			check(Events.pending(s4).is_empty(), "Committed option clears pending_event: %s#%d" % [id, i])
			check(float(p4.hp)>=1.0, "Event costs never kill the player: %s#%d" % [id, i])
			check(int(p4.rogue_gold)>=0, "Event costs never push gold below zero: %s#%d" % [id, i])
			if int(delta.get("gold", 0))<0:
				check(int(p4.rogue_gold)==gold_before+int(delta.gold), "Gold cost charged exactly once: %s#%d" % [id, i])
			if float(delta.get("hp_ratio", 0.0))<0.0:
				check(float(p4.hp)<hp_before, "HP cost is actually paid: %s#%d" % [id, i])
			if int(delta.get("attribute_points", 0))>0:
				check(int(p4.build_attribute_points)>=int(delta.attribute_points), "Attribute points land on the player: %s#%d" % [id, i])
			if str(delta.get("curse", ""))!="":
				check(Curses.has(p4, str(delta.curse)), "Curse option applies its curse: %s#%d" % [id, i])
			if int(delta.get("gear_reward", 0))>0:
				check(int(p4.build_reward_queue.size())>0, "Gear reward queues a three-choice: %s#%d" % [id, i])
	check(Curses.count(p4)<=Curses.MAX_CURSES, "Events never exceed the curse cap")

	print("ROGUE EVENTS: %d checks, %d failures" % [checks, failures])
	for session in sessions: session.queue_free()
	quit(1 if failures>0 else 0)
