extends Node

# A frame that can be moved and recoloured every frame: used for the ghost plate,
# the landing-cell preview and the "cannot drop here" hatch.
class ObjectRing extends Control:
	var area := Rect2()
	var tone := Color("d8bd8a")
	var blocked := false

	func _init(colour: Color) -> void:
		tone=colour
		mouse_filter=Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(area,Color(tone,0.18 if not blocked else 0.22),true)
		draw_rect(area,tone,false,2.0)
		if blocked:
			var step := 11.0
			var offset := 0.0
			var span := area.size.x+area.size.y
			while offset<span:
				var a := Vector2(maxf(0.0,offset-area.size.y),minf(offset,area.size.y))
				var b := Vector2(minf(offset,area.size.x),maxf(0.0,offset-area.size.x))
				if a!=b:
					draw_line(area.position+a,area.position+b,Color(tone,0.55),1.6)
				offset+=step

func object_ring(colour: Color) -> ObjectRing:
	return ObjectRing.new(colour)

func object_ring_node(parent: Node, colour: Color) -> void:
	var ring := ObjectRing.new(colour)
	ring.name="GhostRing"
	ring.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(ring)

const BG := Color("0d121c")
const PANEL := Color("151b27")
const INK := Color("e7dfd5")
const MUTED := Color("969aaa")
const RED := Color("ad4056")
const GOLD := Color("c5a67b")
# R7: the roguelike view-model (HUD strings, event view, growth rows, seeds) and the
# growth tree it reads. Preloaded by path because the .godot class cache is stale for
# the newer Rogue* modules and a bare class name would fail at parse time.
const RogueUi := preload("res://scripts/rogue_ui_model.gd")
const RogueGrowth := preload("res://scripts/rogue_growth.gd")
const RogueGraph := preload("res://scripts/rogue_graph.gd")
# R7b: the dedicated-room view-model (游方锻炉 / 赌徒营帐 / 镜中挑战). Same preload rule
# as above — no bare class names while the class cache is stale.
const RogueRoomUi := preload("res://scripts/rogue_room_ui.gd")
var profile := Profile.new()
var online_service: OnlineService
var p2p: TideP2P
var online_ui_busy := false
var economy_syncing := false
var session: TideSession
var sound: TideSound
var rogue_field: Control
var rogue_panel: Control
var rogue_signature := ""
var rogue_panel_context := ""
var rogue_panel_dismissed := false
var rogue_panel_open := false
var rogue_inventory = preload("res://scripts/rogue_inventory.gd").new()
var extraction_inventory = preload("res://scripts/extraction_inventory.gd").new()
var rogue_pending_cost := -1
var rogue_cards := 0
var rogue_weapon := -1
# R7: the seed/daily choice is armed on the setup page and consumed by `start_rogue()`.
# 0 means "not chosen" — session.gd:1386 reserves 0 for a random run, so an invalid
# seed must be refused by the UI instead of silently turning into a random one.
var rogue_seed_pending := 0
var rogue_daily_pending := false
var rogue_seed_field: LineEdit
var rogue_event_buttons: Array = []
var rogue_room_buttons: Array = []
var rogue_growth_buttons: Dictionary = {}
var field: Battlefield
var canvas: CanvasLayer
var root: Control
var page: Control
var overlay: Control
var toast: Label
var page_name := "title"
var hud: Dictionary = {}
var inventory_open := false
var selected := -1
var selected_slot := "backpack"
var rotated := false
# The grabbed item is a live overlay node, so it can follow the cursor every
# frame instead of only when the inventory happens to be rebuilt.
var drag_ghost: Control
var drag_ring: Control
var drag_caption: Label
var drag_last_point := Vector2(-1,-1)
var drag: Dictionary = {"active":false,"slot":"backpack","source":-1,"rot":false}
var _loot_index := -1
# Click bookkeeping: a press that never moves is a select, two of them in quick
# succession on the same item are an equip shortcut.
var press_point := Vector2(-1,-1)
var press_moved := false
var last_click_slot := ""
var last_click_index := -1
var last_click_ms := 0
# Drop sockets for the worn kit: "weapon", "gear0..2" and the equipped backpack
# "bag". A drag released over a matching socket equips the held item.
var equip_zones: Dictionary = {}
# The item bar: three sockets drawn under the worn kit and again along the bottom
# of the screen once the backpack is shut. The selection is the socket [F] acts
# on, and the panel strip is remembered separately so the bottom copy can be drawn
# while the panel is off screen.
var selected_item_slot := 0
var slot_zone_rects: Array = []
# Where the panel copy of the strip was last drawn, and what it was drawn for.
# The details column and the search-window copy of it put the sockets on the same
# pixels, so a click can only be routed to a socket while the layout the player is
# looking at is the one those rectangles came from.
var _slot_origin := Vector2(10000,10000)
var _slot_loot := false
var bottom_slot_width := 870.0
var bottom_slot_x := 570.0
var bottom_slot_y := 808.0
# A press that found nothing to loot hands the key to the item bar on release, and
# only a socket with no verb either gives it back to the medkit. This flag is what
# carries that decision from the press to the release.
var _fell_through_loot := false
var _pending_tips: Array = []
var _tip_running := false
# Right-column panels: releasing a drag over one of them is a miss, not a throw
# onto the ground.
var panel_rects: Array = []
var bag_cell := 46.0
var bag_gap := 6.0
var pocket_cell := 44.0
var pocket_gap := 6.0
var grids: Dictionary = {}
var bag_signature := ""
var nickname: LineEdit
var address: LineEdit
var extra_meds := 0
var toast_time := 0.0
var modal := false
var ready_local := false
var time_ui := 0.0
var title_font: Font
var ultimate: UltimateCinematic
var damage_overlay: ColorRect
var damage_tween: Tween
# The pre-raid camp is a separate 3D map with its own camera and storm. It is
# created once and switched on and off, so walking into it never rebuilds it.
var camp: Control
# Set for one frame when the hidden ending recruits somebody, so the report can
# announce the unlock that this run just earned.
var recruited := ""

func _ready() -> void:
	profile.load_profile()
	online_service=OnlineService.new()
	add_child(online_service)
	online_service.watch(profile)
	online_service.status.connect(notify)
	setup_inputs()
	sound=TideSound.new()
	add_child(sound)
	session=TideSession.new()
	session.name="Session"
	add_child(session)
	p2p=TideP2P.new()
	add_child(p2p)
	p2p.setup(online_service,session)
	p2p.status.connect(notify)
	field=Battlefield.new()
	field.session=session
	field.visible=false
	add_child(field)
	canvas=CanvasLayer.new()
	add_child(canvas)
	root=Control.new()
	root.size=Vector2(1440,900)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	root.theme=make_theme()
	rogue_field=preload("res://scripts/rogue_field.gd").new()
	rogue_field.session=session
	rogue_field.visible=false
	root.add_child(rogue_field)
	var serif := FontVariation.new()
	serif.base_font=load("res://assets/NotoSerifSC.ttf")
	serif.variation_embolden=0.55
	title_font=serif
	page=Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(page)
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	toast=label(root,"",Vector2(230,700),19,GOLD,Vector2(980,34))
	toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast.z_index=50
	session.map_changed.connect(func():
		close_bag()
		say("进入晨曦王城 · 击败失乡骑士，带走王庭珍藏；倒计时仍在继续。" if session.map_id=="city" else "返回月冠边境 · 前往撤离点保全战利品。"))
	session.started.connect(on_started)
	session.finished.connect(on_finished)
	session.changed.connect(on_lobby)
	session.message.connect(say)
	session.direct_connect_failed.connect(func():
		if page_name=="network":
			show_server_rooms()
			notify("直连失败：请与房主改用服务器房间号重新集结。"))
	session.effect.connect(on_effect)
	session.combat_event.connect(on_combat_audio)
	get_viewport().size_changed.connect(fit_ui)
	fit_ui()
	var damage_layer := CanvasLayer.new()
	damage_layer.layer=50
	add_child(damage_layer)
	damage_overlay=ColorRect.new()
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	damage_overlay.color=Color(0.75,0.035,0.09,0.25)
	var damage_material := ShaderMaterial.new()
	damage_material.shader=preload("res://resources/damage_vignette.gdshader")
	damage_overlay.material=damage_material
	damage_layer.add_child(damage_overlay)
	damage_overlay.hide()
	var cinema_layer := CanvasLayer.new()
	cinema_layer.layer=100
	add_child(cinema_layer)
	ultimate=UltimateCinematic.new()
	cinema_layer.add_child(ultimate)
	ultimate.burst.connect(func(): sound.burst_cinematic(ultimate.hero))
	ultimate.ended.connect(sound.end_cinematic)
	ultimate.ended.connect(func(_interrupted: bool):
		if not session.online and page_name=="game":
			session.release_ultimate(session.my_id())
	)
	ultimate.began.connect(sound.begin_cinematic)
	session.combat_event.connect(func(data: Dictionary):
		if data.kind=="ultimate-start" and int(data.get("id",-1))==session.my_id() and page_name=="game":
			ultimate.play(int(data.hero),session.online)
	)
	set_volume(float(profile.data.volume))
	set_voice_volume(float(profile.data.voice_volume))
	set_music_volume(float(profile.data.music_volume))
	if profile.data.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	show_account()
	# A deterministic screenshot/smoke path, separate from normal player saves.
	if "--preview-camp" in OS.get_cmdline_user_args():
		session.solo(config())
	# The start-of-game camp map: a standalone 3D stronghold walked before a raid.
	if "--preview-ground" in OS.get_cmdline_user_args():
		session.solo(config())
		go_camp()
	if "--preview-game" in OS.get_cmdline_user_args():
		session.solo(config())
		session.launch(false,1729)
	# Fills both containers so the dual-grid panel can be inspected without playing.
	if "--preview-bag" in OS.get_cmdline_user_args():
		session.solo(config())
		session.launch(false,1729)
		var preview: Dictionary=session.players.get(session.my_id(),{})
		if not preview.is_empty():
			var sizes := [9,12,15,16,18]
			var kinds := ["scrap","medicine","ammo","charm","relic","backpack"]
			for i in 18:
				if Catalog.container_free(preview.backpack)>sizes[i%5]:
					Catalog.add_item(preview.backpack,kinds[i%kinds.size()])
			for i in 6:
				Catalog.add_item(preview.pocket,kinds[i])
			preview.bags=[Catalog.make_bag("white"),Catalog.make_bag("blue"),Catalog.make_bag("gold"),Catalog.make_bag("red")]
			inventory_open=true
			show_inventory()
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/preview-"+page_name+".png")
		get_tree().quit()

func set_online_busy(value: bool) -> void:
	online_ui_busy=value
	for child in page.get_children():
		if child is Button: child.disabled=value

func show_account() -> void:
	if online_ui_busy or online_service.busy:
		notify("正在处理同步，请稍候。")
		return
	online_service.syncing=false
	new_page("account")
	background(0.7)
	header("守夜人通行证","ACCOUNT   /   注册、登录或离线游客")
	label(page,"账号",Vector2(430,255),20)
	var username := line_edit(page,"",Vector2(430,300),Vector2(580,54),"3–24 位英文字母、数字或下划线")
	username.max_length=24
	label(page,"密码",Vector2(430,377),20)
	var password := line_edit(page,"",Vector2(430,420),Vector2(580,54),"8–128 个字符")
	password.secret=true
	password.max_length=128
	button(page,"登录",Vector2(430,520),Vector2(280,56),func(): account_submit(username.text,password.text,false),true)
	button(page,"注册并登录",Vector2(730,520),Vector2(280,56),func(): account_submit(username.text,password.text,true))
	button(page,"游客登录 · 离线也能玩",Vector2(430,610),Vector2(580,56),func():
		online_service.token=""
		online_service.guest=true
		online_service.account_id=""
		online_service.account_name="游客"
		switch_profile("user://profile.json")
		show_title())
	label(page,"游客进度保存在本机；登录账号后可选择云端同步。",Vector2(430,706),17,MUTED,Vector2(670,36))
	label(page,"服务器："+online_service.api_url,Vector2(430,755),16,MUTED,Vector2(780,36))

func account_submit(username: String, password: String, create_account: bool) -> void:
	if online_ui_busy: return
	set_online_busy(true)
	notify("正在连接账号服务器…")
	var reply := await online_service.authenticate(username.strip_edges(),password,create_account)
	set_online_busy(false)
	if not reply.ok:
		notify(str(reply.get("error","登录失败。")))
		return
	var key := (online_service.api_url+"/"+online_service.account_id).sha256_text()
	switch_profile("user://account-"+key+".json")
	show_storage()

func switch_profile(path: String) -> void:
	profile.data=Profile.new().data.duplicate(true)
	profile.path=path
	profile.load_profile()
	online_service.dirty=false
	online_service.revision=0
	set_volume(float(profile.data.volume))
	set_voice_volume(float(profile.data.voice_volume))
	set_music_volume(float(profile.data.music_volume))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if profile.data.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func show_storage() -> void:
	if online_ui_busy or online_service.busy:
		notify("正在同步，请稍候。")
		return
	new_page("storage")
	background(0.75)
	header("账号与存档","PROFILE   /   "+online_service.account_name)
	label(page,"本地进度  ·  银币 %d  /  等级 %d  /  远征 %d" % [profile.data.coins,profile.level(),profile.data.runs],Vector2(230,255),25,GOLD,Vector2(1000,50))
	label(page,"当前："+("自动同步云端" if online_service.syncing else "仅本地保存"),Vector2(230,324),21)
	label(page,"每个账号独立保存；游客原有存档仍保留。",Vector2(230,379),18,MUTED)
	button(page,"使用本地 · 进入游戏",Vector2(230,451),Vector2(470,60),func(): online_service.syncing=false; show_title(),true)
	button(page,"查看云端 / 设置同步",Vector2(735,451),Vector2(470,60),inspect_cloud).disabled=online_service.guest
	button(page,"导入本机游客进度…",Vector2(230,544),Vector2(470,60),confirm_guest_import).disabled=online_service.guest
	button(page,"切换账号 / 游客",Vector2(735,544),Vector2(470,60),show_account)
	button(page,"继续游戏",Vector2(230,645),Vector2(975,60),show_title)
	label(page,"离线时仍保存本地。同步冲突会暂停上传，等待你选择保留哪份。",Vector2(230,742),18,MUTED,Vector2(1060,40))

func confirm_guest_import() -> void:
	online_service.syncing=false
	new_page("storage")
	background(0.75)
	header("导入游客进度","会替换当前账号的本地进度；原存档会保留为 .backup 文件")
	button(page,"确认导入游客存档",Vector2(430,360),Vector2(580,60),func():
		backup_profile()
		var guest_profile := Profile.new()
		guest_profile.load_profile()
		profile.apply_data(guest_profile.data)
		profile.save_profile()
		show_storage())
	button(page,"取消",Vector2(430,460),Vector2(580,60),show_storage)

func backup_profile() -> void:
	if FileAccess.file_exists(profile.path):
		DirAccess.copy_absolute(profile.path,profile.path+".backup")

func inspect_cloud() -> void:
	if online_ui_busy or online_service.busy: return
	online_service.syncing=false
	set_online_busy(true)
	var reply := await online_service.request("/v1/profile")
	set_online_busy(false)
	if not reply.ok:
		notify(str(reply.get("error","读取云端失败。")))
		return
	online_service.revision=int(reply.revision)
	new_page("storage")
	background(0.75)
	header("选择存档来源","选择后开启自动同步；替换本地前会保留 .backup 备份")
	label(page,"本地  ·  银币 %d  /  远征 %d" % [profile.data.coins,profile.data.runs],Vector2(230,266),25,GOLD)
	var cloud = reply.get("data")
	label(page,"云端  ·  银币 %d  /  远征 %d" % [int(cloud.get("coins",0)),int(cloud.get("runs",0))] if cloud is Dictionary else "云端暂无存档",Vector2(230,344),25,INK)
	button(page,"上传本地 · 替换云端并同步",Vector2(230,455),Vector2(975,60),func():
		if online_ui_busy: return
		set_online_busy(true)
		var result := await online_service.upload()
		set_online_busy(false)
		if result.ok:
			online_service.syncing=true
			show_title()
		else: notify(str(result.get("error","上传失败。"))))
	button(page,"使用云端 · 替换本地并同步",Vector2(230,555),Vector2(975,60),func():
		backup_profile()
		profile.apply_data(cloud)
		profile.save_profile()
		online_service.dirty=false
		online_service.syncing=true
		show_title()).disabled=not cloud is Dictionary
	button(page,"返回 · 继续使用本地",Vector2(230,655),Vector2(975,60),show_storage)

func show_server_rooms() -> void:
	new_page("server_rooms")
	background(0.75)
	header("服务器房间","ONLINE ROOMS   /   "+online_service.api_url)
	label(page,"由服务器运行远征；将六位房间号分享给好友即可加入。",Vector2(230,255),23,GOLD,Vector2(1030,48))
	label(page,"你的代号",Vector2(230,327),18,MUTED)
	nickname=line_edit(page,profile.data.name,Vector2(230,370),Vector2(975,55),"输入代号")
	nickname.max_length=16
	button(page,"创建服务器房间",Vector2(230,480),Vector2(470,60),func(): connect_server_room(""),true)
	var code := line_edit(page,"",Vector2(735,480),Vector2(470,60),"输入六位房间号")
	code.max_length=6
	button(page,"加入服务器房间",Vector2(735,575),Vector2(470,60),func(): connect_server_room(code.text.strip_edges().to_upper(),false),true)
	label(page,"游客也可联机；账号的本地 / 云端选择与联机方式独立。",Vector2(230,682),18,MUTED,Vector2(1000,40))
	button(page,"← 返回联机",Vector2(230,780),Vector2(470,55),show_p2p_rooms)

func show_p2p_rooms() -> void:
	new_page("p2p_rooms")
	background(0.75)
	header("P2P 联机","STUN · NAT 打洞   /   直连优先，专用服务器兜底")
	label(page,"创建六位房间号，好友加入后自动探测公网 UDP 地址。",Vector2(230,255),22,GOLD,Vector2(1030,48))
	label(page,"你的代号",Vector2(230,327),18,MUTED)
	nickname=line_edit(page,profile.data.name,Vector2(230,370),Vector2(975,55),"输入代号")
	nickname.max_length=16
	button(page,"创建 P2P 房间",Vector2(230,480),Vector2(470,60),func(): connect_p2p_room(""),true)
	var code := line_edit(page,"",Vector2(735,480),Vector2(470,60),"输入六位房间号")
	code.max_length=6
	button(page,"加入 P2P 房间",Vector2(735,575),Vector2(470,60),func(): connect_p2p_room(code.text.strip_edges().to_upper(),false),true)
	label(page,"打洞不支持所有 NAT；失败时全队自动切换到专用服务器。",Vector2(230,675),18,MUTED,Vector2(1000,40))
	button(page,"手动 IP 直连",Vector2(230,780),Vector2(320,55),show_network)
	button(page,"直接使用服务器",Vector2(575,780),Vector2(370,55),show_server_rooms)
	button(page,"← 返回",Vector2(970,780),Vector2(235,55),show_title)

func connect_p2p_room(code: String, create_room: bool = true) -> void:
	if online_ui_busy: return
	if not create_room and code.length()!=6:
		notify("请输入六位房间号。")
		return
	remember_name()
	set_online_busy(true)
	var reply: Dictionary=await p2p.create_room(config()) if create_room else await p2p.join_room(code,config())
	if page_name=="p2p_rooms": set_online_busy(false)
	else: online_ui_busy=false
	if not reply.ok:
		notify(str(reply.get("error","P2P 房间连接失败。")))
		if create_room: show_p2p_rooms()
	else:
		notify("P2P 房间 "+str(reply.code)+(" 已创建，等待好友加入。" if create_room else "：正在进行 STUN 探测…"))

func connect_server_room(code: String, create_room: bool = true) -> void:
	if online_ui_busy: return
	# An empty join field must never create a room accidentally.
	if not create_room and code.length()!=6:
		notify("请输入六位房间号。")
		return
	remember_name()
	set_online_busy(true)
	var auth := await online_service.ensure_session()
	if not auth.ok:
		set_online_busy(false)
		notify(str(auth.get("error","连接服务器失败。")))
		return
	var route := "/v1/rooms" if create_room else "/v1/rooms/"+code.uri_encode()+"/join"
	var reply := await online_service.request(route,HTTPClient.METHOD_POST)
	set_online_busy(false)
	if not reply.ok:
		notify(str(reply.get("error","创建 / 加入房间失败。")))
		return
	var err := session.join_server(reply,config())
	notify("正在连接房间 "+str(reply.code)+"…" if err==OK else "连接房间失败。")

func fit_ui() -> void:
	var view := get_viewport().get_visible_rect().size
	var scale_factor := minf(view.x/1440,view.y/900)
	root.scale=Vector2.ONE*scale_factor
	root.position=(view-Vector2(1440,900)*scale_factor)/2

func setup_inputs() -> void:
	var keys := {"left":KEY_A,"right":KEY_D,"up":KEY_W,"down":KEY_S,"interact":KEY_E,"loot":KEY_F,"search_drop":KEY_H,"reload":KEY_R,"skill":KEY_Q,"dash":KEY_SPACE,"jump":KEY_C,"sprint":KEY_SHIFT,"heal":KEY_F,"bag":KEY_TAB,"map":KEY_M,"pause":KEY_ESCAPE}
	# The smart-click modifier is a real action rather than a raw key read so the
	# gesture is bound, rebindable and visible to the input system like every
	# other control. Both control keys are bound; the action is only ever polled,
	# never matched against a pressed event, so it cannot swallow a keystroke.
	if not InputMap.has_action("smart_click"):
		InputMap.add_action("smart_click")
		for code in [KEY_CTRL,KEY_CTRL]:
			var binding := InputEventKey.new()
			binding.physical_keycode=code
			InputMap.action_add_event("smart_click",binding)
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode=keys[action]
		InputMap.action_add_event(action,event)
	InputMap.add_action("fire")
	var click := InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire",click)
	if not InputMap.has_action("weapon_art"):
		InputMap.add_action("weapon_art")
		var art_click := InputEventMouseButton.new()
		art_click.button_index=MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("weapon_art",art_click)

func make_theme() -> Theme:
	var theme := Theme.new()
	var face := FontVariation.new()
	face.base_font=load("res://assets/NotoSansSC.ttf")
	face.variation_opentype={"wght":450.0}
	face.variation_embolden=0.45
	theme.default_font=face
	theme.default_font_size=18
	theme.set_color("font_color","Label",INK)
	theme.set_color("font_color","Button",INK)
	theme.set_color("font_hover_color","Button",Color.WHITE)
	theme.set_color("font_disabled_color","Button",Color("5f6576"))
	theme.set_stylebox("normal","Button",style(Color("202332"),Color("46404b")))
	theme.set_stylebox("hover","Button",style(Color("52303e"),Color("b36272")))
	theme.set_stylebox("pressed","Button",style(Color("702f43"),GOLD))
	theme.set_stylebox("focus","Button",style(Color(0,0,0,0),GOLD))
	theme.set_stylebox("disabled","Button",style(Color("161c27"),Color("303642")))
	theme.set_stylebox("normal","LineEdit",style(Color("121724"),Color("4f4657")))
	theme.set_stylebox("focus","LineEdit",style(Color("1b2030"),GOLD))
	theme.set_color("font_color","LineEdit",INK)
	theme.set_color("font_placeholder_color","LineEdit",MUTED)
	return theme

func style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=color
	s.border_color=border
	s.border_width_top=1 if border.a>0 else 0
	s.border_width_bottom=1 if border.a>0 else 0
	s.set_corner_radius_all(10)
	s.content_margin_left=18
	s.content_margin_right=18
	s.content_margin_top=10
	s.content_margin_bottom=10
	return s

func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func rect(parent: Node, at: Vector2, size: Vector2, color: Color, border: Color = Color.TRANSPARENT) -> Panel:
	var panel := Panel.new()
	panel.position=at
	panel.size=size
	panel.add_theme_stylebox_override("panel",style(color,border))
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel

