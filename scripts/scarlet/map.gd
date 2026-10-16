extends Control
## Actual scene photography with live authoritative overlays in both map views.
signal open_requested
var campaign
var capture
var navigator
var compact := false
var selected := ""
var pins: Array=[]
var extent := Vector2(1800,1800)
var timer := 0.0

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_STOP
	clip_contents=true
	gui_input.connect(select_pin)

func map_rect() -> Rect2:
	var area := Rect2(10,34,size.x-20,size.y-62) if compact else Rect2(20,53,size.x-40,size.y-132)
	var side := minf(area.size.x,area.size.y)
	return Rect2(area.get_center()-Vector2.ONE*side*.5,Vector2.ONE*side)

func local(p: Vector2) -> Vector2:
	var rect := map_rect()
	var geo=campaign.terrain()
	var start := Vector2(-720,0) if not campaign.state.trial_task.is_empty() else Vector2.ZERO
	var native_extent: Vector2=geo.region.extent-start*geo.ratio
	var side: float=maxf(native_extent.x,native_extent.y)
	return rect.position+((p-start)*geo.ratio+(Vector2.ONE*side-native_extent)*.5)/side*rect.size

func select_pin(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT: return
	if compact: open_requested.emit(); accept_event(); return
	var best := 22.0
	for pin in pins:
		var distance := local(pin.p).distance_to(event.position)
		if distance<best: best=distance; selected=pin.label
	queue_redraw(); accept_event()

func _process(dt: float) -> void:
	if not is_visible_in_tree() or campaign.state.is_empty(): return
	timer-=dt
	if timer<=0: timer=.1; queue_redraw()

func _draw() -> void:
	if campaign.state.is_empty(): return
	var font: Font=theme.default_font if theme else ThemeDB.fallback_font
	draw_style_box(preload("res://scripts/scarlet/art.gd").frame(Color("181a27")),Rect2(Vector2.ZERO,size))
	draw_string(font,Vector2(12,24) if compact else Vector2(24,33),campaign.zone().name,HORIZONTAL_ALIGNMENT_LEFT,size.x-50,15 if compact else 21,Color("e6d2a8"))
	var rect := map_rect()
	if capture and capture.texture:
		draw_texture_rect(capture.texture,rect,false)
	else:
		for cell in campaign.terrain().cells:
			draw_rect(Rect2(local(cell-Vector2(10,10)),local(cell+Vector2(10,10))-local(cell-Vector2(10,10))),Color("494653"))
	draw_rect(rect,Color("66566e"),false,1)
	if navigator and navigator.path.size()>1:
		var line := PackedVector2Array()
		for p in navigator.path: line.append(local(p))
		draw_polyline(line,Color(0,0,0,.8),4 if compact else 6,true)
		draw_polyline(line,Color("f5d590"),1.5 if compact else 2.5,true)
	for b in campaign.combat.barriers():
		draw_rect(Rect2(local(Vector2(b[0],b[1])),local(Vector2(b[0]+b[2],b[1]+b[3]))-local(Vector2(b[0],b[1]))),Color("c877a0"))
	pins=campaign.objective_nodes()
	for pin in pins:
		var tracked: bool=pin.get("qid","")==campaign.tracked().get("id","~")
		var color := Color("ffe1a0") if tracked else Color("cba974")
		if pin.kind in ["original_portal","travel"]: color=Color("b7a2eb")
		if pin.kind in ["rest","forge","inventory"]: color=Color("8cbfce")
		var at := local(pin.p)
		draw_circle(at,5 if compact else 7,Color("161722"))
		draw_circle(at,3 if compact else 5,color)
		if tracked: draw_arc(at,8 if compact else 11,0,TAU,24,color,1.5,true)
	for e in campaign.enemies:
		if e.hp>0: draw_circle(local(e.p),3 if compact else 5,Color("e86888"))
	for person in campaign.escort_group: draw_circle(local(person.p),3 if compact else 6,Color("80d5d2") if person.hp>0 else Color("e59a9a"))
	draw_circle(local(campaign.gate_at()),5 if compact else 9,Color("b8a6cf"),false,1.5)
	if navigator and not navigator.target.is_empty():
		var at := local(navigator.target.p)
		draw_polyline(PackedVector2Array([at+Vector2(0,-9),at+Vector2(7,0),at+Vector2(0,9),at+Vector2(-7,0),at+Vector2(0,-9)]),Color("ffe4a4"),2,true)
	var hero := local(campaign.hero_at)
	var direction: Vector2=campaign.facing.normalized()
	var perpendicular := Vector2(-direction.y,direction.x)
	draw_circle(hero,7 if compact else 9,Color("101a28"))
	draw_colored_polygon(PackedVector2Array([hero+direction*9,hero-direction*5+perpendicular*5,hero-direction*5-perpendicular*5]),Color("e5ffff"))
	draw_string(font,rect.position+Vector2(5,17),"N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
	if compact:
		draw_string(font,Vector2(12,size.y-10),"实景俯视 · 点击展开",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("b6b2c3"))
	else:
		draw_string(font,Vector2(20,size.y-55),"白：小队  金：任务／路线  红：敌人",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d9cfbf"))
		draw_string(font,Vector2(20,size.y-34),"青：服务  紫：入口／路标  ◇：追踪目标",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("b6b2c3"))
		draw_string(font,Vector2(20,size.y-12),selected if selected!="" else "点击标记查看名称 · 地形取自实际关卡场景",HORIZONTAL_ALIGNMENT_LEFT,size.x-40,14,Color("e2cfad"))
