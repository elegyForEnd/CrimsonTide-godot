extends SceneTree
## Confirmed damage drives local feedback; misses, bystanders and camera follow stay clean.
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run() -> void:
	root.size=Vector2i(1440,900)
	var app=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://weapon-weight-test.json"; root.add_child(app)
	var s=app.session; s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1729)
	s.set_physics_process(false)
	s.raid.phase="rogue_combat"
	var field=app.rogue_field; field.show()
	for frame in 6: await process_frame
	field.set_process(false)
	field.combat.set_process(false)
	var p: Dictionary=s.players[1]
	p.rogue_selection={}
	p.p=Vector2(700,690); p.height=0; p.aim=Vector2.RIGHT; p.strike_aim=p.aim
	for weapon in [600,615]:
		p.weapon=weapon; field.combat.reset(); s.enemies.clear()
		var strike := {"kind":"strike","p":p.p,"weapon_index":weapon,"weapon":1 if weapon==600 else 2,"aim":p.aim,"reach":160,"id":1}
		s.broadcast_combat(strike)
		var release=field.combat.weapon_world.effects.back()
		field.combat._process(.016)
		check(release.contact_hold==0 and field.combat.impact_camera_offset()==Vector2.ZERO,"A missed swing cannot cause contact pause or screen kick")
		var follow: Vector2=field.camera_target(p.p)
		s.spawn_enemy(p.p+Vector2(85,0),0)
		if s.enemies.is_empty():
			push_error("Fixture target must spawn on the verified battle-capture tile")
			quit(1); return
		var enemy: Dictionary=s.enemies.back(); enemy.hp=10000; enemy.max_hp=10000
		s.damage_enemy(enemy,10,1,Vector2.RIGHT,15 if weapon==600 else 50,1 if weapon==600 else 2,weapon)
		check(enemy.hp<10000 and p.hitstop>0,"Feedback is triggered by actual authoritative damage")
		check(release.contact_hold>0,"Confirmed contact catches the matching emitted stroke")
		check(field.combat.impact_camera_offset().length()>1,"Roguelike camera consumes the directional contact kick")
		check(field.camera_target(p.p).is_equal_approx(follow),"Camera follow target never integrates the temporary kick")
		var age: float=release.age
		var hold: float=release.contact_hold
		var contact=field.combat.weapon_world.effects.back()
		field.combat._process(.016)
		check(is_equal_approx(release.age,age) and contact.age>0,"Caught blade pauses while target flash continues")
		s.spawn_enemy(p.p+Vector2(85,0),0)
		var second: Dictionary=s.enemies.back(); second.hp=10000; second.max_hp=10000
		s.damage_enemy(second,10,1,Vector2.RIGHT,15,1,weapon)
		check(release.contact_hold<hold,"A crowd cannot stack additional pause onto one swing")
		field.combat._process(.20)
		check(release.age>age and field.combat.impact_camera_offset()==Vector2.ZERO,"Follow-through resumes and camera returns exactly to rest")
		check(field.combat.enemy_impact_pose(int(enemy.id)).scale==Vector2.ONE,"Target compression fully recovers")
		field.combat.reset()
		check(field.combat.sample_reactions.is_empty() and field.combat.sample_kick.is_empty(),"Scene reset clears target reactions and camera impulses")
	app.queue_free(); await process_frame; await process_frame
	print("WEAPON HIT FEEDBACK ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