func label(parent: Node, text: String, at: Vector2, font_size: int = 18, color: Color = INK, size: Vector2 = Vector2(700,40)) -> Label:
	var l := Label.new()
	l.text=text
	l.clip_text=true
	l.position=at
	l.size=size
	l.add_theme_font_size_override("font_size",font_size)
	if font_size>=28:
		l.add_theme_font_override("font",title_font)
	l.add_theme_color_override("font_shadow_color",Color(0.015,0.01,0.018,0.85))
	l.add_theme_constant_override("shadow_offset_y",2)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func button(parent: Node, text: String, at: Vector2, size: Vector2, callback: Callable, primary: bool = false, font_size: int = 0) -> Button:
	var b := GothicButton.new()
	b.primary=primary
	b.accent=GOLD
	b.serif=title_font
	# The font size has to be in place before the size is assigned, otherwise the
	# cell inherits the minimum height of the default 18px font.
	if font_size>0:
		b.add_theme_font_size_override("font_size",font_size)
	b.text=text
	b.position=at
	b.size=size
	b.focus_mode=Control.FOCUS_NONE
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.pressed.connect(func(): sound.play("ui"); callback.call())
	parent.add_child(b)
	return b

func ornament(parent: Node, at: Vector2, dimensions: Vector2, mode: String = "line", color: Color = GOLD) -> UIOrnament:
	var art := UIOrnament.new()
	art.position=at
	art.size=dimensions
	art.mode=mode
	art.accent=color
	parent.add_child(art)
	return art

func fade(parent: Node, at: Vector2, dimensions: Vector2, color: Color, reverse: bool = false, vertical: bool = false) -> void:
	var gradient := Gradient.new()
	gradient.colors=PackedColorArray([Color(color,0),color] if reverse else [color,Color(color,0)])
	var texture := GradientTexture2D.new()
	texture.gradient=gradient
	texture.width=256
	texture.height=4
	if vertical:
		texture.width=4
		texture.height=256
		texture.fill_to=Vector2(0,1)
	var image := TextureRect.new()
	image.texture=texture
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.position=at
	image.size=dimensions
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)

func portrait(parent: Node, hero: int, at: Vector2, height: float, camp: bool = false) -> Sprite2D:
	var art := Sprite2D.new()
	var solo_path := "res://assets/portrait-%d.png" % hero
	if camp and ResourceLoader.exists(solo_path):
		art.texture=load(solo_path)
		art.position=at
		art.scale=Vector2.ONE*(height*1.04/art.texture.get_height())
		parent.add_child(art)
		return art
	var atlas := AtlasTexture.new()
	var path := "res://assets/camp-sentinels.png" if camp and ResourceLoader.exists("res://assets/camp-sentinels.png") else "res://assets/sentinels.png"
	atlas.atlas=load(path)
	var dims := atlas.atlas.get_size()
	atlas.region=Rect2(hero*dims.x/3,0,dims.x/3,dims.y)
	art.texture=atlas
	art.position=at
	art.scale=Vector2.ONE*(height/dims.y)
	parent.add_child(art)
	return art

