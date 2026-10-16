extends Control
const Art=preload("res://scripts/scarlet/art.gd")
const Diagram=preload("res://scripts/scarlet/fieldwork_art.gd")
const GOLD:=Color("dbbd85")
const TEAL:=Color("92cebd")
var screen
var activity
var panel: Panel
var part_buttons: Array[Button]=[]
var order: Array[int]=[]
var title_label: Label
var body: Label
var result: Label
var counter: Label
var gauge_caption: Label
var action: Button
var submit_button: Button
var relaxed_box: CheckBox
var mouse_holding:=false
var transition:=0.0
var gauge: Control
var adjustment_buttons: Array[Button]=[]
var adjustment_direction:=0.0

func _ready() -> void:
	theme=Art.theme()
	size=Vector2(1440,900); mouse_filter=MOUSE_FILTER_STOP
	var shade:=ColorRect.new(); shade.size=size; shade.color=Color(.014,.019,.03,.75); add_child(shade)
	panel=Panel.new(); panel.position=Vector2(112,94); panel.size=Vector2(1216,710)
	panel.add_theme_stylebox_override("panel",Art.frame(Color("151c25"),Color("8f7955"),10)); add_child(panel)
	var n: Dictionary=activity.active; var p: Dictionary=activity.profile()
	text(n.label,Vector2(30,24),Vector2(1040,42),28,GOLD)
	text(p.subtitle+"   /   "+screen.campaign.zone().name,Vector2(32,70),Vector2(1040,28),16,Color("99aaa9"))
	var exit_button:=button("暂离 · Esc",Vector2(1052,25),Vector2(134,42),activity.cancel)
	exit_button.tooltip_text="已完成的部位会保留；未完成的动作需要重新稳定。"
	var board:=Panel.new(); board.position=Vector2(28,112); board.size=Vector2(608,450)
	board.add_theme_stylebox_override("panel",Art.frame(Color("1b242c"),Color("49544f"),4)); panel.add_child(board)
	var illustration:=Diagram.new(); illustration.size=board.size; illustration.activity=activity; board.add_child(illustration)
	order.assign([0,1,2])
	if p.mode=="procedure":
		# Fixed spatial order per object; never reshuffles after an operation or reload.
		var rotation:=int(str(n.id).hash()%3)
		order.assign([rotation,(rotation+2)%3,(rotation+1)%3])
	var positions: Array=[Vector2(14,27),Vector2(378,27),Vector2(44,372)]
	for slot in 3:
		var index: int=order[slot]
		var b:=Button.new(); b.position=positions[slot]; b.size=Vector2(215,55); b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; b.add_theme_font_size_override("font_size",16)
		b.pressed.connect(func(): mouse_holding=false; activity.select_part(index)); board.add_child(b); part_buttons.append(b)
	text("部位快捷键  1 / 2 / 3\n已查证的细节与已完成的工序会自动保存。",Vector2(35,584),Vector2(597,64),17,Color("9baaa6"))
	counter=text("",Vector2(666,112),Vector2(486,28),16,TEAL)
	title_label=text("",Vector2(666,152),Vector2(486,64),24,GOLD)
	body=text("",Vector2(666,223),Vector2(486,101),18)
	result=text("",Vector2(666,335),Vector2(486,104),17)
	gauge_caption=text("",Vector2(666,451),Vector2(486,25),15,TEAL)
	action=button("",Vector2(666,522),Vector2(486,48),func():
		if activity.calibration(): activity.press())
	action.button_down.connect(func(): mouse_holding=true)
	action.button_up.connect(func(): mouse_holding=false)
	for direction in [-1,1]:
		var adjust_button:=button("◀  A 微调" if direction<0 else "微调 D  ▶",Vector2(666 if direction<0 else 1038,477),Vector2(114,29),func(): activity.adjust(direction*.045))
		adjust_button.add_theme_font_size_override("font_size",14)
		adjust_button.button_down.connect(func(): adjustment_direction=float(direction))
		adjust_button.button_up.connect(func(): adjustment_direction=0)
		adjustment_buttons.append(adjust_button)
	relaxed_box=CheckBox.new(); relaxed_box.position=Vector2(666,575); relaxed_box.size=Vector2(486,29); relaxed_box.text="宽松校准 · 更慢指针，更宽安全区"; relaxed_box.add_theme_font_size_override("font_size",16)
	relaxed_box.button_pressed=activity.relaxed(); relaxed_box.toggled.connect(activity.set_relaxed); panel.add_child(relaxed_box)
	submit_button=button("",Vector2(666,625),Vector2(486,51),activity.submit)
	activity.updated.connect(refresh); refresh()
	gauge=Control.new(); gauge.mouse_filter=MOUSE_FILTER_IGNORE; panel.add_child(gauge); gauge.draw.connect(draw_gauge)
	panel.modulate.a=0; panel.position.y+=16

func text(value: String,at: Vector2,extent: Vector2,font: int=18,tint: Color=Color("e0dacb")) -> Label:
	var l:=Label.new(); l.text=value; l.position=at; l.size=extent; l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; l.add_theme_font_size_override("font_size",font); l.add_theme_color_override("font_color",tint); panel.add_child(l); return l
