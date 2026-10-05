extends SceneTree
## R6：守层者半血「二阶段换招表」+ 深渊变数的敌人侧数值钩子。
##
## 本用例**刻意不依赖 TideSession**：R5 在飞时 session.gd/roguelike.gd 可能整体编译失败，
## 而 R6 的验收对象只是 RogueCombat / BossChoreography 自身，所以这里用一个最小桩会话
## （StubSession/StubRuins/StubRogue）驱动真实的战斗与编排代码，保证 R6 的结论随时可复跑。

const Combat = preload("res://scripts/rogue_combat.gd")
const Choreo = preload("res://scripts/boss_choreography.gd")
const Art = preload("res://scripts/boss_effect_art.gd")
const Variants = preload("res://scripts/rogue_variants.gd")

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


class StubSession:
	signal message(detail: String)
	var raid: Dictionary = {"variant":"","floor":1,"hazards":[]}
	var enemies: Array = []
	var bullets: Array = []
	var players: Dictionary = {}
	var ruins = StubRuins.new()
	var roguelike = StubRogue.new()
	var next_enemy: int = 2
	var messages: Array = []
	var audio: Array = []
	var combat_events: Array = []

	func broadcast_combat(data: Dictionary) -> void:
		combat_events.append(data)

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


func make_session() -> StubSession:
	var s := StubSession.new()
	var combat := Combat.new()
	s.roguelike.combat=combat
	s.players={1:{"id":1,"status":"active","p":Vector2(2400,580)}}
	return s


func make_boss(s, floor_index: int, with_session: bool = true) -> Dictionary:
	var e := {"id":1,"p":Vector2(2500,580),"type":4,"hp":0.0,"max_hp":0.0,"facing":1.0,
		"flash":0.0,"moving":false,"motion_phase":0.0,"attack_time":0.0,"stagger":0.0}
	s.enemies=[e]
	if with_session: s.roguelike.combat.setup_boss(e,floor_index,s)
	else: s.roguelike.combat.setup_boss(e,floor_index)
	return e


