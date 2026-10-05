extends Control
## Native camp economy, sharing the game's fonts, ornaments and item artwork.
var host: Node
var market := false
var category := 0
var query := ""
var order := 0
var selected: Array = []
var focused := -1
var confirming := false
var notice := ""
var grid: GridContainer
var details: Control
var status: Label
var balance: Label
var filters: Array = []
const CATEGORIES := ["全部藏品","武器与装备","补给物资","遗物与珍宝","背包"]

func _ready() -> void:
	position=Vector2(80,115)
	size=Vector2(1280,725)
	build()

func text(value: String, at: Vector2, font_size: int = 18, color: Color = Color("e7dfd5"), dimensions: Vector2 = Vector2(700,40), parent: Node = null) -> Label:
	return host.label(self if parent==null else parent,value,at,font_size,color,dimensions)

func action(value: String, at: Vector2, dimensions: Vector2, callback: Callable, primary: bool = false, parent: Node = null) -> Button:
	return host.button(self if parent==null else parent,value,at,dimensions,callback,primary,17)

func build() -> void:
	action("永久仓库",Vector2(0,0),Vector2(170,44),func(): host.show_economy(false),not market)
	action("晨钟交易行",Vector2(182,0),Vector2(180,44),func(): host.show_economy(true),market)
	balance=text("",Vector2(955,5),23,host.GOLD,Vector2(310,36))
	text("NIGHTWATCH  /  VAULT & EXCHANGE",Vector2(0,53),12,host.MUTED)
	text("商会按标价即时收购 · 无手续费" if market else "永久保管 · 撤离战利品自动入库",Vector2(640,52),14,host.GOLD)
	host.rect(self,Vector2(0,87),Vector2(1280,1),host.GOLD)
	for i in CATEGORIES.size():
		var b := action(CATEGORIES[i],Vector2(0,107+i*52),Vector2(185,44),func(): category=i; confirming=false; refresh())
		filters.append(b)
	text("携行物资",Vector2(10,393),20,host.GOLD)
	text("取出后随下一次出征携带。\n背包物资阵亡掉落；\n次元口袋中的物品保留。",Vector2(10,434),14,host.MUTED,Vector2(175,96))
	action("携行物资全部入库",Vector2(0,554),Vector2(185,44),deposit)
	var search := LineEdit.new()
	search.placeholder_text="搜索物品名称…"
	search.position=Vector2(210,104)
	search.size=Vector2(430,42)
	search.add_theme_font_override("font",host.root.theme.default_font)
	search.add_theme_font_size_override("font_size",17)
	add_child(search)
	search.text_changed.connect(func(value): query=value; refresh())
	var sorting := OptionButton.new()
	sorting.position=Vector2(654,104)
	sorting.size=Vector2(280,42)
	sorting.add_theme_font_override("font",host.root.theme.default_font)
	sorting.add_theme_font_size_override("font_size",17)
	for value in ["默认顺序","价值：从高到低","价值：从低到高","品质：从高到低"]: sorting.add_item(value)
	add_child(sorting)
	sorting.item_selected.connect(func(index): order=index; refresh())
	var scroll := ScrollContainer.new()
	scroll.position=Vector2(210,164)
	scroll.size=Vector2(724,422)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	grid=GridContainer.new()
	grid.columns=4
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	scroll.add_child(grid)
	details=Control.new()
	details.position=Vector2(958,104)
	details.size=Vector2(310,550)
	add_child(details)
	action("全选筛选结果",Vector2(210,601),Vector2(190,42),func():
		selected=visible_indices().filter(func(index): return not market or Catalog.market_value(host.profile.data.warehouse[index])>0)
		confirming=false
		refresh())
	action("清空选择",Vector2(412,601),Vector2(155,42),func(): selected.clear(); confirming=false; refresh())
	status=text("",Vector2(210,659),16,host.GOLD,Vector2(1030,47))
	refresh()

func matches(item: Dictionary) -> bool:
	if not query.is_empty() and not Catalog.item_name(item).to_lower().contains(query.to_lower()): return false
	var kind := str(item.kind)
	match category:
		1: return kind in ["weapon","gear","charm"]
		2: return kind in ["medicine","ammo","crystal"]
		3: return kind not in ["weapon","gear","charm","medicine","ammo","crystal","backpack"]
		4: return kind=="backpack"
	return true

func visible_indices() -> Array:
	var result: Array = []
	var items: Array=host.profile.data.warehouse
	for i in items.size():
		if matches(items[i]): result.append(i)
	if order!=0:
		result.sort_custom(func(a,b):
			var av: int=Catalog.item_tier(items[a]) if order==3 else Catalog.market_value(items[a])
			var bv: int=Catalog.item_tier(items[b]) if order==3 else Catalog.market_value(items[b])
			return a<b if av==bv else (av<bv if order==2 else av>bv))
	return result

