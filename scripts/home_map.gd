extends Control
## Live plan of the authored village; geometry and destinations come from the site.
const HearthSkin = preload("res://scripts/home_ui_skin.gd")
const WORLD_RECT := Rect2(1050,1250,3900,3600)
const IMAGE_RECT := Rect2(104,114,660,660)
var camp: Control
var hovered := ""
var detail: Label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_font_override("font",load("res://assets/NotoSansSC.ttf"))
	var background := ColorRect.new()
	background.color = Color(0.015,0.006,0.016,0.97)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var art := MapCanvas.new()
	art.site = camp.site
	art.position = IMAGE_RECT.position
	art.size = IMAGE_RECT.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var hotspots := Control.new()
	hotspots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hotspots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotspots.draw.connect(draw_hotspots.bind(hotspots))
	add_child(hotspots)
	for station in camp.site.stations:
		var id: String = station.id
		var button := Button.new()
		button.text = station.name
		HearthSkin.dress(button)
		var index: int = station.no.to_int()-1
		button.position = Vector2(830+(index%2)*230,226+int(index/2)*84)
		button.size = Vector2(216,68)
		button.add_theme_font_size_override("font_size",18)
		button.pressed.connect(func(): travel(id))
		button.mouse_entered.connect(func(): hovered=id; hotspots.queue_redraw(); update_detail())
		button.mouse_exited.connect(func(): hovered=""; hotspots.queue_redraw())
		add_child(button)
	var heading := Label.new()
	heading.text = "晨钟家园"
	heading.position = Vector2(830,114)
	heading.add_theme_font_size_override("font_size",30)
	heading.add_theme_color_override("font_color",Color("ddd0ca"))
	add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "月下圣域 · 开放庭院与城堡回廊"
	subtitle.position = Vector2(830,164)
	subtitle.add_theme_font_size_override("font_size",16)
	subtitle.add_theme_color_override("font_color",Color("a599a4"))
	add_child(subtitle)
	detail = Label.new()
	detail.position = Vector2(830,676)
	detail.size = Vector2(440,70)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_color_override("font_color",Color("ddd0ca"))
	detail.add_theme_font_size_override("font_size",17)
	add_child(detail)
	var close_button := Button.new()
	close_button.text = "返回"
	HearthSkin.dress(close_button)
	close_button.position = Vector2(830,742)
	close_button.size = Vector2(440,42)
	close_button.pressed.connect(close)
	add_child(close_button)
	var info := HearthSkin.info(self,camp,"地图导览","点击地图编号或设施名称，直接前往。抵达后按 E 使用。\nM / Esc 返回家园。\n菜园用于播种与收获；栈桥用于钓鱼；商店购置种子与渔具；厨房准备出征料理。\n会议桌整备小队，锻炉升级天赋，军需补充物资，书匣打开手册，闸门通往远征。")
	info.position = Vector2(1232,126)
	visible = false

func draw_hotspots(canvas: Control) -> void:
	for station in camp.site.stations:
		var at: Vector2 = map_spot(station.id)
		var color: Color = station.tint
		canvas.draw_circle(at,18,Color(0.02,0.055,0.04,0.9))
		canvas.draw_arc(at,19,0,TAU,32,color,2,true)
		if hovered==station.id: canvas.draw_arc(at,25,0,TAU,32,Color("e4b3bc"),3,true)
		canvas.draw_string(load("res://assets/NotoSansSC.ttf"),at+Vector2(-10,6),station.no,HORIZONTAL_ALIGNMENT_LEFT,-1,17,color)

func update_detail() -> void:
	var station: Dictionary = camp.site.station_by_id(hovered)
	detail.text = str(station.name) if not station.is_empty() else ""

func open() -> void:
	get_child(1).queue_redraw()
	visible = true
	camp.input_blocked = true
	camp.site.hero_walking = false
	update_detail()

func close() -> void:
	visible = false
	camp.input_blocked = false

func travel(id: String) -> void:
	camp.warp_to(id)
	close()
	camp.say("已抵达 "+str(camp.site.station_by_id(id).name))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for station in camp.site.stations:
			var id: String = station.id
			if event.position.distance_to(map_spot(id))<32:
				travel(id)
				accept_event()
				return

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode in [KEY_M,KEY_ESCAPE]:
		close()
		get_viewport().set_input_as_handled()

func map_spot(id: String) -> Vector2:
	var station: Dictionary = camp.site.station_by_id(id)
	return IMAGE_RECT.position+(station.at+station.offset-WORLD_RECT.position)/WORLD_RECT.size*IMAGE_RECT.size

class MapCanvas extends Control:
	var site: Node3D
	func mapped(at: Vector2) -> Vector2:
		return (at-WORLD_RECT.position)/WORLD_RECT.size*size
	func mapped_rect(rect: Rect2) -> Rect2:
		return Rect2(mapped(rect.position),rect.size/WORLD_RECT.size*size)
	func _draw() -> void:
		draw_style_box(frame(),Rect2(Vector2.ZERO,size))
		var walls := PackedVector2Array([mapped(Vector2(2550,4770)),mapped(Vector2(1150,4770)),mapped(Vector2(1150,1300)),mapped(Vector2(4850,1300)),mapped(Vector2(4850,4770)),mapped(Vector2(3050,4770))])
		draw_polyline(walls,Color("92838d"),4,true)
		for path in site.PATHS:
			draw_rect(mapped_rect(path),Color("5b586c"))
		draw_rect(mapped_rect(Rect2(2280,2955,1040,470)),Color("736b7a"))
		var shore := PackedVector2Array()
		for at in site.SHORE: shore.append(mapped(at))
		draw_colored_polygon(shore,Color("293e58"))
		draw_polyline(shore,Color("636d88"),3,true)
		draw_rect(mapped_rect(site.DOCK),Color("766778"))
		for i in 9:
			draw_rect(mapped_rect(Rect2(site.garden_at(i)-Vector2(101,92),Vector2(202,185))),Color("6c513b"))
		for station in site.architecture.open_stations:
			var pad := mapped_rect(station.rect)
			draw_rect(pad,Color("534b62"))
			if station.canopy:
				draw_rect(Rect2(pad.position,Vector2(pad.size.x,8)),Color("793b50"))
		for building in site.architecture.buildings:
			var box := mapped_rect(building.rect)
			draw_rect(box.grow(2),Color("352f2a"))
			draw_rect(box,Color("7d6878"))
			draw_rect(Rect2(box.position,Vector2(box.size.x,5)),Color("944b48"))
			var door := mapped(building.door)
			draw_line(door-Vector2(9,0),door+Vector2(9,0),Color("ede0b7"),5,true)
		draw_circle(mapped(site.hero_at),7,Color("f5e5ba"))
		draw_arc(mapped(site.hero_at),11,0,TAU,24,Color("f5e5ba"),2,true)
		var font: Font = load("res://assets/NotoSansSC.ttf")
		draw_string(font,Vector2(22,32),"北 · 圣堂回廊 / 厨房",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("eadcc0"))
		draw_string(font,Vector2(22,size.y-20),"南 · 出征闸门     浅色缺口为房屋入口",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("eadcc0"))
	func frame() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("1e2131")
		style.border_color = Color("bba37d")
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		return style
