extends RefCounted
## Presentation only: grids and sockets register with the existing drag controller.
const GOLD := Color("cbb087")
const INK := Color("ede5d8")
const MUTED := Color("9d9791")
# The shared cell renderer: the camp panel draws through the same one.
const ItemTile := preload("res://scripts/item_tile.gd")
var host
var tooltip: Panel
var hover_key := ""
var zones: Array=[]
var health: Label
var stats: Label
var bag_scroll := 0
var bag_scroller: ScrollContainer
var layout_shift := Vector2.ZERO

func text(value: String, at: Vector2, size: Vector2, font_size: int = 17, color: Color = INK) -> Label:
	return host.label(host.overlay,value,at,font_size,color,size)

func tile(at: Vector2, size: Vector2, item: Dictionary = {}, tone: Color = GOLD, secure: bool = false) -> Control:
	# The cell look itself lives in `item_tile.gd`, so the camp panel draws exactly
	# the same sockets, linings, rotations and stack badges as a raid.
	return ItemTile.tile(host,at,size,item,tone,secure)

func draw(app, p: Dictionary, container: Dictionary) -> void:
	host=app
	zones.clear()
	hover_key=""
	hide_tooltip()
	var search := not container.is_empty()
	layout_shift=Vector2.ZERO if search else Vector2(216,0)
	var blocker: Panel=host.rect(host.overlay,Vector2.ZERO,Vector2(1440,900),Color(0.008,0.006,0.009,0.95))
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	var art := TextureRect.new()
	var source: Texture2D=load("res://assets/ui/extraction-inventory-v2.png")
	art.texture=source
	if not search:
		var cropped := AtlasTexture.new()
		cropped.atlas=source
		cropped.region=Rect2(0,0,source.get_width()*0.663,source.get_height())
		art.texture=cropped
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.position=Vector2(36,28)
	art.size=Vector2(1368 if search else 907,828)
	art.name="ExtractionBackdrop"
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	host.overlay.add_child(art)
	text("远 征 行 囊",Vector2(90,54),Vector2(400,50),31,GOLD)
	text("携带价值  %d ◈" % host.loot_total(p),Vector2(940 if search else 624,66),Vector2(300,30),20,GOLD)
	host.button(host.overlay,"×",Vector2(1310 if search else 850,50),Vector2(52,48),host.close_bag,false,28)
	character(p)
	var grid: Vector2i=Catalog.bag_grid(p.backpack)
	var cell := 48.0
	host.bag_cell=cell
	host.bag_gap=4
	var width := grid.x*(cell+4)-4
	var at := Vector2(446+(440-width)*0.5,158)
	draw_grid("backpack",p.backpack,at,cell,4,Catalog.bag_name(p.backpack),"%s · %d 格空闲 · 阵亡掉落" % [Catalog.bag_quality(p.backpack),Catalog.container_free(p.backpack)],Color("bdab81"))
	host.pocket_cell=40
	host.pocket_gap=4
	draw_grid("pocket",p.pocket,Vector2(580,456),40,4,"次元口袋","阵亡保留 · 固定 4×4",Color("b7a3d3"))
	if search:
		search_grid(container)
	current_pack(p)
	quick_slots(p)
	text("拖拽整理 · R / 右键旋转 · 双击装备 · Ctrl 快捷操作",Vector2(87,865),Vector2(700,26),14,MUTED)
	text("TAB / ESC  关闭",Vector2(1160 if search else 750,865),Vector2(190,26),14,GOLD)
	# Protect the three columns from an accidental drop outside their grids, and tell
	# the drag system where the panel ends: outside the backdrop a released item is
	# dropped on the ground, and the frosted sheet says so before the player lets go.
	host.panel_rects.append(Rect2(65,130,1320 if search else 880,702))
	host.drop_region=Rect2(36,28,1368 if search else 907,828)
	host.drop_art="res://assets/ui/extraction-inventory-v2.png"
	host.update_frost_art()
	if not search:
		var edge := TextureRect.new()
		var trim := AtlasTexture.new()
		trim.atlas=source
		trim.region=Rect2(source.get_width()*0.96,0,source.get_width()*0.04,source.get_height())
		edge.texture=trim
		edge.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		edge.position=Vector2(905,28)
		edge.size=Vector2(55,828)
		edge.mouse_filter=Control.MOUSE_FILTER_IGNORE
		host.overlay.add_child(edge)
		for child in host.overlay.get_children():
			if child!=blocker: child.position+=layout_shift
		for entry in host.grids.values():
			entry.origin+=layout_shift
			if entry.has("clip"): entry.clip.position+=layout_shift
		for key in host.equip_zones: host.equip_zones[key].position+=layout_shift
		for i in host.slot_zone_rects.size(): host.slot_zone_rects[i].position+=layout_shift
		host._slot_origin+=layout_shift
		for zone in zones: zone.rect.position+=layout_shift
		for i in host.panel_rects.size(): host.panel_rects[i].position+=layout_shift

