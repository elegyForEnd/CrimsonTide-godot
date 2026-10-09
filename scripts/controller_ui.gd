extends RefCounted

var pointer := false
var pressed: Control
var repeat_direction := Vector2.ZERO
var repeat_time := 0.0
var scope_id := 0
var focus_key := ""
var ribbon: Label
var frame: Panel
var layer: CanvasLayer

func scope(app) -> Control:
	if app.inventory_open and is_instance_valid(app.rogue_inventory.menu): return app.rogue_inventory.menu
	if app.modal or app.inventory_open or app.camp_pack_open: return app.overlay
	if app.page_name=="ground" and app.camp:
		if app.camp.home_ui.visible: return app.camp.home_ui
		if app.camp.home_map.visible: return app.camp.home_map
		return null
	if app.field.map_open and app.session.roguelike.active(app.session): return app.rogue_map_screen
	if app.page_name=="game":
		if app.rogue_panel_open or not app.session.players.get(app.session.my_id(),{}).get("rogue_selection",{}).is_empty(): return app.rogue_panel
		return null
	return app.page

func collect(node: Node, result: Array[Control]) -> void:
	if node.is_queued_for_deletion(): return
	if node is Control and not node.is_visible_in_tree(): return
	if node is BaseButton:
		if not node.disabled:
			node.focus_mode=Control.FOCUS_ALL
			result.append(node)
	elif node is Slider or node is LineEdit or node.has_meta("controller_item"):
		node.focus_mode=Control.FOCUS_ALL
		result.append(node)
	for child in node.get_children(): collect(child,result)

func key(node: Control) -> String:
	return str(node.name)+"|"+(str(node.text) if node is BaseButton else str(node.position))

func focus_to(app, target: Control) -> void:
	target.focus_mode=Control.FOCUS_ALL
	target.grab_focus()
	focus_key=key(target)
	var parent := target.get_parent()
	while parent:
		if parent is ScrollContainer: parent.ensure_control_visible(target)
		parent=parent.get_parent()
	var point := target.get_global_transform_with_canvas()*(target.size*0.5)
	app.controller.cursor_position=point
	app.controller.cursor_valid=true
	app.controller.warp_point=point
	app.controller.warp_until=Time.get_ticks_msec()+80
	var motion := InputEventMouseMotion.new()
	motion.device=-2; motion.position=point; motion.global_position=point
	app.controller.prepare_pointer(app)
	app.get_viewport().call_deferred("push_input",motion,true)

func ensure_focus(app) -> Control:
	var owner := scope(app)
	if not is_instance_valid(owner): return null
	var controls: Array[Control]=[]
	collect(owner,controls)
	if controls.is_empty(): return null
	if scope_id!=owner.get_instance_id():
		scope_id=owner.get_instance_id(); focus_key=""; pointer=false; pressed=null; repeat_direction=Vector2.ZERO
	var focused: Control=app.get_viewport().gui_get_focus_owner()
	if focused in controls: return focused
	for control in controls:
		if focus_key!="" and key(control)==focus_key:
			focus_to(app,control); return control
	var target: Control=controls[0]
	for control in controls:
		if control is BaseButton and ("返回" in control.text or control.text in ["关闭","关闭 ×"]): continue
		target=control; break
	focus_to(app,target)
	return target