func button(value: String,at: Vector2,extent: Vector2,callback: Callable) -> Button:
	var b:=Button.new(); b.text=value; b.position=at; b.size=extent; b.pressed.connect(callback); panel.add_child(b); return b

func refresh() -> void:
	if activity.active.is_empty(): return
	var p: Dictionary=activity.profile(); var inspected: Array=activity.done()
	var survey: bool=p.mode=="survey"
	counter.text=("已查证" if survey else "已完成工序")+"  %d / 3" % inspected.size()+"   ·   "+("可任选部位" if survey else "按安全顺序操作")
	for slot in 3:
		var index: int=order[slot]; var b: Button=part_buttons[slot]
		b.text=("✓  " if index in inspected else "%d  " % (slot+1))+str(p.parts[index].name)
		b.add_theme_color_override("font_color",TEAL if index in inspected else GOLD if index==activity.selected else Color("d8d2c3"))
		b.disabled=false
	var selected: int=activity.selected
	title_label.text="证据已核实" if activity.ready() and survey else "现场操作已完成" if activity.ready() else p.parts[selected].name if selected>=0 else "观察现场"
	body.text="确认后会将完整调查结论记入线索袋。" if activity.ready() and survey else "确认收尾后推进任务，现场会保留处理后的状态。" if activity.ready() else p.parts[selected].instruction if selected>=0 else p.hint
	result.text=activity.feedback
	result.add_theme_color_override("font_color",TEAL if activity.feedback_good else Color("bea98a"))
	action.disabled=selected<0 or selected in inspected or activity.ready()
	action.text="已完成 · 选择另一处部位" if selected in inspected else "按住收紧 · 在安全区松开" if activity.calibration() and activity.challenge()=="tension" else "在安全区按 E / 点击确认" if activity.calibration() else "按住 E / 按住此处调查" if survey else "按住 E / 按住此处操作"
	for adjust_button in adjustment_buttons: adjust_button.visible=activity.calibration() and activity.challenge()=="alignment"
	relaxed_box.visible=int(p.get("calibrate",-1))>=0
	submit_button.disabled=not activity.ready()
	submit_button.text=("收入线索袋 · Enter" if survey else "确认收尾 · Enter") if activity.ready() else "先完成三个部位" if survey else "先完成三道工序"
	queue_redraw()
	if is_instance_valid(gauge): gauge.queue_redraw()

func _process(dt: float) -> void:
	if activity.active.is_empty(): return
	transition=minf(1,transition+dt*5)
	panel.modulate.a=transition; panel.position.y=94+16*pow(1-transition,3)
	activity.tick(dt,mouse_holding or Input.is_physical_key_pressed(KEY_E))
	if activity.active.is_empty(): return
	activity.adjust((float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))+adjustment_direction)*dt*.42)
	if activity.calibration(): gauge_caption.text="A / D 微调，进入安全区确认" if activity.challenge()=="alignment" else "按住收紧，在青色区间松开" if activity.challenge()=="tension" else "青色区间内确认 · 可反复尝试"
	elif activity.selected>=0 and not activity.selected in activity.done(): gauge_caption.text="稳定操作  %d%% · 松开后进度缓慢回落" % int(activity.progress*100)
	else: gauge_caption.text="✓  部位已记录，可回看或继续" if activity.selected in activity.done() else "选择带编号的部位开始"
	queue_redraw()
	if is_instance_valid(gauge): gauge.queue_redraw()

func handle_key(key: int) -> void:
	if key==KEY_ESCAPE: activity.cancel()
	elif key in [KEY_1,KEY_2,KEY_3]: activity.select_part(order[key-KEY_1])
	elif key==KEY_E: activity.press()
	elif key==KEY_ENTER and activity.ready(): activity.submit()

func _input(event: InputEvent) -> void:
	if is_queued_for_deletion() or activity.active.is_empty() or not event is InputEventKey: return
	if event.keycode in [KEY_ESCAPE,KEY_1,KEY_2,KEY_3,KEY_E,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_TAB]:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo: handle_key(KEY_ENTER if event.keycode==KEY_KP_ENTER else event.keycode)

func draw_gauge() -> void:
	if activity==null or activity.active.is_empty() or not is_instance_valid(panel): return
	var origin:=Vector2(666,485)
	if activity.calibration():
		var band: Vector2=activity.band()
		var width: float=234 if activity.challenge()=="alignment" else 486
		if activity.challenge()=="alignment":
			origin.x+=126
		gauge.draw_rect(Rect2(origin,Vector2(width,12)),Color("2d3940"))
		gauge.draw_rect(Rect2(origin+Vector2(band.x*width,-3),Vector2((band.y-band.x)*width,18)),Color(.38,.76,.65,.6))
		var x: float=origin.x+activity.needle()*width
		gauge.draw_line(Vector2(x,origin.y-10),Vector2(x,origin.y+22),GOLD,3,true)
	else:
		gauge.draw_rect(Rect2(origin,Vector2(486,12)),Color("2d3940"))
		gauge.draw_rect(Rect2(origin,Vector2(486*activity.progress,12)),TEAL)
	for i in 3:
		var at:=Vector2(1145+i*15,123)
		gauge.draw_circle(at,3,TEAL if i<activity.done().size() else Color("475650"))
