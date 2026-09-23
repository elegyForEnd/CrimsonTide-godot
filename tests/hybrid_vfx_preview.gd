extends SceneTree
## Capture with --write-movie build/hybrid-vfx.avi --fixed-fps 30.
var app: Node
var session: TideSession
var enemy: Dictionary
var age := 0.0
var stage := -1
var triggered := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-hybrid-preview.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	session=app.session
	session.set_physics_process(false)
	session.players[1].invuln=1000
	next_stage()

func next_stage() -> void:
	stage+=1
	if stage>=4:
		print("HYBRID PREVIEW: four themed attack and phase sequences")
		session=null
		app.queue_free()
		await create_timer(.3).timeout
		quit()
		return
	age=0
	triggered=false
	session.enemies.clear()
	session.raid.hazards=[]
	session.raid.phase="explore"
	session.raid.kind=mini(stage,2)
	session.raid.day=3 if stage==2 else 2
	if stage==3: session.spawn_enemy(session.raid.center,4)
	else: session.expedition.spawn_boss(session)
	enemy=session.enemies.back()
	enemy["presentation_seen"]=true
	session.players[1].p=enemy.p+Vector2(210,110)
	app.field.camera=session.players[1].p
	app.field.boss_fx.reset()
	app.field.combat.reset()
	if stage==3: session.start_knight_attack(enemy,"combo",Vector2.RIGHT)
	else: session.expedition.cast_boss(session,enemy,session.players[1],["bell","fan","lances"][stage],Vector2.RIGHT,enemy.p+Vector2(180,0))

func _process(dt: float) -> bool:
	if session==null: return false
	age+=dt
	if stage==3: session.update_knight(enemy,dt)
	else:
		session.expedition.update_hazards(session,dt)
		enemy.attack_time=maxf(0,float(enemy.attack_time)-dt)
	if age>2.4 and not triggered:
		triggered=true
		enemy.attack_time=0
		session.raid.hazards=[]
		enemy.phase=3 if stage==2 else 2
		session.BossPresentation.send(session,enemy,"phase")
	if age>4.4: next_stage()
	return false