func navigate(app, direction: Vector2) -> void:
	pointer=false
	var focused := ensure_focus(app)
	if not focused: return
	var neighbor: NodePath=focused.focus_neighbor_left if direction.x<0 else focused.focus_neighbor_right if direction.x>0 else focused.focus_neighbor_top if direction.y<0 else focused.focus_neighbor_bottom
	if not neighbor.is_empty():
		var explicit: Control=focused.get_node_or_null(neighbor)
		if is_instance_valid(explicit) and explicit.is_visible_in_tree() and (not explicit is BaseButton or not explicit.disabled):
			focus_to(app,explicit); return
	if focused is Slider and direction.x!=0:
		focused.value+=signf(direction.x)*maxf(focused.step,(focused.max_value-focused.min_value)*0.05)
		return
	var controls: Array[Control]=[]
	collect(scope(app),controls)
	var origin := focused.get_global_transform_with_canvas()*(focused.size*0.5)
	var best: Control
	var best_score := INF
	for control in controls:
		if control==focused: continue
		var offset := control.get_global_transform_with_canvas()*(control.size*0.5)-origin
		var forward := offset.dot(direction)
		if forward<=3: continue
		var across := absf(offset.cross(direction))
		var score := forward+across*3.0+across*across/maxf(forward,1.0)
		if score<best_score: best_score=score; best=control
	if best: focus_to(app,best)

func activate(app, node: Control) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_visible_in_tree(): return
	if node is BaseButton:
		if node.disabled: return
		if node.toggle_mode: node.button_pressed=not node.button_pressed
		node.pressed.emit()
	elif node is LineEdit:
		node.grab_focus()
	elif node.has_meta("controller_item"):
		# List-style rogue items expose their actions on right click.
		if node.get_meta("controller_item")=="rogue":
			var event := InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_RIGHT; event.pressed=true; event.position=node.size*0.5
			node.gui_input.emit(event)
		else:
			app.controller.mouse_button(app,MOUSE_BUTTON_LEFT,true)
			app.controller.mouse_button(app,MOUSE_BUTTON_LEFT,false)

func back(app) -> void:
	if app.inventory_open and is_instance_valid(app.rogue_inventory.menu):
		app.rogue_inventory.close_menu(); return
	if app.modal: app.close_modal(); return
	if app.inventory_open or app.camp_pack_open: app.close_bag(); return
	if app.page_name=="ground" and app.camp:
		if app.camp.home_ui.visible: app.camp.home_ui.close(); return
		if app.camp.home_map.visible: app.camp.home_map.close(); return
	if app.page_name=="game":
		var pause := InputEventAction.new(); pause.action="pause"; pause.pressed=true
		app._unhandled_input(pause); return
	var controls: Array[Control]=[]
	var owner := scope(app)
	if owner: collect(owner,controls)
	for control in controls:
		if control is BaseButton and ("返回" in control.text or control.text=="取消"):
			activate(app,control); return
	if app.page_name!="title": app.show_title()

func handle(app, event: InputEvent) -> bool:
	if app.field.map_open and not app.session.roguelike.active(app.session) and event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]:
		if event.pressed: app.field.map_filter=(app.field.map_filter+(1 if event.button_index==JOY_BUTTON_DPAD_RIGHT else 3))%4
		return true
	var owner := scope(app)
	if not is_instance_valid(owner): return false
	if event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
			var direction := Vector2(signf(event.axis_value),0) if event.axis==JOY_AXIS_LEFT_X else Vector2(0,signf(event.axis_value))
			if absf(event.axis_value)<0.5:
				if (event.axis==JOY_AXIS_LEFT_X and repeat_direction.x!=0) or (event.axis==JOY_AXIS_LEFT_Y and repeat_direction.y!=0): repeat_direction=Vector2.ZERO
			elif direction!=repeat_direction:
				navigate(app,direction); repeat_direction=direction; repeat_time=0.35
			return true
		if event.axis in [JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y] and absf(event.axis_value)>0.22:
			pointer=true; pressed=null
			var focused: Control=app.get_viewport().gui_get_focus_owner()
			if focused: focused.release_focus()
		return false
	if event is InputEventJoypadButton:
		if event.button_index==JOY_BUTTON_B:
			if event.pressed: back(app)
			return true
		var directions := {JOY_BUTTON_DPAD_UP:Vector2.UP,JOY_BUTTON_DPAD_DOWN:Vector2.DOWN,JOY_BUTTON_DPAD_LEFT:Vector2.LEFT,JOY_BUTTON_DPAD_RIGHT:Vector2.RIGHT}
		if event.button_index in directions:
			if event.pressed: navigate(app,directions[event.button_index]); repeat_direction=directions[event.button_index]; repeat_time=0.35
			else: repeat_direction=Vector2.ZERO
			return true
		if event.button_index==JOY_BUTTON_A and not pointer:
			if event.pressed: pressed=ensure_focus(app)
			else:
				var target := pressed; pressed=null
				if is_instance_valid(target) and (owner==target or owner.is_ancestor_of(target)): activate(app,target)
			return true
		if event.button_index==JOY_BUTTON_X and not pointer:
			var focused := ensure_focus(app)
			if event.pressed and focused and focused.has_meta("controller_item"):
				if focused.get_meta("controller_item")=="rogue": activate(app,focused)
				else: app.controller.mouse_button(app,MOUSE_BUTTON_RIGHT,true)
			elif not event.pressed and app.controller.mouse_buttons & MOUSE_BUTTON_MASK_RIGHT: app.controller.mouse_button(app,MOUSE_BUTTON_RIGHT,false)
			return true
	return false