func item_icon(parent: Node, kind: String, at: Vector2, dimensions: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture=TideUIArt.icon(kind)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position=at
	icon.size=dimensions
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func line_edit(parent: Node, value: String, at: Vector2, size: Vector2, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text=value
	edit.placeholder_text=placeholder
	edit.position=at
	edit.size=size
	edit.max_length=64
	parent.add_child(edit)
	return edit

func background(dim: float = 0.0) -> void:
	var art := TextureRect.new()
	art.texture=load("res://assets/keyart.png" if page_name=="title" else "res://assets/ui/sanctuary.png")
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size=Vector2(1440,900)
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	page.add_child(art)
	if dim>0:
		rect(page,Vector2.ZERO,Vector2(1440,900),Color(0.02,0.03,0.06,dim))

func new_page(name_value: String) -> void:
	clear_damage_feedback()
	if name_value!="game" and not session.online:
		session.cancel_ultimate(session.my_id())
	if ultimate and ultimate.active:
		ultimate.stop()
	# The camp map is switched off, never freed: it keeps its storm and meshes.
	if camp and not camp.is_queued_for_deletion():
		camp.set_active(false)
	clear(page)
	clear(overlay)
	modal=false
	inventory_open=false
	page_name=name_value
	sound.set_scene(name_value)
	toast_time=0
	field.visible=name_value=="game" and not session.roguelike.active(session)
	rogue_field.visible=name_value=="game" and session.roguelike.active(session)
	rogue_signature=""
	rogue_panel_context=""
	rogue_panel_dismissed=false
	rogue_panel_open=false
	rogue_panel=null
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE


## Builds the camp once, then only ever toggles it.
func ensure_camp() -> Control:
	if camp and not camp.is_queued_for_deletion():
		return camp
	camp=preload("res://scripts/camp_screen.gd").new()
	camp.name="GroundCamp"
	# The camp builds its map in _ready, so it has to be in the tree before it is
	# handed the session and the profile it reads the roster from.
	add_child(camp)
	camp.set_context(session,profile)
	camp.station_requested.connect(on_camp_station)
	camp.launch_requested.connect(camp_departure)
	camp.home_changed.connect(func():
		if not session.running and not session.players.is_empty(): session.configure(config())
		camp.update_static())
	camp.codex_requested.connect(show_help)
	camp.exit_requested.connect(func():
		if page_name=="ground":
			leave_to_title())
	camp.set_active(false)
	return camp


## Enters the standalone pre-raid camp map. A solo expedition is prepared first so
## the camp has a real loadout to edit, exactly as the old整备 panel required.
func go_camp() -> void:
	if page_name=="rogue_setup" and rogue_pending_cost>=0 and not session.running:
		rogue_pending_cost=-1
		ready_local=false
		session.configure(config())
	if not session.running and session.players.is_empty():
		session.solo(config())
	ensure_camp()
	camp.set_context(session,profile)
	camp.extra_meds=extra_meds
	if camp.has_method("refresh_roster"):
		camp.refresh_roster()
	if camp.has_method("update_static"):
		camp.update_static()
	new_page("ground")
	camp.set_active(true)
	sound.set_scene("camp")
	sound.music.set_scene("home")
	# The camp owns the bottom of the screen here, so the hint goes through its
	# own line instead of the shared toast band.
	if camp.has_method("say"):
		camp.say("营地 · 南侧闸门进入搜打撤，东侧紫色传送门进入魔境闯关。走近按 E 或 Space。")


## The camp raises these and this scene performs them, so the camp can never fork
## the expedition flow, the online protocol or the profile save.
func on_camp_station(id: String) -> void:
	match id:
		"warehouse":
			show_economy(false)
		"market":
			show_economy(true)
		"table":
			show_camp()
		"forge":
			show_camp_forge()
		"quarter":
			buy_camp_supply()
		"codex":
			show_help()
		"launch":
			if session.is_leader(): session.select_mode("expedition")
			if session.selected_mode!="expedition":
				notify("队长选择了闯关，请走到魔境传送门准备。")
				return
			rogue_pending_cost=-1
			on_camp_launch()
		"rogue":
			if session.is_leader(): session.select_mode("roguelike")
			if session.selected_mode!="roguelike":
				notify("请等待队长选择魔境闯关。")
				return
			show_rogue_setup()


func camp_departure() -> void:
	var station: Dictionary=camp.site.station_at(camp.site.hero_position())
	if station.get("action","") in ["launch","rogue"]:
		on_camp_station(str(station.action))
	else: camp.say("走到南侧搜打撤闸门或东侧魔境传送门，再出发。")

func on_camp_launch() -> void:
	if session.players.is_empty():
		session.solo(config())
	if not session.running:
		if not session.is_leader():
			ready_local=not bool(session.players.get(session.my_id(),{}).get("ready",false))
			session.configure(config())
			return
		session.configure(config())
		session.request_launch()
	else:
		say("远征已在进行中。")


func buy_camp_supply() -> void:
	var message := "急救针已满，本局最多携带 3 支。"
	if extra_meds<2:
		if profile.data.coins<25:
			message="银币不足，补给需要 25 银币。"
		else:
			extra_meds+=1
			profile.data.coins-=25
			ready_local=false
			profile.save_profile()
			session.configure(config())
			message="已补给急救针（-25 银币），本局共 %d 支。" % (1+extra_meds)
	if camp and page_name=="ground":
		camp.extra_meds=extra_meds
		camp.update_static()
		camp.say(message)
	else:
		say(message)

func show_economy(market: bool = false) -> void:
	if session.running: return
	modal_box("晨钟交易行" if market else "守夜人仓库",Vector2(1320,820))
	var screen := preload("res://scripts/economy_screen.gd").new()
	screen.name="EconomyScreen"
	screen.host=self
	screen.market=market
	overlay.add_child(screen)

func economy_changed() -> void:
	ready_local=false
	economy_syncing=true
	if not session.players.is_empty() and not session.running: session.configure(config())
	economy_syncing=false
	if camp: camp.update_static()


func show_camp_forge() -> void:
	if session.running: return
	var at := modal_box("锻炉 · 角色属性",Vector2(1080,760))
	var points := profile.attribute_points()
	var preview := session.make_player(session.my_id(),config())
	label(overlay,"Lv.%d  ·  可用属性点 %d  ·  银币 %d" % [profile.level(),points,profile.data.coins],at+Vector2(35,86),19,GOLD,Vector2(990,30))
	label(overlay,"初始 5 点；每升一级获得 1 点。全角色共享，40 / 70 后收益递减。",at+Vector2(35,125),15,MUTED,Vector2(1000,26))
	for i in WatcherAttributes.KEYS.size():
		var key: String=WatcherAttributes.KEYS[i]
		var rank := int(profile.data.attributes[key])
		var y := 175+i*74
		label(overlay,"%s  %d" % [WatcherAttributes.NAMES[i],rank],at+Vector2(38,y),22,INK,Vector2(270,29))
		label(overlay,WatcherAttributes.DESCRIPTIONS[i],at+Vector2(38,y+31),13,MUTED,Vector2(435,25))
		var raise_button := button(overlay,"+ 1",at+Vector2(485,y),Vector2(105,44),func():
			if profile.raise_attribute(key):
				ready_local=false
				session.configure(config())
				if camp: camp.update_static()
				show_camp_forge()
		)
		raise_button.name="Attribute_"+key
		raise_button.disabled=points<=0 or rank>=WatcherAttributes.CAP
	var weapon := int(preview.weapon)
	label(overlay,"出战能力",at+Vector2(640,173),23,GOLD,Vector2(385,32))
	var summary := "生命 %d    蓝量 %d\n受击减伤 %.1f%%    耐力抗性 %.1f%%\n寻宝力 %.0f    击杀掉率 ×%.2f\n%s    攻击 %.1f\n%s\n%s" % [preview.max_hp,preview.max_mana,session.stat_defense(preview)*100.0,session.stat_resistance(preview)*100.0,session.stat_discovery(preview),session.stat_discovery(preview)/100.0,Catalog.weapon_name(weapon),session.weapon_damage(preview),Catalog.scaling_text(weapon),WeaponArts.text(weapon)]
	var summary_label := label(overlay,summary,at+Vector2(640,219),14,INK,Vector2(395,188))
	summary_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_constant_override("line_spacing",5)
	label(overlay,"灵契天赋 · 保留原有成长",at+Vector2(640,417),20,GOLD,Vector2(390,30))
	for i in 3:
		var rank: int=profile.data.talents[i]
		var cost := 80+rank*65
		var y := 464+i*78
		label(overlay,"%s  %d / 5" % [Catalog.TALENTS[i],rank],at+Vector2(640,y),17,INK,Vector2(205,27))
		label(overlay,["生命 +12 / 级","伤害 +8% / 级","移速 +9 / 级"][i],at+Vector2(640,y+30),13,MUTED,Vector2(210,24))
		var upgrade := button(overlay,"满阶" if rank>=5 else "%d ◈" % cost,at+Vector2(891,y),Vector2(145,45),func():
			if profile.upgrade(i):
				ready_local=false
				session.configure(config())
				if camp: camp.update_static()
				show_camp_forge()
		)
		upgrade.disabled=rank>=5 or profile.data.coins<cost
	label(overlay,"加点永久生效；蓝量在停止施法 1.5 秒后自动恢复。",at+Vector2(38,710),14,MUTED,Vector2(990,26))

func show_title() -> void:
	new_page("title")
	background()
	fade(page,Vector2.ZERO,Vector2(850,900),Color(0.025,0.018,0.035,0.64))
	ornament(page,Vector2.ZERO,Vector2(1440,900),"title")
	var title_logo := TextureRect.new()
	title_logo.name="TitleLogo"
	title_logo.texture=load("res://assets/ui/title-crimson-tide-transparent-v1.png")
	title_logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	title_logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_logo.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	title_logo.position=Vector2(64,75)
	title_logo.size=Vector2(580,239)
	title_logo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	page.add_child(title_logo)
	var motto := label(page,"当血月升起\n我们依然守望人类的明天",Vector2(92,340),22,Color("c8b6b5"),Vector2(505,90))
	motto.add_theme_font_override("font",title_font)
	motto.add_theme_constant_override("line_spacing",12)
	ornament(page,Vector2(74,498),Vector2(40,287),"rail",Color("9b5c65"))
	var entries := ["开始游戏","创建 / 加入房间","设置","制作组","退出游戏"]
	var actions: Array[Callable]=[go_camp,show_p2p_rooms,show_settings,show_credits,func(): get_tree().quit()]
	for i in entries.size():
		var b := button(page,entries[i],Vector2(74,493+i*50),Vector2(445,50),actions[i]) as GothicButton
		b.menu=true
		b.selected=i==0
		b.heat=1 if i==0 else 0
		b.add_theme_font_size_override("font_size",32 if i==0 else 29)
		b.focus_mode=Control.FOCUS_ALL
		b.mouse_entered.connect(func(): select_title_entry(b))
		b.focus_entered.connect(func(): select_title_entry(b))
	button(page,"账号 / 存档",Vector2(990,817),Vector2(195,45),show_storage)
	button(page,"守夜手册",Vector2(1200,817),Vector2(155,45),show_help)
	label(page,"晨钟城档案   Lv.%02d    /    远征 %d" % [profile.level(),profile.data.runs],Vector2(95,822),13,Color("a599a0"))
	label(page,"© CRIMSON TIDE   ·   共赴黎明",Vector2(95,867),11,Color("7d717b"))

func select_title_entry(target: GothicButton) -> void:
	for node in page.get_children():
		if node is GothicButton and node.menu:
			node.selected=node==target

func config() -> Dictionary:
	var payload := profile.storage_payload()
	return {"mode":session.selected_mode,"rogue_rerolls":rogue_cards if rogue_pending_cost>=0 else 0,"rogue_weapon":rogue_weapon if rogue_pending_cost>=0 else -1,"name":profile.data.name,"hero":profile.data.hero,"gear":profile.data.gear,"talents":profile.data.talents.duplicate(),"attributes":profile.data.attributes.duplicate(),"home_meal":str(profile.data.home.prepared),"meds":1+extra_meds,"ready":ready_local or session.is_leader(),"pocket":payload.pocket,"bags":payload.bags,"bag_key":payload.bag_key}

func show_network() -> void:
	new_page("network")
	background(0.72)
	header("守夜人集结","COOPERATIVE EXPEDITION   /   ENET · UDP 24872")
	fade(page,Vector2(80,225),Vector2(590,485),Color(0.03,0.02,0.04,0.8))
	fade(page,Vector2(705,225),Vector2(655,485),Color(0.03,0.02,0.04,0.8))
	ornament(page,Vector2(658,245),Vector2(25,420),"rail")
	ornament(page,Vector2(95,637),Vector2(1230,15))
	label(page,"01  /  建立通讯",Vector2(111,251),26)
	label(page,"你的代号",Vector2(113,317),15,MUTED)
	nickname=line_edit(page,profile.data.name,Vector2(113,357),Vector2(520,55),"输入代号")
	nickname.max_length=16
	label(page,"成为房主，在营地等待最多 3 名好友。",Vector2(113,445),18,MUTED)
	button(page,"创建房间",Vector2(113,531),Vector2(520,60),func():
		remember_name()
		var err := session.host(config())
		if err!=OK: notify("创建失败：UDP 24872 可能已被占用。")
	,true)
	label(page,"02  /  接入信标",Vector2(741,251),26)
	label(page,"房主的 IP 地址",Vector2(742,317),15,MUTED)
	address=line_edit(page,"127.0.0.1",Vector2(742,357),Vector2(580,55),"例如 192.168.1.20")
	label(page,"优先直连：同一局域网或虚拟局域网。",Vector2(742,436),18,MUTED)
	label(page,"失败后进入服务器房间；公网直连需映射 UDP 24872。",Vector2(742,470),16,MUTED)
	button(page,"加入房间",Vector2(742,531),Vector2(580,60),func():
		remember_name()
		var host_address := address.text.strip_edges().trim_suffix(":24872")
		var err := session.join(host_address,config())
		notify("正在连接房主…" if err==OK else "地址无效或网络不可用。")
	,true)
	button(page,"服务器房间 · 无需端口映射",Vector2(430,671),Vector2(580,60),show_server_rooms,true)
	label(page,"IP 直连由房主结算；服务器房间由服务器运行。最多 4 人。",Vector2(85,755),17,MUTED)
	button(page,"← 返回",Vector2(80,811),Vector2(180,48),func(): session.disconnect_room(); show_p2p_rooms())

func remember_name() -> void:
	profile.data.name=nickname.text.strip_edges() if not nickname.text.strip_edges().is_empty() else "守夜人"
	profile.save_profile()

func header(title: String, subtitle: String) -> void:
	label(page,"血潮守望  /  CRIMSON TIDE",Vector2(80,35),13,GOLD)
	label(page,title,Vector2(78,89),43)
	label(page,subtitle,Vector2(82,161),13,MUTED)
	ornament(page,Vector2(80,203),Vector2(1280,12))

func on_lobby() -> void:
	if economy_syncing: return
	if session.players.is_empty():
		if page_name in ["ground","camp","game","results"]:
			show_title()
		return
	if not session.running:
		if page_name=="rogue_setup": return
		if modal and overlay.has_node("EconomyScreen"): return
		# The walking camp map has its own start button; do not yank the player out
		# of it when a lobby refresh arrives.
		if page_name=="ground":
			if camp: camp.refresh_roster()
			return
		if page_name=="results":
			extra_meds=0
			ready_local=false
		go_camp()

func show_camp() -> void:
	new_page("camp")
	background(0.08)
	fade(page,Vector2(480,0),Vector2(960,900),Color(0.025,0.02,0.037,0.97),true)
	fade(page,Vector2.ZERO,Vector2(470,900),Color(0.025,0.02,0.037,0.6))
	ornament(page,Vector2.ZERO,Vector2(1440,900),"title")
	label(page,"晨钟城",Vector2(66,37),37,INK,Vector2(280,60))
	label(page,"T H E   L A S T   S A N C T U A R Y",Vector2(70,106),11,GOLD)
	label(page,"整 备  /  守 夜 人 档 案",Vector2(581,64),16,GOLD)
	label(page,"Lv.%02d    ◈ %d" % [profile.level(),profile.data.coins],Vector2(1110,56),22,GOLD,Vector2(265,42))
	ornament(page,Vector2(571,121),Vector2(790,14))
	var hero: Dictionary=Catalog.HEROES[profile.data.hero]
	ornament(page,Vector2(30,216),Vector2(505,505),"seal",hero.color)
	var character := portrait(page,profile.data.hero,Vector2(294,435),625,true)
	var breath := character.create_tween().set_loops()
	breath.tween_property(character,"position:y",430.0,2.4).set_trans(Tween.TRANS_SINE)
	breath.tween_property(character,"position:y",435.0,2.4).set_trans(Tween.TRANS_SINE)
	fade(page,Vector2(46,575),Vector2(500,170),Color(0.035,0.019,0.04,0.94),true,true)
	label(page,hero.name,Vector2(72,605),52,INK,Vector2(180,80))
	label(page,hero.title,Vector2(226,642),19,hero.color)
	label(page,hero.desc,Vector2(74,691),15,Color("c1b5bb"),Vector2(453,50)).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	# The roster only grows once the hidden ending has been reached: a locked
	# recruit is simply not drawn, so the base three keep their original layout.
	var roster := profile.roster_size()
	for i in roster:
		var h: Dictionary=Catalog.HEROES[i]
		var b := button(page,h.name if i<Catalog.BASE_ROSTER else "%s ✦" % h.name,
			Vector2(66+(i%3)*160,750+int(i/3)*58),Vector2(147,50),func():
			if profile.data.hero!=i:
				profile.data.hero=i
				ready_local=false
				profile.save_profile()
				session.configure(config())
			sound.dialogue.play_selection(i)
		) as GothicButton
		b.selected=profile.data.hero==i
		b.accent=h.color
		b.add_theme_font_size_override("font_size",22)
	label(page,"出战装备",Vector2(583,160),27,INK,Vector2(250,45))
	label(page,"LOADOUT",Vector2(583,207),10,GOLD)
	for i in 3:
		var gear: Dictionary=Catalog.GEAR[i]
		var x := 582+i*126
		var b := button(page,"",Vector2(x,247),Vector2(113,104),func():
			profile.data.gear=i
			profile.save_profile()
			ready_local=false
			session.configure(config())
		) as GothicButton
		b.selected=profile.data.gear==i
		var icon: String = Catalog.GEAR_ICONS[i]
		item_icon(page,icon,Vector2(x+31,251),Vector2(52,52))
		label(page,gear.name,Vector2(x,310),15,INK if profile.data.gear==i else MUTED,Vector2(113,31)).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label(page,Catalog.GEAR[profile.data.gear].desc,Vector2(584,356),15,GOLD)
	label(page,"开局只有角色的临时武器；局内捡到的武器装备后才能换用",Vector2(584,380),12,MUTED,Vector2(384,20))
	label(page,"背包本身就是一件装备：双击或 Ctrl+左键换装，紫色及以上占 2×2",Vector2(584,398),12,MUTED,Vector2(384,20))
	ornament(page,Vector2(578,406),Vector2(384,12))
	label(page,"灵契天赋",Vector2(583,431),27,INK,Vector2(250,45))
	button(page,"角色属性 · %d 点" % profile.attribute_points(),Vector2(784,431),Vector2(184,43),show_camp_forge)
	for i in 3:
		var level: int=profile.data.talents[i]
		var y := 495+i*78
		item_icon(page,["heart","rifle","boots"][i],Vector2(585,y+5),Vector2(34,34))
		label(page,Catalog.TALENTS[i],Vector2(636,y-4),18,INK,Vector2(180,34))
		label(page,["生命 +12 / 级","伤害 +8% / 级","移速 +9 / 级"][i],Vector2(636,y+29),12,MUTED)
		for rank in 5:
			var pip := ornament(page,Vector2(785+rank*13,y+11),Vector2(11,8),"line",GOLD if rank<level else Color("4c3d46"))
			pip.modulate.a=1.0 if rank<level else 0.7
		var upgrade := button(page,"满阶" if level>=5 else "+ %d" % (80+level*65),Vector2(858,y-3),Vector2(108,48),func():
			if profile.upgrade(i):
				ready_local=false
				session.configure(config())
			else: say("银币不足，带回战利品即可升级。")
		)
		upgrade.disabled=level>=5
	ornament(page,Vector2(1001,150),Vector2(25,585),"rail",Color("66505a"))
	label(page,"远征小队",Vector2(1058,160),27,INK,Vector2(270,45))
	label(page,"WATCHERS  /  %02d" % session.players.size(),Vector2(1061,209),11,GOLD)
	var row := 0
	for p in session.players.values():
		var y := 259+row*69
		portrait(page,p.hero,Vector2(1080,y+22),61)
		label(page,p.name,Vector2(1115,y-3),18,INK,Vector2(148,32))
		label(page,("房主" if p.id==session.leader_id else "队友")+" · "+Catalog.HEROES[p.hero].name,Vector2(1115,y+26),12,MUTED)
		label(page,"就绪" if p.ready else "整备",Vector2(1300,y+7),13,Color("98bcae") if p.ready else GOLD,Vector2(60,30))
		row+=1
	for i in range(row,4):
		label(page,"◇",Vector2(1066,260+i*69),22,Color("68505d"),Vector2(36,40))
		label(page,"等待守夜人" if session.online else "空席",Vector2(1116,263+i*69),15,Color("746671"))
	if session.online:
		button(page,"房间号 "+session.room_code+" · 复制" if not session.room_code.is_empty() else "邀请好友 · 复制地址",Vector2(1050,555),Vector2(310,42),copy_invite)
	else:
		label(page,"单人远征  /  无需联网",Vector2(1061,561),13,MUTED)
	ornament(page,Vector2(1047,611),Vector2(314,10))
	item_icon(page,"medicine",Vector2(1056,648),Vector2(38,45))
	label(page,"急救针  ×%d" % (1+extra_meds),Vector2(1113,645),17,INK,Vector2(180,37))
	label(page,"每局免费补给一支",Vector2(1113,679),12,MUTED)
	var supply := button(page,"+ 25 ◈",Vector2(1256,646),Vector2(112,48),func():
		buy_camp_supply()
	)
	supply.disabled=extra_meds>=2
	label(page,"每天 5 分钟 · 第 3 分钟缩圈",Vector2(1024,745),18,INK,Vector2(349,43))
	ornament(page,Vector2(62,814),Vector2(1314,10))
	button(page,"← 返回营地",Vector2(60,839),Vector2(183,43),go_camp)
	button(page,"仓库",Vector2(255,839),Vector2(140,43),func(): show_economy(false))
	button(page,"交易行",Vector2(405,839),Vector2(140,43),func(): show_economy(true))
	button(page,"守夜手册",Vector2(555,839),Vector2(165,43),show_help)
	label(page,"活着带回来的，才属于你。",Vector2(738,849),16,Color("a797a3"),Vector2(280,35))
	if session.is_leader():
		button(page,"返回营地 · 选择入口",Vector2(1032,831),Vector2(340,61),go_camp,true).add_theme_font_size_override("font_size",27)
	else:
		button(page,"取消准备" if session.players.get(session.my_id(),{}).get("ready",false) else "准备出发",Vector2(1032,831),Vector2(340,61),func(): ready_local=not ready_local; session.configure(config()),true)

func copy_invite() -> void:
	if not session.room_code.is_empty():
		DisplayServer.clipboard_set(session.room_code)
		notify("已复制房间号："+session.room_code)
		return
	var ip := "127.0.0.1"
	for candidate in IP.get_local_addresses():
		if candidate.begins_with("192.168.") or candidate.begins_with("10.") or candidate.begins_with("172."):
			ip=candidate
			break
	DisplayServer.clipboard_set(ip+":24872")
	notify("已复制 "+ip+":24872  ·  发给同一网络的好友")

func on_started() -> void:
	if session.roguelike.active(session) and rogue_pending_cost>=0:
		profile.data.coins-=rogue_pending_cost
		profile.save_profile()
	rogue_pending_cost=-1
	toast.position.y=700
	rogue_field.camera_x=0.0
	rogue_field.camera_y=0.0
	rogue_field.area_signature=""
	var home := preload("res://scripts/homestead.gd").new(profile)
	home.consume_started(str(session.players.get(session.my_id(),{}).get("home_meal","")))
	extra_meds=0
	ready_local=false
	# The camp map hides itself as soon as the raid screen takes over, and the
	# raid's own presentation camera becomes current again.
	if camp:
		camp.set_active(false)
	new_page("game")
	if field and field.world_3d and field.world_3d.view_camera:
		field.world_3d.view_camera.make_current()
	field.camera=Ruins.SPAWN
	field.explored.clear()
	field.map_open=false
	hud.clear()
	fade(page,Vector2(0,0),Vector2(365,245),Color(0.025,0.018,0.035,0.7))
	label(page,"血潮守望",Vector2(29,17),24).add_theme_font_override("font",title_font)
	hud.time=label(page,"",Vector2(30,54),15,GOLD)
	var meal_id: String = preload("res://scripts/homestead.gd").meal_id(session.players[session.my_id()].get("home_meal",""))
	if not meal_id.is_empty():
		var food: Dictionary = preload("res://scripts/homestead.gd").MEALS[meal_id]
		var badge := TextureRect.new()
		badge.texture = preload("res://scripts/home_art.gd").icon(meal_id)
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.position = Vector2(30,92)
		badge.size = Vector2(26,26)
		page.add_child(badge)
		var meal_label := label(page,str(food.name)+" · "+str(food.desc).replace("本次远征",""),Vector2(62,93),13,Color("b9d7a6"),Vector2(310,25))
		meal_label.name = "HomeMealBuff"
		meal_label.tooltip_text = str(food.desc)

	hud.mission=label(page,"",Vector2(550,18),20,INK)
	hud.area=label(page,"",Vector2(550,49),14,GOLD,Vector2(610,25))
	ornament(page,Vector2(540,83),Vector2(300,10))
	hud.seed=label(page,"遗迹 #"+str(session.seed_value),Vector2(1175,26),14,MUTED)
	hud.team=label(page,"",Vector2(31,125),15,INK,Vector2(320,180))
	hud.team.add_theme_constant_override("line_spacing",10)
	button(page,"行囊 · 构筑  TAB" if session.roguelike.active(session) else "背包  TAB",Vector2(1175,310),Vector2(234,39),toggle_bag)
	if not session.roguelike.active(session): button(page,"地图  M",Vector2(1175,360),Vector2(111,38),toggle_map)
	button(page,"菜单",Vector2(1298,360),Vector2(111,38),pause_menu)
	hud.notice=label(page,"",Vector2(375,624),22,GOLD,Vector2(690,40))
	hud.notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hud.prompt=label(page,"",Vector2(335,696),18,INK,Vector2(770,48))
	hud.prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	fade(page,Vector2(15,776),Vector2(555,112),Color(0.03,0.018,0.033,0.94))
	ornament(page,Vector2(20,775),Vector2(475,110),"frame")
	portrait(page,session.players[session.my_id()].hero,Vector2(80,824),102)
	hud.health=label(page,"",Vector2(132,794),17,Color("efc3c4"),Vector2(230,32))
	hud.mana=label(page,"",Vector2(132,835),13,Color("83b9ef"),Vector2(240,23))
	rect(page,Vector2(134,860),Vector2(220,5),Color("203149"))
	hud.mpbar=rect(page,Vector2(134,860),Vector2(220,5),Color("548fd0"))
	hud.sanity=label(page,"",Vector2(132,868),11,Color("b5b8d4"),Vector2(280,19))
	rect(page,Vector2(134,832),Vector2(220,5),Color("3c2333"))
	hud.hpbar=rect(page,Vector2(134,832),Vector2(220,5),RED)
	hud.weapon_icon=item_icon(page,"rifle",Vector2(404,791),Vector2(39,39))
	hud.ammo=label(page,"",Vector2(454,791),18,INK,Vector2(267,35))
	hud.scent=label(page,"",Vector2(412,842),13,GOLD,Vector2(260,33))
	if not session.roguelike.active(session):
		ornament(page,Vector2(722,717),Vector2(48,65),"seal",Color("b8a0c8"))
		item_icon(page,"skill",Vector2(728,732),Vector2(40,40))
	hud.skill=label(page,"",Vector2(792,714),14,Color("d4c0de"),Vector2(350,26))
	hud.art=label(page,"",Vector2(792,748),14,Color("83b9ef"),Vector2(350,26))
	hud.items=label(page,"",Vector2(412,870),11,MUTED,Vector2(310,20))
	label(page,"WASD 走路 · SHIFT 奔跑 · 鼠标攻击",Vector2(1170,754),11,MUTED,Vector2(241,20))
	label(page,"右键 战技 · SPACE 闪避 · C 跃起",Vector2(1170,776),11,MUTED,Vector2(241,20))
	label(page,"F 血瓶 · 倒地长按F魂灯" if session.roguelike.active(session) else "F 拾取/搜索 · 1/2/3 道具",Vector2(1170,798),11,MUTED,Vector2(241,20))
	label(page,"E 选择路线 · TAB 行囊构筑" if session.roguelike.active(session) else "E 长按 救援/城门/撤离/封印 · TAB 背包 · M 地图",Vector2(1170,820),11,MUTED,Vector2(241,20))
	hud.loadout=label(page,"",Vector2(1170,846),11,GOLD,Vector2(241,18))
	hud.loadout2=label(page,"",Vector2(1170,864),11,MUTED,Vector2(241,18))
	hud.raid_continue=button(page,"留下挑战 [Y]",Vector2(400,351),Vector2(205,42),func(): session.action("raid_choice",{"choice":"continue"}))
	hud.raid_extract=button(page,"安全撤离 [N]",Vector2(618,351),Vector2(205,42),func(): session.action("raid_choice",{"choice":"extract"}))
	hud.raid_wait=button(page,"取消就绪 [U]",Vector2(836,351),Vector2(205,42),func(): session.action("raid_choice",{"choice":"wait"}))
	for key in ["raid_continue","raid_extract","raid_wait"]: hud[key].hide()
	if session.roguelike.active(session):
		hud.skill.position=Vector2(770,800)
		hud.art.position=Vector2(770,837)
		hud.notice.position=Vector2(375,113)
		hud.prompt.position=Vector2(335,739)
		toast.position.y=157
		# R7: the right-hand column under the seed readout carries the run-wide
		# information the older HUD had nowhere to put — the floor's 深渊变数, the
		# curses this Watcher is carrying, ash income and the node-graph position.
		var variant := label(page,"",Vector2(1175,58),13,GOLD,Vector2(252,58))
		variant.name="RogueVariant"
		variant.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		hud.rogue_variant=variant
		var curses := label(page,"",Vector2(1175,124),12,Color("c8a0b4"),Vector2(252,88))
		curses.name="RogueCurses"
		curses.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		hud.rogue_curses=curses
		var ash := label(page,"",Vector2(1175,218),12,MUTED,Vector2(252,22))
		ash.name="RogueAsh"
		hud.rogue_ash=ash
		var route := label(page,"",Vector2(1175,244),12,GOLD,Vector2(252,40))
		route.name="RogueNode"
		route.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		hud.rogue_node=route
		var run_seed := label(page,"",Vector2(1175,286),11,MUTED,Vector2(252,20))
		run_seed.name="RogueSeedLine"
		hud.rogue_seed=run_seed
		notify("魔境闯关：E开箱 / 拾取 · Tab构筑 · F血瓶 · C跃起")
		return
	notify("第一天无法撤离。M 查看黎明印记；血潮收缩完成后迎战 Boss。")
	# The two things a first raid has to know: the backpack is a piece of equipment
	# like any other, and three sockets at the bottom of the screen are one key away.
	popup_tip("屏幕下方新增三格道具栏：按 [1][2][3] 直接使用对应格的道具或换装。捡到背包后双击即可换装。")
func _process(dt: float) -> void:
	if camp:
		camp.input_blocked=modal
	toast_time-=dt
	toast.visible=toast_time>0 and not inventory_open
	if session.roguelike.active(session) and not session.players.get(session.my_id(),{}).get("rogue_selection",{}).is_empty(): toast.hide()
	if page_name!="game" or not session.running:
		return
	sound.update_world(session.players.get(session.my_id(),{"p":field.camera}).p if session.roguelike.active(session) else field.camera,session.players,dt)
	var blocked: bool=inventory_open or modal or field.map_open or (session.roguelike.active(session) and not session.players.get(session.my_id(),{}).get("rogue_selection",{}).is_empty())
	session.local_input={"move":Vector2.ZERO if blocked else Input.get_vector("left","right","up","down"),"aim":rogue_field.aim() if session.roguelike.active(session) else field.aim(),"fire":not blocked and Input.is_action_pressed("fire") and not mouse_over_button(),"interact":not blocked and Input.is_action_pressed("interact"),"sprint":not blocked and Input.is_action_pressed("sprint"),"flask_held":not inventory_open and Input.is_action_pressed("heal")}
	if session.roguelike.active(session): session.local_input["aim_point"]=mouse_point()+rogue_field.camera_offset()
	time_ui+=dt
	if time_ui>0.1:
		time_ui=0
		update_hud()
		keep_loot_window()
		if inventory_open:
			var p: Dictionary=session.players.get(session.my_id(),{})
			var container: Dictionary=session.container_at(_loot_index) if _loot_index>=0 else {}
			if container.is_empty() and _loot_index>=0:
				_loot_index=-1
			var signature := rogue_inventory.signature(p,session) if session.roguelike.active(session) else str(p.get("backpack",{}))+str(p.get("pocket",{}))+str(p.get("equipped",{}))+str(container)
			if session.roguelike.active(session): rogue_inventory.update_live(p)
			if _loot_index>=0:
				signature+=str(int(float(p.get("search",0.0))*10.0))
			if signature!=bag_signature:
				show_inventory()
	if inventory_open and not session.roguelike.active(session): extraction_inventory.update_hover()
	# The grabbed item follows the cursor on every frame, not only on a rebuild.
	sync_drag()

func mouse_over_button() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered is Button

# Dragging lives on the overlay: item bodies ignore the mouse, so the pointer is
# hit-tested against whichever grid is underneath it.
func _input(event: InputEvent) -> void:
	if session.roguelike.active(session): return
	if not event is InputEventMouseButton:
		return
	if not inventory_open or modal or page_name!="game":
		return
	if event.button_index==MOUSE_BUTTON_RIGHT:
		# Right click is the mouse shortcut for the same R rotation.
		if event.pressed: rotate_selected()
		get_viewport().set_input_as_handled()
		return
	if event.button_index!=MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		var point := mouse_point()
		# A click on the item bar selects the socket [E] will act on. It is checked
		# before the grids because the strip is not a grid: a socket holds exactly
		# one item, however many cells that item would need in a backpack. The hit
		# test only counts while the strip still sits where the last rebuild drew
		# it: the search window shifts the details column down the screen, and a
		# stale rectangle would swallow a click meant for a grid.
		var bar_slot := slot_at(point) if not slot_bar_stale() else -1
		if bar_slot>=0:
			select_item_slot(bar_slot)
			get_viewport().set_input_as_handled()
			return
		# Ctrl+left is checked before anything else: the same click means "do the
		# obvious thing with this" instead of starting a drag, both on carried loot
		# and on something already worn.
		if ctrl_held():
			var worn := worn_zone_at(point)
			if not worn.is_empty():
				ctrl_click_worn(worn)
				get_viewport().set_input_as_handled()
				return
		var hit := grid_at(point)
		if hit.is_empty():
			return
		var slot := str(hit.slot)
		var index: int=index_at(slot,Vector2i(hit.cell))
		if index<0:
			return
		if ctrl_held():
			if slot=="loot":
				auto_store_loot(index)
				get_viewport().set_input_as_handled()
				return
			if ctrl_click_item(slot,index):
				get_viewport().set_input_as_handled()
				return
		# Two quick taps on the same item wear it: weapons and gear go to their
		# slot, a loose backpack becomes the equipped pack.
		var now := Time.get_ticks_msec()
		var quick := slot==last_click_slot and index==last_click_index and now-last_click_ms<450
		last_click_ms=0
		# The same gesture on something already worn takes it off, with the tidy
		# rule the Ctrl+left take-off uses.
		if quick:
			var worn_zone := worn_zone_at(point)
			if not worn_zone.is_empty():
				ctrl_click_worn(worn_zone)
				get_viewport().set_input_as_handled()
				return
		if quick and slot in ["backpack","pocket"]:
			if double_click_equip(slot,index):
				get_viewport().set_input_as_handled()
				return
		# The same gesture on a loot card is the one-click haul: the item is
		# worked into the backpack, or the pocket when the bag cannot take it.
		if quick and slot=="loot":
			auto_store_loot(index)
			get_viewport().set_input_as_handled()
			return
		last_click_slot=slot
		last_click_index=index
		last_click_ms=now
		var rot := false
		if slot=="loot":
			var shown: Array=session.visible_items(session.container_at(_loot_index))
			if index<shown.size():
				rot=bool(shown[index].get("rot",false))
		else:
			rot=bool(session.players[session.my_id()][slot].items[index].get("rot",false))
		press_point=point
		press_moved=false
		start_drag(slot,index,rot)
		get_viewport().set_input_as_handled()
	elif drag.active:
		# A press that never travelled is a click, not a drag: it selects the
		# item so the details panel can offer its use / equip buttons.
		if not press_moved and mouse_point().distance_to(press_point)<8.0:
			var slot := str(drag.slot)
			var index: int=int(drag.source)
			stop_drag()
			pick_item(slot,index)
		else:
			release_drag()
		get_viewport().set_input_as_handled()

# Which item covers a cell. Loot cards keep their real footprint in the search
# window, so a 2x2 relic is grabbed by any of the four cells it spans.
func index_at(slot: String, cell: Vector2i) -> int:
	if slot=="loot":
		var container: Dictionary=session.container_at(_loot_index)
		if container.is_empty():
			return -1
		var shown: Array=session.visible_items(container)
		for i in shown.size():
			var dims := Catalog.item_size(shown[i])
			if Rect2i(Vector2i(int(shown[i].x),int(shown[i].y)),dims).has_point(cell):
				return i
		return -1
	var list: Array=session.players[session.my_id()][slot].items
	for i in list.size():
		var at := Vector2i(int(list[i].x),int(list[i].y))
		var size := Catalog.item_size(list[i])
		if Rect2i(at,size).has_point(cell):
			return i
	return -1

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if modal:
			close_modal()
		elif field.map_open:
			toggle_map()
		elif inventory_open:
			close_bag()
		elif page_name=="game" and rogue_panel_open:
			close_rogue_panel()
		elif page_name=="game":
			pause_menu()
		get_viewport().set_input_as_handled()
		return
	if page_name!="game" or modal:
		return
	if session.roguelike.active(session) and not session.players.get(session.my_id(),{}).get("rogue_selection",{}).is_empty():
		if event.is_action_pressed("bag"): toggle_bag()
		return
	if event is InputEventKey and event.pressed and not event.echo and session.raid.get("phase","") in ["choice","complete"]:
		var code: int=event.physical_keycode if event.physical_keycode else event.keycode
		if code in [KEY_Y,KEY_N,KEY_U]:
			session.action("raid_choice",{"choice":"continue" if code==KEY_Y else ("extract" if code==KEY_N else "wait")})
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("bag") and not field.map_open:
		toggle_bag()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("map") and not inventory_open:
		toggle_map()
	if field.map_open:
		return
	if session.roguelike.active(session):
		if event.is_action_pressed("loot") and not event.is_echo():
			heal_action()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_released("loot") or event.is_action_pressed("search_drop"):
			return
		if event is InputEventKey and event.pressed and event.physical_keycode in [KEY_1,KEY_2,KEY_3]: return
		if inventory_open: return
	if event.is_action_pressed("search_drop") and not event.is_echo():
		search_drops_action()
		get_viewport().set_input_as_handled()
		return
	# --- 1 / 2 / 3 directly use the corresponding item bar socket -----------
	# The map screen owns the same keys while it is open, so the map is asked
	# first: with it up, 1-4 still switch the filter it has always switched.
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int=event.physical_keycode if event.physical_keycode else event.keycode
		if code in [KEY_1,KEY_2,KEY_3]:
			select_item_slot(code-KEY_1)
			apply_item_slot(code-KEY_1)
			get_viewport().set_input_as_handled()
			return
	# --- F: the item bar, looting and the fallback heal ---------------------
	# F does the most immediate thing the moment it goes down: a downed Watcher
	# reaches for the medkit, anyone else grabs or searches what is in reach. A
	# press that found nothing to loot calls the item bar instead, and if the
	# socket has no verb either — an empty socket, or a relic that is treasure and
	# nothing else — the release falls back to the medkit, which is what keeps a
	# self-heal one key away without giving it a key of its own.
	if event.is_action_pressed("loot") and not event.is_echo():
		var me: Dictionary=session.players.get(session.my_id(),{})
		var downed := not me.is_empty() and str(me.get("status",""))=="down"
		_fell_through_loot=false
		if downed:
			heal_action()
		elif inventory_open:
			quick_inventory_at(mouse_point())
		elif not loot_action():
			_fell_through_loot=true
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("loot") and not event.is_echo():
		var reached_bar := false
		if _fell_through_loot:
			reached_bar=apply_item_slot(selected_item_slot)
		if _fell_through_loot and not reached_bar:
			heal_action()
		_fell_through_loot=false
		get_viewport().set_input_as_handled()
		return
	# --- E: the world's key, held down --------------------------------------
	# Everything E does takes seconds and is worth interrupting, so it is never
	# acted on at the moment the key goes down: the session counts the hold and the
	# ring under the player shows the count. The key is left unhandled here so the
	# world interaction keeps receiving it.
	if event.is_action_pressed("interact") or event.is_action_released("interact"):
		return
	if inventory_open:
		if event.is_action_pressed("reload") and not event.is_echo():
			rotate_selected()
		return
	if field.map_open:
		return
	if session.roguelike.active(session) and event.is_action_pressed("fire") and not event.is_echo(): session.action("attack")
	for action in ["reload","skill","dash","weapon_art","jump"]:
		if event.is_action_pressed(action) and not event.is_echo():
			session.action(action)

# F: quick-grab loose ground loot, otherwise open the search window on whatever
# container is in reach. Grabbing never closes the backpack you already have open.
# Returns false when there was nothing to loot, which is what lets the same key
# fall through to the medkit.
func loot_action() -> bool:
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty() or p.status not in ["active","down"]:
		return false
	for drop in session.world_drops:
		if session.container_units(drop)==1 and p.p.distance_to(drop.p)<70:
			if session.authority():
				if session.pick_up_ground(p):
					if inventory_open:
						show_inventory()
				else:
					notify("背包与次元口袋空间不足，无法拾取。")
			else:
				session.action("pickup")
			return true
	var index: int=session.search_target(p)
	if index<0:
		if session.search_dropped_target(p)>=0:
			notify("按 [H] 搜索附近的多件掉落包。")
			return true
		return false
	return open_search(index,p)

func search_drops_action() -> bool:
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty() or p.status not in ["active","down"]:
		return false
	var index := session.search_dropped_target(p)
	if index<0:
		return false
	return open_search(index,p)

func open_search(index: int,p: Dictionary) -> bool:
	var container: Dictionary=session.container_at(index)
	if container.is_empty():
		return false
	# A container the window already points at and that is fully revealed has
	# nothing left to show, so F is free to do the other job.
	if index==_loot_index and session.container_searched(container):
		return false
	session.action("search",{"index":index})
	if index!=_loot_index or not inventory_open:
		sound.play("search-open",0,p.p)
	_loot_index=index
	inventory_open=true
	selected=-1
	show_inventory()
	return true

func heal_action() -> void:
	session.action("heal")
	if inventory_open:
		show_inventory()

# R (or the right mouse button) turns the item in hand, and the item selected in
# the grid when nothing is held. Position is preserved whenever the turned
# footprint still fits, otherwise the session slides it to the nearest free cell.
func rotate_selected() -> void:
	if drag.active:
		# "rot" is the orientation the item will end up in, not a delta: releasing
		# the drag writes exactly this back, so a turned item stays turned.
		drag.rot=not bool(drag.rot)
		show_inventory()
		return
	if selected<0 or selected_slot not in ["backpack","pocket"]:
		return
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return
	var list: Array=Catalog.container_items(p[selected_slot])
	if selected>=list.size():
		return
	rotated=not bool(list[selected].get("rot",false))
	session.action("bag_rotate",{"slot":selected_slot,"index":selected})
	# The authoritative item decides the shown orientation: a refused rotation
	# must not leave the panel claiming the item turned.
	var after: Array=Catalog.container_items(p[selected_slot])
	if selected<after.size():
		rotated=bool(after[selected].get("rot",false))
	show_inventory()

# The search window follows the player: walking out of reach closes it.
func keep_loot_window() -> void:
	if _loot_index<0:
		return
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return
	var container: Dictionary=session.container_at(_loot_index)
	if container.is_empty() or p.p.distance_to(container.p)>150:
		_loot_index=-1

func update_hud() -> void:
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty() or hud.is_empty():
		return
	if session.roguelike.active(session): update_rogue_hud(p)
	sound.music.set_world(session.map_id,session.raid,session.enemies,p.p)
	var choosing: bool=session.raid.get("phase","")=="choice" and p.status=="active"
	hud.raid_continue.visible=choosing
	hud.raid_wait.visible=choosing
	hud.raid_extract.visible=(choosing or session.raid.get("phase","")=="complete") and p.status=="active"
	var remaining := maxi(0,int(ceil(session.duration-float(session.raid.get("time",0)))))
	hud.time.text="第 %d 天 · %02d:%02d / %s" % [session.raid.get("day",1),remaining/60,remaining%60,{"explore":"血潮收缩" if float(session.raid.get("time",0))>=session.SHRINK_START else "血月初升","boss":"黎明决战","choice":"黎明抉择","complete":"终夜已破"}.get(session.raid.get("phase","explore"),"")]
	hud.mission.text="王城探索 · 缩圈前自动返回边境" if session.map_id=="city" else ("晨钟封印 %d/3 · %s" % [session.objectives,"可撤离" if session.can_extract() else "撤离封锁 · 击败黎明 Boss"])
	var block := Ecology.block_at(session.ruins,p.p) if session.map_id=="border" else -1
	hud.area.text=str(session.ruins.sites[block].name)+" · "+Ecology.site_status(session,block) if block>=0 else ("击败骑士与全部守卫，领取王庭珍藏" if session.map_id=="city" else "野外稀有补给 · 清理据点获得宝箱")
	if session.roguelike.active(session):
		hud.raid_continue.hide()
		hud.raid_wait.hide()
		hud.raid_extract.hide()
		hud.time.text=RogueUi.floor_line(session.raid,session.roguelike.depth_count(session))
		hud.mission.text=session.roguelike.FLOORS[int(session.raid.floor)-1]+" · "+session.roguelike.ROOM_NAMES[session.raid.room]
		hud.area.text={"rogue_combat":"清场出现宝箱 · 开箱爆出随机品质秘藏","rogue_reward":"E 开箱 / 拾取 · 三选一后领取或分享","rogue_shop":"游商补给 · 购买后沿右侧分叉继续","rogue_exit":"直行或斜向 · 靠近路线末端按 E"}.get(session.raid.phase,"")
		hud.area.text+=" · Lv.%d 经验%d/%d 属性点%d" % [p.build_level,p.build_xp,preload("res://scripts/rogue_build.gd").xp_needed(int(p.build_level)),p.build_attribute_points]
		if hud.has("rogue_variant"):
			hud.rogue_variant.text=RogueUi.variant_line(session.raid)
			hud.rogue_curses.text=RogueUi.curses_text(p)
			hud.rogue_ash.text=RogueUi.ash_line(p,profile.data)
			hud.rogue_node.text=RogueUi.node_line(session.raid,session.roguelike.ROOM_NAMES)
			hud.rogue_seed.text=RogueUi.seed_line(session.raid)
	hud.health.text="生命   %d / %d" % [maxf(0,p.hp),p.max_hp]
	hud.hpbar.size.x=220*clampf(p.hp/p.max_hp,0,1)
	hud.mana.text="蓝量   %d / %d" % [p.mana,p.max_mana]
	hud.mpbar.size.x=220*clampf(p.mana/maxf(1.0,p.max_mana),0,1)
	hud.sanity.text="理智  %d%%    ·    血香  %d" % [p.sanity,p.scent]
	var family := Catalog.weapon_family(p.weapon)
	# The HUD icon follows whatever is in hand, looted or temporary. The cache
	# key is the weapon index rather than its family, because an issue weapon may
	# ship its own icon inside a family it only borrows.
	if int(hud.get("weapon_icon_index",-1))!=int(p.weapon):
		hud.weapon_icon_index=int(p.weapon)
		hud.weapon_icon.texture=preload("res://scripts/rogue_build_art.gd").item_icon(p.equipped.get("weapon",{})) if session.roguelike.active(session) and int(p.weapon)>=600 else TideUIArt.icon(Catalog.weapon_icon(int(p.weapon)))
	hud.ammo.text=weapon_title(p)+(" · 装填中" if p.reload>0 else (" %02d/%d" % [p.ammo,p.reserve] if family==0 else " · 三连击" if family==1 else ""))
	hud.scent.text="战利品  %d ◈   /   击杀 %d" % [loot_total(p),p.kills]
	hud.skill.text="[Q] "+Catalog.HEROES[p.hero].skill+("  %.0fs" % ceil(p.skill) if p.skill>0 else "  蓝量不足" if p.mana<session.ULTIMATE_MANA else "  就绪")+" · 30 蓝"
	var art := WeaponArts.of(int(p.weapon))
	hud.art.text="[右键] %s · %d 蓝 · %s" % [art.name,art.mana,"%.1fs" % p.art_cd if p.art_cd>0 else "蓝量不足" if p.mana<float(art.mana) else "就绪"]
	hud.art.tooltip_text=WeaponArts.text(int(p.weapon))+"\n"+Catalog.scaling_text(int(p.weapon))
	hud.items.text="血瓶 %d%% · F饮用 / 倒地长按F魂灯" % p.flask if session.roguelike.active(session) else "血晶 ×%d    /    %s" % [session.crystals_carried(p),session.backpack_label(p)]
	var kit: Array=loadout_lines(p)
	hud.loadout.text=str(kit[0])
	hud.loadout2.text=str(kit[1])
	var team := "远征小队\n"
	for ally in session.players.values():
		var status: String={"active":"%d HP" % ally.hp,"down":"倒地 · %.0fs" % ally.bleed,"dead":"阵亡","extracted":"已撤离"}[ally.status]
		team+="%s  /  %s\n" % [ally.name,status]
	hud.team.text=team
	hud.notice.text=""
	hud.prompt.text=""
	# The bar rides with the HUD, so it is drawn before any of the early returns
	# below: a downed Watcher still sees what is in their sockets.
	draw_hud_item_bar()
	if session.roguelike.active(session):
		hud.items.text="血瓶 %d%% · 刷新卡 %d · %s" % [p.flask,p.rogue_rerolls,"饮用中" if p.flask_time>0 else "%.1fs" % p.flask_cd if p.flask_cd>0 else "F饮用"]
		hud.sanity.text="补正 +%d%% · 修为 %d/%d · 武器 +%d" % [session.weapon_scaling(p)*100,session.RogueBuild.talent_cost(p),p.build_cultivation,session.RogueBuild.forge_level(p)]
		hud.scent.text="本局魔晶 %d · 击杀 %d" % [p.rogue_gold,p.kills]
		if p.status=="down":
			hud.notice.text="倒地 · 长按F两秒使用魂灯" if p.soul_lamp else "倒地 · 等待队友长按E救援"
		elif session.raid.phase=="rogue_combat":
			hud.prompt.text=("剩余魔物 %d · 第 %d / 3 段遭遇" % [session.enemies.size(),session.raid.wave]) if not session.enemies.is_empty() else "继续向右探索 · 前方还有魔物"
		if p.get("rogue_lava",false): hud.notice.text="岩浆灼烧！离开橙红色熔岩区域"
		return
	if p.status=="down":
		hud.notice.text="你已倒地 · 等待队友救援"
		hud.prompt.text="[F] 消耗急救针自救（每局一次）" if p.self_revive and session.carried(p,"medicine")>0 else "倒计时结束后阵亡；队友靠近并长按 E 可救起你。"
		return
	if p.status in ["extracted","dead"]:
		hud.notice.text="撤离成功 · 战利品已保全" if p.status=="extracted" else "守夜终结 · 背包与身上装备已散落，次元口袋仍在"
		hud.prompt.text="正在观战队友；所有人撤离或阵亡后统一结算。"
		return
	if session.map_id=="border" and p.p.distance_to(session.safe_center())>session.safe_radius():
		hud.notice.text="你正处于血潮中！向地图上的黎明印记移动"
	elif p.scent>32:
		hud.notice.text="血香浓烈 · 当地使魔警觉"
	elif p.sanity<25:
		hud.notice.text="理智濒临崩坏 · 治疗或尽快撤离"
	for ally in session.players.values():
		if ally.id!=p.id and ally.status=="down" and p.p.distance_to(ally.p)<75:
			hud.prompt.text="长按 [E] 3 秒救援 "+ally.name
			return
	if p.p.distance_to(session.portal_position())<85 and session.can_travel():
		hud.prompt.text=("长按 [E] 1.5 秒返回边境" if session.map_id=="city" else "长按 [E] 1.5 秒进入王城") if session.party_at_gate() else "全体存活队友需在城门附近集合；先救起倒地队友"
		return
	for exit_pos in session.ruins.exits:
		if p.p.distance_to(exit_pos)<83:
			hud.prompt.text="长按 [E] 4 秒独立撤离 · 受伤会打断" if session.can_extract() else "撤离封锁 · 第一天需击败黎明 Boss；终局需击败女王"
			return
	for shrine in session.ruins.shrines:
		if session.raid.phase not in ["choice","complete"] and not shrine.done and p.p.distance_to(shrine.p)<72:
			hud.prompt.text="长按 [E] 3 秒点亮封印 · 惊动当地守军 · 全队 +55 ◈"
			return
	for i in session.container_count():
		var container: Dictionary=session.container_at(i)
		if container.is_empty() or (container.items.is_empty() and i>=session.ruins.chests.size()) or container.p.distance_to(p.p)>=70:
			continue
		var title: String=session.container_title(container)
		if i>=session.ruins.chests.size() and session.container_units(container)==1:
			hud.prompt.text="[F] 拾取 "+Catalog.item_name(container.items[0])+"   /   [TAB] 整理背包"
			return
		if i>=session.ruins.chests.size():
			hud.prompt.text="[H] 搜索 "+title+"   ·   已搜出 %d / %d" % [session.visible_units(container),session.container_units(container)]
			return
		if session.container_searched(container) and container.get("open",false):
			hud.prompt.text="[F] 打开 "+title+"   /   [TAB] 整理背包"
		elif not container.get("open",false):
			hud.prompt.text="[F] 搜索 "+title+"   /   [TAB] 整理背包"
		else:
			hud.prompt.text="[F] 搜索 "+title+"   ·   已搜出 %d / %d" % [session.visible_units(container),session.container_units(container)]
		return

func loot_total(p: Dictionary) -> int:
	return Catalog.container_value(p.backpack)+Catalog.container_value(p.pocket)

# The item bar, both halves of it: the sockets under the worn kit while the
# backpack is open, and the same three sockets along the bottom of the screen
# during play. It is redrawn with the HUD rather than with the panels because the
# panel layout is only rebuilt when something in it changes, and the player needs
# to watch the bar fill up while looting with the bag shut.
func draw_hud_item_bar() -> void:
	if session.roguelike.active(session): return
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return
	# The panel draws its own sockets, and the map covers the page entirely: the
	# bottom copy would only be a second, conflicting set of bars underneath.
	if inventory_open or field.map_open:
		return
	var first := overlay.get_child_count()
	draw_item_bar(p,bottom_slot_x,bottom_slot_y,bottom_slot_width,true)
	# The HUD copy is named so a test, or anything else, can pick it out of the
	# overlay without guessing at rectangles.
	for i in range(first,overlay.get_child_count()):
		overlay.get_child(i).name="HudItemBar%d" % i

# The same three sockets as plain rectangles, for the tests and for anything that
# needs to aim at a socket without rebuilding the panel layout.
func slot_zones() -> Array:
	return slot_zone_rects

# The pointed-at socket, or -1. The panel strip is drawn as buttons that ignore
# the mouse, so this is the one hit test both the [F] key and a click use.
func slot_at(point: Vector2) -> int:
	for i in slot_zone_rects.size():
		var area: Rect2=slot_zone_rects[i]
		if area.has_point(point):
			return i
	return -1

# The strip a click is aiming at has to be the one the current layout drew, not one
# left over from before the search window moved the column: stale() is true while
# the rectangles on file belong to the other layout.
func slot_bar_stale() -> bool:
	if slot_zone_rects.is_empty():
		return true
	var loot_open_now := _loot_index>=0
	return _slot_loot!=loot_open_now or not Rect2(slot_zone_rects[0]).position.is_equal_approx(Vector2(_slot_origin.x+22,_slot_origin.y))

# Clicking a socket hands it to [F]; clicking outside the strip keeps the
# selection, because losing it to a stray click in the bag would be a surprise.
func select_item_slot(index: int) -> void:
	selected_item_slot=clampi(index,0,session.ITEM_SLOT_COUNT-1)
	show_inventory()

# [F] on the item bar. The socket's own rule decides first, because the answer is
# also the fall-through signal: a medkit is spent, a weapon, a piece of gear or a
# backpack changes places with what the Watcher is using, and a relic or a stack of
# scrap does nothing at all — in which case the key is free to do whatever else it
# does. The rule lives in Catalog so host and client agree without a round trip.
func apply_item_slot(index: int) -> bool:
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return false
	var at := clampi(index,0,session.ITEM_SLOT_COUNT-1)
	if not Catalog.slot_operable(session.item_slot_kind(p,at)):
		return false
	selected_item_slot=at
	session.action("slot_apply",{"slot":at})
	if inventory_open:
		show_inventory()
	return true

# "收回": the socket's item goes back into the backpack, or into the pocket when
# the bag has no room left for it.
func take_item_slot(index: int) -> void:
	session.action("slot_take",{"slot":index})
	selected=-1
	if inventory_open:
		show_inventory()

# A drop from a container into a socket. One item in, one item out: the socket
# hands back whatever it was holding, because the bar holds exactly one thing.
func put_in_item_slot(index: int, slot: String, item_index: int) -> void:
	session.action("slot_put",{"slot":index,"from":slot,"index":item_index})
	selected=-1
	selected_item_slot=clampi(index,0,session.ITEM_SLOT_COUNT-1)
	if inventory_open:
		show_inventory()

func toggle_bag() -> void:
	if session.roguelike.active(session): session.action("break_combo")
	if modal:
		return
	if inventory_open:
		close_bag()
	else:
		sound.play("ui-open")
		inventory_open=true
		selected=-1
		selected_slot="backpack"
		drag.active=false
		show_inventory()

# Closing the bag has to take the panels off the screen: the whole inventory is
# drawn straight onto the overlay, so nothing else would ever erase it. The search
# window closes with it — the container keeps its search progress, and pressing F
# at the chest opens it again.
func close_bag() -> void:
	if inventory_open:
		sound.play("ui-close")
	inventory_open=false
	_loot_index=-1
	selected=-1
	stop_drag()
	grids.clear()
	equip_zones.clear()
	slot_zone_rects.clear()
	_slot_origin=Vector2(10000,10000)
	panel_rects.clear()
	detach_drag_nodes()
	clear(overlay)
	if drag_ghost and is_instance_valid(drag_ghost):
		drag_ghost.queue_free()
	if drag_ring and is_instance_valid(drag_ring):
		drag_ring.queue_free()
	drag_ghost=null
	drag_ring=null
	drag_caption=null

# Unparents the live drag nodes without freeing them, so clear(overlay) during a
# rebuild cannot queue_free the icon the player is holding.
func detach_drag_nodes() -> void:
	for node in [drag_ghost,drag_ring]:
		if node and is_instance_valid(node) and node.get_parent()!=null:
			node.get_parent().remove_child(node)

func toggle_map() -> void:
	if session.roguelike.active(session): return
	field.map_open=not field.map_open
	page.visible=not field.map_open
	if field.map_open: toast_time=0; toast.visible=false
	sound.play("ui-open" if field.map_open else "ui-close")

func stop_drag() -> void:
	drag.active=false
	if drag_ghost and is_instance_valid(drag_ghost):
		drag_ghost.visible=false
	if drag_ring and is_instance_valid(drag_ring):
		drag_ring.visible=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func pick_item(slot: String, index: int) -> void:
	if slot=="loot":
		var shown: Array=session.visible_items(session.container_at(_loot_index))
		if index<0 or index>=shown.size():
			return
		selected=index
		selected_slot="loot"
		rotated=bool(shown[index].get("rot",false))
		show_inventory()
		return
	var list: Array=session.players[session.my_id()][slot].items
	if index<0 or index>=list.size():
		return
	selected=index
	selected_slot=slot
	rotated=bool(list[index].get("rot",false))
	show_inventory()

# Two quick taps on a backpack item wear it on the spot: weapons and gear go to
# their kit slot, a loose backpack becomes the equipped pack. Anything else
# returns false so the second tap degrades into an ordinary drag start.
func double_click_equip(slot: String, index: int) -> bool:
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty() or slot not in ["backpack","pocket"]:
		return false
	var list: Array=Catalog.container_items(p[slot])
	if index<0 or index>=list.size():
		return false
	var kind := str(list[index].kind)
	if kind=="backpack":
		session.action("equip_bag",{"slot":slot,"index":index})
	elif Catalog.is_wearable(kind):
		session.action("equip",{"slot":slot,"index":index})
	else:
		return false
	selected=-1
	show_inventory()
	return true

# Ctrl+left on a carried item does what the item is for: a consumable is used, a
# wearable is worn. A relic, a crate of scrap or a stack of ammo has no verb, so
# the click falls through to the plain selection the way it always did.
func ctrl_click_item(slot: String, index: int) -> bool:
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty() or slot not in ["backpack","pocket"]:
		return false
	var list: Array=Catalog.container_items(p[slot])
	if index<0 or index>=list.size():
		return false
	var kind := str(list[index].kind)
	if kind=="backpack" or Catalog.is_wearable(kind):
		return double_click_equip(slot,index)
	if kind in ["medicine","ammo"]:
		use_item(slot,index)
		return true
	return false

# Ctrl+left on something already worn takes it off. The backpack is tried first
# because that is where loot belongs; when it has no room the pocket is asked to
# tidy itself once, and when even that fails the click does nothing at all rather
# than throwing the item on the ground.
func ctrl_click_worn(zone: String) -> void:
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return
	if zone=="bag":
		session.action("unwear_bag")
	elif zone=="weapon":
		session.action("unequip_stow",{"type":"weapon","index":0})
	elif zone.begins_with("gear"):
		session.action("unequip_stow",{"type":"gear","index":zone.substr(4).to_int()})
	elif zone.begins_with("charm"):
		session.action("unequip_stow",{"type":"charm","index":zone.substr(5).to_int()})
	else:
		return
	selected=-1
	show_inventory()

# F acts on the item under the cursor while an inventory panel is open. The
# search panel transfers between the chest and carried storage; TAB mode puts
# wearables on the character and other items in the first free quick socket.
func quick_inventory_at(point: Vector2) -> bool:
	if drag.active:
		return true
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return false
	var hit := grid_at(point)
	if not hit.is_empty():
		var slot := str(hit.slot)
		var index: int=index_at(slot,Vector2i(hit.cell))
		if index<0:
			return false
		if slot=="loot":
			if _loot_index<0:
				return false
			session.action("auto_store",{"index":index})
		elif _loot_index>=0:
			var entry: Dictionary=p[slot].items[index]
			session.action("bag_drop",{"from":slot,"to":"loot:%d" % _loot_index,"index":index,"rot":bool(entry.get("rot",false))})
		else:
			var entry: Dictionary=p[slot].items[index]
			var kind := str(entry.kind)
			if kind=="backpack":
				session.action("equip_bag",{"slot":slot,"index":index})
			elif Catalog.is_wearable(kind):
				session.action("equip",{"slot":slot,"index":index})
			else:
				var free_slot := -1
				for i in session.ITEM_SLOT_COUNT:
					if session.item_slot(p,i).is_empty():
						free_slot=i
						break
				if free_slot<0:
					notify("道具栏已满，请先收回一件道具。")
					return true
				selected_item_slot=free_slot
				session.action("slot_put",{"slot":free_slot,"from":slot,"index":index})
		selected=-1
		show_inventory()
		return true
	if _loot_index>=0:
		return false
	var bar_slot := slot_at(point) if not slot_bar_stale() else -1
	if bar_slot>=0:
		if not session.item_slot(p,bar_slot).is_empty():
			session.action("slot_take",{"slot":bar_slot})
			selected_item_slot=bar_slot
			show_inventory()
		return true
	var zone := worn_zone_at(point)
	if zone=="weapon":
		session.action("unequip_stow",{"type":"weapon","index":0})
	elif zone.begins_with("gear"):
		session.action("unequip_stow",{"type":"gear","index":zone.substr(4).to_int()})
	elif zone.begins_with("charm"):
		session.action("unequip_stow",{"type":"charm","index":zone.substr(5).to_int()})
	else:
		return false
	selected=-1
	show_inventory()
	return true

# --- mouse dragging --------------------------------------------------------
# Grabs an item without removing it: the item only moves when the mouse is
# released over a legal slot, exactly like a loot screen in an extraction game.
func start_drag(slot: String, index: int, rot: bool) -> void:
	drag.active=true
	drag.slot=slot
	drag.source=index
	drag.rot=rot
	drag_last_point=Vector2(-1,-1)
	press_point=mouse_point()
	press_moved=false
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
	show_inventory()
	var held := held_item()
	if not held.is_empty():
		show_drag_item(held)
	sync_drag()

func release_drag(at: Vector2 = Vector2.INF) -> void:
	if not drag.active:
		return
	var source_slot := str(drag.slot)
	var source_index := int(drag.source)
	var rot: bool=bool(drag.rot)
	var point: Vector2=mouse_point() if not at.is_finite() else at
	var held := held_item()
	# A drop onto a socket goes through the socket's own action, whatever kind of
	# item is in hand: the item bar takes everything.
	if not held.is_empty() and not str(drag.slot).begins_with("slot:"):
		var zone := zone_at(point,held)
		if not zone.is_empty():
			stop_drag()
			# The bar is keyed by zone rather than by grid, so it is asked first.
			if str(zone.zone).begins_with("slot"):
				put_in_item_slot(int(str(zone.zone).substr(4)),source_slot,source_index)
				return
			if str(zone.zone)=="bag":
				session.action("equip_bag",{"slot":source_slot,"index":source_index})
			elif str(zone.zone).begins_with("charm"):
				session.action("equip",{"slot":source_slot,"index":source_index,"charm_slot":str(zone.zone).substr(5).to_int()})
			else:
				session.action("equip",{"slot":source_slot,"index":source_index})
			selected=-1
			show_inventory()
			return
	stop_drag()
	var slot := ""
	var spot := Vector2i.ZERO
	var hit := grid_at(point)
	if not hit.is_empty():
		slot=str(hit.slot)
		spot=Vector2i(hit.cell)
	var valid := not slot.is_empty()
	if valid:
		var target := drag_target_rect(hit,str(held.get("kind","")))
		valid=int(Vector2i(target.get("cell",Vector2i(-1,-1))).x)>=0
	if not valid:
		if source_slot=="loot":
			session.action("loot_drop",{"index":source_index})
		elif source_slot.begins_with("slot:"):
			session.action("slot_drop",{"slot":slot_source(source_slot)})
		else:
			session.action("bag_drop",{"from":source_slot,"to":"world","index":source_index})
	elif source_slot.begins_with("slot:"):
		session.action("slot_take",{"slot":slot_source(source_slot)})
	else:
		session.action("bag_drop",{"from":source_slot,"to":slot,"index":source_index,"x":spot.x,"y":spot.y,"rot":rot})
	selected=-1
	show_inventory()

# Which inventory grid, if any, sits under a point; loot cards are rectangular,
# everything else is a square grid.
func grid_at(point: Vector2) -> Dictionary:
	for key in grids:
		var entry: Dictionary=grids[key]
		if entry.has("clip") and not Rect2(entry.clip).has_point(point):
			continue
		var local: Vector2=point-entry.origin
		if local.x<0 or local.y<0:
			continue
		var step: float=float(entry.cell)+float(entry.gap)
		var col := int(local.x/step)
		var row := int(local.y/step)
		if col<0 or row<0 or col>=int(entry.grid.x) or row>=int(entry.grid.y):
			continue
		return {"slot":key,"cell":Vector2i(col,row)}
	return {}

# Which equipment socket, if any, sits under a point and accepts the held item.
# Preview and drop share this, so the glowing socket is always the socket that
# would receive the item.
func zone_at(point: Vector2, held: Dictionary) -> Dictionary:
	if held.is_empty() or str(drag.slot)=="loot":
		return {}
	var kind := str(held.kind)
	for key in equip_zones:
		var zone_rect: Rect2=equip_zones[key]
		if not zone_rect.has_point(point):
			continue
		# Every socket of the item bar takes any item at all: that is what makes a
		# 2x2 weapon and a single blood crystal equally at home in one.
		if key.begins_with("slot"):
			return {"zone":key,"rect":zone_rect}
		if key=="bag" and kind=="backpack":
			return {"zone":key,"rect":zone_rect}
		if key=="weapon" and kind=="weapon":
			return {"zone":key,"rect":zone_rect}
		if key.begins_with("gear") and kind=="gear" and Catalog.gear_slot(held)==int(key.substr(4)):
			return {"zone":key,"rect":zone_rect}
		if key.begins_with("charm") and kind=="charm":
			return {"zone":key,"rect":zone_rect}
	return {}

# Which worn socket sits under a point, whatever kind of item is being held. This
# is the plain hit test the Ctrl+left take-off needs; zone_at() layers the
# "would this item be accepted here" rules on top of it for dragging.
func worn_zone_at(point: Vector2) -> String:
	for key in equip_zones:
		var zone_rect: Rect2=equip_zones[key]
		if zone_rect.has_point(point):
			return key
	return ""

# While an item is held the screen shows three things: the slot it came from as a
# dashed outline, the cell the item would land in, and a lifted icon that follows
# the cursor. The icon is a live overlay node updated every frame in _process,
# because the inventory itself is only rebuilt when something changes.
func build_drag_nodes() -> void:
	if drag_ghost==null or not is_instance_valid(drag_ghost):
		drag_ghost=Control.new()
		drag_ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE
		drag_ghost.visible=false
		overlay.add_child(drag_ghost)
		var plate := Panel.new()
		plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
		plate.size=Vector2(70,70)
		drag_ghost.add_child(plate)
		var icon := TextureRect.new()
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate=Color(1.07,1.05,1.04,0.96)
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		icon.size=Vector2(60,60)
		icon.position=Vector2(5,5)
		drag_ghost.add_child(icon)
		drag_caption=label(drag_ghost,"",Vector2(0,74),13,INK,Vector2(220,22))
		drag_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		drag_caption.visible=false
		object_ring_node(drag_ghost,GOLD)
		drag_ghost.get_child(3).visible=false
	if drag_ring==null or not is_instance_valid(drag_ring):
		drag_ring=object_ring(GOLD)
		drag_ring.visible=false
		overlay.add_child(drag_ring)

func show_drag_item(held: Dictionary) -> void:
	build_drag_nodes()
	var count := int(held.get("count",1))
	var accent := item_tint(held)
	var icon := drag_ghost.get_child(1) as TextureRect
	var plate := drag_ghost.get_child(0) as Panel
	var stroke := drag_ghost.get_child(3) as ObjectRing
	if icon==null or plate==null:
		return
	icon.texture=TideUIArt.icon(Catalog.item_icon(held))
	# The lifted art turns with the item, exactly like the slot it came from.
	icon.rotation=PI*0.5 if bool(drag.rot) else 0.0
	plate.add_theme_stylebox_override("panel",style(Color(accent.darkened(0.88),0.62),Color(accent,0.95)))
	if stroke:
		stroke.tone=Color(accent,0.95)
		stroke.queue_redraw()
	drag_caption.text=Catalog.item_name(held)+(" ×%d" % count if count>1 else "")
	drag_caption.visible=true
	drag_ghost.visible=true
	drag_ring.visible=true

# One frame of drag feedback: move the icon under the cursor and redraw the
# landing cell so the preview always matches what the session would do.
func sync_drag() -> void:
	if not drag.active:
		if drag_ghost and is_instance_valid(drag_ghost):
			drag_ghost.visible=false
		if drag_ring and is_instance_valid(drag_ring):
			drag_ring.visible=false
		return
	var held := held_item()
	if held.is_empty():
		return
	var kind := str(held.kind)
	var accent := item_tint(held)
	drag_caption.text=Catalog.item_name(held)+(" ×%d" % int(held.get("count",1)) if int(held.get("count",1))>1 else "")
	var cell_size := held_size(held)
	var point := mouse_point()
	if point.distance_to(press_point)>8.0:
		press_moved=true
	if point.distance_to(drag_last_point)>0.01:
		drag_last_point=point
		move_drag_ghost(point,cell_size)
	drag_ring.size=cell_size
	drag_ring.queue_redraw()
	var zone := zone_at(point,held)
	if not zone.is_empty():
		# The socket itself is the landing preview while a matching item hovers it.
		var zone_rect: Rect2=zone.rect
		drag_ring.area=zone_rect
		drag_ring.tone=accent
		drag_ring.blocked=false
		return
	if str(drag.slot).begins_with("slot:"):
		# Away from a socket, the held item will be dropped on the ground.
		drag_ring.area=Rect2(point-cell_size/2,cell_size)
		drag_ring.tone=Color("c96a74")
		drag_ring.blocked=false
		drag_caption.text="松开丢弃到地面"
		return
	var hit := grid_at(point)
	var target := drag_target_rect(hit,kind)
	var slot := ""
	var cell := Vector2i.ZERO
	var exact := false
	if not target.is_empty():
		slot=str(target.slot)
		cell=Vector2i(target.cell)
		exact=bool(target.exact)
	if not slot.is_empty():
		var entry: Dictionary=grids[slot]
		var step: float=float(entry.cell)+float(entry.gap)
		var dims := Catalog.item_size({"kind":kind,"rot":bool(drag.rot)})
		if cell.x<0:
			drag_ring.area=Rect2(Vector2(entry.origin)+Vector2(int(target.cursor.x)*step,int(target.cursor.y)*step),Vector2(entry.cell,entry.cell))
			drag_ring.tone=Color("c96a74")
			drag_ring.blocked=false
			drag_caption.text="松开丢弃到地面"
		else:
			drag_ring.area=Rect2(Vector2(entry.origin)+Vector2(cell.x*step,cell.y*step),Vector2(dims.x*step-float(entry.gap),dims.y*step-float(entry.gap)))
			drag_ring.tone=accent if exact else Color("c9a06a")
			drag_ring.blocked=false
	else:
		drag_ring.area=Rect2(point-cell_size/2,cell_size)
		drag_ring.tone=Color("c96a74")
		drag_ring.blocked=false
		drag_caption.text="松开丢弃到地面"

func move_drag_ghost(point: Vector2, cell_size: Vector2) -> void:
	var lift := Vector2.ONE*minf(cell_size.x,cell_size.y)*0.10
	var ghost_size := cell_size+lift
	drag_ghost.position=point-ghost_size/2
	drag_ghost.size=ghost_size
	var plate := drag_ghost.get_child(0) as Panel
	if plate:
		plate.size=ghost_size
	var stroke := drag_ghost.get_child(3) as ObjectRing
	if stroke:
		stroke.area=Rect2(Vector2(0,0),ghost_size)
		stroke.queue_redraw()
	var icon := drag_ghost.get_child(1) as TextureRect
	if icon:
		icon.size=ghost_size-Vector2(10,10)
		icon.position=Vector2(5,5)
		icon.pivot_offset=icon.size/2
	drag_caption.position=Vector2(0,ghost_size.y+4)
	reparent_drag_nodes()

# The lifted icon always draws on top of every panel. Panels are rebuilt by
# clearing the overlay, which detaches these nodes, so re-attach defensively.
func reparent_drag_nodes() -> void:
	if drag_ghost==null or not is_instance_valid(drag_ghost):
		return
	var holder: Node=drag_ghost.get_parent()
	if holder!=overlay:
		if holder!=null:
			holder.remove_child(drag_ghost)
		overlay.add_child(drag_ghost)
	if drag_ring==null or not is_instance_valid(drag_ring):
		return
	holder=drag_ring.get_parent()
	if holder!=overlay:
		if holder!=null:
			holder.remove_child(drag_ring)
		overlay.add_child(drag_ring)

# Where the item under the cursor would land, asked of the same resolver the
# session uses. cell is (-1,-1) when the container cannot take the item at all.
func drag_target_rect(hit: Dictionary, kind: String) -> Dictionary:
	if hit.is_empty():
		return {}
	var slot := str(hit.slot)
	var cursor: Vector2i=Vector2i(hit.cell)
	var probe := {"kind":kind,"rot":bool(drag.rot)}
	var landing := Vector2i(-1,-1)
	if slot=="loot":
		var target: Dictionary=session.container_at(_loot_index)
		if not target.is_empty():
			landing=session.resolve_drop(session.peek_items(target),session.container_grid(target),probe,cursor)
	else:
		var p: Dictionary=session.players.get(session.my_id(),{})
		if not p.is_empty() and p.has(slot):
			var dest: Dictionary=p[slot]
			var skip := int(drag.source) if str(drag.slot)==slot else -1
			landing=session.resolve_drop(Catalog.container_items(dest),Catalog.container_grid(dest),probe,cursor,skip)
	return {"slot":slot,"cell":landing,"cursor":cursor,"exact":landing==cursor}

# The cursor in the same space as the panels (the 1440x900 design space).
func mouse_point() -> Vector2:
	var viewport := get_viewport()
	if viewport and root and root.is_inside_tree():
		return root.get_global_transform_with_canvas().affine_inverse()*viewport.get_mouse_position()
	return Vector2.ZERO

# Every cell the held item covers where it currently sits. A socket is not a
# grid, so an item lifted out of the bar leaves its whole box outlined instead.
func drag_slot_rect() -> Rect2:
	var slot := str(drag.slot)
	var index: int=int(drag.source)
	if slot.begins_with("slot:"):
		var at := slot_source(slot)
		if at<0 or at>=slot_zone_rects.size():
			return Rect2()
		return slot_zone_rects[at]
	if slot=="loot":
		var entry: Dictionary=grids.get("loot",{})
		if entry.is_empty():
			return Rect2()
		var shown: Array=session.visible_items(session.container_at(_loot_index))
		if index<0 or index>=shown.size():
			return Rect2()
		var loot_item: Dictionary=shown[index]
		var loot_dims := Catalog.item_size(loot_item)
		var loot_step := float(entry.cell)+float(entry.gap)
		return Rect2(Vector2(entry.origin)+Vector2(int(loot_item.x)*loot_step,int(loot_item.y)*loot_step),Vector2(loot_dims.x*loot_step-float(entry.gap),loot_dims.y*loot_step-float(entry.gap)))
	var list: Array=session.players[session.my_id()][slot].items
	if index<0 or index>=list.size():
		return Rect2()
	var entry: Dictionary=grids.get(slot,{})
	if entry.is_empty():
		return Rect2()
	var item: Dictionary=list[index]
	var dims := Catalog.item_size(item)
	var cell: float=float(entry.cell)
	var gap: float=float(entry.gap)
	return Rect2(Vector2(entry.origin)+Vector2(int(item.x)*(cell+gap),int(item.y)*(cell+gap)),Vector2(dims.x*(cell+gap)-gap,dims.y*(cell+gap)-gap))

func item_tint(item: Dictionary) -> Color:
	return Catalog.item_color(item)

func outline(area: Rect2, color: Color, width: float) -> void:
	rect(overlay,area.position,Vector2(area.size.x,width),color)
	rect(overlay,area.position+Vector2(0,area.size.y-width),Vector2(area.size.x,width),color)
	rect(overlay,area.position,Vector2(width,area.size.y),color)
	rect(overlay,area.position+Vector2(area.size.x-width,0),Vector2(width,area.size.y),color)

func draw_cross(area: Rect2, color: Color) -> void:
	var step := 11.0
	var span := area.size.x+area.size.y
	var offset := 0.0
	while offset<span:
		var a := Vector2(maxf(0.0,offset-area.size.y),minf(offset,area.size.y))
		var b := Vector2(minf(offset,area.size.x),maxf(0.0,offset-area.size.x))
		if a!=b:
			draw_diagonal(area.position+a,area.position+b,color)
		offset+=step

func draw_diagonal(a: Vector2, b: Vector2, color: Color) -> void:
	var strip := Polygon2D.new()
	strip.polygon=PackedVector2Array([a+Vector2(0,1.6),b+Vector2(0,1.6),b-Vector2(0,1.6),a-Vector2(0,1.6)])
	strip.color=color
	strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.add_child(strip)

# "slot:N" names the Nth socket of the item bar, which is a drag source like any
# container: an item parked in the bar can be pulled back into the bag, onto the
# floor or into another socket.
func slot_source(value: String) -> int:
	return value.substr(5).to_int() if value.begins_with("slot:") else -1

func held_item() -> Dictionary:
	if not drag.active:
		return {}
	var slot := str(drag.slot)
	var index: int=int(drag.source)
	if slot=="loot":
		var container: Dictionary=session.container_at(_loot_index)
		var visible: Array=session.visible_items(container)
		if index<0 or index>=visible.size():
			return {}
		return visible[index]
	if slot.begins_with("slot:"):
		return session.item_slot(session.players.get(session.my_id(),{}),slot_source(slot))
	var list: Array=session.players[session.my_id()][slot].items
	if index<0 or index>=list.size():
		return {}
	return list[index]

func held_size(held: Dictionary) -> Vector2:
	if drag.slot=="loot":
		var loot_size := Catalog.item_size({"kind":held.kind,"rot":bool(drag.rot)})
		var entry: Dictionary=grids.get("loot",{"cell":LOOT_CELL,"gap":LOOT_GAP})
		var step: float=float(entry.cell)+float(entry.gap)
		return Vector2(loot_size.x*step-float(entry.gap),loot_size.y*step-float(entry.gap))
	var cell: float=bag_cell if drag.slot=="backpack" else pocket_cell
	var gap: float=bag_gap if drag.slot=="backpack" else pocket_gap
	var size := Catalog.item_size({"kind":held.kind,"rot":bool(drag.rot)})
	# An item lifted out of the bar is drawn at the scale of the row it came from,
	# so the art in the hand is the same size as the art left behind.
	if str(drag.slot).begins_with("slot:"):
		cell=SLOT_CELL
		gap=3.0
	return Vector2(size.x*(cell+gap)-gap,size.y*(cell+gap)-gap)

func can_drop_at(slot: String, cell: Vector2i) -> bool:
	var held := held_item()
	if held.is_empty():
		return false
	if slot=="loot":
		if str(drag.slot)=="loot":
			return false
		var target: Dictionary=session.container_at(_loot_index)
		var probe := {"kind":str(held.kind),"rot":bool(drag.rot)}
		return Catalog.can_place(session.peek_items(target),probe,cell,-1,session.container_grid(target))
	if slot=="backpack" or slot=="pocket":
		var p: Dictionary=session.players.get(session.my_id(),{})
		var dest: Dictionary=p[slot]
		var probe := {"kind":str(held.kind),"rot":bool(drag.rot)}
		var skip := int(drag.source) if str(drag.slot)==slot else -1
		if not Catalog.can_place(Catalog.container_items(dest),probe,cell,skip,Catalog.container_grid(dest)):
			return false
		if slot=="pocket" and not is_pocket_item(str(held.kind)):
			return false
		return true
	return false

# Only the relic is deliberately kept in the safe pocket; other loot belongs to
# the backpack, but a player may still park anything there by hand.
func is_pocket_item(kind: String) -> bool:
	return true

# One grid renderer for both containers: the backpack resizes with its quality,
# the dimensional pocket stays 4x4 forever.
func draw_grid(slot: String, at: Vector2, cell: float, gap: float, grid: Vector2i, title: String, subtitle: String, tint: Color) -> void:
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return
	var panel_size := Vector2(grid.x*(cell+gap)-gap+34,grid.y*(cell+gap)-gap+96)
	rect(overlay,at,panel_size,BG,tint)
	ornament(overlay,at,panel_size,"frame",tint)
	label(overlay,title,at+Vector2(20,12),22,INK)
	label(overlay,subtitle,at+Vector2(21,46),13,tint,Vector2(panel_size.x-40,24))
	var origin := at+Vector2(17,78)
	grids[slot]={"origin":origin,"cell":cell,"gap":gap,"grid":grid}
	for y in grid.y:
		for x in grid.x:
			var cell_button := button(overlay,"",origin+Vector2(x*(cell+gap),y*(cell+gap)),Vector2(cell,cell),func(): place_selected(x,y)) as GothicButton
			cell_button.slot=true
			cell_button.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var items: Array=p[slot].items
	for i in items.size():
		var item: Dictionary=items[i]
		var dims := Catalog.item_size(item)
		var accent: Color=Catalog.item_color(item)
		var count := int(item.get("count",1))
		var caption: String=Catalog.item_name(item)+(" ×%d" % count if count>1 else "")
		if drag.active and str(drag.slot)==slot and i==int(drag.source):
			continue	# the held item follows the cursor instead
		var item_button := button(overlay,caption,origin+Vector2(item.x*(cell+gap),item.y*(cell+gap)),Vector2(dims.x*(cell+gap)-gap-3,dims.y*(cell+gap)-gap-3),func(): pick_item(slot,i),false,12)
		item_button.slot=true
		item_button.item_kind=Catalog.item_icon(item)
		item_button.rotated=bool(item.get("rot",false))
		item_button.short_caption=Catalog.item_short_name(item)+(" ×%d" % count if count>1 else "")
		item_button.accent=accent
		item_button.selected=selected==i and selected_slot==slot
		var f_hint := "[F] 放入宝箱" if _loot_index>=0 else "[F] 快捷装备 / 放入道具栏"
		item_button.tooltip_text=Catalog.item_name(item)+"\n"+Catalog.item_desc(item)+"\n价值："+str(Catalog.item_value(item))+"\n"+f_hint
		# The body ignores the mouse so the overlay can hit-test the whole grid and
		# drag items around; caption text is drawn, not clicked.
		item_button.mouse_filter=Control.MOUSE_FILTER_IGNORE

func place_selected(x: int,y: int) -> void:
	if selected<0:
		return
	session.action("bag_move",{"index":selected,"slot":selected_slot,"x":x,"y":y,"rot":rotated})
	selected=-1
	show_inventory()

const LOOT_CELL := 58.0
const LOOT_GAP := 6.0

func show_inventory() -> void:
	# A deferred rebuild can land after the bag was closed; drawing then would put
	# the panels back on a screen the player already dismissed.
	if not inventory_open or modal:
		return
	if session.roguelike.active(session):
		stop_drag()
		clear(overlay)
		grids.clear()
		equip_zones.clear()
		slot_zone_rects.clear()
		panel_rects.clear()
		_loot_index=-1
		var player: Dictionary=session.players.get(session.my_id(),{})
		if not player.is_empty():
			bag_signature=rogue_inventory.signature(player,session)
			rogue_inventory.draw(self,player)
		return
	# The lifted icon and the landing ring live on the overlay, but they must
	# outlive a rebuild: clear() queue_frees every child, and a rotation mid-drag
	# rebuilds the panel, which used to free the ghost out of the player's hand.
	detach_drag_nodes()
	clear(overlay)
	grids.clear()
	equip_zones.clear()
	slot_zone_rects.clear()
	panel_rects.clear()
	var p: Dictionary=session.players.get(session.my_id(),{})
	if p.is_empty():
		return
	var container: Dictionary=session.container_at(_loot_index) if _loot_index>=0 else {}
	if container.is_empty():
		_loot_index=-1
	bag_signature=str(p.backpack)+str(p.pocket)+str(p.get("equipped",{}))+str(container)
	var bag_grid: Vector2i=Catalog.bag_grid(p.backpack)
	var pocket_grid: Vector2i=Catalog.container_grid(p.pocket)
	var bag_items: Array=p.backpack.items
	if selected_slot not in ["backpack","pocket"]:
		selected_slot="backpack"
	if selected_slot=="backpack" and selected>=bag_items.size():
		selected=-1
	if selected_slot=="pocket" and selected>=p.pocket.items.size():
		selected=-1
	extraction_inventory.draw(self,p,container)
	# The held item must stay above every panel, so the live drag nodes are
	# re-attached to the end of the overlay after the panels are rebuilt.
	if drag.active:
		build_drag_nodes()
		reparent_drag_nodes()
		var held := held_item()
		if not held.is_empty():
			show_drag_item(held)
			# Re-measure even without cursor movement: a rotation changes the
			# footprint and the turned art has to show up on the same frame.
			move_drag_ghost(mouse_point(),held_size(held))
		sync_drag()

# --- item details ----------------------------------------------------------
# In TAB mode, the right column reads from top to bottom: worn equipment,
# quick slots, selected item actions and the backpack cabinet.
func draw_details(p: Dictionary, x: float, y: float, wide: float, tall: float) -> void:
	rect(overlay,Vector2(x,y),Vector2(wide,tall),BG,Color("6e4d5d"))
	ornament(overlay,Vector2(x,y),Vector2(wide,tall),"frame")
	panel_rects.append(Rect2(x,y,wide,tall))
	label(overlay,"战利品档案 / 装备",Vector2(x+20,y+15),21,GOLD)
	ornament(overlay,Vector2(x+18,y+50),Vector2(wide-36,10))
	var ix := x+22
	var inner := wide-44.0
	draw_equipment(p,x,y,wide)
	draw_item_bar(p,x,y+270.0,wide,false)
	ornament(overlay,Vector2(x+18,y+389),Vector2(wide-36,10))
	label(overlay,"选中物品",Vector2(ix,y+400),16,GOLD,Vector2(inner,22))
	if selected>=0 and selected_slot in ["backpack","pocket"] and selected<p[selected_slot].items.size():
		var item: Dictionary=p[selected_slot].items[selected]
		var accent: Color=Catalog.item_color(item)
		item_icon(overlay,Catalog.item_icon(item),Vector2(ix,y+425),Vector2(43,43))
		label(overlay,Catalog.item_name(item),Vector2(ix+54,y+426),17,accent,Vector2(inner-58,27))
		label(overlay,("背包" if selected_slot=="backpack" else Catalog.POCKET_NAME)+" · 第 %d 件  ·  %d ◈" % [selected+1,Catalog.item_value(item)],Vector2(ix+54,y+452),12,GOLD,Vector2(inner-58,18))
		var text := label(overlay,Catalog.item_desc(item),Vector2(ix,y+474),12,MUTED,Vector2(inner,32))
		text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		text.tooltip_text=Catalog.item_desc(item)
		if str(item.kind)=="weapon":
			text.text="补正后攻击 %.1f · %s" % [session.weapon_damage(p,int(item.get("weapon",0)),int(item.get("tier",0))),Catalog.scaling_text(int(item.get("weapon",0)))]
			text.tooltip_text="补正后攻击 %.1f\n%s" % [session.weapon_damage(p,int(item.get("weapon",0)),int(item.get("tier",0))),Catalog.item_desc(item)]
		var action: Dictionary=use_action(item,p)
		if not action.is_empty():
			var action_text := "生命已满" if not bool(action.enabled) else "使用" if str(item.kind) in ["medicine","ammo"] else "装备"
			var primary := button(overlay,action_text,Vector2(ix,y+510),Vector2(105,33),use_selected,true)
			primary.disabled=not bool(action.enabled)
			primary.tooltip_text=str(action.text)
		else:
			label(overlay,"仅可结算",Vector2(ix,y+518),12,MUTED,Vector2(105,20))
		var other: String="pocket" if selected_slot=="backpack" else "backpack"
		var label_text := "存入 "+Catalog.POCKET_NAME if other=="pocket" else "放回角色背包"
		button(overlay,label_text,Vector2(ix+114,y+510),Vector2(136,33),func(): move_to_other(selected_slot,selected))
		button(overlay,"丢到地面",Vector2(ix+259,y+510),Vector2(87,33),func():
			session.action("drop",{"index":selected,"slot":selected_slot})
			selected=-1
			show_inventory()
		)
	else:
		label(overlay,"悬停物品按 [F] 快捷装备或放入道具栏",Vector2(ix,y+434),13,MUTED,Vector2(inner,24))
		label(overlay,"双击或拖到装备栏 / 背包槽即可穿上",Vector2(ix,y+460),12,Color("8d8494"),Vector2(inner,22))
	draw_cabinet(p,x,y,wide)

# The worn kit: six drop sockets (weapon, three gear pieces and two charms). A
# matching item dragged out of either container lands on its socket, and two
# quick taps on the item in the bag do the same. Filled sockets carry an
# unequip tab in the corner.
func draw_equipment(p: Dictionary, x: float, y: float, wide: float) -> void:
	var ix := x+22
	var inner := wide-44.0
	label(overlay,"装备栏   /   本局强化",Vector2(ix,y+65),17,GOLD,Vector2(inner,26))
	label(overlay,"悬停 [F] 装备 / 收回",Vector2(ix+158,y+71),11,MUTED,Vector2(inner-158,20))
	ornament(overlay,Vector2(x+18,y+91),Vector2(wide-36,10))
	var rows: Array = [{"title":"武器","item":session.kit_weapon(p),"type":"weapon","slot":0}]
	var gear: Array=session.kit_gear(p)
	for i in Catalog.GEAR.size():
		var entry: Dictionary={}
		if i<gear.size() and gear[i] is Dictionary:
			entry=gear[i]
		rows.append({"title":["护甲","瞄具","轻靴"][i],"item":entry,"type":"gear","slot":i})
	var charms: Array=session.kit_charms(p)
	for i in 2:
		var entry: Dictionary=charms[i] if charms[i] is Dictionary else {}
		rows.append({"title":"饰品 %d" % (i+1),"item":entry,"type":"charm","slot":i})
	var box := 54.0
	var gapx := (inner-box*float(rows.size()))/float(rows.size()-1)
	for i in rows.size():
		var entry: Dictionary=rows[i]
		var bx := ix+float(i)*(box+gapx)
		var by := y+102.0
		var item: Dictionary=entry.item
		var kind := str(entry.type)
		var index: int=int(entry.slot)
		var zone_key := "weapon" if kind=="weapon" else "%s%d" % [kind,index]
		equip_zones[zone_key]=Rect2(bx,by,box,box)
		var filled := not item.is_empty()
		# An empty weapon socket still means a weapon in hand: the temporary issue
		# weapon. It is drawn greyed out and without an unequip tab, so it can
		# never be mistaken for a piece of worn loot.
		var issue := kind=="weapon" and not filled
		var accent: Color=Catalog.quality_color(int(item.get("tier",0))) if filled else Color("565064")
		var socket := rect(overlay,Vector2(bx,by),Vector2(box,box),Color(accent.darkened(0.84),0.9) if filled else Color(0.06,0.05,0.08,0.7),accent)
		socket.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if filled:
			socket.tooltip_text="%s\n%s" % [Catalog.item_name(item),equipment_bonus_text(item,kind)]
		elif issue:
			socket.tooltip_text="临时武器 %s\n捡到武器并装备到此槽后即可换用。" % Catalog.weapon_name(p.weapon)
		else:
			socket.tooltip_text="%s槽 · 拖拽对应装备到此穿上" % entry.title
		if filled:
			item_icon(overlay,Catalog.item_icon(item),Vector2(bx+9,by+4),Vector2(36,36))
			rect(overlay,Vector2(bx+1,by+box-17),Vector2(box-2,16),Color(0.035,0.025,0.04,0.78))
			var name_label := label(overlay,Catalog.item_short_name(item),Vector2(bx+1,by+box-16),10,INK,Vector2(box-2,14))
			name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			var off := button(overlay,"卸",Vector2(bx+box-19,by+1),Vector2(18,15),func(): unequip_slot(kind,index),false,9)
			off.tooltip_text="卸下 "+Catalog.item_name(item)
		elif issue:
			item_icon(overlay,Catalog.weapon_icon(int(p.weapon)),Vector2(bx+9,by+4),Vector2(36,36)).modulate=Color(1,1,1,0.42)
			rect(overlay,Vector2(bx+1,by+box-17),Vector2(box-2,16),Color(0.035,0.025,0.04,0.6))
			var issue_label := label(overlay,Catalog.weapon_name(p.weapon),Vector2(bx+1,by+box-16),10,Color("9d94a6"),Vector2(box-2,14))
			issue_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		else:
			var glyph := label(overlay,"◇",Vector2(bx,by+12),22,Color("6a6470"),Vector2(box,30))
			glyph.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var title := label(overlay,str(entry.title),Vector2(bx,by+box+3),12,INK if filled else MUTED,Vector2(box,18))
		title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var status := "空槽"
		if filled:
			status="伤+%d%%" % int(round(Catalog.weapon_bonus(item)*100.0)) if kind=="weapon" else equipment_bonus_text(item,kind)
		elif issue:
			status="临时"
		var status_label := label(overlay,status,Vector2(bx,by+box+20),11,GOLD if filled else Color("6a6470"),Vector2(box,16))
		status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

# Compact slot bonus for the equipment list: one glance, no wrapping.
func equipment_bonus_text(item: Dictionary, kind: String) -> String:
	if item.has("rogue_id"): return preload("res://scripts/rogue_equipment.gd").attributes_text(item)
	if kind=="weapon":
		return "伤+%d%% 速+%d%%" % [int(round(Catalog.weapon_bonus(item)*100.0)),int(round(Catalog.weapon_rate_bonus(item)*100.0))]
	if kind=="charm":
		return "伤+12%"
	match Catalog.gear_slot(item):
		0: return "生命+%d 减伤%d%%" % [int(round(Catalog.gear_bonus(item))),int(round(Catalog.gear_defense(item)*100.0))]
		1: return "火力+%d%%" % int(round(Catalog.gear_bonus(item)*100.0))
		_: return "移速+%d" % int(round(Catalog.gear_bonus(item)))

# --- the item bar -----------------------------------------------------------
# Three sockets under the worn kit, and the same bar again along the bottom of
# the screen while the backpack is shut. A socket takes exactly one item, so the
# bar is about reach rather than storage — and because a socket is not a grid, an
# item keeps the footprint it would claim in a backpack. That is why the cells
# below are fixed: a 2x2 weapon and a 1x1 crystal are drawn at the scale they
# really occupy, and a piece too big for the box is clipped by it rather than
# pretending to be a single cell.
const SLOT_CELL := 22.0
const SLOT_BOX := 94.0
const HUD_SLOT_CELL := 20.0
const HUD_SLOT_BOX := 84.0

# The item bar's own colours: gold while a key or the cursor is on it, so the
# active socket is unmistakable at a glance.
func slot_tone(entry: Dictionary, lit: bool, filled: bool) -> Color:
	var accent: Color=Catalog.item_color(entry) if filled else Color("565064")
	return GOLD if lit else accent

# One socket: the frame, the part, and the cell count that tells the player how
# much room the thing would take in a bag. Returns the box it drew, because both
# the panel layout and the bottom bar need to know where the socket landed.
func draw_item_slot_body(p: Dictionary, index: int, at: Vector2, box: float, cell: float, lit: bool) -> Rect2:
	var entry: Dictionary=session.item_slot(p,index)
	var filled := not entry.is_empty()
	var accent: Color=slot_tone(entry,lit,filled)
	var area := Rect2(at,Vector2(box,box))
	var socket := rect(overlay,at,Vector2(box,box),Color(0.055,0.045,0.075,0.88) if not filled else Color(accent.darkened(0.86),0.9),Color(accent,1.0 if lit else 0.55))
	socket.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if filled:
		draw_slot_item(entry,at,box,cell)
		socket.tooltip_text="%s\n%s\n占 %d×%d 格   ·   价值 %d ◈\n[F] 使用 / 与手上的互换   ·   [%d] 切到此栏" % [Catalog.item_name(entry),Catalog.item_desc(entry),Catalog.item_size(entry).x,Catalog.item_size(entry).y,Catalog.item_value(entry),index+1]
	else:
		var glyph := label(overlay,"◇",at+Vector2(0,box*0.5-16),int(box*0.3),Color("6a6470"),Vector2(box,box*0.4))
		glyph.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		socket.tooltip_text="%s · 空\n把武器 / 背包 / 消耗品拖到这里，关闭背包后按 [F] 使用。" % session.item_slot_name(index)
	return area

# The part inside a socket, drawn at the footprint it really owns. The socket's
# cells are placed so that any item up to 3x3 sits in the middle of the box.
func draw_slot_item(entry: Dictionary, at: Vector2, box: float, cell: float) -> void:
	var dims := Catalog.item_size(entry)
	var gap := 3.0
	var drawn := Vector2(minf(box-4.0,dims.x*(cell+gap)-gap),minf(box-4.0,dims.y*(cell+gap)-gap))
	var inner := at+(Vector2(box,box)-drawn)/2.0
	item_icon(overlay,Catalog.item_icon(entry),inner,drawn)
	var count := int(entry.get("count",1))
	if count>1:
		var tally := label(overlay,"×%d" % count,inner+Vector2(drawn.x-30,0),12,GOLD,Vector2(30,16))
		tally.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT

# The socket strip: three boxes, the selection, and the [F] hint. The panel copy
# is inset into the details column, exactly like the grids and the equipment row it
# sits under, and its sockets double as drop targets; the bottom copy is centred on
# the HUD and only ever looked at — with the bag open the mouse belongs to the
# panel, so the bottom row is drawn on the panel's terms instead.
func draw_item_bar(p: Dictionary, x: float, y: float, wide: float, bottom: bool) -> void:
	var selected_now: int=selected_item_slot
	var count: int=session.ITEM_SLOT_COUNT
	var box := HUD_SLOT_BOX if bottom else SLOT_BOX
	var cell := HUD_SLOT_CELL if bottom else SLOT_CELL
	var step := box+6.0
	var inner := wide-44.0
	var from_left := x
	if bottom:
		var total := float(count)*box+float(count-1)*6.0
		from_left=x+bottom_slot_width*0.5-total*0.5
	else:
		var total := float(count)*box+float(count-1)*6.0
		from_left=x+22.0+(inner-total)*0.5
		_slot_origin=Vector2(from_left-22.0,y)
		_slot_loot=_loot_index>=0
	for i in count:
		var at := Vector2(from_left+float(i)*step,y)
		var lit := i==selected_now
		var area := draw_item_slot_body(p,i,at,box,cell,lit)
		var title := label(overlay,"[%d] %s" % [i+1,session.item_slot_name(i)],Vector2(at.x,at.y+box+2),11,GOLD if lit else MUTED,Vector2(box,16))
		title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if bottom:
			continue
		# In the panel the sockets are drop targets as well as buttons: a drag
		# from the bag lands here, and a socket that already holds something gives
		# it back the moment the arriving item is known to fit.
		equip_zones["slot%d" % i]=area
		slot_zone_rects.append(area)
		var entry: Dictionary=session.item_slot(p,i)
		var filled := not entry.is_empty()
		# The body ignores the mouse, exactly like an inventory cell, so a click
		# selects the socket instead of starting a drag out of it.
		var body := button(overlay,"",at,Vector2(box,box),func(): select_item_slot(i))
		body.slot=true
		body.item_kind=Catalog.item_icon(entry) if filled else ""
		body.short_caption=Catalog.item_short_name(entry) if filled else ""
		body.accent=slot_tone(entry,lit,filled)
		body.selected=lit
		body.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if filled:
			var out := button(overlay,"收回",Vector2(at.x+box-38,at.y+box-17),Vector2(37,16),func(): take_item_slot(i),false,10)
			out.tooltip_text="把这一格收回背包（按对应数字键直接使用或换装）"
	var label_at := Vector2(from_left,y-22)
	if bottom:
		var hud_head := label(overlay,"道具栏 · 1/2/3 直接使用",label_at,11,GOLD,Vector2(count*box+(count-1)*6.0,20))
		hud_head.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		return
	label(overlay,"道具栏   /   快捷位",Vector2(x+22,y-22),17,GOLD,Vector2(170,26))
	label(overlay,"悬停 [F] 收回 · [1-3] 使用",Vector2(x+200,y-16),11,MUTED,Vector2(inner-178,20))

func draw_cabinet(p: Dictionary, x: float, y: float, wide: float) -> void:
	var ix := x+22
	var inner := wide-44.0
	label(overlay,"背包柜   /   点击装备",Vector2(ix,y+550),17,GOLD,Vector2(inner,26))
	ornament(overlay,Vector2(x+18,y+576),Vector2(wide-36,10))
	# The equipped backpack gets its own socket: dropping a pack item here (or
	# double-clicking it in the bag) swaps what the player carries.
	var by := y+585.0
	equip_zones["bag"]=Rect2(ix,by,inner,46)
	var tint: Color=Catalog.bag_color(p.backpack)
	var socket := rect(overlay,Vector2(ix,by),Vector2(46,46),Color(tint.darkened(0.84),0.9),tint)
	socket.mouse_filter=Control.MOUSE_FILTER_IGNORE
	socket.tooltip_text="当前装备 "+session.backpack_label(p)+" · 拖拽背包到此或双击背包换装"
	item_icon(overlay,"backpack",Vector2(ix+8,by+8),Vector2(30,30))
	label(overlay,"当前："+session.backpack_label(p),Vector2(ix+54,by+3),13,GOLD,Vector2(inner-56,20))
	label(overlay,"拖拽背包到此处或双击背包即可换装",Vector2(ix+54,by+25),11,MUTED,Vector2(inner-56,18))
	var half := inner/2.0
	for i in Catalog.BAG_TIERS.size():
		var tier: Dictionary=Catalog.BAG_TIERS[i]
		var tx := ix+float(i%2)*half
		var ty := y+638+float(int(i/2))*20
		if tier.key==str(p.backpack.key):
			label(overlay,"◈ %s %d×%d  已装备" % [tier.quality,tier.grid.x,tier.grid.y],Vector2(tx,ty),12,tier.color,Vector2(half-4,20))
		else:
			var spare := spare_index(p,tier.key)
			label(overlay,"· %s %d×%d" % [tier.quality,tier.grid.x,tier.grid.y],Vector2(tx,ty),12,Color("cfc6bb") if spare>=0 else Color("6a6470"),Vector2(half-58,20))
			if spare>=0:
				var take := spare
				button(overlay,"装备",Vector2(tx+half-54,ty-1),Vector2(52,18),func(): equip_spare(take),false,11)

# --- the search window -----------------------------------------------------
# Loot surfaces one card at a time; unrevealed slots stay as sealed placeholders.
func draw_search_window(container: Dictionary, x: float, y: float) -> void:
	var grid: Vector2i=session.container_grid(container)
	var cell_size := 36.0 if grid.x>5 or grid.y>5 else LOOT_CELL
	var gap := 4.0 if grid.x>5 or grid.y>5 else LOOT_GAP
	var step := cell_size+gap
	var units: int=session.container_units(container)
	var revealed: int=session.visible_units(container)
	var wide := grid.x*step-gap+34
	var tall := grid.y*step-gap+128
	rect(overlay,Vector2(x,y),Vector2(wide,tall),BG,Color("4b6076"))
	ornament(overlay,Vector2(x,y),Vector2(wide,tall),"frame",Color("7fa0bd"))
	label(overlay,session.container_title(container),Vector2(x+18,y+12),22,Color("cfe0f0"))
	var next: Dictionary=session.next_search_item(container)
	var duration: float=session.search_seconds(next) if not next.is_empty() else 0.0
	var state := "搜索完毕 %d 件" % units if revealed>=units else "搜索中…  %d / %d  ·  下件 %.1f 秒" % [revealed,units,duration]
	label(overlay,state,Vector2(x+19,y+46),13,Color("8fb0cc"),Vector2(wide-44,22))
	var origin := Vector2(x+17,y+76)
	grids["loot"]={"origin":origin,"cell":cell_size,"gap":gap,"grid":grid}
	panel_rects.append(Rect2(x,y,wide,tall))
	for cy in grid.y:
		for cx in grid.x:
			var cell := button(overlay,"",origin+Vector2(cx*step,cy*step),Vector2(cell_size,cell_size),func(): pass) as GothicButton
			cell.slot=true
			cell.accent=Color("6d8aa8")
			cell.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shown: Array=session.visible_items(container)
	# Cards keep the footprint the item really owns: a 2x2 relic covers four
	# cells here exactly like it does in the backpack, so what you see is what
	# you will have to make room for.
	var covered := {}
	for item in Catalog.container_items(container):
		var dims := Catalog.item_size(item)
		for cy in range(int(item.y),int(item.y)+dims.y):
			for cx in range(int(item.x),int(item.x)+dims.x):
				covered[Vector2i(cx,cy)]=true
	for cy in grid.y:
		for cx in grid.x:
			if covered.has(Vector2i(cx,cy)):
				continue
			var hidden := button(overlay,"",origin+Vector2(cx*step,cy*step),Vector2(cell_size,cell_size),func(): pass) as GothicButton
			hidden.slot=true
			hidden.disabled=true
			hidden.accent=Color("5d7690")
			hidden.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# The actual occupied cells appear as sealed grey cards before their contents
	# are revealed. Their shape is visible, but the name, icon and quality are not.
	var budget := session.visible_units(container)
	for item in Catalog.container_items(container):
		var units_in_item := int(item.get("count",1)) if Catalog.stacks(str(item.kind)) else 1
		if budget>=units_in_item:
			budget-=units_in_item
			continue
		if budget>0:
			budget=0
			continue
		var dims := Catalog.item_size(item)
		var cell_pos := origin+Vector2(int(item.x)*step,int(item.y)*step)
		var card_size := Vector2(dims.x*step-gap,dims.y*step-gap)
		var sealed := button(overlay,"?",cell_pos,card_size,func(): pass,false,22) as GothicButton
		sealed.slot=true
		sealed.sealed_slot=true
		sealed.accent=Color("646b75")
		sealed.modulate=Color(0.62,0.65,0.69,0.82)
		sealed.tooltip_text="尚未搜索 · 搜索完成后才能查看和拾取"
		sealed.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for i in shown.size():
		var item: Dictionary=shown[i]
		var dims := Catalog.item_size(item)
		var cell_pos := origin+Vector2(int(item.x)*step,int(item.y)*step)
		var card_size := Vector2(dims.x*step-gap,dims.y*step-gap)
		var count := int(item.get("count",1))
		var caption: String=Catalog.item_name(item)+(" ×%d" % count if count>1 else "")
		if item.kind=="backpack":
			var key := str(item.get("quality",Catalog.DEFAULT_BAG_KEY))
			caption=Catalog.tier(key).quality+"背包"
		var card := button(overlay,caption,cell_pos,card_size,func(): take_loot_card(i),false,12)
		card.slot=true
		card.item_kind=Catalog.item_icon(item)
		card.rotated=bool(item.get("rot",false))
		card.short_caption=Catalog.item_short_name(item)+(" ×%d" % count if count>1 else "")
		card.accent=Catalog.item_color(item)
		card.tooltip_text="%s\n%s\n占 %d×%d 格 · 悬停按 [F] 快捷拾取 / 双击自动收纳 / 拖入背包" % [Catalog.item_name(item),Catalog.item_desc(item),dims.x,dims.y]
		card.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# progress bar
	var bar_w := wide-44.0
	rect(overlay,Vector2(x+22,y+tall-32),Vector2(bar_w,6),Color("26303c"))
	var p: Dictionary=session.players.get(session.my_id(),{})
	var progress := 0.0
	if duration>0.0 and session.search_reference(p)==_loot_index:
		progress=clampf(float(p.get("search",0.0))/duration,0.0,0.99)
	var ratio := 1.0 if units<=0 else clampf((float(revealed)+progress)/float(units),0,1)
	rect(overlay,Vector2(x+22,y+tall-32),Vector2(maxf(0,bar_w*ratio),6),Color("7fa0bd"))

func draw_loot_details(p: Dictionary, container: Dictionary, x: float, y: float) -> void:
	var grid: Vector2i=session.container_grid(container)
	var step := 40.0 if grid.x>5 or grid.y>5 else LOOT_CELL+LOOT_GAP
	var gap := 4.0 if grid.x>5 or grid.y>5 else LOOT_GAP
	var top := maxf(y+404.0,y+grid.y*step-gap+128.0+12.0)
	rect(overlay,Vector2(x,top),Vector2(390,254),BG,Color("4b6076"))
	ornament(overlay,Vector2(x,top),Vector2(390,254),"frame",Color("7fa0bd"))
	panel_rects.append(Rect2(x,top,390.0,254.0))
	label(overlay,"选中物品",Vector2(x+20,top+12),18,GOLD)
	var held := held_item()
	if held.is_empty() and selected_slot=="loot" and selected>=0:
		var shown: Array=session.visible_items(session.container_at(_loot_index))
		if selected<shown.size():
			held=shown[selected]
	if held.is_empty():
		label(overlay,"悬停物品按 [F] 快捷拾取，高价值优先放入口袋；也可拖入背包。",Vector2(x+20,top+46),13,MUTED,Vector2(350,40)).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	else:
		item_icon(overlay,Catalog.item_icon(held),Vector2(x+20,top+44),Vector2(46,46))
		label(overlay,Catalog.item_name(held),Vector2(x+78,top+48),19,Catalog.item_color(held),Vector2(286,30))
		var text := label(overlay,Catalog.item_desc(held),Vector2(x+20,top+98),13,MUTED,Vector2(350,46))
		text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label(overlay,"价值 %d ◈   ·   悬停 [F] 快捷拾取 / 拖入背包" % Catalog.item_value(held),Vector2(x+20,top+146),13,GOLD)
	# Supplies stay usable while the search window is open, so a medkit never
	# needs the window closed first.
	label(overlay,"快捷使用",Vector2(x+20,top+178),13,Color("9fb6c8"),Vector2(80,22))
	var quick := quick_use_slots(p)
	if quick.is_empty():
		label(overlay,"背包与口袋中没有可用的消耗品。",Vector2(x+94,top+179),12,Color("6d7d8c"),Vector2(270,22))
	var slot_x := x+94.0
	for entry in quick:
		var kind := str(entry.kind)
		var slot := str(entry.slot)
		var index: int=int(entry.index)
		var chip := button(overlay,"%s ×%d" % [Catalog.ITEMS[kind].name,Catalog.container_count(p[slot],kind)],Vector2(slot_x,top+204),Vector2(112,34),func(): use_item(slot,index),false,13)
		chip.tooltip_text=Catalog.ITEMS[kind].desc
		slot_x+=118.0

# Ctrl turns the same click into its "smart" twin: Ctrl+left on a loot card hauls
# the item in, on a consumable it uses it, on a wearable it wears it, and on
# something already worn it takes it off. Read from the key state rather than the
# mouse event, because the modifier belongs to the keyboard while the click
# belongs to the mouse.
func ctrl_held() -> bool:
	return Input.is_action_pressed("smart_click")

func take_loot_card(index: int) -> void:
	session.action("loot_take",{"ref":_loot_index,"index":index})
	call_deferred("show_inventory")

# Double clicking a loot card: hand the item to the session, which works it into
# the backpack, tidies that container once if it is full, falls back to the
# pocket, and gives up in silence when neither can take it. The window is
# rebuilt from what really happened, so a refusal leaves the card sitting there.
func auto_store_loot(index: int) -> void:
	if _loot_index<0:
		return
	session.action("auto_store",{"ref":_loot_index,"index":index})
	show_inventory()

func spare_index(p: Dictionary, key: String) -> int:
	for i in p.bags.size():
		if str(p.bags[i].key)==key:
			return i
	return -1

func equip_spare(index: int) -> void:
	session.action("bag_swap",{"index":index})
	selected=-1
	call_deferred("show_inventory")

# A loose backpack found in the field is worn through the authoritative session,
# so the swap also works for clients in a co-op room.
func equip_pocket_pack(index: int, slot: String = "pocket") -> void:
	session.action("equip_bag",{"slot":slot,"index":index})
	selected=-1
	call_deferred("show_inventory")

func move_to_other(slot: String, index: int) -> void:
	session.action("move_to",{"from":slot,"index":index})
	selected=-1
	call_deferred("show_inventory")

# --- using and equipping from the backpack ---------------------------------
func use_selected() -> void:
	if selected<0 or selected_slot not in ["backpack","pocket"]:
		return
	use_item(selected_slot,selected)

# The one entry point for using an item, shared by the details panel, the quick
# bar next to a search window and the tests.
func use_item(slot: String, index: int) -> void:
	session.action("use",{"slot":slot,"index":index})
	call_deferred("show_inventory")

func equip_slot(slot: String, index: int) -> void:
	session.action("equip",{"slot":slot,"index":index})
	selected=-1
	call_deferred("show_inventory")

func unequip_slot(type: String, index: int = 0) -> void:
	session.action("unequip",{"type":type,"index":index})
	call_deferred("show_inventory")

# What the big button in the details panel does for the selected item. An empty
# dictionary means the item can only be carried home.
func use_action(item: Dictionary, p: Dictionary) -> Dictionary:
	match str(item.kind):
		"medicine":
			if float(p.hp)<float(p.max_hp):
				return {"text":"使用 · 恢复 45 生命","enabled":true}
			return {"text":"生命已满 · 留着","enabled":false}
		"ammo":
			return {"text":"使用 · 补充 48 发弹药","enabled":true}
		"weapon":
			return {"text":"装备到手上 · 伤害 +%d%%  攻速 +%d%%" % [int(round(Catalog.weapon_bonus(item)*100.0)),int(round(Catalog.weapon_rate_bonus(item)*100.0))],"enabled":true}
		"gear":
			return {"text":"装备 · "+Catalog.gear_desc(item),"enabled":true}
		"charm":
			return {"text":"装备到饰品栏 · 伤害 +12%","enabled":true}
		"backpack":
			return {"text":"装备这个背包","enabled":true}
	return {}

# The first usable supply of each kind, so the quick bar stays three wide while a
# search window has the player's attention.
func quick_use_slots(p: Dictionary) -> Array:
	var out: Array = []
	for slot in ["backpack","pocket"]:
		var items: Array=Catalog.container_items(p[slot])
		for i in items.size():
			var kind := str(items[i].kind)
			if not kind in ["medicine","ammo"]:
				continue
			var seen := false
			for entry in out:
				if str(entry.kind)==kind:
					seen=true
			if seen:
				continue
			out.append({"kind":kind,"slot":slot,"index":i})
			if out.size()>=3:
				return out
	return out

func weapon_title(p: Dictionary) -> String:
	var title: String=Catalog.weapon_name(p.weapon)
	if session.roguelike.active(session): return title+" +%d" % session.RogueBuild.forge_level(p)+(" · "+Catalog.quality_name(int(p.equipped.weapon.get("tier",0))) if not p.equipped.weapon.is_empty() else " · 初始")
	if session.weapon_kit_active(p):
		var item: Dictionary=session.kit_weapon(p)
		if item.has("rogue_id"):
			return title+" · "+Catalog.item_short_name(item)+" 攻击+%d%%" % roundi(preload("res://scripts/rogue_equipment.gd").value(item,"damage")*100)
		return title+" 强化+%d%%" % int(round(Catalog.weapon_bonus(session.kit_weapon(p))*100.0))
	# An issue weapon is temporary: say so, so nobody mistakes it for a real one.
	return title+" · 临时"

# Two compact HUD lines: how many slots are filled, and what they add up to.
func loadout_lines(p: Dictionary) -> Array:
	var parts: Array = []
	var hp: float=session.equipment_hp(p)
	var damage: float=session.equipment_damage(p)
	var speed: float=session.equipment_speed(p)
	if hp>0.5:
		parts.append("生命 +%d" % int(round(hp)))
	if damage>0.005:
		parts.append("火力 +%d%%" % int(round(damage*100.0)))
	if speed>0.5:
		parts.append("移速 +%d" % int(round(speed)))
	var worn := 0 if session.kit_weapon(p).is_empty() else 1
	for entry in session.kit_gear(p):
		if entry is Dictionary and not entry.is_empty():
			worn+=1
	if parts.is_empty():
		# Nothing adds a bonus yet, so the line reports what is actually in hand:
		# the temporary issue weapon, or a looted weapon whose quality is white.
		if session.issue_weapon_active(p):
			return ["本局装备  %d / %d" % [worn,1+Catalog.GEAR.size()],"临时武器 %s · 捡到武器装备后才能换用" % Catalog.weapon_name(p.weapon)]
		return ["本局装备  %d / %d" % [worn,1+Catalog.GEAR.size()],"手持 "+Catalog.item_name(session.kit_weapon(p))]
	return ["本局装备  %d / %d" % [worn,1+Catalog.GEAR.size()]," ".join(PackedStringArray(parts))]

func move_item(x: int,y: int) -> void:
	place_selected(x,y)

func on_finished() -> void:
	ultimate.stop()
	recruited=""
	var reward: Dictionary=session.results.get(session.my_id(),{})
	if not session.report_paid and not reward.is_empty():
		profile.data.coins+=reward.coins
		profile.data.xp+=reward.xp
		profile.data.runs+=1
		if reward.escaped:
			profile.data.extracts+=1
		profile.data.best=maxi(profile.data.best,int(reward.loot)+int(reward.shared))
		# The pocket always comes home; the backpack only if the player escaped.
		if reward.has("pocket"):
			profile.data.pocket=reward.pocket
		if reward.has("bags"):
			profile.data.bags=reward.bags
			profile.data.bag_key=str(reward.bags[0].get("key",Catalog.DEFAULT_BAG_KEY))
		profile.sanitize_storage()
		profile.bank_carried_items(reward.get("equipment_loot",[]))
		# Reaching the hidden ending is what recruits 墓煜, and the flag is
		# written straight into the save file so she stays pickable afterwards.
		if reward.get("hidden",false):
			for i in range(Catalog.BASE_ROSTER,Catalog.HEROES.size()):
				if profile.has_recruit(i):
					continue
				for key in Profile.RECRUIT_HEROES:
					if int(Profile.RECRUIT_HEROES[key])!=i:
						continue
					profile.unlock(str(key))
					recruited=str(Catalog.HEROES[i].name)
		profile.save_profile()
		session.report_paid=true
		# R7b: a roguelike settlement credits ash and stamps the daily record straight into
		# `profile.data` (roguelike.settle()); save once more so a run whose only profile
		# change is that credit still reaches disk. `version` stays 1.
		if bool(reward.get("roguelike",false)): profile.save_profile()
		extra_meds=0
		economy_changed()
	new_page("results")
	sound.music.set_result(bool(reward.get("escaped",false)))
	background(0.85)
	var hidden_end: bool=bool(reward.get("hidden",false))
	header("隐藏结局 · 冥火之下" if hidden_end else ("黎明的回响" if reward.get("escaped",false) else "长夜未尽"),
		"HIDDEN ENDING   /   冥火尸王已伏诛，新的守夜人已经回应召唤" if hidden_end else "EXPEDITION REPORT   /   个人战利品与全队目标已结算")
	label(page,("魔境闯关 · 已完成 %d / %d 区" % [int(reward.get("cleared",0)),rogue_total_nodes()]) if reward.get("roguelike",false) else ("%d / 3  晨钟封印" % session.objectives),Vector2(83,235),25,GOLD)
	if hidden_end:
		label(page,"骑士的护身符 · 三处晨钟 · 隐藏 Boss 已击败",Vector2(300,241),17,Color("c07ae0"))
	if not recruited.is_empty():
		label(page,"新角色解锁：%s · 可在营地选择并游玩" % recruited,Vector2(560,241),17,Color("e8c9f5"))
	label(page,"遗迹 #%d   ·   探索 %02d:%02d" % [session.seed_value,int(session.elapsed)/60,int(session.elapsed)%60],Vector2(860,235),17,MUTED)
	var i := 0
	for id in session.results:
		var r: Dictionary=session.results[id]
		var y := 305+i*99
		fade(page,Vector2(80,y),Vector2(1280,83),Color(0.13,0.06,0.10,0.7))
		ornament(page,Vector2(80,y+81),Vector2(1280,8))
		portrait(page,session.players[id].hero,Vector2(122,y+40),72)
		label(page,r.name,Vector2(162,y+18),24)
		label(page,"成功撤离" if r.escaped else "阵亡 / 失联",Vector2(370,y+21),18,Color("85c8b1") if r.escaped else Color("d38193"))
		label(page,"入库估值 %d · 奖励 %d" % [r.loot,r.shared],Vector2(585,y+21),18,MUTED)
		label(page,"%d ◈     +%d XP" % [r.coins,r.xp],Vector2(1020,y+21),22,GOLD)
		if r.get("bags",[]).size()>0 and r.escaped:
			label(page,"带出 "+Catalog.bag_quality(r.bags[0])+"背包",Vector2(585,y+50),13,Catalog.bag_color(r.bags[0]),Vector2(175,22))
		var worn: Array=r.get("worn",[])
		if not worn.is_empty():
			var shown: String="  ".join(PackedStringArray(worn.slice(0,2)))
			if worn.size()>2:
				shown+=" 等 %d 件" % worn.size()
			label(page,"身上装备 %s · %s" % [shown,"已存入仓库" if r.escaped else "已散落在废墟"],Vector2(770,y+50),12,MUTED,Vector2(540,22))
		i+=1
	label(page,"当前等级  Lv.%02d     ·     城邦银币  %d     ·     历史最佳  %d" % [profile.level(),profile.data.coins,profile.data.best],Vector2(83,741),19,MUTED)
	button(page,"返回标题",Vector2(80,804),Vector2(205,57),leave_to_title)
	button(page,"仓库 / 出售战利品",Vector2(310,804),Vector2(260,57),func(): show_economy(true))
	if reward.get("roguelike",false):
		button(page,"返回营地  →",Vector2(978,797),Vector2(382,66),func(): session.request_camp(),true)
	elif session.is_leader():
		button(page,"返回营地 · 继续守夜  →",Vector2(978,797),Vector2(382,66),func(): session.request_camp(),true)
	else:
		label(page,"等待房主带领小队返回营地…",Vector2(987,814),18,GOLD)

func on_effect(kind: String,pos: Vector2) -> void:
	# These legacy events still drive VFX. Their sound is emitted once via combat events.
	if kind in ["shot","skill","hurt"]:
		return
	if page_name=="game":
		sound.listener.global_position=rogue_field.camera if session.roguelike.active(session) else field.camera
		if kind.begins_with("search-reveal-"):
			sound.play("search-reveal",clampi(kind.substr(14).to_int(),0,5),pos)
			return
		var cue: String={"hit":"death","guard":"impact-metal","guard-break":"impact-heavy","extract":"bell"}.get(kind,kind)
		sound.play(cue,-1,pos)

func flash_damage_feedback() -> void:
	if damage_tween:
		damage_tween.kill()
	damage_overlay.modulate.a=1.0
	damage_overlay.show()
	damage_tween=create_tween()
	damage_tween.tween_interval(0.045)
	damage_tween.tween_property(damage_overlay,"modulate:a",0.0,0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	damage_tween.tween_callback(damage_overlay.hide)

func clear_damage_feedback() -> void:
	if damage_tween:
		damage_tween.kill()
	if damage_overlay:
		damage_overlay.hide()

func on_combat_audio(data: Dictionary) -> void:
	if page_name!="game":
		return
	sound.listener.global_position=rogue_field.camera if session.roguelike.active(session) else field.camera
	var emitter := int(data.get("id",0))
	var speaker: Dictionary=session.players.get(emitter,{})
	var voice_hero := int(speaker.get("hero",0))
	sound.dialogue.local_id=session.my_id()
	match str(data.kind):
		"boss-vfx":
			sound.boss(data)
		"ultimate-start":
			sound.stop_cue("reload",emitter)
			sound.stop_cue("magic-windup",emitter)
		"strike":
			sound.attack(int(data.weapon),int(data.get("combo",0)),data.p,emitter,str(data.get("spell","star")))
			sound.dialogue.play_line(voice_hero,"attack",emitter,data.p,sound.listener.global_position)
		"windup":
			if int(data.weapon)==3:
				sound.play("magic-windup",-1,data.p,0.0,emitter)
		"impact":
			var weapon := int(data.get("weapon",-1))
			var cue := "impact-magic" if weapon==3 else "impact-heavy" if data.get("heavy",false) else "hit"
			sound.play(cue,-1,data.p)
			if int(data.get("enemy_type",0)) in [2,3] and weapon in [0,1,2]:
				sound.play("impact-metal",-1,data.p,-4.0)
		"audio":
			# Authoritative hurt/down events also reach clients; only flash the victim's screen.
			if emitter==session.my_id() and str(data.cue) in ["hurt","down"]:
				flash_damage_feedback()
			if str(data.cue) in ["equip","down"]:
				sound.stop_cue("reload",emitter)
				sound.stop_cue("magic-windup",emitter)
			sound.play(str(data.cue),int(data.get("variant",-1)),data.p,0.0,emitter)
			if str(data.cue) in ["heal","hurt","down"]:
				sound.dialogue.play_line(voice_hero,str(data.cue),emitter,data.p,sound.listener.global_position)
		"dodge":
			sound.stop_cue("magic-windup",emitter)
			sound.dialogue.play_line(voice_hero,"dash",emitter,data.p,sound.listener.global_position)
		"skill":
			# A host release may arrive just before the final local CG frame.
			if emitter==session.my_id() and ultimate.active:
				ultimate.stop(false)
			sound.play("skill",int(data.hero),data.p,0.0,emitter)
			if emitter!=session.my_id():
				sound.dialogue.play_line(int(data.hero),"ultimate-short",emitter,data.p,sound.listener.global_position)

func notify(text: String) -> void:
	toast.text=text
	toast_time=5.0
	toast.visible=true

# Opening tips queue up instead of fighting over the one toast line: the raid-start
# line and the item bar's own line would otherwise overwrite each other, and the
# second one is exactly the one written down in the manual. Gameplay notices go
# through say() for the same reason — an event line should never erase a line the
# player has not finished reading.
func say(text: String) -> void:
	_pending_tips.append(text)
	if not _tip_running:
		_tip_running=true
		run_tips()

func run_tips() -> void:
	while not _pending_tips.is_empty():
		var line: String=str(_pending_tips.pop_front())
		notify(line)
		await get_tree().create_timer(5.4).timeout
	_tip_running=false

func popup_tip(text: String) -> void:
	say(text)

func modal_box(title: String, size: Vector2 = Vector2(800,580)) -> Vector2:
	clear(overlay)
	modal=true
	if camp:
		camp.input_blocked=true
	var at := (Vector2(1440,900)-size)/2
	var shade := rect(overlay,Vector2.ZERO,Vector2(1440,900),Color(0.015,0.02,0.04,0.85))
	shade.mouse_filter=Control.MOUSE_FILTER_STOP
	rect(overlay,at,size,BG,Color("6b495c"))
	ornament(overlay,at,size,"frame")
	label(overlay,title,at+Vector2(33,21),29)
	button(overlay,"关闭",at+Vector2(size.x-135,23),Vector2(103,43),close_modal)
	return at

func close_modal() -> void:
	clear(overlay)
	modal=false
	if camp:
		camp.input_blocked=false
	if inventory_open:
		show_inventory()

func pause_menu() -> void:
	var at := modal_box("守夜通讯",Vector2(630,460))
	label(overlay,"本局时间继续流逝，请先移动到安全处。",at+Vector2(35,100),18,MUTED)
	button(overlay,"继续探索",at+Vector2(35,174),Vector2(560,56),close_modal,true)
	button(overlay,"守夜手册",at+Vector2(35,249),Vector2(270,52),show_help)
	button(overlay,"设置",at+Vector2(325,249),Vector2(270,52),show_settings)
	button(overlay,"放弃本局并离开",at+Vector2(35,325),Vector2(560,52),confirm_leave)
	label(overlay,"房主离开会结束房间；未结算的战利品将丢失。",at+Vector2(35,394),14,Color("c38b98"))

func confirm_leave() -> void:
	var at := modal_box("确认放弃远征？",Vector2(650,320))
	label(overlay,"尚未结算的战利品会遗失；房主离开将关闭房间。",at+Vector2(32,105),17,MUTED)
	button(overlay,"继续守夜",at+Vector2(32,206),Vector2(275,55),close_modal,true)
	button(overlay,"确认离开",at+Vector2(331,206),Vector2(285,55),leave_to_title)

func leave_to_title() -> void:
	session.disconnect_room()
	extra_meds=0
	ready_local=false
	show_title()

func show_settings() -> void:
	var at := modal_box("设置",Vector2(740,585))
	label(overlay,"主音量",at+Vector2(37,112),20)
	var slider := HSlider.new()
	slider.position=at+Vector2(185,127)
	slider.size=Vector2(480,30)
	slider.min_value=0
	slider.max_value=1
	slider.step=0.01
	slider.value=profile.data.volume
	slider.value_changed.connect(func(value: float): set_volume(value); profile.data.volume=value; profile.save_profile())
	overlay.add_child(slider)
	label(overlay,"角色语音",at+Vector2(37,187),20)
	var voice_slider := HSlider.new()
	voice_slider.position=at+Vector2(185,202)
	voice_slider.size=Vector2(480,30)
	voice_slider.min_value=0
	voice_slider.max_value=1
	voice_slider.step=.01
	voice_slider.value=profile.data.voice_volume
	voice_slider.value_changed.connect(func(value: float): set_voice_volume(value); profile.data.voice_volume=value; profile.save_profile())
	overlay.add_child(voice_slider)
	label(overlay,"背景音乐",at+Vector2(37,262),20)
	var music_slider := HSlider.new()
	music_slider.position=at+Vector2(185,277)
	music_slider.size=Vector2(480,30)
	music_slider.min_value=0
	music_slider.max_value=1
	music_slider.step=.01
	music_slider.value=profile.data.music_volume
	music_slider.value_changed.connect(func(value: float): set_music_volume(value); profile.data.music_volume=value; profile.save_profile())
	overlay.add_child(music_slider)
	button(overlay,"切换全屏 / 窗口",at+Vector2(37,353),Vector2(665,56),func():
		profile.data.fullscreen=not profile.data.fullscreen
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if profile.data.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		profile.save_profile()
	)
	label(overlay,"日语角色语音 · 奥义配有中文字幕",at+Vector2(37,443),16,MUTED)
	label(overlay,"成长自动保存；标题页「账号 / 存档」可设置云同步。",at+Vector2(37,485),15,MUTED)

func set_music_volume(value: float) -> void:
	var bus := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(.001,value)))
	AudioServer.set_bus_mute(bus,value<.005)

func set_voice_volume(value: float) -> void:
	var bus := AudioServer.get_bus_index("Dialogue")
	AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(.001,value)))
	AudioServer.set_bus_mute(bus,value<.005)