func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func refresh() -> void:
	clear_children(grid)
	clear_children(details)
	var items: Array=host.profile.data.warehouse
	balance.text="城邦银币  ◈ %d" % host.profile.data.coins
	for i in filters.size(): filters[i].modulate=Color.WHITE if i==category else Color("a6a2ad")
	var indices := visible_indices()
	for index in indices:
		var item: Dictionary=items[index]
		var card := Button.new()
		card.custom_minimum_size=Vector2(166,150)
		card.tooltip_text=Catalog.item_name(item)+"\n"+Catalog.item_desc(item)+"\n价值 %d 银币" % Catalog.item_value(item)
		var style := StyleBoxFlat.new()
		style.bg_color=Color("292335") if index in selected else Color("151b27")
		style.border_color=host.GOLD if index in selected else Color(Catalog.item_color(item),0.45)
		style.set_border_width_all(2 if index in selected else 1)
		card.add_theme_stylebox_override("normal",style)
		var hover := style.duplicate()
		hover.bg_color=Color("303040")
		card.add_theme_stylebox_override("hover",hover)
		card.add_theme_stylebox_override("pressed",hover)
		grid.add_child(card)
		host.item_icon(card,Catalog.item_icon(item),Vector2(52,12),Vector2(62,62))
		text(Catalog.item_short_name(item),Vector2(9,81),15,Catalog.item_color(item),Vector2(148,30),card)
		text("营地补给 · 禁售" if item.get("provision",false) else "◈ %d" % Catalog.market_value(item),Vector2(12,115),16,host.GOLD,Vector2(145,28),card)
		if int(item.get("count",1))>1: text("×%d" % item.count,Vector2(9,9),15,host.GOLD,Vector2(45,25),card)
		if index in selected: text("✓",Vector2(139,7),19,host.GOLD,Vector2(25,25),card)
		card.pressed.connect(func():
			focused=index
			if index in selected: selected.erase(index)
			elif not market or Catalog.market_value(item)>0: selected.append(index)
			confirming=false
			refresh())
	if indices.is_empty():
		var empty := Label.new()
		empty.text="暂无匹配物品\n\n完成远征带回物资，或将携行物资存入仓库。"
		empty.custom_minimum_size=Vector2(700,210)
		empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size",18)
		grid.add_child(empty)
	var total := 0
	for index in selected:
		if index<items.size(): total+=Catalog.market_value(items[index])
	status.text=notice if not notice.is_empty() else "仓库 %d 件 · 总估值 %d ◈   /   已选 %d 件 · %d ◈" % [items.size(),Catalog.market_total(items),selected.size(),total]
	show_details(total)

func show_details(total: int) -> void:
	host.rect(details,Vector2.ZERO,Vector2(310,540),host.PANEL,Color("665469"))
	text("物品档案",Vector2(22,14),22,host.GOLD,Vector2(260,34),details)
	var items: Array=host.profile.data.warehouse
	if focused>=0 and focused<items.size():
		var item: Dictionary=items[focused]
		host.item_icon(details,Catalog.item_icon(item),Vector2(104,57),Vector2(102,102))
		var title := text(Catalog.item_name(item),Vector2(22,173),22,Catalog.item_color(item),Vector2(267,65),details)
		title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		text("营地补给 · 不可出售" if item.get("provision",false) else "收购价  ◈ %d" % Catalog.market_value(item),Vector2(22,249),22,host.GOLD,Vector2(267,38),details)
		var description_scroll := ScrollContainer.new()
		description_scroll.position=Vector2(22,297)
		description_scroll.size=Vector2(267,112)
		description_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		details.add_child(description_scroll)
		var description := text(Catalog.item_desc(item),Vector2.ZERO,15,host.MUTED,Vector2(249,112),description_scroll)
		description.custom_minimum_size.x=249
		description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	else:
		text("选择一件藏品\n查看价值与用途",Vector2(25,118),20,host.MUTED,Vector2(260,80),details)
	if market:
		text("已选 %d 件 · 合计 %d ◈" % [selected.size(),total],Vector2(22,421),18,host.GOLD,Vector2(268,35),details)
		var sale := action("确认出售 · 不可撤回" if confirming else "出售所选物品",Vector2(20,468),Vector2(270,48),sell,true,details)
		sale.disabled=selected.is_empty()
	else:
		var bag := action("取出到出征背包",Vector2(20,426),Vector2(270,44),func(): withdraw(false),true,details)
		var pocket := action("取出到次元口袋",Vector2(20,479),Vector2(270,44),func(): withdraw(true),false,details)
		bag.disabled=focused<0
		pocket.disabled=focused<0

func deposit() -> void:
	var count: int=host.profile.bank_carried_items()
	host.profile.save_profile()
	host.economy_changed()
	selected.clear(); focused=-1; confirming=false
	notice="已存入 %d 件携行物资。" % count
	refresh()

func withdraw(pocket: bool) -> void:
	if host.profile.withdraw_item(focused,pocket):
		host.economy_changed()
		selected.clear(); focused=-1
		notice="物品已放入%s，下次出征携带。" % ("次元口袋" if pocket else "背包")
	else:
		notice="空间不足，请先存入携行物资腾出位置。"
	refresh()

func sell() -> void:
	if selected.is_empty(): return
	if not confirming:
		confirming=true
		notice="请核对所选物品，再次点击确认出售。稀有物品也会出售。"
		refresh()
		return
	var count := selected.size()
	var earned: int=host.profile.sell_items(selected)
	host.economy_changed()
	selected.clear(); focused=-1; confirming=false
	notice="已出售 %d 件物品，获得 %d 银币。" % [count,earned]
	refresh()
