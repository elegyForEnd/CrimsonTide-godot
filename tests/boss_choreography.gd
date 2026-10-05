extends SceneTree
const Choreo = preload("res://scripts/boss_choreography.gd")
const Geometry = preload("res://scripts/boss_geometry.gd")
var checks := 0
var failures := 0
var s: TideSession
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func boss(key: String) -> Dictionary:
	var e := {"id":1000,"p":s.players[1].p+Vector2(100,0),"hp":5000.0,"max_hp":5000.0,"type":4,"last":1,"phase":1,"sequence":0,"cd":0.0,"stagger":0.0,"attack_time":0.0,"attack_total":0.0,"facing":1.0,"flash":0.0,"motion_phase":0.0}
	match key:
		"bell","thorn","queen": e["raid_boss"]=true; e["boss_kind"]=["bell","thorn","queen"].find(key)
		"hidden": e["hidden_final"]=true; e["boss_kind"]=4
		"moon": e["final_form"]=true; e["boss_kind"]=2
		"mirror","ember": e["mini_kind"]=["mirror","ember"].find(key); e["boss_kind"]=0
		"earth","storm","abyss": e["wild_boss"]=true; e["wild_kind"]=["earth","storm","abyss"].find(key); e["boss_kind"]=2
		"dragon": e["dragon_boss"]=true; e["boss_kind"]=3
		"grove","furnace","astral","wing","obsidian":
			e["rogue_guardian"]=true; e["rogue_skin"]=Choreo.Art.ROGUE.find(key); e["boss_skill"]=0
	s.enemies=[e]
	return e
func reset_world() -> void:
	s.enemies.clear()
	s.bullets.clear()
	s.raid.hazards=[]
	s.roguelike.combat.reset()
	s.players[1].status="active"
	s.players[1].invuln=999
func run() -> void:
	s=TideSession.new()
	root.add_child(s)
	s.solo({"hero":0})
	s.launch(false,1729)
	s.set_physics_process(false)
	# The fixture exercises raid and rogue timelines in one session, including summons.
	s.raid["floor"]=1
	var all_names: Dictionary={}
	var projectile_patterns: Dictionary={}
	var constructs := 0
	var moving_fields := 0
	for key in Choreo.Art.KEYS:
		for name in Choreo.MOVES[key]:
			reset_world()
			var e := boss(key)
			var point: Vector2=s.players[1].p
			check(not all_names.has(name),"Every authored move has its own identity")
			all_names[name]=true
			check(Choreo.start(s,e,name,Vector2.LEFT,point),"Playable new move: "+key+" / "+name)
			check(e.attack_time>e.windup+.6,"A real recovery window follows contacts")
			var hp: float=s.players[1].hp
			Choreo.advance(s,.01)
			s.expedition.update_hazards(s,.01)
			s.roguelike.combat.tick(s,.01)
			check(s.players[1].hp==hp,"Anticipation never damages players")
			for entity in s.enemies:
				if entity.get("boss_construct",false): constructs+=1
			var records: Array=s.raid.hazards.duplicate()
			records.append_array(s.roguelike.combat.effects)
			for h in records:
				check(h.art_key==key,"Every hazard keeps the caster identity through RPC / renderer stages")
				check(h.choreographed and h.has("vfx_role") and h.has("origin"),"Collision and art retain one timeline record")
				if h.has("velocity") or h.has("rotate"): moving_fields+=1
				var uniforms := Geometry.shader_data(h)
				check(uniforms.radius==h.radius and uniforms.inner==h.inner,"Shader consumes actual collision dimensions")
			for i in 45:
				Choreo.advance(s,.10)
				s.expedition.update_hazards(s,.10)
				s.roguelike.combat.tick(s,.10)
				for b in s.bullets:
					for field in ["boss_path","boss_return","boss_orbit","boss_homing","boss_plant"]:
						if b.has(field): projectile_patterns[field]=true
				s.update_bullets(.10)
			check(not e.choreo_active,"Timeline exits and returns control")
	check(all_names.size()==73,"All 73 moves across seventeen bosses are authored")
	check(constructs>=20 and moving_fields>=8,"Variety includes interactive constructs and moving ground threats")
	check(projectile_patterns.size()==5,"Refraction, return, orbit, early homing and planted threats all execute")
	reset_world()
	var bell := boss("bell")
	Choreo.start(s,bell,Choreo.MOVES.bell[2],Vector2.LEFT,s.players[1].p)
	Choreo.advance(s,.01)
	var tower: Dictionary=s.enemies.back()
	check(tower.boss_construct,"Bell tower is a real targetable entity")
	s.damage_enemy(tower,100,1,Vector2.RIGHT,200,2)
	check(tower.hp<=0,"Construct destruction uses normal attacks")
	s.expedition.update_hazards(s,3.0)
	check(s.raid.hazards.is_empty(),"Destroying the tower cancels every linked delayed toll")
	reset_world()
	var dragon := boss("dragon")
	Choreo.start(s,dragon,Choreo.MOVES.dragon[1],Vector2.LEFT,s.players[1].p)
	Choreo.advance(s,.01)
	var cover: Dictionary=s.enemies[2]
	var breath := {"p":dragon.p,"cover":true}
	check(Choreo.cover_blocks(s,breath,cover.p+(cover.p-dragon.p).normalized()*100),"Ice pillar provides actual breath cover")
	reset_world()
	var cancelled := boss("thorn")
	Choreo.start(s,cancelled,Choreo.MOVES.thorn[2],Vector2.LEFT,s.players[1].p)
	cancelled.stagger=1.0
	Choreo.advance(s,.1)
	check(s.raid.hazards.is_empty() and not cancelled.choreo_active,"Interrupt clears unreleased damage and motion")
	reset_world()
	var window_boss := boss("bell")
	Choreo.start(s,window_boss,Choreo.MOVES.bell[0],Vector2.LEFT,s.players[1].p)
	s.raid.hazards=[]
	var player: Dictionary=s.players[1]
	var center: Vector2=player.p
	player.p=center+Vector2(120,0)
	player.invuln=0
	var before_hp: float=player.hp
	Choreo.zone(s,window_boss,"circle",center,Vector2.RIGHT,55,.1,10,"fracture")
	s.expedition.update_hazards(s,.11)
	check(player.hp==before_hp,"Outside the released footprint is safe")
	player.p=center
	s.expedition.update_hazards(s,.05)
	check(player.hp<before_hp,"Entering a still-visible active footprint actually hits")
	before_hp=player.hp
	player.invuln=0
	s.expedition.update_hazards(s,.05)
	check(player.hp==before_hp,"One contact cannot hit twice during its visual window")
	s.queue_free()
	await process_frame
	print("BOSS CHOREOGRAPHY ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