func set_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,value)))
	AudioServer.set_bus_mute(0,value<0.005)

func show_help() -> void:
	var at := modal_box("守夜手册",Vector2(1060,720))
	var left := at+Vector2(36,100)
	label(overlay,"01  /  活着带回去",left,23,GOLD)
	label(overlay,"WASD 移动 · 鼠标瞄准与左键攻击 · 空格闪避 · Q 技能 · R 装填\n开局只有角色的临时武器，不能切换；捡到武器后装备，才能换用更强的武器\nF 短按 = 拾取单件 / 搜索宝箱；H = 搜索附近的多件掉落包\n[1] [2] [3] 直接使用对应格道具 / 换装；[F] 也可使用当前格\nE 长按 = 救援倒地队友 / 进出王城城门 / 独立撤离 / 点亮晨钟封印\nTAB 背包与口袋 · M 战术地图 · ESC 菜单",left+Vector2(0,51),17,INK,Vector2(480,240)).add_theme_constant_override("line_spacing",7)
	label(overlay,"02  /  搜刮要慢慢来",left+Vector2(0,318),23,GOLD)
	var risk := label(overlay,"对着物资箱按 [F] 搜索，附近多件掉落包按 [H] 搜索。物品按品质逐件浮出，未搜索的卡片呈灰色。\n\n用鼠标把搜出的物品拖进背包或次元口袋即可拿走；按 [TAB] 关掉。深处教堂的箱子是 5×5，普通箱子是 4×4。\n\n单击选中物品，双击或拖到右侧装备栏即可穿上：武器进武器槽，护甲 / 瞄具 / 轻靴按部位进对应槽，背包拖到背包槽即可换装。\n\n背包内按 [R]（或右键）旋转物品；拖出有效网格和装备槽后松开，就会丢到地上。地面单件物品按 [F] 拾取。",left+Vector2(0,361),17,MUTED,Vector2(462,262))
	risk.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var right := at+Vector2(554,100)
	label(overlay,"03  /  一同出征，独立撤离",right,23,GOLD)
	var coop := label(overlay,"地图上的金色菱形是晨钟封印。长按 [E] 3 秒激活；每处全队奖励 55 银币，完成三处额外奖励 100。\n\n绿色十字是撤离点：第二天起长按 [E] 4 秒独立撤离，受伤会中断。城门是往返王城的路，全队到齐后长按 [E] 1.5 秒通过。\n\n第二天击败 Boss 后，Y 留下挑战第三天，N 直接撤离，U 取消就绪。所有留下的人就绪后进入终局。",right+Vector2(0,51),17,MUTED,Vector2(463,262))
	coop.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(overlay,"04  /  道具栏与不要遗忘时间",right+Vector2(0,318),23,GOLD)
	var danger := label(overlay,"装备面板下方有三格道具栏，关闭 TAB 后同样显示在屏幕底部：拖进去一个物品，不管它在背包里占几格，道具栏里都只占一格。按 1 / 2 / 3 直接使用对应格的道具或换装。\n\n藏品（月蚀遗物等）放在道具栏里按 [F] 没有任何效果，只有武器、护甲 / 瞄具 / 轻靴、背包和急救针 / 弹药匣有用。身边没东西可捡时，[F] 会先给道具栏，再兜底用急救针；倒地时按 [F] 仍可消耗急救针自救。\n\n前两天每天 5 分钟，第 3 分钟围绕黎明印记缩圈，第 5 分钟 Boss 降临。倒地可被队友长按 [E] 救起，背包与身上装备会掉落。全员离场后结算：撤离保留战利品，阵亡只保留次元口袋。",right+Vector2(0,366),17,MUTED,Vector2(463,268))
	danger.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func show_credits() -> void:
	var at := modal_box("制作组 / 资源说明",Vector2(830,620))
	label(overlay,"血潮守望 · Crimson Tide",at+Vector2(37,107),29,GOLD)
	label(overlay,"游戏实现  /  Godot 4 · GDScript\n主视觉、立绘与精灵  /  AI 原创插画\n音效  /  Lentikula · Kenney 等 CC0 素材再设计\n日语真人语音  /  フリーボイス素材屋すぱらんど\n声优  /  すぱるな瀟洒 · 三套角色演绎\n攻击 · 施法 · 受伤 · 奥义出招\n免费授权录音 · 日语台词 · 中文奥义字幕\n完整鸣谢  /  AUDIO-CREDITS.txt · VOICE-CREDITS.txt\n字体  /  Noto Serif & Sans SC · SIL OFL",at+Vector2(37,172),18,MUTED,Vector2(750,340)).add_theme_constant_override("line_spacing",10)
	label(overlay,"献给每一位在长夜中守望黎明的人。",at+Vector2(37,550),18,INK)


