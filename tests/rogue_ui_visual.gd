extends SceneTree
## R7 · 魔境 UI/HUD 截图（**需要真实窗口**，`run_all_tests.ps1` 只对 `*_visual` 结尾的用例开窗口）
##
##   引擎: Godot_v4.7.2-stable_win64_console.exe --path . --script tests/rogue_ui_visual.gd
##   产物: res://build/rogue-ui-*.png
##
## 这是 `tests/rogue_ui.gd` 的可视化对照：那边断言文本与动作 payload，这边把这些
## 界面真正画出来，好让人一眼看出新面板没有互相遮挡、也没有画到屏幕外。

const Model = preload("res://scripts/rogue_ui_model.gd")
const Events = preload("res://scripts/rogue_events.gd")

var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void: call_deferred("run")

func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image!=null, "the viewport produced a frame for "+file)
	if image!=null:
		image.save_png("res://build/"+file+".png")

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-ui-visual.json"
	root.add_child(app)
	app.session.solo({"hero":0,"mode":"roguelike"})
	app.session.launch(false,20261005)
	app.session.set_physics_process(false)
	await process_frame
	var p: Dictionary=app.session.players[app.session.my_id()]
	if not p.get("rogue_selection",{}).is_empty():
		app.session.perform(app.session.my_id(),"rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})

	# 1. HUD: 变数 / 诅咒 / 灰烬 / 节点进度 / 种子
	app.session.raid["variant"]="fog"
	app.session.raid["room"]="curse"
	app.session.raid["floor"]=3
	app.session.raid["depth"]=4
	app.session.raid["seed_shared"]="CT-1F3A2B04-E"
	p["rogue_curses"]=["CU01","CU06","CU02","CU03"]
	p["rogue_ash_run"]=48
	app.profile.data["ashes"]=312
	app.update_hud()
	check(app.hud.rogue_variant.text.contains("雾障"), "the HUD drew the rolled variant")
	check(app.hud.rogue_curses.text.contains("4 / 4"), "the HUD drew a full curse loadout")
	check(app.hud.rogue_ash.text.contains("累计 312"), "the HUD drew the ash totals")
	await capture("rogue-ui-hud")

	# 2. 幽暗异事 事件房面板
	# 新语义：面板要求 "确实站在事件房(room=='event')" 且报价 revision 与当前 revision 一致；
	# 上一段为了 HUD 把 room 设成了 curse，所以这里先真正走进事件房，再抽报价。
	app.session.raid["room"]="event"
	Events.roll_offer(app.session)
	app.update_rogue_hud(p)
	check(app.rogue_event_buttons.size()>0, "the event panel has buttons to draw")
	await capture("rogue-ui-event")

	# 3. 灰烬成长树
	app.session.raid["pending_event"]={}
	app.show_growth_tree()
	check(app.rogue_growth_buttons.size()>=12, "the growth tree drew every node")
	await capture("rogue-ui-growth")

	# 4. 种子 / 每日挑战页
	app.close_modal()
	app.show_rogue_seed_page()
	check(is_instance_valid(app.rogue_seed_field), "the seed page drew its input")
	await capture("rogue-ui-seed")

	# 5. 魔境出发页（新的两个入口按钮）
	app.show_rogue_setup()
	check(app.find_child("RogueSeedButton",true,false)!=null, "the setup page drew the seed entry")
	check(app.find_child("RogueGrowthButton",true,false)!=null, "the setup page drew the growth entry")
	await capture("rogue-ui-setup")

	print("ROGUE UI VISUAL: 5 captures, %d checks, %d failures" % [checks, failures])
	app.session.disconnect_room()
	app.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	quit(1 if failures>0 else 0)
