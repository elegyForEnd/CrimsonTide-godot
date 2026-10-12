extends SceneTree
## Interactive ACTUAL combat with temporary saves, plus a close-up asset inspection.
var app
var mode := -1
var clock := 0.0
var workshop: Node3D
var actor: Node3D
var camera: Camera3D
var hint: Label
var captures := false
var shot := 0
var next_shot := 2.0
var workshop_animation := "idle"
var view_turn := 0.0
var finished := false
class Keys extends Node:
	var receive: Callable
	func _input(e: InputEvent) -> void:
		if receive.is_valid(): receive.call(e)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	OS.set_environment("CRIMSON_BOSS3D_PREVIEW","1")
	root.size=Vector2i(1440,900); root.content_scale_size=root.size
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.profile.path="user://boss-3d-preview-profile.json"
	var keys := Keys.new(); keys.receive=key; root.add_child(keys)
	var canvas := CanvasLayer.new(); canvas.layer=30; root.add_child(canvas)
	hint=Label.new(); hint.position=Vector2(290,790); hint.size=Vector2(1030,85)
	hint.add_theme_font_override("font",load("res://assets/NotoSansSC.ttf")); hint.add_theme_font_size_override("font_size",18)
	hint.add_theme_color_override("font_shadow_color",Color.BLACK); hint.add_theme_constant_override("shadow_outline_size",5); canvas.add_child(hint)
	captures="--capture-boss-3d" in OS.get_cmdline_user_args()
	change_mode(3 if "--workshop" in OS.get_cmdline_user_args() else 0)
func change_mode(value: int) -> void:
	if mode==value: return
	if workshop: workshop.queue_free(); workshop=null; actor=null; camera=null
	app.show_title(); app.session.running=false
	if app.story_screen: app.story_screen.set_physics_process(true)
	mode=value; clock=0; shot=0; next_shot=2.0
	if mode==0:
		app.go_story("user://boss-3d-preview-story.json")
		var c=app.story_screen.campaign; c.save_enabled=false; c.state=c.new_state(); c.enter(1,9)
		var guardian: Dictionary={}
		for e: Dictionary in c.enemies:
			if e.get("model_3d","")=="oath-knight": guardian=e; break
		if guardian.is_empty(): push_error("Castle guardian not installed"); quit(1); return
		c.hero_at=c.map.move(guardian.p,Vector2(0,320)); c.allies=[c.hero_at,c.hero_at+Vector2(-70,50),c.hero_at+Vector2(70,50)]
		c.state.potions=99; c.state.gear.armor=10
		# Preview survivability only; production encounter stats remain unchanged.
		guardian.hp=8500.; guardian.maxhp=8500.
	elif mode<3:
		app.session.solo({"hero":0,"mode":"roguelike" if mode==1 else "expedition"})
		app.session.launch(false,20261011)
		var s=app.session; var p: Dictionary=s.players[1]
		s.enemies.clear(); s.bullets.clear(); p.weapon=600; p.hp=999; p.max_hp=999; p.flasks=99
		if mode==1:
			p.p=Vector2(720,575); app.rogue_field.camera_x=0; app.rogue_field.camera_y=0
			s.raid.phase="rogue_combat"
		else: s.raid.phase="explore"
		s.spawn_enemy(s.ruins.move(p.p,Vector2(240,0),20),4)
		var e: Dictionary=s.enemies[-1]; e.hp=8500.; e.max_hp=8500.; e.cd=1.0
		if mode==1: s.roguelike.combat.setup_boss(e,4,s)
		app.close_modal(); app.overlay.hide(); app.modal=false; paused=false
	else:
		app.page.hide(); app.field.hide(); app.rogue_field.hide()
		app.set_process_input(false); app.set_process_unhandled_input(false)
		workshop=Node3D.new(); root.add_child(workshop)
		actor=preload("res://scripts/boss_actor_3d.gd").new(); workshop.add_child(actor); actor.target_scale=1.0
		camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=4.2
		camera.position=Vector3(4,3.3,6); workshop.add_child(camera); camera.look_at(Vector3(0,1.5,0)); camera.make_current()
		var key_light := DirectionalLight3D.new(); key_light.rotation_degrees=Vector3(-35,-30,0); key_light.light_energy=2.3; key_light.shadow_enabled=true; workshop.add_child(key_light)
		var fill := DirectionalLight3D.new(); fill.rotation_degrees=Vector3(-25,140,0); fill.light_color=Color("a4bed4"); fill.light_energy=1.15; workshop.add_child(fill)
		var env := WorldEnvironment.new(); env.environment=Environment.new(); env.environment.background_mode=Environment.BG_COLOR
		env.environment.background_color=Color("20242c"); env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color=Color("bcc5cb"); env.environment.ambient_light_energy=.5; env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC; workshop.add_child(env)
		var floor_mesh := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size=Vector2(12,12); floor_mesh.mesh=plane
		var mat := StandardMaterial3D.new(); mat.albedo_color=Color("303540"); mat.roughness=.88; floor_mesh.material_override=mat; workshop.add_child(floor_mesh)
	if mode!=3: app.set_process_input(true); app.set_process_unhandled_input(true)
	hint.text="3D Boss 实战预览 · "+["灰棘旧堡守门人","黑曜剑圣 · 魔境","失乡骑士 · 远征","模型与骨骼动作检查"][mode]+"\n1 故事 / 2 闯关 / 3 搜打撤 / 4 模型  ·  实战沿用游戏操作  ·  模型：←→切动作 / 拖动视角  ·  临时存档"
func key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4]: change_mode(event.keycode-KEY_1)
		if mode==3 and event.keycode in [KEY_LEFT,KEY_RIGHT]:
			var names := ["idle","walk","charge","slash","sweep","thrust","slam","guard","hit","break","phase","cast","entrance","death"]
			workshop_animation=names[posmod(names.find(workshop_animation)+(1 if event.keycode==KEY_RIGHT else -1),names.size())]; clock=0
	if mode==3 and event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		view_turn+=event.relative.x*.007
func _process(dt: float) -> bool:
	if mode<0 or finished: return false
	clock+=dt
	if actor and actor.model_ok:
		actor.age=10
		var e := {"id":1,"p":Vector2.ZERO,"hp":100.,"phase":1,"facing":-1.,"attack_time":0.}
		actor.sync(e,dt,clock)
		actor.rotation.y=view_turn
		if actor.clips.has(workshop_animation):
			actor.player.play(actor.clips[workshop_animation]); actor.player.seek(fmod(clock,actor.player.get_animation(actor.clips[workshop_animation]).length),true); actor.player.advance(0)
	if captures and clock>next_shot:
		RenderingServer.force_draw(false)
		var path := "res://build/boss-3d-%s-%02d.png" % [["story","rogue","expedition","workshop"][mode],shot]
		root.get_texture().get_image().save_png(path); print("BOSS_3D_CAPTURE ",path)
		shot+=1; next_shot+=1.0
		if mode==3:
			view_turn+=PI/2
			if shot==3: workshop_animation="slash"; clock=0; next_shot=.27
		if shot>= (4 if mode==3 else 3):
			if mode<3: change_mode(mode+1)
			else: finished=true; app.queue_free(); workshop.queue_free(); print("BOSS_3D_CAPTURE_COMPLETE ","4" if "--workshop" in OS.get_cmdline_user_args() else "13"); quit()
	return false