func show_rogue_setup() -> void:
	if session.players.is_empty(): session.solo(config())
	if session.is_leader(): session.select_mode("roguelike")
	attach_profile()
	new_page("rogue_setup")
	background(0.8)
	header("魔境闯关", "ROGUE ADVENTURE  /  五层魔境 · 每层 7~10 个节点 · 深渊变数与局外成长")
	label(page,"幽光菌林 → 魔焰铸炉 → 星晶幻境 → 风暴空港 → 黑曜魔宫",Vector2(82,220),23,GOLD,Vector2(1290,50))
	# R5 replaced the fixed five-slot floor with a node graph, so the old "每层五区"
	# copy would describe a game that no longer exists.
	label(page,"每层 7~10 个节点，路线按分支自选：战斗 / 精英 / 游商 / 遗落宝藏 / 灵契圣坛 / 守层者，\n另有诅咒回廊、幽暗异事、熔炉工坊、赌徒帐幕与镜像试炼。\n每层开局抽取一条全队共享的深渊变数；天赋只在圣坛获得，装备清场后开箱获取。",Vector2(82,290),19,INK,Vector2(1270,112))
	rogue_cards=0; rogue_weapon=-1
	label(page,"免费出发 · 每人3次刷新 · 60魔晶 · 血瓶100%",Vector2(82,405),26,GOLD)
	label(page,"252项独立构筑：48武器 / 72装备 / 96天赋 / 24铭刻 / 12武器核心",Vector2(82,473),23,INK,Vector2(1260,52))
	rogue_icon(page,rogue_field.art.item_icons[8],Vector2(816,453),Vector2(80,80))
	label(page,"开局免费三选一白色武器，保留角色自带武器作后备。不同角色有初始属性；永久分配完整保留。",Vector2(82,551),21,INK,Vector2(1260,66))
	label(page,"每局保底18修为 / 8锻造点。打怪获得局内经验，每级+2属性点；宝箱概率掉落额外属性灵晶。\nTab → 构筑：天赋、加点、锻造、连招手册和全部素材图鉴。",Vector2(82,628),21,GOLD,Vector2(1260,70))
	label(page,"WASD移动 · 左键攻击 · 右键战技 · Space闪避 · C跃起 · Q奥义 · F血瓶 · E救援/出口\n种子 / 每日挑战与灰烬成长树见下方两个入口：同一条种子必得同一座魔境，灰烬只在局外消费。",Vector2(82,722),18,MUTED,Vector2(1260,72))
	# R7: the third and fourth slots of the bottom row are the two new魔境 entries —
	# the run seed / daily challenge, and the ash growth tree.
	var seed_button := button(page,RogueUi.seed_button_text(rogue_seed_pending,rogue_daily_pending),Vector2(330,813),Vector2(300,56),show_rogue_seed_page)
	seed_button.name="RogueSeedButton"
	seed_button.tooltip_text=RogueUi.pending_seed_text(rogue_seed_pending,rogue_daily_pending)
	var growth_button := button(page,"灰烬成长树",Vector2(650,813),Vector2(300,56),show_growth_tree)
	growth_button.name="RogueGrowthButton"
	growth_button.tooltip_text=RogueUi.growth_summary(profile.data)
	button(page,"返回营地",Vector2(82,813),Vector2(230,56),go_camp)
	button(page,"全队闯关 · 出发  →" if session.is_leader() else "确认购买 · 准备",Vector2(980,807),Vector2(370,66),start_rogue,true)

