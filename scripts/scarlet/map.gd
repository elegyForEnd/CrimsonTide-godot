extends Control
## Local floorplan is drawn from exactly the same footprints as movement.
var campaign
var selected:=""
var hover:=""
var pins: Array=[]
var extent:=Vector2(1800,1800)
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_STOP
	if not campaign.state.trial_task.is_empty(): extent.x=2520
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			for pin in pins:
				if local(pin.p).distance_to(event.position)<22: selected=pin.label; queue_redraw(); break)
func local(p: Vector2) -> Vector2: return Vector2(28,55)+(p+Vector2(720 if not campaign.state.trial_task.is_empty() else 0,0))/extent*Vector2(size.x-56,size.y-125)
func _draw() -> void:
	var font: Font=theme.default_font if theme else ThemeDB.fallback_font
	draw_style_box(preload("res://scripts/scarlet/art.gd").frame(Color("181a27")),Rect2(Vector2.ZERO,size))
	draw_string(font,Vector2(24,33),campaign.zone().name,HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("e6d2a8"))
	var geography=campaign.terrain()
	if not campaign.state.trial_task.is_empty():
		draw_rect(Rect2(local(Vector2(-680,200)),Vector2(820,1400)/extent*Vector2(size.x-56,size.y-125)),Color("264651"))
	# Original walkable shoreline and room footprint, including voids and walls.
	for cell in geography.cells:
		draw_rect(Rect2(local(cell-Vector2(10,10)),Vector2(20,20)/extent*Vector2(size.x-56,size.y-125)),Color("494653"))
	for b in campaign.combat.barriers():
		draw_rect(Rect2(local(Vector2(b[0],b[1])),Vector2(b[2],b[3])/extent*Vector2(size.x-56,size.y-125)),Color("997b99"))
	pins=campaign.objective_nodes()
	for i in pins.size():
		var pin: Dictionary=pins[i]
		draw_circle(local(pin.p),7,Color("e2bd72")); draw_string(font,local(pin.p)+Vector2(10,5),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e2bd72"))
	for e in campaign.enemies:
		if e.hp>0: draw_circle(local(e.p),5,Color("c46d88"))
	for person in campaign.escort_group: draw_circle(local(person.p),6,Color("80d5d2") if person.hp>0 else Color("e59a9a"))
	draw_circle(local(campaign.hero_at),7,Color.WHITE)
	draw_circle(local(campaign.gate_at()),10,Color("b8a6cf"),false,2)
	draw_string(font,Vector2(25,size.y-43),"白：小队  金：交互  青：同行者  紫环：路口",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("b6b2c3"))
	draw_string(font,Vector2(25,size.y-17),selected if selected!="" else "点击金色标记查看目标名称",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e2cfad"))
