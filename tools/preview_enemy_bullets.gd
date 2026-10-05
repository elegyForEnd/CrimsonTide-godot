extends SceneTree
## Screenshot of enemy projectiles in flight, for the readability change.
##
## It stages one bolt per draw pipeline (ordinary ecology bolt, boss projectile,
## mirror-realm vector) on the real raid field and captures the viewport.  The
## simulation is paused first, so every bolt in the picture is a live, authoritative
## bullet dictionary - nothing is faked for the camera.
var app: Node
const Ecology=preload("res://scripts/ecology.gd")
func _initialize() -> void: call_deferred("run")
func wants_rogue(argument: PackedStringArray) -> bool:
	return argument.has("--rogue")
func wants_dark(argument: PackedStringArray) -> bool:
	return argument.has("--dark")
## `--visual=1.5` switches to the A/B mode: the same deterministic layout, no
## telegraphs, and every staged bolt carrying that `bullet_visual` factor, so two
## runs differ only in the variant factor.
func visual_arg(argument: PackedStringArray) -> float:
	for item in argument:
		if item.begins_with("--visual="):
			return float(item.get_slice("=",1))
	return -1.0
func tier_name(value: float) -> String:
	return str(roundi(value*100.0))
## A bullet and a ground telegraph must be judgeable in the same frame, so the
## windup is staged by hand: attack_time counts down from attack_total and the
## telegraph paints whenever it is above zero.
func stage_windup(s: TideSession, at: Vector2, kind: int, elapsed: float, aim: Vector2) -> void:
	s.spawn_enemy(at,kind)
	var e: Dictionary=s.enemies.back()
	e["attack_aim"]=aim
	e["attack_point"]=at+aim*220.0
	e["attack_total"]=float(Ecology.WINDUP[kind])+0.5
	e["attack_time"]=float(Ecology.WINDUP[kind])+0.5-elapsed
	e["attack_released"]=false
	e["cd"]=99.0
	e["attack_start"]=at
func run() -> void:
	print("PREVIEW: boot")
	var args := OS.get_cmdline_user_args()
	var visual := visual_arg(args)
	if wants_rogue(args):
		await capture_rogue(visual)
		quit()
		return
	var dark := wants_dark(args)
	var ab := visual>0.0
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-enemy-bolt-preview.json"
	app.session.solo({"hero":0})
	app.session.launch(false,1729)
	var s=app.session
	print("PREVIEW: launched, page=",app.page_name," dark=",dark," visual=",visual)
	s.set_physics_process(false)
	s.enemies.clear()
	s.bullets.clear()
	var p: Dictionary=s.players[1]
	p.status="active"
	p.hp=float(p.max_hp)
	p.aim=Vector2.RIGHT
	# Ordinary enemy bolts: a spread of headings, all with the real default
	# hit_radius (the drawing code reads nothing else from these dictionaries).
	var origin := Vector2(1300,1100)
	var headings := [Vector2(1,0),Vector2(1,-0.45),Vector2(-1,0),Vector2(0.25,1)]
	p.p=origin
	app.field.camera=origin
	app.field.combat.reset()
	for index in headings.size():
		var bolt := {"p":origin+Vector2(-210+float(index)*140,-150), "v":headings[index].normalized()*240.0,
			"life":9.0,"damage":1.0,"owner":0}
		if ab: bolt["bullet_visual"]=visual
		s.bullets.append(bolt)
	# A boss projectile through the staged shader path (capsule, inner=hit_radius).
	# Placed over open ground, not behind the raised hall, so its shell is visible.
	var boss := {"p":origin+Vector2(-300,-30),"v":Vector2(1,0)*90.0,"life":9.0,"damage":1.0,"owner":0,
		"boss_projectile":true,"boss_source":-1,"art_key":"knight","vfx_role":"lance",
		"boss_previous":origin+Vector2(-320,-30),"boss_token":"preview:1","hit_radius":18.0}
	if ab: boss["bullet_visual"]=visual
	s.bullets.append(boss)
	if not ab:
		# Ground telegraphs beside the bolts: a ranged lane mid-charge and a melee
		# disc nearly locked, so the two danger languages are directly comparable.
		stage_windup(s,origin+Vector2(-30,240),1,0.22,Vector2.RIGHT)
		stage_windup(s,origin+Vector2(260,255),0,0.20,Vector2.LEFT)
	if dark:
		# A night-fight backdrop: the bolts are additive, so this is exactly the
		# dark-terrain read, with no change to any bolt parameter.
		var shade := ColorRect.new()
		shade.color=Color(0.05,0.06,0.11,0.74)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
		app.add_child(shade)
		app.move_child(shade,app.get_child_count()-1)
		var veil := ColorRect.new()
		veil.color=Color(0.02,0.03,0.09,0.55)
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
		app.add_child(veil)
	print("PREVIEW: staged ",s.bullets.size()," bolts and ",s.enemies.size()," telegraphs")
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	var path := "res://build/enemy-bullets-readability-dark.png" if dark else "res://build/enemy-bullets-readability.png"
	if ab:
		path="res://build/enemy-bullets-visual-%s.png" % tier_name(visual)
	image.save_png(path)
	print("PREVIEW SAVED ",path," ",image.get_size())
	app.queue_free()
	quit()

## The mirror-realm bolts live on their own field node, so the capture hosts that
## node directly instead of booting a second game scene.
func capture_rogue(visual: float) -> void:
	var ab := visual>0.0
	var session=load("res://scripts/session.gd").new()
	root.add_child(session)
	session.solo({"hero":0,"mode":"roguelike"})
	session.launch(false,1729)
	session.set_physics_process(false)
	var field: Control=load("res://scripts/rogue_field.gd").new()
	field.session=session
	root.add_child(field)
	var home: Vector2=field.camera
	for floor_index in 5:
		var bolt := {"p":home+Vector2(-340+float(floor_index)*170,-150),"v":Vector2(1,0)*200.0,
			"life":9.0,"damage":1.0,"owner":0,"boss_source":-1,"fx_move":"shot","rogue_tone":floor_index}
		if ab: bolt["bullet_visual"]=visual
		session.bullets.append(bolt)
		field.enemy_fx.trails.append({"p":home+Vector2(-370+float(floor_index)*170,-150),
			"floor":floor_index,"age":0.05,"aim":0.0,"visual":maxf(1.0,visual)})
	print("PREVIEW: staged ",session.bullets.size()," mirror-realm bolts at visual=",visual)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	var path := "res://build/enemy-bullets-visual-rogue-%s.png" % tier_name(visual) if ab else "res://build/enemy-bullets-readability-rogue.png"
	image.save_png(path)
	print("PREVIEW SAVED ",path," ",image.get_size())
	field.queue_free()
	session.queue_free()
	quit()