func rogue_cost() -> int:
	return 0


## R7b: hand the local save to the session. `TideSession.profile_data()` (session.gd:115)
## reads `get_meta("profile_data")`, and `RogueGrowth.grant()` probes the same channel; without
## it the ash bank is never credited (the run-local `p.rogue_ash_run` still ticks, so the HUD
## looked right while nothing was saved) and `roguelike.reset()` scales the starting gold /
## rerolls by an empty growth table, i.e. the purchased nodes were a silent no-op.
## Only the dictionary is attached, never the Profile object, so the session never saves by
## itself — `on_finished()` stays the single place that writes the file.
func attach_profile() -> void:
	if session == null: return
	session.set_meta("profile_data",profile.data)


func start_rogue() -> void:
	if page_name!="rogue_setup": return
	var cost := rogue_cost()
	if profile.data.coins<cost:
		notify("金币不足，请减少开局准备。")
		return
	if session.selected_mode!="roguelike":
		notify("队长已切换为搜打撤，请返回营地。")
		return
	rogue_pending_cost=cost
	ready_local=true
	var seed := rogue_launch_seed()
	var payload := config()
	# R7: the seed/daily intent rides with the config (so a host can re-read it) and is
	# handed to `launch()` directly, because session.gd:1386 is the only place that
	# turns a chosen seed into `seed_value`.
	payload.merge({"mode":"roguelike","rogue_rerolls":rogue_cards,"rogue_weapon":rogue_weapon,"rogue_seed":seed,"rogue_daily":rogue_daily_pending},true)
	attach_profile()
	session.configure(payload)
	if seed>0 and session.authority():
		session.launch(false,seed)
	elif session.is_leader():
		session.request_launch()
		if seed>0 and not session.running:
			notify("指定种子需要由房主（本地主机）发起；本局按随机种子开始。")
	if session.running:
		rogue_seed_pending=0
		rogue_daily_pending=false
	if not session.running: notify("闯关准备完成，等待队友确认后由队长免费出发。")

