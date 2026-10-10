extends Control
## Seventy-three authored tasks, graphical cards and live objectives over campaign authority.
const UISkin = preload("res://scripts/story_ui_skin.gd")
const PAPER := Color("eee1c8")
const GOLD := Color("d9bb7c")
const MUTED := Color("a1afbd")
var screen
var campaign
var content: Control
var detail: Control
var filter := "main"
var requested_filter := ""
var selected := ""
var cards: Dictionary={}
var list_scroll: ScrollContainer
var status := "主线自动推进 · 地区与人物委托在营地接取"
var status_label: Label
func _ready() -> void:
	size=Vector2(1296,760); mouse_filter=MOUSE_FILTER_STOP; campaign=screen.campaign
	var background := TextureRect.new(); background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; background.texture=load("res://assets/story/items/interface-sanctum-v1.png"); background.size=size; background.mouse_filter=MOUSE_FILTER_IGNORE; add_child(background)
	content=Control.new(); content.size=size; add_child(content)
	selected=str(campaign.tracked().get("id",""))
	if selected!="": filter=str(campaign.content.quests[selected].kind)
	if requested_filter!="": filter=requested_filter; selected=""
	campaign.changed.connect(changed)
	render()
func changed() -> void:
	if not is_queued_for_deletion(): render.call_deferred()
func text(parent: Node, value: String, at: Vector2, extent: Vector2, font_size: int = 17, color: Color = PAPER) -> Label:
	var node: Label=screen.label(parent,value,at,extent,font_size); node.add_theme_color_override("font_color",color); return node
func button(parent: Node, value: String, at: Vector2, extent: Vector2, action: Callable, disabled: bool = false) -> Button:
	var node: Button=screen.button(parent,value,at,extent,action); node.disabled=disabled; return node
func picture(parent: Node, base: String, at: Vector2, extent: Vector2) -> void:
	var image := TextureRect.new(); image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture=UISkin.item_icon(base); image.position=at; image.size=extent; image.mouse_filter=MOUSE_FILTER_IGNORE; parent.add_child(image)
func phase(q: Dictionary) -> String:
	if q.id in campaign.state.completed: return "已完成"
	if q.id in campaign.state.accepted or q.id==campaign.current_main().get("id",""): return "进行中"
	if q.kind!="main" and campaign.available(q): return "待接取"
	return "未解锁"
func ordered_tasks() -> Array:
	var result: Array=[]
	for q in campaign.content.quests.values():
		if (filter=="completed" and q.id in campaign.state.completed) or (filter!="completed" and q.kind==filter): result.append(q)
	result.sort_custom(func(a,b):
		var priority := {"进行中":0,"待接取":1,"未解锁":2,"已完成":3}
		if priority[phase(a)]!=priority[phase(b)]: return priority[phase(a)]<priority[phase(b)]
		return str(a.id)<str(b.id))
	return result
func render() -> void:
	if is_queued_for_deletion(): return
	var previous := int(list_scroll.scroll_vertical) if is_instance_valid(list_scroll) else 0
	for node in content.get_children(): content.remove_child(node); node.queue_free()
	cards.clear()
	text(content,"旅 程 与 委 托",Vector2(62,18),Vector2(600,40),28,GOLD)
	text(content,"六幕守望   ·   已完成 %d / 73" % campaign.state.completed.size(),Vector2(870,26),Vector2(339,30),18,GOLD)
	button(content,"×",Vector2(1220,17),Vector2(46,38),screen.close_panel)
	var groups := {"main":"主线旅程","side":"地区委托","personal":"人物故事","completed":"已完成篇章"}
	var x := 57
	for kind in groups:
		var key: String=kind
		var tab := button(content,groups[kind],Vector2(x,74),Vector2(210,40),func(): filter=key; selected=""; list_scroll=null; render())
		UISkin.button(tab,filter==kind); x+=220
	button(content,"王国档案",Vector2(952,74),Vector2(123,40),func(): screen.show_chapter("王国档案",campaign.content.history))
	button(content,"六地后日谈",Vector2(1085,74),Vector2(123,40),func(): screen.show_chapter("回访 · 六地的灯",campaign.content.aftermath),not "E-M01" in campaign.state.completed)
	text(content,groups[filter],Vector2(53,151),Vector2(390,30),22,GOLD)
	var tasks := ordered_tasks()
	text(content,"%d 项" % tasks.size(),Vector2(450,154),Vector2(80,25),17,MUTED)
	list_scroll=ScrollContainer.new(); list_scroll.position=Vector2(53,202); list_scroll.size=Vector2(487,472); content.add_child(list_scroll)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",10); column.size_flags_horizontal=SIZE_EXPAND_FILL; list_scroll.add_child(column)
	if selected=="" and not tasks.is_empty(): selected=tasks[0].id
	for q in tasks:
		var id: String=q.id
		var card := Button.new(); card.text=""; card.custom_minimum_size=Vector2(465,94); UISkin.button(card,id==selected); column.add_child(card); cards[id]=card
		card.add_theme_stylebox_override("normal",UISkin.frame(4 if id!=selected else 3))
		card.pressed.connect(func(): selected=id; refresh_details())
		picture(card,"crystal" if q.kind=="main" else "raven" if q.kind=="personal" else "ruby",Vector2(14,20),Vector2(47,52))
		text(card,q.title,Vector2(76,11),Vector2(363,28),19,PAPER)
		var state: String=phase(q)
		text(card,"第%d幕   ·   %s   ·   %d / %d" % [q.act,state,campaign.step_count(q),q.steps.size()],Vector2(76,46),Vector2(363,24),15,GOLD if state=="进行中" else MUTED)
		if q.id==campaign.tracked().get("id",""): text(card,"◆",Vector2(425,8),Vector2(25,26),18,GOLD)
	list_scroll.set_deferred("scroll_vertical",previous)
	detail=Control.new(); detail.position=Vector2(623,148); detail.size=Vector2(605,523); content.add_child(detail)
	status_label=text(content,status,Vector2(58,723),Vector2(1190,29),15,GOLD)
	refresh_details()
