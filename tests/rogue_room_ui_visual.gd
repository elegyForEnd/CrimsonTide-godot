extends SceneTree
## R7b · 三个专属房间的界面截图（**需要真实窗口**，`run_all_tests.ps1` 只对 `*_visual` 结尾的用例开窗口）
##
##   引擎: Godot_v4.7.2-stable_win64_console.exe --path . --script tests/rogue_room_ui_visual.gd
##   产物: res://build/rogue-room-*.png
##
## `tests/rogue_room_ui.gd` 断言的是文本与 payload，这里把面板真正画出来，好确认它们没有
## 互相遮挡、没有画到屏幕外，并且四个服务/三样赌法/镜像两次点击都各有一个可点的按钮。

var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image!=null, "the viewport produced a frame for "+file)
	if image!=null:
		image.save_png("res://build/"+file+".png")

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-room-ui-visual.json"
	root.add_child(app)
	app.session.solo({"hero":0,"mode":"roguelike"})
	app.session.launch(false,20261006)
	app.session.set_physics_process(false)
	await process_frame
	var p: Dictionary=app.session.players[app.session.my_id()]
	if not p.get("rogue_selection",{}).is_empty():
		app.session.perform(app.session.my_id(),"rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})
	p["status"]="active"
	if not p.equipped.weapon.is_empty(): p.equipped.weapon["tier"]=2
	app.update_hud()

	# 1. 游方锻炉 —— 四个服务，钱不够的那几项要显示原因而不是静默不可点
	app.session.raid["room"]="forge"
	app.session.raid["floor"]=3
	app.session.raid["depth"]=3
	app.session.raid["phase"]="rogue_reward"
	p["rogue_gold"]=180
	p["build_forge_level"]=1
	app.session.roguelike.open_room(app.session)
	app.session.roguelike.refresh_dedicated(app.session,p)
	app.update_rogue_hud(p)
	check(app.rogue_room_buttons.size()==4, "the forge panel drew one button per service")
	check(app.find_child("RogueRoomOption0",true,false)!=null, "the forge rows are addressable by name")
	await capture("rogue-room-forge")

	# 2. 赌徒营帐 —— 三样赌法，赔率写在每一项里
	app.session.raid["room"]="gamble"
	p["rogue_gold"]=600
	p["rogue_ash_run"]=140
	app.session.roguelike.refresh_dedicated(app.session,p)
	app.update_rogue_hud(p)
	check(app.rogue_room_buttons.size()==3, "the tent panel drew one button per wager")
	await capture("rogue-room-gamble")

	# 3. 镜中挑战 —— 第一次点击"应战"
	app.session.raid["room"]="mirror"
	p["rogue_mirror_used"]=false
	app.session.raid["mirror_state"]={}
	app.update_rogue_hud(p)
	check(app.rogue_room_buttons.size()==1, "the mirror panel drew exactly one button")
	await capture("rogue-room-mirror")

	# 4. 应战后面板关闭，场景中出现持有同款武器的影子。
	p.rogue_selection={}; p.build_reward_queue=[]
	app.session.enemies.clear()
	app.session.roguelike.mirror_action(app.session,p)
	var mirror: Dictionary=app.session.enemies.back()
	mirror.p=p.p+Vector2(230,0)
	check(mirror.get("rogue_mirror",false),"Visual encounter contains the mirror enemy")
	app.rogue_field.queue_redraw()
	app.update_rogue_hud(p)
	check(not preload("res://scripts/rogue_room_ui.gd").panel_open("mirror",app.session.raid), "combat closes the service panel")
	await capture("rogue-room-mirror-active")
	p.rogue_curses=["CU08"]
	app.rogue_field._process(0.0)
	check(app.rogue_field.vision_overlay.visible,"Mist curse enables the local vision mask")
	check(is_equal_approx(float((app.rogue_field.vision_overlay.material as ShaderMaterial).get_shader_parameter("radius")),416.0),"Mist reduces the visible radius by 35 percent")
	await capture("rogue-room-mirror-mist")
	p.rogue_curses=[]
	app.rogue_field._process(0.0)
	check(not app.rogue_field.vision_overlay.visible,"Removing mist restores vision")

	print("ROGUE ROOM UI VISUAL: 5 captures, %d checks, %d failures" % [checks,failures])
	app.session.disconnect_room()
	app.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	quit(1 if failures>0 else 0)