func update_rogue_hud(p: Dictionary) -> void:
	var revision: int=int(session.raid.revision)
	var claimed: bool=p.id in session.raid.get("reward_claims",[])
	var selection: Dictionary=p.get("rogue_selection",{})
	var browsing_shop: bool=p.p.x<session.ruins.fork_start-80
	var signature := "%d:%s:%d:%d:%s:%d:%s" % [revision,session.raid.phase,p.rogue_gold,p.rogue_rerolls,claimed,session.raid.get("reward_claims",[]).size(),browsing_shop]
	signature+="/%s/%s" % [selection.get("id",-1),selection.get("version",-1)]
	if not selection.is_empty(): signature="selection:%s:%s:%s" % [selection.id,selection.version,p.rogue_rerolls]
	# R7: an 幽暗异事 room is raid-wide state, so its identity has to be part of the
	# rebuild key or the panel would never appear for the second player.
	signature+="/event:%s:%d" % [RogueUi.event_id(session.raid),int(RogueUi.pending_event(session.raid).get("revision",-1))]
	# R7b: the three dedicated rooms repaint from their own signature — the room kind,
	# the raid revision and the local resources that decide whether an offer is clickable.
	var room_kind := str(session.raid.room)
	# Purchases and rerolls change revision, but must not reopen a dismissed panel.
	# A new room, event or personal reward gets its own visibility state.
	var context := "%s:%s:%s:%s:%s:%s" % [session.raid.get("floor",1),session.raid.get("node",""),session.raid.get("area",1),room_kind,RogueUi.event_id(session.raid),selection.get("id",-1)]
	if context!=rogue_panel_context:
		rogue_panel_context=context
		rogue_panel_dismissed=false
	signature+="/context:%s/hidden:%s" % [context,rogue_panel_dismissed]
	if RogueRoomUi.handled(room_kind):
		signature+="/room:"+RogueRoomUi.signature(room_kind,session.raid,RogueRoomUi.context_of(session,p))
	if signature==rogue_signature: return
	rogue_signature=signature
	rogue_panel_open=false
	rogue_event_buttons=[]
	rogue_room_buttons=[]
	if is_instance_valid(rogue_panel):
		page.remove_child(rogue_panel)
		rogue_panel.queue_free()
	rogue_panel=Control.new()
	rogue_panel.size=Vector2(1440,900)
	rogue_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	page.add_child(rogue_panel)
	var panel_title := ""
	if not selection.is_empty(): panel_title="奖励抉择"
	elif RogueUi.event_active(session.raid): panel_title="幽暗异事"
	elif RogueRoomUi.handled(room_kind): panel_title=RogueRoomUi.room_name(room_kind)
	elif session.raid.phase=="rogue_shop" and browsing_shop: panel_title="游商"
	if panel_title!="" and rogue_panel_dismissed:
		var reopen := button(rogue_panel,"打开"+panel_title,Vector2(1130,140),Vector2(235,44),open_rogue_panel)
		reopen.name="RoguePanelReopen"
		return
	rogue_panel_open=panel_title!=""
	if not selection.is_empty():
		var reward_ui=preload("res://scripts/rogue_reward_ui.gd").new()
		rogue_panel.add_child(reward_ui)
		reward_ui.build(self,selection)
		# World loot can be put back; personal starting/room rewards must be resolved.
		rogue_panel_open=not bool(selection.get("personal",false))
		if rogue_panel_open: rogue_panel_close_button(Vector2(1265,48))
		return
	if RogueUi.event_active(session.raid):
		rogue_event_panel(p,revision)
		rogue_panel_close_button()
		return
	if RogueRoomUi.handled(room_kind):
		rogue_room_panel(p,revision,room_kind)
		rogue_panel_close_button()
		return
	label(rogue_panel,"魔晶 %d · 刷新卡 %d" % [p.rogue_gold,p.rogue_rerolls],Vector2(1030,92),18,GOLD,Vector2(380,35))
	if session.raid.phase=="rogue_reward":
		label(rogue_panel,"E 开箱 / 拾取 · 每人武器与装备三选一 · Tab管理构筑",Vector2(380,130),20,GOLD,Vector2(900,40))
	if session.raid.phase=="rogue_shop" and browsing_shop:
		rect(rogue_panel,Vector2(335,174),Vector2(1050,530),Color(0.035,0.025,0.07,0.96))
		label(rogue_panel,"游商 · 可购买多件" if session.raid.phase=="rogue_shop" else "区域通关 · 选择一项奖励",Vector2(360,187),22,GOLD)
		for i in p.get("rogue_shop_offers",[]).size():
			var offer: Dictionary=p.rogue_shop_offers[i]
			var index: int=i
			var x: int=360+(i%3)*330
			var y: int=floori(i/3.0)*230
			rogue_icon(rogue_panel,rogue_field.art.offer_icon(offer),Vector2(x,228+y),Vector2(54,54))
			var title := label(rogue_panel,offer.name,Vector2(x+73,230+y),17,INK,Vector2(240,52))
			title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			var details := label(rogue_panel,offer.desc,Vector2(x,289+y),14,MUTED,Vector2(300,111))
			details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			var b := button(rogue_panel,"已售出" if offer.get("sold",false) else ("%d 魔晶 · 购买" % offer.price if offer.price>0 else "领取"),Vector2(x,414+y),Vector2(300,47),func(): session.action("rogue_take",{"index":index,"revision":revision}))
			b.disabled=offer.get("sold",false) or p.rogue_gold<int(offer.price) or (offer.has("flask_refill") and p.flask>50)
		var reroll := button(rogue_panel,"使用刷新卡",Vector2(975,180),Vector2(235,42),func(): session.action("rogue_reroll",{"revision":revision}))
		reroll.disabled=p.rogue_rerolls<=0
		rogue_panel_close_button()
		if session.raid.phase=="rogue_prepare": label(rogue_panel,"等待队友选好开局武器",Vector2(480,400),22,GOLD)
	if session.raid.phase in ["rogue_shop","rogue_exit"]:
		label(rogue_panel,"全队向右集合 · 靠近目标路线末端按 E",Vector2(1040,730),20,GOLD,Vector2(360,40))

