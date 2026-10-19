extends SceneTree
## 升级弹窗 UI：真实 main.tscn 上构建“七属性 +1”和“雷霆三选一”，并检查文字不裁切。
const Abilities = preload("res://scripts/rogue_abilities.gd")
var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-level-ui.json"
	root.add_child(app)
	await process_frame
	app.session.solo({"hero":0,"mode":"roguelike"})
	app.session.launch(false,4242)
	app.session.set_physics_process(false)
	app.page_name="game"
	var p: Dictionary=app.session.players[1]
	if not p.rogue_selection.is_empty():
		app.session.perform(1,"rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})
	app.session.roguelike.tick(app.session,.01)
	p=app.session.players[1]
	app.session.raid.phase="rogue_exit"
	p.build_pending_levels=1
	p.build_pending_abilities=0
	p.build_ability_offers=[]
	app._sync_rogue_level_ui(p)
	await process_frame
	check(is_instance_valid(app.rogue_level_ui),"Level UI builds for a pending attribute choice")
	check(app.rogue_level_ui.mode=="attributes","Attribute mode is selected first")
	var attr_buttons := 0
	var first_attr: Button=null
	for node in app.rogue_level_ui.find_children("*","Button",true,false):
		if (node as Button).text.contains("→   +1"):
			attr_buttons+=1
			if first_attr==null: first_attr=node
	check(attr_buttons==7,"All seven attributes are offered, one point each")
	if first_attr!=null:
		var first_key: String=WatcherAttributes.KEYS[0]
		first_attr.pressed.emit()
		await process_frame
		check(int(p.build_pending_levels)==0 and int(p.build_attributes.get(first_key,0))==1,"Clicking the attribute button spends exactly one level choice")

	p.build_pending_levels=0
	p.build_pending_abilities=1
	p.build_ability_offers=Abilities.roll_offers(app.session,p,3)
	app._sync_rogue_level_ui(p)
	await process_frame
	check(app.rogue_level_ui.mode=="ability","Ability mode follows after attribute choices")
	var card_buttons: Array=app.rogue_level_ui.find_children("*","Button",true,false)
	check(card_buttons.size()>=3,"Ability panel builds three clickable cards")
	if card_buttons.size()>=1:
		var chosen_before := Abilities.total_rank(p)
		(card_buttons[0] as Button).pressed.emit()
		await process_frame
		check(int(p.build_pending_abilities)==0 and Abilities.total_rank(p)==chosen_before+1,"Clicking an ability card grants exactly one rank")
	var clipped := 0
	var nodes: Array=[app.rogue_level_ui]
	while not nodes.is_empty():
		var node: Node=nodes.pop_back()
		nodes.append_array(node.get_children())
		if node is Label:
			var label: Label=node
			var lines: int=label.get_line_count()
			var required: float=label.get_theme_font("font").get_height(label.get_theme_font_size("font_size"))*lines+2*maxi(0,lines-1)
			if required>label.size.y+0.1:
				clipped+=1
				print("CLIPPED [",label.text,"] box ",label.size," required ",required)
	check(clipped==0,"Level-up text fits its painted boxes")

	p.build_pending_abilities=0
	p.build_ability_offers=[]
	app._sync_rogue_level_ui(p)
	await process_frame
	check(not is_instance_valid(app.rogue_level_ui) or not app.rogue_level_ui.visible,"Level UI closes when no choices remain")

	app.queue_free()
	await process_frame
	print("ROGUE LEVEL UI: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
