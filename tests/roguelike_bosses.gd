extends SceneTree
const Choreo = preload("res://scripts/boss_choreography.gd")
var checks := 0
var failures := 0
var audio: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)


## 危险区取点：不从形状“反推”一个看似在区内的位置（旧写法对内圈有空洞的
## ring/gap_ring 会取到空洞里，池化后楼层与身份解耦就暴露了）。这里给一组候选点，
## 由 combat.contains() 自己判定，取第一个确实落在几何内的点。
func danger_candidates(fx: Dictionary) -> Array:
	var points: Array=[]
	var radius := float(fx.get("radius",0.0))
	var inner := float(fx.get("inner",0.0))
	var aim: Vector2=fx.get("direction",fx.get("aim",Vector2.RIGHT))
	if aim.length()<.01: aim=Vector2.RIGHT
	var end: Vector2=fx.get("end",Vector2.ZERO)
	points.append(fx.p)
	match str(fx.get("shape","circle")):
		"ring","gap_ring":
			# 危险带在内圈与外圈之间：沿 12 个方向取带内中点，天然绕开透明缺口方向。
			for i in 12: points.append(fx.p+Vector2.from_angle(TAU*i/12.0)*maxf(1.0,(inner+radius)*.5))
		"line","lane","capsule":
			if end!=Vector2.ZERO: points.append(fx.p.lerp(end,.5))
			points.append(fx.p+aim*minf(maxf(radius*.5,20.0),80.0))
		"cone":
			points.append(fx.p+aim*minf(maxf(radius*.4,20.0),60.0))
	return points


func first_inside(combat, fx: Dictionary) -> Dictionary:
	var points := danger_candidates(fx)
	for candidate in points:
		if combat.contains(fx,candidate): return {"found":true,"point":candidate,"candidates":points}
	return {"found":false,"point":Vector2.ZERO,"candidates":points}


func describe(fx: Dictionary) -> String:
	return "shape=%s inner=%.1f radius=%.1f aim=%s" % [str(fx.get("shape","")),float(fx.get("inner",0.0)),float(fx.get("radius",0.0)),str(fx.get("direction",fx.get("aim",Vector2.RIGHT)))]


