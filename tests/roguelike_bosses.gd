extends SceneTree
const Choreo = preload("res://scripts/boss_choreography.gd")
var checks := 0
var failures := 0
var audio: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
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
		s.raid.area=5
		s.roguelike.enter(s)
		s.enemies.clear()
		s.raid.wave=3
		s.roguelike.spawn_wave(s)
		var e: Dictionary=s.enemies[0]
		names[e.boss_name]=true
		check(e.rogue_guardian and not e.get("raid_boss",false),"Guardian cannot trigger campaign victory")
		check(combat.MOVES[floor_index].size()==5,"Five distinct moves per guardian")
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
			for action in e.choreo_steps:
				if action.op=="projectile": planned_projectiles=true
			var shape := "projectile" if planned_projectiles else "summon" if floor_index==0 and skill==4 else "zone"
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
				var point: Vector2=damage_fx.p
				if damage_fx.shape=="ring": point+=Vector2.RIGHT*(damage_fx.inner+damage_fx.radius)*0.5
				elif damage_fx.shape in ["line","lane"]: point=damage_fx.p+damage_fx.aim*damage_fx.radius*.5
				elif damage_fx.shape=="cone": point+=damage_fx.direction*40
				check(combat.contains(damage_fx,point),"Damage geometry includes advertised danger area")
				check(not combat.contains(damage_fx,Vector2(-900,-900)),"Damage geometry excludes distant safe space")
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
				p.p=contact.p
				if contact.shape in ["line","lane"]: p.p+=contact.aim*contact.radius*.5
				elif contact.shape=="cone": p.p+=contact.aim*40
				elif contact.shape=="ring": p.p+=Vector2.RIGHT*(contact.inner+contact.radius)*.5
				contact.erase("visual_sent")
				combat.effects=[contact]
				p.invuln=0
				combat.tick(s,0.01)
				check(p.hp<hp,"Standing inside released danger actually takes damage: %d/%d %s" % [floor_index,skill,e.move_id])
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
	s.queue_free()
	await process_frame
	print("ROGUE BOSSES ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
