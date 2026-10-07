extends SceneTree
## R14：守层者池扩容（8 个身份 / 每局抽 5 个 / 每人 7 招，含两招二阶段终结技）。
##
## 本用例**刻意不依赖 TideSession**（W1 正在改 session.gd / roguelike.gd），
## 用最小桩会话驱动真实的 RogueCombat / BossChoreography，保证结论随时可复跑。

const Combat = preload("res://scripts/rogue_combat.gd")
const Choreo = preload("res://scripts/boss_choreography.gd")
const Art = preload("res://scripts/boss_effect_art.gd")
const RogueArt = preload("res://scripts/rogue_art.gd")

var checks := 0
var failures := 0


class StubRuins:
	func safe_point(at: Vector2) -> Vector2: return at
	func move(origin: Vector2, delta: Vector2, _radius: float) -> Vector2: return origin+delta
	func blocked(_at: Vector2, _radius: float) -> bool: return false


class StubRogue:
	var combat
	func active(_s) -> bool: return true
	func spawn_point(_s, at: Vector2) -> Vector2: return at


class StubActions:
	func height_hit(_height: float, _tag: String) -> bool: return true


class StubBuild:
	func gear(_p, _id: int) -> bool: return false


class StubSession:
	signal message(detail: String)
	var raid: Dictionary = {"variant":"","floor":1,"hazards":[]}
	var enemies: Array = []
	var bullets: Array = []
	var players: Dictionary = {}
	var ruins = StubRuins.new()
	var roguelike = StubRogue.new()
	var RogueActions = StubActions.new()
	var RogueBuild = StubBuild.new()
	var next_enemy: int = 2
	var seed_value: int = 0
	var rng := RandomNumberGenerator.new()
	var audio: Array = []

	func broadcast_combat(_data: Dictionary) -> void:
		pass

	func broadcast_audio(cue: String, _emitter = null) -> void:
		audio.append(cue)

	func hurt(_p, _amount, _source, _kind: String = "normal", _extra: String = "", _element: String = "") -> void:
		pass


func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(reason)


func _initialize() -> void:
	call_deferred("run")


func make_session(seed_value: int) -> StubSession:
	var s := StubSession.new()
	s.roguelike.combat=Combat.new()
	s.seed_value=seed_value
	s.rng.seed=seed_value*31+7
	s.players={1:{"id":1,"status":"active","p":Vector2(2400,580),"hp":100000.0,"max_hp":100000.0,"invuln":0}}
	return s


func make_boss(s, floor_index: int, with_seed: bool = true) -> Dictionary:
	var e := {"id":1,"p":Vector2(2500,580),"type":4,"hp":0.0,"max_hp":0.0,"facing":1.0,
		"flash":0.0,"moving":false,"motion_phase":0.0,"attack_time":0.0,"stagger":0.0}
	s.enemies=[e]
	if with_seed: s.roguelike.combat.setup_boss(e,floor_index,s)
	else: s.roguelike.combat.setup_boss(e,floor_index)
	return e


func same_pool(a: Array, b: Array) -> bool:
	if a.size()!=b.size(): return false
	for i in a.size():
		if int(a[i])!=int(b[i]): return false
	return true


