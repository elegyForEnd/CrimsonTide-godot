extends SceneTree
const Semantics=preload("res://scripts/effect_semantics.gd")
const Visual=preload("res://scripts/boss_damage_visual.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-effect-semantics.json"
	root.add_child(app)
	await process_frame
	var s=app.session
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1729); s.set_physics_process(false)
	var c=s.roguelike.combat
	var field=app.rogue_field
	var families := {}
	for floor_index in 5:
		for variant in 8:
			for skill_index in 2:
				c.reset(); s.enemies.clear(); s.bullets.clear(); field.reset_effects()
				s.roguelike.spawn_minion(s,Vector2(600,575),floor_index,variant,false)
				var e: Dictionary=s.enemies.back()
				e.minion_skill=skill_index; e.attack_aim=Vector2.RIGHT; e.attack_point=e.p+Vector2(60,0)
				var move: String=c.minions.skill(e,skill_index).kind
				families[Semantics.family(move,floor_index)]=true
				c.zone(e,"cone",e.p,80,0,.25,12,Vector2.RIGHT)
				var fx: Dictionary=c.effects.back()
				check(fx.fx_move==move,"Zone captures actual source move before a later combo")
				var h=Visual.minion_hazard(fx)
				check(h.semantic_only and h.standalone_key=="spark","Minion never receives a player weapon body")
				check(h.attack_family==Semantics.family(move,floor_index),"Move selects semantic material")
				for angle in 12:
					var point: Vector2=e.p+Vector2.from_angle(angle*TAU/12)*90
					check(c.contains(fx,point)==Visual.Geometry.contains(h,point),"Visible minion boundary equals collision boundary")
				c.bolt(s,e,Vector2.RIGHT,200,10)
				check(s.bullets.back().fx_move==move,"Projectile keeps its own move")
				c.missile(e,"shot",e.p,e.p+Vector2(200,0),0,.5,10)
				check(c.missiles.back().fx_move==move,"Delayed missile keeps its own move")
	check(families.size()>=10,"Attack identities differ in material, not only color")
	check(Semantics.family("breath",1)!=Semantics.family("sweep",1),"Fire breath never becomes a melee feather")
	check(Semantics.family("heal",0)!=Semantics.family("roots",0),"Healing never becomes a damaging root")
	check(Semantics.mote_texture().resource_path.ends_with("particles/mote.png"),"Reward particles use a separate neutral ImageGen point")
	field.enemy_fx.energy.particles(Vector2.ZERO,Color.WHITE)
	check(field.enemy_fx.energy.emitters.back().texture==Semantics.mote_texture(),"Old particle emitter no longer throws whole attack sprites")
	app.queue_free(); await process_frame; await process_frame
	print("EFFECT SEMANTICS ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
