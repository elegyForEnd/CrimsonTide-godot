extends Control
## Trade and cooking only; farming and fishing remain in the world.
const Rules = preload("res://scripts/homestead.gd")
const Art = preload("res://scripts/home_art.gd")
const HearthSkin = preload("res://scripts/home_ui_skin.gd")
const INK := Color("eee5e1")
const MUTED := Color("9d9299")
const GOLD := Color("d6b9b5")
var camp: Control
var home
var shade: ColorRect
var panel: Control
var body: VBoxContainer
var status: Label
var wallet: Label
var section := "home_shop"
var shop_mode := "buy"
var tick := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	shade = ColorRect.new()
	shade.color = Color(0.016,0.007,0.018,0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = Control.new()
	panel.position = Vector2(88,64)
	panel.size = Vector2(1264,772)
	add_child(panel)
	add_theme_font_override("font",load("res://assets/NotoSansSC.ttf"))
	add_theme_color_override("font_color",INK)
	add_theme_font_size_override("font_size",17)
	visible = false

func text(parent: Node, value: String, extent: int = 17, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",extent)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func button(parent: Node, value: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = value
	node.custom_minimum_size = Vector2(108 if value!="×" else 36,38)
	HearthSkin.dress(node,value.begins_with("已携带"))
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func report(message: String, rebuild: bool = true) -> void:
	if rebuild: build()
	status.text = message
	camp.site.refresh_crops(home.state())
	camp.home_changed.emit()

func card(parent: Node, key: String, title: String, hint: String, tall: bool = false) -> VBoxContainer:
	# The composed backdrop carries the design; items have no repeated outer frames.
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(232,466 if tall else 228)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	parent.add_child(content)
	item_picture(content,key,174 if tall else 104)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var name_label := text(heading,title,19,INK)
	name_label.add_theme_font_override("font",load("res://assets/NotoSerifSC.ttf"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HearthSkin.info(heading,camp,title,hint)
	return content

func build_shop(parent: Node) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	parent.add_child(grid)
	if shop_mode=="sell":
		for key in Rules.CROPS.keys()+Rules.FISH.keys():
			var item: String = key
			var entry: Dictionary = Rules.CROPS.get(key,Rules.FISH.get(key,{}))
			var content := card(grid,item,entry.name,"出售一份获得 %d 金币。作物和鱼也可留作厨房食材，不占用远征背包。" % entry.sell)
			text(content,"× %d" % home.state().stock[key],14,MUTED)
			button(content,"出售  +%d ◈" % entry.sell,func(): report(home.sell(item))).disabled = home.state().stock[key]<=0
		return
	for key in Rules.CROPS:
		var crop: String = key
		var entry: Dictionary = Rules.CROPS[key]
		var content := card(grid,crop,entry.name+"种子","生长 %d 分钟，每块田收获 3 份。浇水缩短 35%% 生长时间；离线继续生长，成熟不会枯萎。" % (entry.seconds/60))
		text(content,"× %d" % home.state().seeds[key],14,MUTED)
		button(content,"购买  %d ◈" % entry.price,func(): report(home.buy(crop)))
	var rod := card(grid,"rod",["木制钓竿","精工钓竿","精工钓竿"][home.state().rod],"钓竿永久保留。精工钓竿扩大绿色收竿区域，提升稀有鱼概率。在栈桥按 E / Space 抛竿与收竿。")
	text(rod,["未购置","可升级","已满级"][home.state().rod],14,MUTED)
	button(rod,"购买  70 ◈" if home.state().rod==0 else "升级  180 ◈",func(): report(home.buy("rod"))).disabled = home.state().rod>=2
	var bait := card(grid,"bait","鱼饵 ×5","每次抛竿消耗 1 份鱼饵；取消或失败不返还。等鱼咬钩后，在绿色区域内按 E / Space 收竿。")
	text(bait,"持有 %d" % home.state().bait,14,MUTED)
	button(bait,"购买  15 ◈",func(): report(home.buy("bait")))
	var beds := card(grid,"seeds","开垦田畦","花费 120 金币，永久增加 3 块田畦，最多 9 块。前往菜园，在空田块按 E 播种，Q 切换种子。")
	text(beds,"田畦 %d / 9" % home.state().beds,14,MUTED)
	button(beds,"开垦  120 ◈",func(): report(home.buy("beds"))).disabled = home.state().beds>=9

func build_kitchen(parent: Node) -> void:
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation",12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	for key in Rules.MEALS:
		var meal: String = key
		var entry: Dictionary = Rules.MEALS[key]
		var content := card(grid,key,entry.name,entry.desc+"。\n选择一份料理随身出征，成功开局时消耗一份，加成持续本次远征，失败不返还。",true)
		text(content,{"bread":"生命 +24","stew":"伤害 +12%","tea":"生命 +12 · 移速 +24"}[key],16,GOLD)
		var ingredients := HBoxContainer.new()
		ingredients.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_child(ingredients)
		var can_cook := true
		for ingredient in entry.needs:
			var part := VBoxContainer.new()
			ingredients.add_child(part)
			item_picture(part,ingredient,40)
			var amount := text(part,"%d / %d" % [home.state().stock[ingredient],entry.needs[ingredient]],14,MUTED)
			amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			part.tooltip_text = Rules.CROPS.get(ingredient,Rules.FISH.get(ingredient,{})).name
			if home.state().stock[ingredient]<entry.needs[ingredient]: can_cook = false
		var stock := text(content,"库存 %d" % home.state().meals[key],14,MUTED)
		stock.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button(content,"烹饪",func(): report(home.cook(meal))).disabled = not can_cook
		button(content,"已携带 ✓" if home.state().prepared==key else "携带",func(): report(home.prepare(meal))).disabled = home.state().meals[key]<=0

func item_picture(parent: Node, key: String, extent: int) -> TextureRect:
	var art := TextureRect.new()
	art.texture = Art.icon(key)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(extent,extent)
	art.modulate = Color(0.92,0.87,0.88)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

func open(id: String) -> void:
	if not camp.profile or camp.activities.busy(): return
	if id in ["garden","fish"]:
		camp.warp_to(id)
		return
	home = Rules.new(camp.profile)
	section = id
	visible = true
	camp.input_blocked = true
	camp.site.hero_walking = false
	build()

func close() -> void:
	visible = false
	camp.input_blocked = false
	if home: camp.site.refresh_crops(home.state())

func build() -> void:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/home/generated/hearthhaven-sanctum-v3.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.size = panel.size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(backdrop)
	var title := text(panel,"炉边厨房" if section=="kitchen" else "家园商店",32,INK)
	title.position = Vector2(474,42)
	title.add_theme_font_override("font",load("res://assets/NotoSerifSC.ttf"))
	wallet = text(panel,"",15,MUTED)
	wallet.position = Vector2(808,57)
	var info := HearthSkin.info(panel,camp,"家园生活","种子和渔具在商店购买；收获可出售或烹饪。\n菜园：E 播种、浇水、收获，Q 换种子。\n栈桥：E / Space 抛竿，咬钩后在绿色区域收竿。\n料理：烹饪后选择携带，成功出征时消耗。\nEsc 关闭当前界面。")
	info.position = Vector2(1136,46)
	var exit := button(panel,"×",close)
	exit.position = Vector2(1182,46)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(474,100)
	tabs.size = Vector2(724,42)
	tabs.add_theme_constant_override("separation",16)
	panel.add_child(tabs)
	for entry in [["home_shop","商店"],["kitchen","厨房"]]:
		var key: String = entry[0]
		var tab := button(tabs,str(entry[1]),func(): section = key; build())
		tab.disabled = key==section
		if key==section:
			tab.add_theme_color_override("font_disabled_color",Color("e5bbb7"))
			tab.add_theme_stylebox_override("disabled",HearthSkin.style("primary",10))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	if section=="home_shop":
		for entry in [["buy","购入"],["sell","出售"]]:
			var mode: String = entry[0]
			var tab := button(tabs,str(entry[1]),func(): shop_mode = mode; build())
			tab.disabled = shop_mode==mode
			if shop_mode==mode:
				tab.add_theme_color_override("font_disabled_color",Color("e5bbb7"))
				tab.add_theme_stylebox_override("disabled",HearthSkin.style("primary",10))
	else:
		button(tabs,"卸下餐食",func(): report(home.prepare(""))).disabled = str(home.state().prepared).is_empty()
	for i in 2:
		var target: String = ["garden","fish"][i]
		var travel := button(panel,["菜园 →","栈桥 →"][i],func(): close(); open(target))
		travel.position = Vector2(52,650+i*46)
		travel.size = Vector2(232,40)
	body = VBoxContainer.new()
	body.position = Vector2(474,182)
	body.size = Vector2(724,492)
	panel.add_child(body)
	if section=="kitchen": build_kitchen(body)
	else: build_shop(body)
	status = text(panel,"",15,Color("cfa2a2"))
	status.position = Vector2(474,710)
	status.size = Vector2(724,30)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refresh()

func refresh() -> void:
	if not home or not wallet: return
	var meal := str(home.state().prepared)
	wallet.text = "◈ %d    ·    携带 %s" % [camp.profile.data.coins,Rules.MEALS[meal].name if Rules.MEALS.has(meal) else "—"]

func _process(dt: float) -> void:
	if not camp or not camp.visible: return
	tick += dt
	if tick>=1:
		tick = 0
		if camp.profile: camp.site.refresh_crops(camp.profile.data.home)
		if visible: refresh()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE: close()
		get_viewport().set_input_as_handled()