func glyphs(app) -> Dictionary:
	var name := Input.get_joy_name(app.controller.device).to_lower() if app.controller.device>=0 else ""
	var sony := "sony" in name or "dualsense" in name or "dualshock" in name or "playstation" in name or "ps5" in name or "ps4" in name
	return {"a":"×" if sony else "A","b":"○" if sony else "B","x":"□" if sony else "X","y":"△" if sony else "Y","rt":"R2" if sony else "RT","lt":"L2" if sony else "LT","lb":"L1" if sony else "LB","rb":"R1" if sony else "RB","back":"Share" if sony else "View","start":"Options" if sony else "Menu"}

func hints(app) -> String:
	var g := glyphs(app)
	if app.field.map_open and not app.session.roguelike.active(app.session):
		return "右摇杆 地图光标   %s 标记   左右 切换地图分类   %s 返回" % [g.a,g.b]
	if scope(app)!=null:
		if pointer: return "右摇杆 光标   %s 点击/按住拖拽   %s 右键   十字键 切回选择   %s 返回   %s 旋转" % [g.a,g.x,g.b,g.y]
		return "十字键 / 左摇杆 选择   %s 确认   %s 返回   右摇杆 切换光标   %s 物品操作   左右 调节滑杆" % [g.a,g.b,g.x]
	if app.page_name=="ground": return "左摇杆 移动   %s 互动/收线   %s 出发/甩竿   %s 种子   %s 行囊   R3 地图   %s 返回" % [g.a,g.y,g.lb,g.back,g.b]
	return "LS 移动  RS 瞄准   %s 轻击   %s 重击/蓄力   %s 点按闪避/长按跑   %s 跳跃   %s 互动   %s 战技   %s 奥义   %s 装填   ↓ 道具   %s 行囊   R3 地图" % [g.rb,g.rt,g.b,g.a,g.y,g.lt,g.lb,g.x,g.back]