func make_minion(s, floor_index: int, seed_value: int, variant: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value
	var m := {"id":9,"p":Vector2(2600,580),"type":1,"hp":0.0,"max_hp":0.0,"facing":1.0,
		"flash":0.0,"moving":false,"motion_phase":0.0,"attack_time":0.0,"stagger":0.0}
	s.roguelike.combat.setup_minion(m,floor_index,variant,false,rng,s)
	return m


func advance_boss(s, e: Dictionary, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed<seconds:
		Choreo.advance(s,0.05)
		elapsed+=0.05


func run() -> void:
	var s := make_session()
	var combat = s.roguelike.combat
	var target: Dictionary=s.players[1]

	# —— ① 七招表：五招原招 + 两招只在半血后出现 ——
	for floor_index in 5:
		check(combat.MOVES[floor_index].size()==7,"guardian %d owns a seven-move table" % floor_index)
		var key: String=str(Art.ROGUE[floor_index])
		check(Choreo.MOVES[key].size()==7,"%s owns seven authored timelines" % key)
		var names := Choreo.names({"rogue_guardian":true,"rogue_skin":floor_index})
		var unique := {}
		for move_name in names: unique[move_name]=true
		check(names.size()==7 and unique.size()==7,"guardian %d has seven distinct move names" % floor_index)
	check(combat.PHASE1_MOVES==5 and combat.PHASE2_MOVES==7,"phase one keeps five moves, phase two opens seven")
	check(combat.phase2_only_skills()==[5,6],"the two finishers are the phase-two-only skills")

	# —— ② 一阶段绝不出现终结技（三条路径都要挡住）——
	var boss := make_boss(s,0)
	var phase1_cursor := {}
	var phase1_choose := {}
	var phase1_skills := {}
	for cursor in 60:
		phase1_cursor[combat.skill_for_cursor(boss,cursor)]=true
		var probe: Dictionary=boss.duplicate(true)
		probe["sequence"]=cursor
		var chosen: String=Choreo.choose(probe)
		phase1_choose[chosen]=true
		phase1_skills[Choreo.MOVES[Art.ROGUE[0]].find(chosen)]=true
	check(phase1_cursor.size()==5,"phase one cursor rotation still covers exactly the original five skills")
	check(not phase1_cursor.has(5) and not phase1_cursor.has(6),"the cursor never reaches a finisher during phase one")
	check(not phase1_skills.has(5) and not phase1_skills.has(6),"choose() never returns a finisher during phase one")
	for move_name in phase1_choose:
		check(Choreo.MOVES[Art.ROGUE[0]].find(move_name)>=0,"phase-one choose() only returns authored moves (%s)" % move_name)

	# —— ③ 半血切换到二阶段：只触发一次，回血不退回 ——
	boss.hp=boss.max_hp*0.49
	combat.update(s,boss,0.02)
	check(boss.boss_enraged and int(boss.phase)==2,"half health switches the guardian to phase two")
	var crest_events := 0
	for event in s.combat_events:
		if str(event.get("kind",""))=="rogue-boss-phase": crest_events+=1
	check(crest_events==1,"the phase crest is announced exactly once")
	check(s.audio.has("rogue-%d-phase" % 0),"the phase sting uses the guardian's own cue")
	boss.hp=boss.max_hp*0.9
	combat.update(s,boss,0.02)
	check(int(boss.phase)==2 and boss.boss_enraged,"a healed guardian does not fall back to phase one")
	for tick in 40:
		boss.hp=boss.max_hp*(0.49 if tick%2==0 else 0.9)
		combat.update(s,boss,0.02)
	var crest_after := 0
	for event in s.combat_events:
		if str(event.get("kind",""))=="rogue-boss-phase": crest_after+=1
	check(crest_after==1,"crossing the threshold repeatedly never re-triggers the phase")
	var phase2_cursor := {}
	var phase2_skills := {}
	for cursor in 60:
		phase2_cursor[combat.skill_for_cursor(boss,cursor)]=true
		var probe: Dictionary=boss.duplicate(true)
		probe["sequence"]=cursor
		phase2_skills[Choreo.MOVES[Art.ROGUE[0]].find(Choreo.choose(probe))]=true
	check(phase2_cursor.has(5) and phase2_cursor.has(6),"phase two rotation reaches both finishers")
	check(phase2_cursor.size()==7,"phase two rotation covers the whole seven-move table")
	check(phase2_skills.has(5) and phase2_skills.has(6),"phase-two choose() reaches both finishers")
	for skill_index in phase2_skills:
		check(skill_index>=0 and skill_index<7,"phase-two choose() stays inside the seven-move table")

	# 真实 AI 循环也必须真的打出两招终结技（不只是在备选表里存在）
	var live := make_boss(s,0)
	live.hp=live.max_hp*0.4
	combat.reset()
	var started := {}
	var guard_ticks := 0
	while guard_ticks<500 and (not started.has(5) or not started.has(6)):
		Choreo.advance(s,0.05)
		combat.update(s,live,0.05)
		if int(live.boss_skill)>=0: started[int(live.boss_skill)]=true
		guard_ticks+=1
	check(int(live.phase)==2,"the live guardian stands in phase two")
	check(started.has(5) and started.has(6),"the live AI actually casts both finishers once enraged")
	for skill_index in started:
		check(skill_index>=0 and skill_index<7,"the live AI never leaves the seven-move table")

	# —— ④ 两招终结技是真实、延迟、与一阶段同构的伤害几何 ——
	for floor_index in 5:
		for skill in [5,6]:
			var guardian := make_boss(s,floor_index)
			guardian.hp=guardian.max_hp*0.4
			guardian.boss_enraged=true
			guardian["phase"]=2
			combat.reset()
			s.bullets=[]
			combat.begin_skill(s,guardian,skill,target)
			check(int(guardian.boss_skill)==skill,"finisher %d of guardian %d starts" % [skill,floor_index])
			check(guardian.attack_time>0.0 and guardian.boss_windup>0.0,"finisher %d/%d owns a full windup" % [floor_index,skill])
			check(not combat.effects.is_empty(),"finisher %d/%d shows an anticipation shape" % [floor_index,skill])
			var damage_planned := false
			for fx in combat.effects:
				check(fx.get("choreographed",false),"finisher %d/%d geometry is choreographed" % [floor_index,skill])
				check(float(fx.delay)>0.0 and not fx.active,"finisher %d/%d damages only after its warning" % [floor_index,skill])
				check(not fx.has("hit_radius") and not fx.has("collision_radius") and not fx.has("hit_scale"),
					"finisher %d/%d telegraph carries no hit-radius override" % [floor_index,skill])
				if float(fx.damage)>0.0: damage_planned=true
			for action in guardian.choreo_steps:
				if str(action.op)=="projectile": damage_planned=true
			check(damage_planned,"finisher %d/%d plans real damage" % [floor_index,skill])
			advance_boss(s,guardian,guardian.attack_total+0.6)
			var landed := s.bullets.size()>0
			for fx in combat.effects:
				if float(fx.damage)>0.0: landed=true
			check(landed,"finisher %d/%d releases hostile entities or a damage area" % [floor_index,skill])
			for b in s.bullets:
				check(is_equal_approx(float(b.get("hit_radius",18.0)),18.0),
					"finisher %d/%d bolt keeps the shared 18px hit radius" % [floor_index,skill])
				check(float(b.get("bullet_visual",1.0))>=1.0,
					"finisher %d/%d bolt only carries a visual scale" % [floor_index,skill])
			for fx in combat.effects:
				if float(fx.damage)<=0.0: continue
				var point: Vector2=fx.p
				if str(fx.shape)=="ring": point+=Vector2.RIGHT*(float(fx.inner)+float(fx.radius))*0.5
				elif str(fx.shape) in ["line","lane"]: point=fx.p+fx.aim*float(fx.radius)*0.5
				elif str(fx.shape)=="cone": point+=fx.aim*40
				check(combat.contains(fx,point),"finisher %d/%d geometry covers its advertised danger area" % [floor_index,skill])
				check(not combat.contains(fx,Vector2(-900,-900)),"finisher %d/%d geometry excludes distant safe space" % [floor_index,skill])
				break

	# —— ⑤ 变数钩子：敌人生命 / 节奏 / 弹速 / 弹幕表现 ——
	var ids := Variants.ids()
	check(ids.size()>=10,"the variant table is populated")
	for id in ids:
		s.raid["variant"]=str(id)
		var hp_scale: float = combat.enemy_hp_scale(s)
		var tempo: float = combat.enemy_tempo(s)
		var speed_scale: float = combat.bullet_speed_scale(s)
		var visual_scale: float = combat.bullet_visual_scale(s)
		check(hp_scale>=0.5 and hp_scale<=3.0,"enemy hp scale stays bounded for %s" % id)
		check(tempo>=0.5 and tempo<=2.0,"enemy tempo stays bounded for %s" % id)
		check(speed_scale>=0.5 and speed_scale<=2.0,"hostile bolt speed stays bounded for %s" % id)
		check(visual_scale>=1.0 and visual_scale<=3.0,"hostile bolts never shrink under %s" % id)
	s.raid["variant"]="bedrock"
	check(is_equal_approx(combat.enemy_hp_scale(s),1.2),"bedrock raises enemy health by 20%")
	s.raid["variant"]="frenzy"
	check(is_equal_approx(combat.enemy_hp_scale(s),0.92),"frenzy trims enemy health by 8%")
	check(is_equal_approx(combat.enemy_tempo(s),1.12),"frenzy raises enemy tempo by 12%")
	s.raid["variant"]="fog"
	check(is_equal_approx(combat.bullet_speed_scale(s),0.8),"fog slows hostile bolts by 20%")
	check(is_equal_approx(combat.bullet_visual_scale(s),1.25),"fog enlarges hostile bolts by 25%")
	s.raid["variant"]=""
	check(is_equal_approx(combat.enemy_hp_scale(s),1.0),"no variant means no enemy stat change")
	check(is_equal_approx(combat.bullet_visual_scale(s),1.0),"no variant means no visual change")

	# 生成时应用（调用方传 s）
	s.raid["variant"]="bedrock"
	var scaled := make_boss(s,2)
	check(is_equal_approx(scaled.max_hp,1650.0*1.2),"bedrock scales a fresh guardian's health at spawn")
	check(is_equal_approx(scaled.hp,scaled.max_hp),"the scaled guardian starts at full health")
	var held: float=scaled.hp
	for tick in 12: combat.update(s,scaled,0.01)
	check(is_equal_approx(scaled.max_hp,1650.0*1.2),"variant stats are applied once, not per frame")
	check(scaled.hp<=held+0.001,"repeated updates do not stack health scaling")

	# 调用方不传 s 时，由首次 update 补应用（W1 尚未改签名也能生效）
	var late := make_boss(s,0,false)
	check(is_equal_approx(late.max_hp,950.0),"without a session the spawn keeps the plain health")
	combat.update(s,late,0.01)
	check(is_equal_approx(late.max_hp,950.0*1.2),"the first update applies the pending variant stats")
	check(int(late.get("variant_stats_applied",0))>0,"the pending application is recorded once")

	# 小怪：生命与出手节奏
	s.raid["variant"]=""
	var base_minion := make_minion(s,0,99)
	s.raid["variant"]="bedrock"
	s.roguelike.combat.reset()
	var tough := make_minion(s,0,99)
	check(is_equal_approx(tough.max_hp,base_minion.max_hp*1.2),"bedrock raises minion health by 20%")
	s.raid["variant"]="frenzy"
	var quick := make_minion(s,0,99)
	check(is_equal_approx(quick.max_hp,base_minion.max_hp*0.92),"frenzy trims minion health by 8%")
	check(is_equal_approx(quick.cd,base_minion.cd/1.12),"frenzy shortens the minion's attack cooldown")

	# —— ⑥ 判定字段在有/无变数时完全一致，只有表现倍率与弹速不同 ——
	s.raid["variant"]=""
	combat.reset()
	s.bullets=[]
	var plain_boss := make_boss(s,0)
	combat.bolt(s,plain_boss,Vector2.RIGHT,200.0,20.0)
	var plain: Dictionary=s.bullets[0]
	s.raid["variant"]="fog"
	s.bullets=[]
	var fog_boss := make_boss(s,0)
	combat.bolt(s,fog_boss,Vector2.RIGHT,200.0,20.0)
	var fogged: Dictionary=s.bullets[0]
	for key in ["life","damage","owner","boss_source","fx_move","rogue_tone","rogue_guardian"]:
		check(plain.get(key)==fogged.get(key),"a bolt keeps %s identical under any variant" % key)
	check(not plain.has("hit_radius") and not fogged.has("hit_radius"),"a bolt never writes its own hit radius")
	check(is_equal_approx(plain.v.length(),200.0),"a plain bolt keeps its authored speed")
	check(is_equal_approx(fogged.v.length(),160.0),"fog slows the bolt by exactly 20%")
	check(fogged.get("bullet_visual",1.0)>plain.get("bullet_visual",1.0),"fog only enlarges the drawn bolt")

	# 编排弹同样只改速度与表现
	s.raid["variant"]=""
	combat.reset()
	s.bullets=[]
	var astral := make_boss(s,2)
	astral.boss_enraged=true
	astral["phase"]=2
	combat.begin_skill(s,astral,5,target)
	advance_boss(s,astral,astral.attack_total+0.6)
	check(s.bullets.size()>0,"the astral finisher releases authored projectiles")
	for b in s.bullets:
		check(is_equal_approx(float(b.get("hit_radius",18.0)),18.0),"choreographed bolts keep the shared hit radius")
		check(is_equal_approx(float(b.get("bullet_visual",1.0)),1.0),"without a variant the bolt has no visual bonus")
	s.raid["variant"]="fog"
	combat.reset()
	s.bullets=[]
	var astral_fog := make_boss(s,2)
	astral_fog.boss_enraged=true
	astral_fog["phase"]=2
	combat.begin_skill(s,astral_fog,5,target)
	check(is_equal_approx(combat.bullet_speed_of(astral_fog),0.8),"a guardian caches the hostile bolt speed factor at cast time")
	check(is_equal_approx(combat.bullet_visual_of(astral_fog),1.25),"a guardian caches the hostile bolt visual factor at cast time")
	advance_boss(s,astral_fog,astral_fog.attack_total+0.6)
	check(s.bullets.size()>0,"the fogged astral finisher still releases projectiles")
	for b in s.bullets:
		check(is_equal_approx(float(b.get("hit_radius",18.0)),18.0),"fog never changes a finisher bolt's hit radius")
		check(is_equal_approx(float(b.get("bullet_visual",1.0)),1.25),"fog is visible on finisher bolts")
		if b.has("boss_aim"):
			var authored_speed := float(b.get("boss_total",0.0))
			check(authored_speed>0.0,"the fogged bolt still carries its authored life time")

	print("ROGUE BOSS PHASE2 ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