## 逐个身份把 7 招都真打一遍：起手有预警、伤害延后、释放产生实体、
## 判定几何不变（没有 hit_radius / hit_scale / collision_radius）。
func drive_all_moves(s, e: Dictionary, index: int) -> void:
	var combat = s.roguelike.combat
	var names: Array=Choreo.names(e)
	check(names.size()==7,"%s owns a seven-move table" % Art.ROGUE[index])
	var unique := {}
	for move_name in names: unique[str(move_name)]=true
	check(unique.size()==7,"%s owns seven distinct move names" % Art.ROGUE[index])
	for skill in 7:
		combat.reset()
		s.bullets.clear()
		e.hp=e.max_hp
		e.choreo_active=false
		e.choreo_steps=[]
		combat.begin_skill(s,e,skill,s.players[1])
		check(int(e.boss_skill)==skill,"%s keeps the requested slot %d" % [Art.ROGUE[index],skill])
		check(str(e.move_name)==str(names[skill]),"%s slot %d records its authored move" % [Art.ROGUE[index],skill])
		var telegraphs: int = combat.effects.size()
		check(telegraphs>0 or not e.choreo_steps.is_empty(),"%s slot %d publishes anticipation" % [Art.ROGUE[index],skill])
		for fx in combat.effects:
			check(float(fx.delay)>0.0 and not fx.active,"%s slot %d defers damage behind the warning" % [Art.ROGUE[index],skill])
			check(not str(fx.get("art_key","")).is_empty(),"telegraph keeps its caster identity")
			for forbidden in ["hit_radius","hit_scale","collision_radius"]:
				check(not fx.has(forbidden),"%s slot %d carries no judgement geometry (%s)" % [Art.ROGUE[index],skill,forbidden])
		check(float(e.attack_total)>float(e.boss_windup)+0.5,"%s slot %d leaves a real recovery window" % [Art.ROGUE[index],skill])
		for step in e.choreo_steps:
			check(str(step.get("op",""))!="","every authored step has an op")
		# 推进到释放：预警结束的那一刻必须真的放出实体或伤害区。
		var window: float=float(e.boss_windup)+0.05
		Choreo.advance(s,window)
		combat.update(s,e,window)
		combat.tick(s,window)
		check(bool(e.boss_released),"%s slot %d actually releases" % [Art.ROGUE[index],skill])
		var released: int = s.bullets.size()
		for fx in combat.effects:
			if float(fx.damage)>0.0 or fx.active: released+=1
		for prop in s.enemies:
			if prop.get("boss_construct",false): released+=1
		check(released>0,"%s slot %d produces entities or damaging ground" % [Art.ROGUE[index],skill])
		for b in s.bullets:
			check(float(b.get("hit_radius",18.0))==18.0,"projectile judgement radius stays 18.0")
		check(not str(e.get("choreo_key","")).is_empty() or index<Art.LEGACY_ROGUE,"legacy guardians keep their bare identity key")