func character(p: Dictionary) -> void:
	text(str(Catalog.HEROES[p.hero].name),Vector2(128,147),Vector2(220,35),27,INK).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var portrait: Sprite2D=host.portrait(host.overlay,int(p.hero),Vector2(243,390),365,true)
	if int(p.hero)==3: portrait.texture=load("res://assets/ui/rogue-inventory-muyu-v2.png")
	portrait.scale=Vector2.ONE*minf(366.0/portrait.texture.get_height(),244.0/portrait.texture.get_width())
	portrait.modulate=Color(0.85,0.82,0.82)
	var rows: Array=[{"item":host.session.kit_weapon(p),"type":"weapon","index":0,"title":"主手"}]
	for i in 3: rows.append({"item":host.session.kit_gear(p)[i],"type":"gear","index":i,"title":["护甲","瞄具","轻靴"][i]})
	for i in 2: rows.append({"item":host.session.kit_charms(p)[i],"type":"charm","index":i,"title":"饰品"})
	for i in rows.size():
		var row: Dictionary=rows[i]
		var at := Vector2(88 if i%2==0 else 327,239+int(i/2)*123)
		var item: Dictionary=row.item
		var node := tile(at,Vector2(67,67),item)
		var key: String="weapon" if row.type=="weapon" else "%s%d" % [row.type,row.index]
		host.equip_zones[key]=Rect2(at,Vector2(67,67))
		text(row.title,at+Vector2(-5,72),Vector2(77,24),14,GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if not item.is_empty():
			zones.append({"rect":Rect2(at,Vector2(67,67)),"item":item,"key":key})
			var off: Button=host.button(host.overlay,"卸",at+Vector2(46,-4),Vector2(22,21),func(): host.unequip_slot(row.type,row.index),false,11)
			off.tooltip_text="卸下 "+Catalog.item_name(item)
		elif row.type=="weapon":
			host.item_icon(node,Catalog.weapon_icon(int(p.weapon)),Vector2(8,8),Vector2(51,51)).modulate=Color(1,1,1,0.35)
	health=text("生命  %d / %d" % [maxf(0,p.hp),p.max_hp],Vector2(104,600),Vector2(278,26),17,INK)
	health.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	stats=text("攻击 %.1f  ·  减伤 %.0f%%" % [host.session.weapon_damage(p),(1.0-host.session.incoming_damage(p,1))*100],Vector2(100,635),Vector2(286,26),15,MUTED)
	stats.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func draw_grid(slot: String, container: Dictionary, at: Vector2, cell: float, gap: float, title: String, subtitle: String, tone: Color) -> void:
	var grid: Vector2i=Catalog.bag_grid(container) if slot=="backpack" else Catalog.container_grid(container)
	var width := grid.x*(cell+gap)-gap
	text(title,at,Vector2(maxf(width,290),33),23,tone)
	text(subtitle,at+Vector2(0,28 if slot=="pocket" else 38),Vector2(maxf(width,290),24),14,MUTED)
	var origin := at+Vector2(0,47 if slot=="pocket" else 75)
	host.grids[slot]={"origin":origin,"cell":cell,"gap":gap,"grid":grid}
	var first_child: int=host.overlay.get_child_count()
	for y in grid.y:
		for x in grid.x: tile(origin+Vector2(x,y)*(cell+gap),Vector2(cell,cell),{},Color(tone,0.3),slot=="pocket")
	var items: Array=container.items
	for i in items.size():
		var item: Dictionary=items[i]
		if host.drag.active and host.drag.slot==slot and host.drag.source==i: continue
		var dims: Vector2i=Catalog.item_size(item)
		var size := Vector2(dims)*(cell+gap)-Vector2.ONE*gap
		var pos := origin+Vector2(item.x,item.y)*(cell+gap)
		var body := tile(pos,size,item)
		if host.selected_slot==slot and host.selected==i: body.selected=true
	if slot=="backpack":
		var children: Array=host.overlay.get_children().slice(first_child)
		bag_scroller=ScrollContainer.new()
		bag_scroller.name="MainBackpackScroll"
		bag_scroller.position=origin
		bag_scroller.size=Vector2(width+20,208)
		bag_scroller.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		bag_scroller.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
		bag_scroller.mouse_filter=Control.MOUSE_FILTER_PASS
		host.overlay.add_child(bag_scroller)
		var content := Control.new()
		content.custom_minimum_size=Vector2(width,grid.y*(cell+gap)-gap)
		content.mouse_filter=Control.MOUSE_FILTER_PASS
		bag_scroller.add_child(content)
		for child in children:
			host.overlay.remove_child(child)
			child.position-=origin
			content.add_child(child)
		host.grids[slot]["clip"]=Rect2(origin,Vector2(width,208))
		style_scrollbar(bag_scroller.get_v_scroll_bar())
		bag_scroller.get_v_scroll_bar().value_changed.connect(func(value: float):
			bag_scroll=int(value)
			if host.grids.has("backpack"):
				host.grids.backpack.origin=origin+layout_shift-Vector2(0,value)
				bag_scroller.queue_redraw()
				hover_key=""
		)
		bag_scroller.set_deferred("scroll_vertical",bag_scroll)
		if grid.y*(cell+gap)-gap>208:
			text("滚轮浏览背包",Vector2(754,443),Vector2(158,23),13,MUTED)

func quick_slots(p: Dictionary) -> void:
	text("快捷道具 · 1/2/3 直接使用",Vector2(100,682),Vector2(280,27),17,GOLD)
	host._slot_origin=Vector2(78,721)
	host._slot_loot=host._loot_index>=0
	for i in 3:
		var at := Vector2(100+i*99,721)
		var item: Dictionary=host.session.item_slot(p,i)
		var body := tile(at,Vector2(84,84),item)
		if host.selected_item_slot==i: body.selected=true
		var area := Rect2(at,Vector2(84,84))
		host.slot_zone_rects.append(area)
		host.equip_zones["slot%d" % i]=area
		text("[%d]" % (i+1),at+Vector2(0,87),Vector2(84,20),12,MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if not item.is_empty():
			zones.append({"rect":area,"item":item,"key":"slot%d" % i})
			host.button(host.overlay,"收回",at+Vector2(43,65),Vector2(40,18),func(): host.take_item_slot(i),false,10)

func current_pack(p: Dictionary) -> void:
	var at := Vector2(806,562)
	tile(at,Vector2(58,58),{"kind":"backpack","quality":p.backpack.key})
	host.equip_zones["bag"]=Rect2(at,Vector2(58,58))
	text("当前背包",at+Vector2(-8,65),Vector2(88,24),13,GOLD)

func search_grid(container: Dictionary) -> void:
	var grid: Vector2i=host.session.container_grid(container)
	var cell: float=36.0 if grid.x>5 or grid.y>5 else host.LOOT_CELL
	var gap: float=4.0 if grid.x>5 or grid.y>5 else host.LOOT_GAP
	var step: float=cell+gap
	var origin := Vector2(952,246)
	var units: int=host.session.container_units(container)
	var revealed: int=host.session.visible_units(container)
	text(host.session.container_title(container),Vector2(952,171),Vector2(378,35),21,Color("afc2d0"))
	text("搜索完毕 · %d 件" % units if revealed>=units else "搜索中 · %d / %d" % [revealed,units],Vector2(952,212),Vector2(378,27),14,MUTED)
	host.grids["loot"]={"origin":origin,"cell":cell,"gap":gap,"grid":grid}
	for y in grid.y:
		for x in grid.x: tile(origin+Vector2(x,y)*step,Vector2(cell,cell),{},GOLD,true)
	var budget: int=revealed
	for item in Catalog.container_items(container):
		var amount := int(item.get("count",1)) if Catalog.stacks(str(item.kind)) else 1
		var dims: Vector2i=Catalog.item_size(item)
		var size: Vector2=Vector2(dims)*step-Vector2.ONE*gap
		var at := origin+Vector2(item.x,item.y)*step
		if budget>0:
			var visible: Dictionary=item.duplicate(true)
			if amount>budget: visible.count=budget
			tile(at,size,visible)
			budget=maxi(0,budget-amount)
		else:
			var sealed := tile(at,size,{},Color("78848c"),true)
			sealed.modulate=Color(0.65,0.65,0.65,1)
			host.label(sealed,"?",Vector2(0,size.y*0.5-16),23,Color("a9adb3"),Vector2(size.x,32)).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var next: Dictionary=host.session.next_search_item(container)
	var duration: float=host.session.search_seconds(next) if not next.is_empty() else 0.0
	var player: Dictionary=host.session.players[host.session.my_id()]
	var progress := 0.0
	if duration>0 and host.session.search_reference(player)==host._loot_index:
		progress=clampf(float(player.get("search",0))/duration,0,0.99)
	var width: float=grid.x*step-gap
	var bar_at := origin+Vector2(0,grid.y*step+18)
	host.rect(host.overlay,bar_at,Vector2(width,4),Color("27333c"))
	var ratio := 1.0 if units<=0 else clampf((revealed+progress)/float(units),0,1)
	host.rect(host.overlay,bar_at,Vector2(width*ratio,4),Color("91bac4"))
	text("F 快捷拾取 · 双击收纳 · 拖入背包",Vector2(952,720),Vector2(374,32),14,MUTED)
	var quick: Array=host.quick_use_slots(player)
	for i in quick.size():
		var entry: Dictionary=quick[i]
		host.button(host.overlay,Catalog.ITEMS[entry.kind].name,Vector2(952+i*174,767),Vector2(163,36),func(): host.use_item(entry.slot,entry.index),false,16)

func hide_tooltip() -> void:
	if is_instance_valid(tooltip): tooltip.queue_free()
	tooltip=null

func update_hover() -> void:
	if host==null or not host.inventory_open or host.modal or host.session.roguelike.active(host.session):
		hide_tooltip()
		return
	if host.drag.active:
		hide_tooltip()
		hover_key=""
		return
	var p_live: Dictionary=host.session.players[host.session.my_id()]
	if is_instance_valid(health): health.text="生命  %d / %d" % [maxf(0,p_live.hp),p_live.max_hp]
	if is_instance_valid(stats): stats.text="攻击 %.1f  ·  减伤 %.0f%%" % [host.session.weapon_damage(p_live),(1.0-host.session.incoming_damage(p_live,1))*100]
	var at: Vector2=host.mouse_point()
	var hit: Dictionary=host.grid_at(at)
	var item: Dictionary={}
	var key := ""
	if not hit.is_empty():
		var index: int=host.index_at(hit.slot,hit.cell)
		if index>=0:
			var items: Array=host.session.visible_items(host.session.container_at(host._loot_index)) if hit.slot=="loot" else host.session.players[host.session.my_id()][hit.slot].items
			if index<items.size(): item=items[index]; key=str(hit.slot)+str(index)
	else:
		for zone in zones:
			if zone.rect.has_point(at): item=zone.item; key=zone.key; break
	if key==hover_key: return
	hover_key=key
	hide_tooltip()
	if item.is_empty(): return
	var p: Dictionary=host.session.players[host.session.my_id()]
	var details: String=Catalog.item_desc(item)
	if item.kind=="weapon":
		var info: Dictionary=Catalog.weapon(int(item.weapon))
		details="构筑伤害 %.1f · 基础 %.1f\n间隔 %.2fs · 距离 %.0f\n\n%s" % [host.session.weapon_damage(p,int(item.weapon),int(item.get("tier",0))),info.damage,info.rate*maxf(0.4,1-Catalog.weapon_rate_bonus(item)),info.reach,details]
	var pos := at+Vector2(18,20)
	pos.x=clampf(pos.x,60,1010)
	pos.y=clampf(pos.y,130,460)
	tooltip=host.rect(host.overlay,pos,Vector2(370,366),Color("100e13"),GOLD)
	tooltip.z_index=30
	host.label(tooltip,Catalog.item_name(item),Vector2(18,15),21,Catalog.item_color(item),Vector2(334,36))
	var label: Label=host.label(tooltip,details,Vector2(18,65),15,INK,Vector2(334,238))
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var dims := Catalog.item_size(item)
	host.label(tooltip,"%d×%d 格  ·  价值 %d ◈" % [dims.x,dims.y,Catalog.item_value(item)],Vector2(18,321),15,GOLD,Vector2(334,25))


func style_scrollbar(bar: VScrollBar) -> void:
	bar.custom_minimum_size.x=14
	for key in ["scroll","scroll_focus"]:
		var track := StyleBoxFlat.new()
		track.bg_color=Color("100d12")
		track.border_color=Color("65523a")
		track.set_border_width_all(1)
		track.set_corner_radius_all(5)
		track.content_margin_left=5
		track.content_margin_right=5
		bar.add_theme_stylebox_override(key,track)
	for key in ["grabber","grabber_highlight","grabber_pressed"]:
		var grip := StyleBoxFlat.new()
		grip.bg_color=Color("ad9163") if key=="grabber" else Color("dbc18e")
		grip.border_color=Color("e4cb98")
		grip.set_border_width_all(1)
		grip.set_corner_radius_all(4)
		grip.content_margin_top=12
		grip.content_margin_bottom=12
		grip.content_margin_left=4
		grip.content_margin_right=4
		bar.add_theme_stylebox_override(key,grip)
	var blank := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.colors=PackedColorArray([Color.TRANSPARENT,Color.TRANSPARENT])
	blank.gradient=gradient
	blank.width=1
	blank.height=1
	for key in ["increment","increment_highlight","increment_pressed","decrement","decrement_highlight","decrement_pressed"]:
		bar.add_theme_icon_override(key,blank)