func prompt_text(app, original: String) -> String:
	if not app.controller.active: return original
	var g := glyphs(app)
	var converted := original
	var interact: String=g.a if app.page_name=="ground" else g.y
	for pair in [["[Space / E]","["+g.a+"]"],["[E]","["+interact+"]"],["按 E","按 "+interact],["E 开",interact+" 开"],["E开",interact+"开"],["E 选",interact+" 选"],["E 交",interact+" 交"],["[F]","[↓]"],["F  喝","↓  喝"],["F  魂灯","↓  魂灯"],["F饮用","↓饮用"],["F魂灯","↓魂灯"],["F 血瓶","↓ 血瓶"],["F血瓶","↓血瓶"],["Q奥义",g.lb+"奥义"],["Space闪避",g.b+"闪避"],["E救援",interact+"救援"],["[Tab]","["+g.back+"]"],["TAB",g.back],["Tab",g.back],["[Esc]","["+g.b+"]"],["[ESC]","["+g.b+"]"],["[右键]","["+g.lt+"]"],["WASD","左摇杆"],["SHIFT",g.b+"长按"],["鼠标攻击",g.rb+"轻击 / "+g.rt+"重击"],["右键 战技",g.lt+" 战技"],["SPACE 闪避",g.b+" 闪避"],["C跃起",g.a+"跃起"],["C 跃起",g.a+" 跃起"],["地图  M","地图  R3"],["地图 M","地图 R3"]]:
		converted=converted.replace(pair[0],pair[1])
	if app.page_name=="ground": converted=converted.replace("[E / Space]","["+g.y+"]").replace("[Space]","["+g.y+"]").replace("Space",g.y).replace("[Q]","["+g.lb+"]")
	return converted

func convert_prompts(app, node: Node) -> void:
	if node.is_queued_for_deletion(): return
	if node is Label or node is Button:
		var current: String=node.text
		var last: String=node.get_meta("controller_prompt_last","")
		var original: String=node.get_meta("controller_prompt_original",current)
		if current!=last: original=current
		var converted := last if current==last and bool(node.get_meta("controller_prompt_active",not app.controller.active))==app.controller.active else prompt_text(app,original)
		node.set_meta("controller_prompt_active",app.controller.active)
		node.set_meta("controller_prompt_original",original)
		node.set_meta("controller_prompt_last",converted)
		if node.text!=converted: node.text=converted
	for child in node.get_children(): convert_prompts(app,child)

func tick(app, dt: float) -> void:
	if not is_instance_valid(app) or not app.is_inside_tree(): return
	if not is_instance_valid(ribbon):
		layer=CanvasLayer.new(); layer.layer=80; app.add_child(layer)
		frame=Panel.new(); frame.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(frame)
		var border := StyleBoxFlat.new(); border.bg_color=Color(0,0,0,0); border.border_color=Color("f5ce87"); border.set_border_width_all(3); border.set_corner_radius_all(5)
		frame.add_theme_stylebox_override("panel",border)
		ribbon=Label.new(); ribbon.name="ControllerHints"; ribbon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		ribbon.add_theme_font_override("font",load("res://assets/NotoSansSC.ttf")); ribbon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		ribbon.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		ribbon.add_theme_color_override("font_color",Color("eee5e1"))
		var background := StyleBoxFlat.new(); background.bg_color=Color("101019ee"); background.content_margin_left=10; background.content_margin_right=10
		ribbon.add_theme_stylebox_override("normal",background); layer.add_child(ribbon)
	ribbon.visible=app.controller.active; frame.hide()
	convert_prompts(app,app.page); convert_prompts(app,app.overlay)
	convert_prompts(app,app.toast)
	if app.camp and app.page_name=="ground": convert_prompts(app,app.camp)
	if not app.controller.active: return
	var view: Vector2=app.get_viewport().get_visible_rect().size
	ribbon.position=Vector2(0,view.y-30); ribbon.size=Vector2(view.x,30)
	ribbon.text=hints(app)
	var font_size := clampi(int(view.x/80.0),14,20)
	var width: float=ribbon.get_theme_font("font").get_string_size(ribbon.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	if width>view.x-24: font_size=maxi(12,int(font_size*(view.x-24)/width))
	ribbon.add_theme_font_size_override("font_size",font_size)
	if not pointer and scope(app)!=null:
		var focused := ensure_focus(app)
		if focused:
			var transform := focused.get_global_transform_with_canvas()
			frame.position=transform*Vector2.ZERO-Vector2(3,3); frame.size=focused.size*transform.get_scale()+Vector2(6,6); frame.show()
		if not repeat_direction.is_zero_approx():
			repeat_time-=dt
			if repeat_time<=0: navigate(app,repeat_direction); repeat_time=0.14