func run() -> void:
	var combat := Combat.new()

	# —— ① 池：8 取 5、确定、互不重复、纯整数派生 ——
	check(Art.ROGUE.size()==8,"the guardian pool holds eight identities")
	check(Art.ROGUE.slice(0,Art.LEGACY_ROGUE)==["grove","furnace","astral","wing","obsidian"],
		"the original five keep their indices")
	check(Choreo.MOVES.size()==Choreo.Art.KEYS.size()+3,"seventeen campaign identities plus three guardians")
	var pool_a: Array=Combat.boss_pool(1729)
	var pool_b: Array=Combat.boss_pool(1729)
	check(same_pool(pool_a,pool_b),"the same seed always yields the same pool")
	check(pool_a.size()==5,"a run draws exactly five guardians")
	var distinct := {}
	for index in pool_a:
		check(int(index)>=0 and int(index)<8,"pool entries stay inside the identity list")
		distinct[int(index)]=true
	check(distinct.size()==5,"a run never repeats a guardian")
	var differing := 0
	for seed in range(1,201):
		if not same_pool(Combat.boss_pool(seed),pool_a): differing+=1
	check(differing>=190,"different seeds shuffle the pool (>=190/200)")

	# —— ② 身份与楼层解耦，且不消耗会话 RNG、不写 raid ——
	var reachable := {}
	for seed in range(1,1001):
		for index in Combat.boss_pool(seed): reachable[int(index)]=true
	check(reachable.size()==8,"every identity in the pool can actually appear")
	var raid_keys_before: Array=[]
	for seed in [1,7,4242,999983,20261005]:
		var s := make_session(seed)
		raid_keys_before=s.raid.keys()
		raid_keys_before.sort()
		var state_before: int=s.rng.state
		var seen := {}
		for floor_index in 5:
			var e := make_boss(s,floor_index)
			var expect: int=Combat.boss_art_for(seed,floor_index)
			check(int(e.boss_art)==expect,"seed %d floor %d draws the derived guardian" % [seed,floor_index])
			check(Art.identity(e)==Art.ROGUE[expect],"identity survives Art.identity through art_key")
			check(str(e.art_key)==Art.ROGUE[expect],"the enemy carries its art identity for RPC/renderers")
			check(str(e.boss_name)==Combat.NAMES[expect],"the announced name matches the drawn identity")
			check(int(e.rogue_skin)==floor_index,"rogue_skin keeps naming the floor for cues and minions")
			check(s.roguelike.combat.moves_of(e).size()==7,"the drawn guardian owns seven moves")
			seen[expect]=true
		check(seen.size()==5,"all five floors of a run get different guardians")
		check(s.rng.state==state_before,"drawing guardians never consumes the run RNG")
		var raid_keys_after: Array=s.raid.keys()
		raid_keys_after.sort()
		check(str(raid_keys_before)==str(raid_keys_after),"drawing guardians writes no new raid key")

	# —— ③ 拿不到种子时回落到扩容前的“楼层即身份” ——
	var legacy_session := make_session(0)
	for floor_index in 5:
		var e := make_boss(legacy_session,floor_index,false)
		check(int(e.boss_art)==floor_index,"without a run seed the floor still names the guardian")
		check(Art.identity(e)==Art.ROGUE[floor_index],"legacy identity stays byte-for-byte")
		check(legacy_session.roguelike.combat.moves_of(e).size()==7,"legacy tables keep seven moves")

	# —— ④ 每个身份：7 招都能真打，含三个新身份的真编排 ——
	var covered := {}
	for seed in range(1,400):
		var s := make_session(seed)
		for floor_index in 5:
			var e := make_boss(s,floor_index)
			var index := int(e.boss_art)
			if covered.has(index): continue
			covered[index]=true
			drive_all_moves(s,e,index)
		if covered.size()==8: break
	check(covered.size()==8,"all eight guardians were driven through their seven moves")

	# —— ⑤ 二阶段专属两招在一阶段绝不出现 ——
	check(Combat.PHASE1_MOVES==5 and Combat.PHASE2_MOVES==7,"phase one keeps five moves, phase two opens seven")
	check(combat.phase2_only_skills()==[5,6],"the two finishers are the phase-two-only skills")
	for index in Art.ROGUE.size():
		var probe := {"rogue_guardian":true,"rogue_skin":0,"boss_art":index,"art_key":Art.ROGUE[index],"phase":1,"sequence":0}
		if Combat.CHOREO_KEYS.has(index): probe["choreo_key"]=Combat.CHOREO_KEYS[index]
		var table: Array=Choreo.MOVES[Choreo.choreo_key(probe)]
		var phase1 := {}
		for cursor in 24:
			var slot: int=combat.skill_for_cursor(probe,cursor)
			check(slot<5,"%s never rotates a finisher in phase one" % Art.ROGUE[index])
			phase1[slot]=true
		check(phase1.size()==5,"%s uses all five phase-one moves" % Art.ROGUE[index])
		for sequence in 24:
			probe.sequence=sequence
			check(table.find(Choreo.choose(probe))<5,"%s choose() stays in phase one" % Art.ROGUE[index])
		probe.phase=2
		probe.boss_enraged=true
		var phase2 := {}
		for sequence in 24:
			probe.sequence=sequence
			phase2[int(table.find(Choreo.choose(probe)))]=true
		check(phase2.has(5) and phase2.has(6),"%s opens both finishers past half health" % Art.ROGUE[index])

	# —— ⑥ 客户端复原：只靠 (seed, floor) 就能算出同一个守层者 ——
	for seed in [13,555,31337]:
		for floor_index in 5:
			var s := make_session(seed)
			var e := make_boss(s,floor_index)
			var client_index: int=Combat.boss_art_for(seed,floor_index)
			check(int(e.boss_art)==client_index,"client rebuilds the same guardian from (seed, floor)")
			check(str(e.get("boss_name",""))==Combat.NAMES[client_index],"boss_name is enough to announce the client-side guardian")

	# —— ⑦ 尸体立绘：新身份守层者的尸体必须带身份，旧流程（无 boss_art）回落到楼层 ——
	var corpse_session := make_session(77)
	var fallen := make_boss(corpse_session,3)
	var fallen_art := int(fallen.boss_art)
	corpse_session.roguelike.combat.defeated(corpse_session,fallen)
	var corpses: Array=corpse_session.raid.get("rogue_corpses",[])
	check(corpses.size()==1,"defeat leaves exactly one corpse")
	if not corpses.is_empty():
		var corpse: Dictionary=corpses[0]
		check(int(corpse.get("boss_art",-1))==fallen_art,"the corpse keeps the pooled identity")
		check(str(corpse.get("art_key",""))==Art.ROGUE[fallen_art],"the corpse keeps its art key")
		check(int(corpse.get("floor",-1))==3,"the corpse still records its floor")
		check(int(corpse.get("boss_art",int(corpse.get("floor",-1))))==fallen_art,"the renderer picks the identity first")
	var legacy_corpse := {"floor":2,"time":1.0,"total":1.2}
	check(int(legacy_corpse.get("boss_art",int(legacy_corpse.get("floor",-1))))==2,
		"a corpse without boss_art falls back to its floor")
	var art=RogueArt.new()
	check(str(art.boss_animation(int(legacy_corpse.get("boss_art",2)),11,int(legacy_corpse.get("floor",2))).texture.atlas.resource_path).get_file().begins_with("boss-hd-2"),
		"a legacy corpse still renders the floor body")
	check(str(art.boss_animation(fallen_art,11,3).texture.atlas.resource_path).get_file().begins_with("boss-hd-%d" % fallen_art),
		"a pooled corpse renders its identity body")

	print("ROGUE BOSS POOL ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