func rogue_panel_close_button(at: Vector2 = Vector2(1230,180)) -> void:
	var close := button(rogue_panel,"关闭 · Esc",at,Vector2(135,42),close_rogue_panel)
	close.name="RoguePanelClose"

func close_rogue_panel() -> void:
	if not rogue_panel_open: return
	var p: Dictionary=session.players[session.my_id()]
	var selection: Dictionary=p.get("rogue_selection",{})
	if not selection.is_empty():
		session.action("rogue_selection_return",{"id":selection.id,"version":selection.version})
		return
	rogue_panel_dismissed=true
	rogue_signature=""
	sound.play("ui-close")
	update_rogue_hud(session.players[session.my_id()])

func open_rogue_panel() -> void:
	rogue_panel_dismissed=false
	rogue_signature=""
	sound.play("ui-open")
	update_rogue_hud(session.players[session.my_id()])


## R7: the 幽暗异事 room. The offer lives in raid-wide `pending_event` (written by
## `RogueEvents.roll_offer()`), so every Watcher sees the same choices and only an
## active Watcher may pick one. The click ships `raid.revision`, which
## `roguelike.choose()` (roguelike.gd:681) compares before touching state — a stale
## button from an earlier room is dropped instead of replaying.
func rogue_event_panel(p: Dictionary, revision: int) -> void:
	rect(rogue_panel,Vector2(335,176),Vector2(1050,548),Color(0.035,0.025,0.07,0.96))
	label(rogue_panel,"幽暗异事",Vector2(360,189),22,GOLD)
	label(rogue_panel,RogueUi.event_title(session.raid),Vector2(360,226),20,INK,Vector2(1000,34))
	var body := label(rogue_panel,RogueUi.event_body(session.raid),Vector2(360,264),15,MUTED,Vector2(1000,44))
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	rogue_event_buttons=[]
	var options := RogueUi.event_options(session,p,session.raid)
	for i in options.size():
		var option: Dictionary=options[i]
		var index: int=int(option.get("index",-1))
		var y := 326+i*100
		rect(rogue_panel,Vector2(360,y),Vector2(1000,92),Color(0.06,0.045,0.10,0.92))
		label(rogue_panel,str(option.get("name","")),Vector2(378,y+10),18,GOLD,Vector2(700,28))
		var require_line := RogueUi.require_text(option)
		var desc_text := str(option.get("desc",""))
		if require_line != "": desc_text+="（"+require_line+"）"
		var desc := label(rogue_panel,desc_text,Vector2(378,y+42),14,MUTED,Vector2(752,40))
		desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var pick := button(rogue_panel,"选择",Vector2(1150,y+22),Vector2(190,48),func(): session.action(RogueUi.ACTION_EVENT,RogueUi.event_payload(session.raid,index)))
		pick.name="RogueEventOption%d" % i
		pick.tooltip_text=require_line if require_line!="" else "无门槛"
		pick.disabled=not bool(option.get("enabled",false)) or p.status!="active"
		rogue_event_buttons.append(pick)
	if options.is_empty():
		label(rogue_panel,"事件数据缺失，等待房主重新抽取。",Vector2(378,330),16,Color("c38b98"),Vector2(940,30))
	if p.status!="active":
		label(rogue_panel,"你当前无法抉择 · 等待队友",Vector2(360,700),16,Color("c38b98"),Vector2(1000,26))


## R7b: 游方锻炉 / 赌徒营帐 / 镜中挑战. `roguelike.open_room()` writes the pending quote
## and `refresh_dedicated()` re-quotes after every deal, so this panel only renders what the
## revision guard will actually accept. Clicking ships the frozen action name together with
## `raid.revision`: a stale button left over from an earlier room is dropped by
## `roguelike.choose()` instead of replaying the purchase.
func rogue_room_panel(p: Dictionary, revision: int, kind: String) -> void:
	var ctx := RogueRoomUi.context_of(session,p)
	rect(rogue_panel,Vector2(335,176),Vector2(1050,548),Color(0.035,0.025,0.07,0.96))
	label(rogue_panel,RogueRoomUi.title(kind),Vector2(360,189),22,GOLD)
	var body := label(rogue_panel,RogueRoomUi.body(kind,ctx),Vector2(360,226),15,MUTED,Vector2(1000,42))
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(rogue_panel,"魔晶 %d · 锻造 +%d · 本局灰烬 %d" % [p.rogue_gold,int(p.get("build_forge_level",0)),int(p.get("rogue_ash_run",0))],Vector2(360,270),15,GOLD,Vector2(1000,24))
	rogue_room_buttons=[]
	var rows := RogueRoomUi.rows(kind,session.raid,ctx)
	for i in rows.size():
		var row: Dictionary=rows[i]
		var y := 304+i*92
		rect(rogue_panel,Vector2(360,y),Vector2(1000,84),Color(0.06,0.045,0.10,0.92))
		label(rogue_panel,str(row.name),Vector2(378,y+8),17,GOLD,Vector2(700,26))
		var desc_text := str(row.desc)
		if str(row.reason)!="": desc_text+="（"+str(row.reason)+"）"
		var desc := label(rogue_panel,desc_text,Vector2(378,y+36),13,MUTED,Vector2(752,42))
		desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var row_action := str(row.action)
		var row_payload: Dictionary=(row.payload as Dictionary).duplicate(true)
		var cost := int(row.cost)
		var take := button(rogue_panel,("%d 魔晶" % cost) if cost>0 else "确认",Vector2(1150,y+20),Vector2(190,46),func(): session.action(row_action,row_payload))
		take.name="RogueRoomOption%d" % i
		take.tooltip_text=str(row.reason) if str(row.reason)!="" else "无门槛"
		take.disabled=not bool(row.enabled) or p.status!="active"
		rogue_room_buttons.append(take)
	if rows.is_empty():
		label(rogue_panel,"这件房契没有可用的服务，向右离开即可。",Vector2(378,308),16,Color("c38b98"),Vector2(940,30))
	var hint_line := RogueRoomUi.footer(kind,session.raid,str(session.raid.phase))
	if hint_line!="": label(rogue_panel,hint_line,Vector2(360,690),16,GOLD,Vector2(1000,26))
	if p.status!="active":
		label(rogue_panel,"你当前无法交易 · 等待队友",Vector2(360,716),15,Color("c38b98"),Vector2(1000,24))


## R7: 种子 / 每日挑战 page. Daily runs are seeded from the **UTC** date and the
## seed has to be computed by the host (contract v3-2), so this page only arms the
## choice — `start_rogue()` hands it to `session.launch(false, seed)`.
func show_rogue_seed_page() -> void:
	new_page("rogue_seed")
	background(0.8)
	header("种子 · 每日挑战","SEED  /  同一串种子必得同一座魔境")
	label(page,"每日挑战（UTC %s）" % RogueUi.daily_date(),Vector2(82,228),25,GOLD,Vector2(1260,34))
	label(page,"全球统一种子 · 不受本地时区影响 · 由房主在出发时下发\n种子：%s" % RogueUi.daily_share(),Vector2(82,272),18,INK,Vector2(1260,66))
	var daily := button(page,"选择每日挑战",Vector2(82,352),Vector2(320,56),func(): choose_daily_seed(true))
	daily.name="RogueDailyPick"
	label(page,"自定义种子 / 分享串",Vector2(82,440),25,GOLD,Vector2(1260,34))
	label(page,"粘贴 CT-XXXXXXXX-X 分享串，或直接输入 1 ~ 2147483647 的十进制种子。\n0 与空值无效——不会被静默换成随机局。",Vector2(82,484),18,INK,Vector2(1260,62))
	rogue_seed_field=line_edit(page,"",Vector2(82,562),Vector2(520,54),"CT-1A2B3C4D-5 或 123456")
	rogue_seed_field.name="RogueSeedInput"
	var apply := button(page,"使用该种子",Vector2(620,562),Vector2(240,54),apply_custom_seed)
	apply.name="RogueSeedApply"
	var copy := button(page,"复制种子",Vector2(880,562),Vector2(240,54),copy_seed_text)
	copy.name="RogueSeedCopy"
	label(page,"当前已选",Vector2(82,644),20,GOLD,Vector2(1260,30))
	var chosen := label(page,RogueUi.pending_seed_text(rogue_seed_pending,rogue_daily_pending),Vector2(82,678),20,INK,Vector2(1260,34))
	chosen.name="RogueSeedChosen"
	chosen.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var clear := button(page,"清空选择",Vector2(330,813),Vector2(230,56),func():
		rogue_seed_pending=0
		rogue_daily_pending=false
		show_rogue_seed_page()
		notify("已清空种子选择：下次出发随机。")
	)
	clear.name="RogueSeedClear"
	var hint := label(page,RogueUi.seed_hint(),Vector2(82,742),15,MUTED,Vector2(1260,56))
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button(page,"返回魔境",Vector2(82,813),Vector2(230,56),show_rogue_setup)


func choose_daily_seed(value: bool) -> void:
	rogue_daily_pending=value
	rogue_seed_pending=0
	show_rogue_setup()
	if value: notify("已选择每日挑战（UTC %s）· %s" % [RogueUi.daily_date(),RogueUi.daily_share()])


func apply_custom_seed() -> void:
	var text := rogue_seed_field.text if is_instance_valid(rogue_seed_field) else ""
	var problem := RogueUi.seed_error(text)
	if problem!="":
		notify(problem)
		return
	rogue_seed_pending=int(RogueUi.parse_seed(text))
	rogue_daily_pending=false
	show_rogue_setup()
	notify("已选择种子 "+RogueUi.share_of(rogue_seed_pending))


func copy_seed_text() -> void:
	var text := RogueUi.copy_text(rogue_seed_pending,rogue_daily_pending)
	if text=="":
		notify("尚未选择种子或每日挑战。")
		return
	# The headless display server has no clipboard; the test run must not fail on it.
	if DisplayServer.get_name()!="headless":
		DisplayServer.clipboard_set(text)
	notify("已复制种子："+text)


## The seed `start_rogue()` should launch with: the armed custom seed, or the UTC
## daily seed computed here on the host. 0 keeps the engine's random behaviour.
func rogue_launch_seed() -> int:
	if rogue_daily_pending: return int(RogueUi.daily_seed())
	return rogue_seed_pending


## R7: 灰烬成长树. Outside a raid this is a local, immediately-saved profile edit;
## inside a raid it has to go through the revision-guarded action channel instead.
func show_growth_tree() -> void:
	var at := modal_box("灰烬成长树",Vector2(1180,790))
	label(overlay,RogueUi.growth_summary(profile.data),at+Vector2(35,84),20,GOLD,Vector2(1100,30))
	label(overlay,"灰烬来自每局结算（结算点只有一个）。成长树只对后续开局生效，敌人倍率恒不超过 1.0。",at+Vector2(35,120),14,MUTED,Vector2(1100,24))
	rogue_growth_buttons={}
	var rows := RogueUi.growth_rows(profile.data)
	for i in rows.size():
		var row: Dictionary=rows[i]
		var node_id := str(row.id)
		var x := 35+int(i%2)*560
		var y := 158+int(i/2)*62
		label(overlay,"%s  %d / %d" % [row.name,row.level,row.max],at+Vector2(x,y),17,INK,Vector2(320,24))
		label(overlay,str(row.desc),at+Vector2(x,y+22),12,MUTED,Vector2(390,20))
		var buy := button(overlay,RogueUi.growth_button_text(row),at+Vector2(x+404,y),Vector2(140,44),func(): buy_growth_node(node_id))
		buy.name="GrowthBuy_"+node_id
		buy.tooltip_text=RogueUi.growth_reason_text(str(row.reason))
		buy.disabled=not bool(row.can_buy)
		rogue_growth_buttons[node_id]=buy
	label(overlay,"选定节点后立刻扣灰烬并写入存档；满级与前置未满足的节点会显示原因。",at+Vector2(35,742),14,MUTED,Vector2(1100,24))


func buy_growth_node(id: String) -> void:
	var reason := RogueGrowth.can_buy_reason(profile.data,id)
	if reason!="":
		notify(RogueUi.growth_reason_text(reason))
		return
	if not RogueGrowth.buy(profile.data,id):
		notify("购买失败：灰烬不足或前置未满足。")
		return
	# Ash and the growth tree are **client-local profile data**: the purchase takes
	# effect and is saved here, and the current run's enemy scaling was fixed at
	# `reset()` so nothing in the raid changes. In a raid the purchase is additionally
	# announced to the host as an audit event — the payload carries `applied: true`,
	# which forbids the host from charging for it a second time.
	profile.save_profile()
	if session.running and session.roguelike.active(session):
		session.action(RogueUi.ACTION_GROWTH,RogueUi.growth_payload(session.raid,id))
	if camp: camp.update_static()
	show_growth_tree()
	notify("已强化："+RogueGrowth.label(id))


## 五层的节点总数。节点图每层生成 7~10 个节点（由种子决定），所以结算面板的分母
## 必须按本局种子算出来，旧的固定「25 区」是「每层五区」年代的写法。
func rogue_total_nodes() -> int:
	var total := 0
	for floor_index in 5:
		var graph: Dictionary=RogueGraph.build(int(session.seed_value),floor_index+1)
		total+=(graph.get("nodes",{}) as Dictionary).size()
	return maxi(1,total)


func rogue_icon(parent: Node, texture: Texture2D, at: Vector2, dimensions: Vector2) -> TextureRect:
	var node := TextureRect.new()
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	node.texture=texture
	node.position=at
	node.size=dimensions
	node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node
