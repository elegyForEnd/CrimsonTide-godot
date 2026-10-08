extends SceneTree
## 营地「远征行囊」面板的真实鼠标回归（要真窗口，所以命名 `*_visual`）。
##
## 三条都是实测过的真 bug：
##   ① **魔境模式下的营地面板整片失效**：`raid.mode` 一旦是 "roguelike"（从魔境跑出来回营地
##      就是这个状态），`main.gd _input` 的早退把整个袋控器关掉，格子/装备位全部点不动——而
##      面板自己的按钮是 Godot Button，不走那条路，所以看上去"只有按钮能用"。
##   ② **面板挡不住底下的按钮**：面板是用普通节点画的，空处没有 Control 接鼠标，点击会穿到
##      营地页去（点「主手」会顺带触发同一位置的「家园设施」行，例如晨光菜园；点面板右下角
##      会顺带点到「出发」）。现在面板铺了一整块 MOUSE_FILTER_STOP 遮罩。
##   ③ **「出发」按钮点了没反应**：它原来只在角色站在闸门/传送门时才有动作，否则只 `say()` 一句
##      提示——而面板打开时那句提示画在面板底下，玩家根本看不见。现在按钮从营地任何位置都能
##      出发，世界里的"走到闸门按 E/Space"仪式不变。
##
## 坐标沿用 `tests/item_bar.gd` 的鼠标标定法：`warp_mouse` 之后读回真实位置，算一个比例。
var app: Node
var failures := 0
var checks := 0
var mouse_scale := Vector2.ONE
var station_requests: Array = []
var launch_requests := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CAMP PACK INPUT FAIL: " + text)

func window_point(design: Vector2) -> Vector2:
	return design*mouse_scale

func calibrate_mouse() -> void:
	Input.warp_mouse(Vector2(600,600))
	await process_frame
	var read: Vector2=app.get_viewport().get_mouse_position()
	if read.x>1.0 and read.y>1.0:
		mouse_scale=Vector2(600,600)/read

func cell_point(slot: String, cell: Vector2i) -> Vector2:
	var entry: Dictionary=app.grids[slot]
	var step: float=float(entry.cell)+float(entry.gap)
	return Vector2(entry.origin)+Vector2((cell.x+0.5)*step,(cell.y+0.5)*step)

func mouse_move(design: Vector2) -> void:
	Input.warp_mouse(window_point(design))
	await process_frame

func button_event(design: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=down
	event.position=window_point(design)
	event.global_position=event.position
	Input.parse_input_event(event)
	await process_frame

func click(design: Vector2) -> void:
	await mouse_move(design)
	await button_event(design,true)
	await process_frame
	await button_event(design,false)
	await process_frame

## A press that reports whether a drag really started before the button goes up.
func press_and_drag(design: Vector2) -> bool:
	await mouse_move(design)
	await button_event(design,true)
	var started: bool=app.drag.active
	await button_event(design,false)
	await process_frame
	return started

func clear_drag() -> void:
	app.drag.active=false
	app.drag["carry"]=0
	app.selected=-1

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-camp-pack-input.json"
	app.profile.data.coins=1000
	app.profile.data.home=preload("res://scripts/homestead.gd").clean({})
	app.go_camp()
	await process_frame
	var p: Dictionary=app.session.players[app.session.my_id()]
	p["backpack"]=Catalog.make_bag("white")
	p.backpack["gw"]=Catalog.BAG_TIERS[0].grid.x
	p.backpack["gh"]=Catalog.BAG_TIERS[0].grid.y
	p["pocket"]=Catalog.make_container([],Catalog.POCKET_GRID)
	p["bags"]=[]
	p["equipped"]=app.session.empty_equipment()
	p["slots"]=app.session.empty_item_slots()
	app.profile.data["warehouse"]=app.profile.make_vault()
	app.profile.data["warehouse_spill"]=[]
	Catalog.add_item(p.backpack,"scrap")
	app.profile.bank_item({"kind":"crystal"})
	p["equipped"]["weapon"]={"kind":"weapon","weapon":3,"tier":4}
	p["weapon"]=3
	app.camp.station_requested.connect(func(id: String) -> void: station_requests.append(id))
	app.camp.launch_requested.connect(func() -> void: launch_requests+=1)
	await create_timer(0.4).timeout
	await calibrate_mouse()

	# ① expedition camp: the carried item answers the mouse.
	clear_drag()
	app.show_camp_pack(false)
	await process_frame
	check(app.drag.active==false,"panel opens with an empty hand")
	var bag_point := cell_point("backpack",Vector2i(0,0))
	check(await press_and_drag(bag_point),"① expedition camp: pressing a carried item starts a drag")

	# ② the same, with the session in the state a player returns to the camp with after a
	#    rogue run: `raid.mode` stays "roguelike" for the whole session.
	await create_timer(0.5).timeout
	clear_drag()
	app.close_bag()
	await process_frame
	app.session.raid["mode"]="roguelike"
	check(app.session.roguelike.active(app.session),"the session reports the rogue mode (as after a rogue run)")
	app.show_camp_pack(false)
	await process_frame
	check(await press_and_drag(bag_point),"② rogue-mode camp: pressing a carried item still starts a drag")

	# ③ nothing behind the panel answers a click. The point below (1300,780) sits inside the
	# 出发 button and outside every button the panel itself draws, so only the shield can stop it.
	await create_timer(0.5).timeout
	clear_drag()
	station_requests.clear()
	launch_requests=0
	var hero_before: Vector2=app.camp.site.hero_position()
	var weapon_point := Vector2(178,259)
	check(await press_and_drag(weapon_point),"③a the 主手 socket is still a drag source")
	await create_timer(0.5).timeout
	clear_drag()
	check(app.worn_zone_at(weapon_point)=="weapon","③b the 主手 socket really is the socket under the cursor")
	await click(Vector2(1300,780))
	await process_frame
	check(launch_requests==0,"③c a click on the 出发 button behind the panel never reaches it")
	check(not app.modal,"③d and it does not open a panel of its own")
	check(station_requests.is_empty(),"③e no 家园设施 row behind the panel answers a click (got %s)" % str(station_requests))
	check(app.camp.site.hero_position()==hero_before,"③f and the hero is not warped to a station")
	check(not app.session.running,"③g the camp is still the current page")

	# ④ with the panel closed the very same point departs from wherever the hero stands.
	await create_timer(0.5).timeout
	app.camp_pack_open=false
	app.close_bag()
	await process_frame
	await click(Vector2(1300,780))
	await process_frame
	check(launch_requests==1,"④a the 出发 button fires when the panel is closed")
	check(app.session.running,"④b and it really departs from the camp spawn (not just a hint)")
	check(app.page_name=="game","④c the raid page is up")

	app.queue_free()
	await process_frame
	print("CAMP PACK INPUT: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