func location(q: Dictionary) -> String:
	var act: Dictionary=campaign.content.acts[int(q.act)-1]
	if q.id.begins_with("P-"): return act.camp+" · 南门"
	return act.camp if int(q.stage)==0 else act.maps[int(q.stage)-1].name
func refresh_details() -> void:
	for id in cards: cards[id].add_theme_stylebox_override("normal",UISkin.frame(3 if id==selected else 4))
	for node in detail.get_children(): detail.remove_child(node); node.queue_free()
	if selected=="" or not campaign.content.quests.has(selected): text(detail,"暂无记录",Vector2(16,55),Vector2(540,40),25,GOLD); return
	var q: Dictionary=campaign.content.quests[selected]
	var state: String=phase(q)
	picture(detail,"crystal" if q.kind=="main" else "raven" if q.kind=="personal" else "ruby",Vector2(0,6),Vector2(46,62))
	text(detail,q.title,Vector2(62,5),Vector2(518,33),25,GOLD)
	text(detail,state+"   ·   "+q.id,Vector2(62,43),Vector2(518,26),16,MUTED)
	text(detail,"第%d幕 · %s\n联系人：%s" % [q.act,location(q),q.contact],Vector2(14,86),Vector2(567,54),18,PAPER)
	text(detail,q.description,Vector2(14,151),Vector2(567,67),18,PAPER)
	var progress := ProgressBar.new(); progress.show_percentage=false; progress.position=Vector2(14,226); progress.size=Vector2(558,7); progress.max_value=q.steps.size(); progress.value=campaign.step_count(q); detail.add_child(progress)
	# Objectives live in a bounded scroller, including tasks with long or numerous steps.
	var scroll := ScrollContainer.new(); scroll.position=Vector2(13,244); scroll.size=Vector2(572,138); detail.add_child(scroll)
	var column := VBoxContainer.new(); column.size_flags_horizontal=SIZE_EXPAND_FILL; column.add_theme_constant_override("separation",5); scroll.add_child(column)
	for index in q.steps.size():
		var row := PanelContainer.new(); row.add_theme_stylebox_override("panel",UISkin.frame(5)); row.custom_minimum_size=Vector2(549,38); column.add_child(row)
		var label := Label.new(); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.add_theme_font_size_override("font_size",16)
		var done: bool=index<campaign.step_count(q)
		label.text=("✓ " if done else "◆ " if index==campaign.step_count(q) and state=="进行中" else "○ ")+q.steps[index]
		label.add_theme_color_override("font_color",Color("92cfb6") if done else PAPER); row.add_child(label)
	var reward: Dictionary=campaign.rewards(q)
	text(detail,"委托报酬 · 药剂补给"+(" · 阶级%d珍稀装备" % reward.equipment if int(reward.equipment)>0 else ""),Vector2(14,395),Vector2(555,27),18,GOLD)
	for i in 3:
		var at := Vector2(13+i*187,433)
		var plate := Panel.new(); plate.position=at; plate.size=Vector2(175,55); plate.add_theme_stylebox_override("panel",UISkin.frame(4)); detail.add_child(plate)
		picture(plate,["ruby","crystal","scrap"][i],Vector2(7,7),Vector2(34,40))
		text(plate,["银币 %d" % reward.coins,"经验 %d" % reward.xp,"铁料 %d" % reward.materials][i],Vector2(49,15),Vector2(120,29),17,PAPER)
	var unlocked: bool=campaign.available(q)
	var trackable: bool=q.id in campaign.state.accepted or q.id==campaign.current_main().get("id","")
	if state=="已完成":
		button(detail,"阅读已完成篇章",Vector2(14,505),Vector2(267,39),func(): screen.show_chapter(q.title,q.story+"\n\n【档案记录】"+q.reward_text))
	elif q.kind!="main" and state=="待接取":
		var can_accept: bool=int(campaign.state.stage)==0 and int(campaign.state.act)==int(q.act)
		var accept := button(detail,"接取委托" if can_accept else "返回第%d幕营地接取" % q.act,Vector2(14,505),Vector2(267,39),func():
			status="已接取「%s」。" % q.title if campaign.accept(q.id) else "前置任务尚未完成。",not can_accept)
		UISkin.button(accept,true)
	else:
		button(detail,"◆ 追踪目标" if trackable else "前置任务未完成",Vector2(14,505),Vector2(267,39),func(): campaign.track(q.id); status="正在追踪「%s」。" % q.title,not trackable)
	button(detail,"查看当前地区地图",Vector2(300,505),Vector2(270,39),screen.show_atlas)
	if not unlocked and state!="已完成":
		var required: Array=[]
		for id in q.requires:
			if not id in campaign.state.completed: required.append(campaign.content.quests[id].title)
		status="前置："+"、".join(required)
	status_label.text=status
