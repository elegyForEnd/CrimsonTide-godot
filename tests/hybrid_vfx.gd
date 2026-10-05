extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-hybrid-vfx.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	app.session.enemies.clear()
	app.session.raid.kind=0
	app.session.expedition.spawn_boss(app.session)
	var enemy: Dictionary=app.session.enemies.back()
	app.field.camera=enemy.p
	app.field.boss_fx.reset()
	var boss: Node=app.field.boss_fx
	enemy.attack_time=1.0
	enemy.attack_total=1.0
	var event := {"kind":"boss-vfx","p":enemy.p,"id":enemy.id,"boss_kind":0,"action":"charge","total":1.0}
	boss.event(event)
	check(boss.effects.size()==1 and boss.effects[0].action=="charge","Charge owns a live painted anticipation layer")
	enemy.attack_time=0.0
	boss._process(.01)
	check(boss.effects.is_empty() and boss.energy.bursts.is_empty(),"Interrupted charge clears its anticipation immediately")
	event.action="phase"
	boss.event(event)
	check(boss.cinematic.active and not paused,"Boss cut-in does not pause gameplay")
	check(not boss.energy.emitters.is_empty(),"Phase emits real textured particles")
	boss.reset()
	check(not boss.cinematic.active and boss.energy.bursts.is_empty() and boss.energy.emitters.is_empty(),"Map/reset clears cut-in, shaders and particles")
	var energy: Node=boss.energy
	for i in 80:
		energy.spawn(enemy.p,Vector2.ONE*100,Color.WHITE,2,.2)
	check(energy.bursts.size()<=64,"Burst count is bounded under simultaneous attacks")
	energy.advance(.3)
	check(energy.bursts.is_empty(),"Expired effects release their nodes")
	for weapon in [1,2]:
		app.field.combat.reset()
		app.field.combat.event({"kind":"strike","p":enemy.p,"weapon":weapon,"aim":Vector2.RIGHT})
		check(app.field.combat.energy.bursts.is_empty() and app.field.combat.energy.emitters.is_empty(),"Original sword attack does not acquire new shader/particle layers")
	app.queue_free()
	await process_frame
	await process_frame
	await create_timer(.3).timeout
	print("HYBRID VFX: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
