extends Control
## Godot native drag/drop. Payload carries an instance id, never an array index.
const Items = preload("res://scripts/story_inventory.gd")
const UISkin = preload("res://scripts/story_ui_skin.gd")
var ui
var source := "bag"
var grid_size := Items.BAG
var cell := 48.0
var equipment_slot := ""
var drop_cell := Vector2i(-1,-1)
var drop_valid := false

func entries() -> Array:
	if source.begins_with("equipped:"):
		var parts := source.split(":")
		var item: Dictionary=ui.campaign.state.equipment[int(parts[1])].get(parts[2],{})
		return [] if item.is_empty() else [item]
	return ui.campaign.state[source]

func hit(at: Vector2) -> Dictionary:
	if source.begins_with("equipped:"): return entries()[0] if not entries().is_empty() else {}
	var point := Vector2i(at/cell)
	for item in entries():
		if Items.rect(item).has_point(point): return item
	return {}

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_STOP
	size=Vector2(grid_size)*cell
	set_process(true)

func _process(_dt: float) -> void:
	if not get_viewport().gui_is_dragging() and drop_cell.x>=0: drop_cell=Vector2i(-1,-1); queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var item := hit(event.position)
		tooltip_text=Items.describe(item) if not item.is_empty() else ""
	if event is InputEventMouseButton and event.pressed:
		var item := hit(event.position)
		if item.is_empty(): return
		ui.select(source,str(item.uid))
		if event.button_index==MOUSE_BUTTON_RIGHT or (event.button_index==MOUSE_BUTTON_LEFT and event.double_click): ui.quick_action(source,str(item.uid))
		accept_event()

func _get_drag_data(at: Vector2) -> Variant:
	var item := hit(at)
	if item.is_empty(): return null
	ui.select(source,str(item.uid))
	var offset := Vector2i.ZERO if source.begins_with("equipped:") else Vector2i(at/cell)-Vector2i(int(item.x),int(item.y))
	var data := {"story_item":true,"source":source,"uid":str(item.uid),"offset":offset,"rotated":bool(item.rotated)}
	var preview := DragPreview.new(); preview.data=data; preview.item=item; preview.ui=ui
	set_drag_preview(preview)
	return data

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.get("story_item",false): return false
	if source.begins_with("equipped:"):
		var parts := source.split(":")
		drop_valid=ui.inventory.can_equip(str(data.source),str(data.uid),int(parts[1]),parts[2])
		drop_cell=Vector2i.ZERO
	else:
		drop_cell=Vector2i(at/cell)-Vector2i(data.offset)
		drop_valid=not ui.inventory.plan_move(str(data.source),str(data.uid),source,drop_cell,bool(data.rotated)).is_empty()
	queue_redraw(); return drop_valid

func _drop_data(at: Vector2, data: Variant) -> void:
	if not _can_drop_data(at,data): return
	if source.begins_with("equipped:"):
		var parts := source.split(":")
		ui.perform(func(): return ui.inventory.equip(str(data.source),str(data.uid),int(parts[1]),parts[2]))
	else: ui.perform(func(): return ui.inventory.move(str(data.source),str(data.uid),source,drop_cell,bool(data.rotated)))

func _draw() -> void:
	for y in grid_size.y:
		for x in grid_size.x:
			var box := Rect2(Vector2(x,y)*cell,Vector2.ONE*(cell-1))
			draw_style_box(UISkin.frame(1 if source.begins_with("equipped:") else 0),box)
	for item in entries():
		var box := Rect2(Vector2.ZERO,size) if source.begins_with("equipped:") else Rect2(Vector2(int(item.x),int(item.y))*cell,Vector2(Items.dimensions(item))*cell)
		# One recessed footprint for an item; internal cell borders must not cut through it.
		draw_style_box(UISkin.frame(1 if source.begins_with("equipped:") else 0),box.grow(-1))
		var color := Items.tone(item)
		draw_rect(box.grow(-2),Color(color.r,color.g,color.b,0.09))
		draw_rect(box.grow(-2),Color(color.r,color.g,color.b,0.6),false,1)
		var selected: bool=ui.selected_source==source and ui.selected_uid==str(item.uid)
		if selected: draw_rect(box.grow(-1),Color("f0cf8e"),false,2)
		ui.draw_icon(self,item,box.grow(-4))
		if int(item.count)>1: draw_string(get_theme_default_font(),box.end-Vector2(21,7),str(item.count),HORIZONTAL_ALIGNMENT_RIGHT,-1,15,Color("fff1cf"))
		if int(item.upgrade)>0: draw_string(get_theme_default_font(),box.position+Vector2(5,18),"+%d" % item.upgrade,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f2d194"))
	if drop_cell.x>=0 and get_viewport().gui_is_dragging():
		var data: Variant=get_viewport().gui_get_drag_data()
		if data is Dictionary and data.get("story_item",false):
			var item: Dictionary=ui.inventory.item_at(str(data.source),str(data.uid)).duplicate(true)
			item.rotated=bool(data.rotated)
			var extent := Vector2.ONE if source.begins_with("equipped:") else Vector2(Items.dimensions(item))
			draw_rect(Rect2(Vector2(drop_cell)*cell,extent*cell),Color(0.3,0.8,0.5,0.3) if drop_valid else Color(0.9,0.25,0.25,0.4))

class DragPreview extends Control:
	var data: Dictionary
	var item: Dictionary
	var ui
	func _ready() -> void: mouse_filter=MOUSE_FILTER_IGNORE; set_process(true)
	func _process(_dt: float) -> void: queue_redraw()
	func _draw() -> void:
		var copy := item.duplicate(true); copy.rotated=bool(data.rotated)
		var extent := Vector2(Items.dimensions(copy))*40
		var box := Rect2(-Vector2(data.offset)*40,extent)
		draw_rect(box,Color(0.06,0.08,0.12,0.94)); draw_rect(box,Items.tone(copy),false,2)
		ui.draw_icon(self,copy,box.grow(-3))