func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.combat_event.connect(func(event):
		if event.kind=="audio": audio.append(event.cue))
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,1729)
	var p: Dictionary=s.players[1]
	var combat=s.roguelike.combat
	var names: Dictionary={}
	for floor_index in 5:
		s.raid.floor=floor_index+1
		s.roguelike.new_floor(s)
		s.raid.area=1
		s.roguelike.enter(s)
		check(s.enemies.size()==6+floor_index,"More monsters on each successive floor")
		var variants: Dictionary={}
		for e in s.enemies:
			variants[e.rogue_variant]=true
			check(e.rogue_radius==13 and e.get("rogue_minion",false),"Small distinct minion has its own AI and collision radius")
		check(variants.size()>=4,"Expanded roster retains a varied wave of local species")
		# R5 的节点图接管了推进入口之后，"第 5 区" 不再等价于 boss：直接进入图里的 boss 节点。
		s.raid.node=str(s.rogue_graph.get("boss",""))
		s.roguelike.enter(s)
		s.enemies.clear()
		s.raid.wave=3
		s.roguelike.spawn_wave(s)
		var e: Dictionary=s.enemies[0]
		names[e.boss_name]=true
		check(e.rogue_guardian and not e.get("raid_boss",false),"Guardian cannot trigger campaign victory")
		# R14：身份现在由 (seed_value, floor) 派生，楼层与身份不再一一对应；
		# 名称、美术身份与 7 招表必须始终指向同一个守层者。
		check(int(e.boss_art)>=0 and int(e.boss_art)<Choreo.Art.ROGUE.size(),
			"Guardian identity stays inside the eight-entry pool")
		check(Choreo.Art.ROGUE[int(e.boss_art)]==Choreo.Art.identity(e),
			"Name, art identity and move table describe the same guardian")
		check(str(e.boss_name)==combat.NAMES[int(e.boss_art)],"Announced name follows the drawn identity")
		check(int(e.rogue_skin)==floor_index,"Floor index still drives floor-based cues and minions")
		check(combat.moves_of(e).size()==7,"Seven distinct moves per guardian")
		check(combat.PHASE1_MOVES==5 and combat.PHASE2_MOVES==7,"Two finishers are gated behind half health")
		e.p=s.roguelike.spawn_point(s,Vector2(2500,580))
		p.p=s.roguelike.spawn_point(s,e.p+Vector2(-100,0))
		p.status="active"
		p.hp=100000
		p.max_hp=100000
		p.invuln=0
		for skill in 5:
			combat.reset()
			audio.clear()
			s.bullets.clear()
			combat.begin_skill(s,e,skill,p)
			Choreo.advance(s,.01)
			check(absf(e.attack_aim.x)<.05 or e.facing==signf(e.attack_aim.x),"Boss sprite faces its locked attack direction")
			check(not combat.effects.is_empty(),"Every move has a visible anticipation shape")
			for fx in combat.effects: check(fx.delay>0 and not fx.active,"Damage is deferred until warning completes")
			var hp: float=p.hp
			combat.tick(s,0.05)
			check(p.hp==hp,"Windup does not deal damage")
			check(audio.has(combat.cue(e,skill,"charge")),"Every move emits its unique charge cue")
			Choreo.advance(s,e.boss_windup+0.01)
			combat.update(s,e,e.boss_windup+0.01)
			combat.tick(s,e.boss_windup+0.01)
			check(e.boss_released and audio.has(combat.cue(e,skill,"release")),"Timed release emits unique impact cue: %d/%d %s" % [floor_index,skill,e.move_id])
			var planned_projectiles := false
			var planned_summons := false
			for action in e.choreo_steps:
				if action.op=="projectile": planned_projectiles=true
				elif action.op=="summon": planned_summons=true
			var shape := "projectile" if planned_projectiles else "summon" if planned_summons else "zone"
			if shape=="projectile":
				check(not s.bullets.is_empty(),"Authored projectile move releases actual hostile entities")
			elif shape=="summon":
				var before: int=s.enemies.size()
				Choreo.advance(s,.4)
				combat.tick(s,0.01)
				check(s.enemies.size()==before+3,"Living grove summons three real minions after iteration")
			else:
				var damage_fx: Dictionary={}
				for fx in combat.effects:
					if fx.damage>0: damage_fx=fx; break
				check(not damage_fx.is_empty(),"Offensive move has real damage geometry")
				var probe := first_inside(combat,damage_fx)
				check(bool(probe.found),"Damage geometry includes advertised danger area: %s candidates=%s" % [describe(damage_fx),str(probe.get("candidates",[]))])
				check(not combat.contains(damage_fx,Vector2(-900,-900)),"Damage geometry excludes distant safe space")
				var point: Vector2=probe.point
				p.p=point
				p.invuln=2
				hp=p.hp
				combat.tick(s,e.boss_windup+0.02)
				check(p.hp==hp,"Invulnerable dodge avoids boss damage")
				combat.reset()
				var contact: Dictionary=damage_fx.duplicate(true)
				contact.delay=0.0
				contact.life=.2
				contact.damage=25.0
				contact.hit={}
				contact.age=0.0
				contact.erase("visual_sent")
				# 合成探针只验证“站在已释放危险区内一定掉血”这一条通道：把该 fx 自身的
				# 位移/旋转与拉扯清掉，否则它在 tick 内会先移动危险带（或把玩家拽走），
				# 使断言测到的是移动/牵引而不是伤害通道（那些行为另有专门用例覆盖）。
				contact["velocity"]=Vector2.ZERO
				contact["rotate"]=0.0
				contact["pull"]=0.0
				contact["push"]=0.0
				combat.effects=[contact]
				var contact_probe := first_inside(combat,contact)
				check(bool(contact_probe.found),"Released danger keeps a reachable interior: %s" % describe(contact))
				p.p=contact_probe.point
				p.invuln=0
				var before_hp: float=p.hp
				combat.tick(s,0.01)
				var diag := "linked=%s cover=%s inside=%s status=%s age=%.2f dmg=%.1f" % [str(Choreo.linked(s,int(contact.get("source",-1)),str(contact.get("link","")))),str(Choreo.cover_blocks(s,contact,p.p)),str(combat.contains(contact,p.p)),str(p.status),float(contact.get("age",0.0)),float(contact.get("damage",0.0))]
				check(p.hp<before_hp,"Standing inside released danger actually takes damage: %d/%d %s %s point=%s [%s]" % [floor_index,skill,str(e.move_id),describe(contact),str(contact_probe.point),diag])
			for action in ["charge","release"]:
				check(ResourceLoader.exists("res://assets/audio/rogue/"+combat.cue(e,skill,action)+".wav"),"Dedicated audio resource exists")
			# Restore a stable target before the next move.
			e.p=s.roguelike.spawn_point(s,Vector2(2500,580))
			p.p=s.roguelike.spawn_point(s,e.p+Vector2(-100,0))
		combat.reset()
		s.enemies=[e]
		e.attack_time=0
		e.cd=0
		e.move_cursor=0
		p.invuln=1000
		var seen: Dictionary={}
		for tick in 2500:
			Choreo.advance(s,.02)
			combat.update(s,e,0.02)
			combat.tick(s,0.02)
			seen[e.boss_skill]=true
		check(seen.size()==5,"Normal AI rotation uses every one of the five skills")
		e.hp=e.max_hp*0.49
		combat.update(s,e,0.02)
		check(e.boss_enraged,"Half health triggers second phase")
		combat.zone(e,"circle",p.p,90,0.0,3,30)
		e.hp=0
		s.simulate(0.01)
		check(combat.effects.is_empty(),"Defeated boss leaves no damaging effects")
		check(s.raid.phase=="rogue_reward" and s.raid.mode=="roguelike","Defeat grants area reward without campaign transitions")
	check(names.size()==5,"Five different guardian identities")
	# —— 池生效时的独立验收：8 个身份 × 7 招的危险区几何都成立 ——
	# 不复用上面“某层恰好是某个身份”的偶然性，而是用 boss_pool 反查一个把该身份
	# 放在某层的 (seed, floor)，再用真实 setup_boss 生成守层者。以后池的分配算法变了也依然有效。
	var audited := {}
	for identity in Choreo.Art.ROGUE.size():
		var seed_for := 0
		var floor_for := -1
		for candidate_seed in range(1,400):
			var hit := false
			for candidate_floor in 5:
				if combat.boss_art_for(candidate_seed,candidate_floor)==identity:
					seed_for=candidate_seed; floor_for=candidate_floor; hit=true; break
			if hit: break
		check(floor_for>=0,"Pool can place %s on some floor" % Choreo.Art.ROGUE[identity])
		if floor_for<0: continue
		var restored_seed: int=s.seed_value
		s.seed_value=seed_for
		var probe_boss := {"id":900+identity,"p":s.players[1].p+Vector2(120,0),"facing":1.0,
			"hp":6000.0,"max_hp":6000.0,"flash":0.0,"moving":false,"motion_phase":0.0,"attack_time":0.0,"stagger":0.0}
		s.enemies=[probe_boss]
		combat.setup_boss(probe_boss,floor_for,s)
		check(int(probe_boss.boss_art)==identity and Choreo.Art.identity(probe_boss)==Choreo.Art.ROGUE[identity],
			"Pooled boss carries the identity under audit (%s)" % Choreo.Art.ROGUE[identity])
		check(int(probe_boss.rogue_skin)==floor_for,"Pooled boss still reports its floor for cues and minions")
		for skill in 7:
			combat.reset()
			s.bullets.clear()
			combat.begin_skill(s,probe_boss,skill,s.players[1])
			var window: float=float(probe_boss.boss_windup)+0.02
			Choreo.advance(s,window)
			combat.update(s,probe_boss,window)
			combat.tick(s,window)
			var released := 0
			for fx in combat.effects:
				if float(fx.damage)<=0.0: continue
				released+=1
				var interior := first_inside(combat,fx)
				check(bool(interior.found),"%s slot %d keeps a reachable interior: %s" % [Choreo.Art.ROGUE[identity],skill,describe(fx)])
				check(not combat.contains(fx,Vector2(-900,-900)),"%s slot %d excludes distant safe space" % [Choreo.Art.ROGUE[identity],skill])
				for forbidden in ["hit_radius","hit_scale","collision_radius"]:
					check(not fx.has(forbidden),"%s slot %d carries no judgement geometry (%s)" % [Choreo.Art.ROGUE[identity],skill,forbidden])
			for prop in s.enemies:
				if prop.get("boss_construct",false): released+=1
			for bullet in s.bullets:
				released+=1
				check(float(bullet.get("hit_radius",18.0))==18.0,"%s slot %d projectile judgement radius stays 18.0" % [Choreo.Art.ROGUE[identity],skill])
			check(released>0,"%s slot %d releases entities or damaging ground" % [Choreo.Art.ROGUE[identity],skill])
		s.seed_value=restored_seed
		audited[identity]=floor_for
		s.enemies.clear()
	check(audited.size()==8,"Every pooled identity was audited across its seven moves")
	s.queue_free()
	await process_frame
	print("ROGUE BOSSES ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
