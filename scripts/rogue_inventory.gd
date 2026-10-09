extends RefCounted
const Homestead = preload("res://scripts/homestead.gd")
## A run build sheet, independent of extraction grids and drag/drop controls.
const PAPER := Color("ede6da")
const MUTED := Color("a6abbc")
const GOLD := Color("dec18d")
const MINT := Color("8fd8bd")
const CARD := Color("192331")
var host
var health: Label
var health_bar: Panel
var medicine_button: Button
var state_label: Label
var stats_label: Label
var stat_values: Array[Label]=[]
var selected_tab := "reserve"
var reserve_page := 0
var tooltip: Panel
var menu: Control

func signature(p: Dictionary, s) -> String:
	return str([p.get("equipped",{}),p.get("rogue_stash",[]),p.get("rogue_inventory_revision",0),p.weapon,p.get("build_talents",{}),p.get("flask",0),p.rogue_gold,p.rogue_rerolls,s.raid.floor,s.raid.area,s.raid.phase])

func text(parent: Node, value: String, at: Vector2, size: Vector2, font_size: int = 18, color: Color = PAPER) -> Label:
	return host.label(parent,value,at,font_size,color,size)

func card(at: Vector2, size: Vector2, color: Color = CARD) -> Panel:
	var panel: Panel=host.rect(host.overlay,at,size,Color("120f13"),Color("927653"))
	var style: StyleBoxFlat=panel.get_theme_stylebox("panel").duplicate()
	style.set_corner_radius_all(2)
	style.shadow_color=Color(0,0,0,0.7)
	style.shadow_size=12
	panel.add_theme_stylebox_override("panel",style)
	return panel

func socket(parent: Node, at: Vector2, size: Vector2, item: Dictionary = {}, ghost_kind: String = "") -> Control:
	var node=preload("res://scripts/rogue_inventory_socket.gd").new()
	node.position=at
	node.size=size
	node.occupied=not item.is_empty()
	node.tone=Catalog.item_color(item) if not item.is_empty() else Color("8c7654")
	parent.add_child(node)
	if not item.is_empty():
		var texture: Texture2D=host.rogue_field.art.flask_icon if item.kind=="medicine" else host.rogue_field.art.offer_icon({"item":item})
		node.icon=host.rogue_icon(node,texture,Vector2(10,10),size-Vector2(20,20))
	elif not ghost_kind.is_empty():
		node.icon=host.item_icon(node,ghost_kind,Vector2(19,19),size-Vector2(38,38))
		node.icon.modulate=Color(0.65,0.6,0.5,0.18)
	if is_instance_valid(node.icon): node.icon.pivot_offset=node.icon.size*0.5
	return node

func draw(app, p: Dictionary) -> void:
	host=app
	if selected_tab=="build": preload("res://scripts/rogue_build_ui.gd").new().build(app,p); return
	hide_tooltip()
	close_menu()
	stat_values.clear()
	var s=host.session
	var root: Control=host.overlay
	var shade: Panel=host.rect(root,Vector2.ZERO,Vector2(1440,900),Color(0.006,0.004,0.01,0.94))
	shade.mouse_filter=Control.MOUSE_FILTER_STOP
	var backdrop := TextureRect.new()
	backdrop.texture=load("res://assets/ui/rogue-inventory-sanctum-v2.png")
	backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	backdrop.position=Vector2(44,24)
	backdrop.size=Vector2(1352,838)
	backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	text(root,"行  囊",Vector2(108,50),Vector2(210,54),34,GOLD)
	text(root,"第 %d 层 · %s" % [s.raid.floor,s.roguelike.FLOORS[int(s.raid.floor)-1]],Vector2(318,65),Vector2(455,34),17,MUTED)
	var gold_icon: TextureRect=host.rogue_icon(root,host.rogue_field.art.item_icons[10],Vector2(1034,60),Vector2(34,34))
	gold_icon.tooltip_text="魔晶：游商处购买本局武器、装备与游商服务"
	gold_icon.mouse_filter=Control.MOUSE_FILTER_PASS
	text(root,str(p.rogue_gold),Vector2(1080,62),Vector2(82,34),22,GOLD)
	var reroll_icon: TextureRect=host.rogue_icon(root,host.rogue_field.art.item_icons[8],Vector2(1173,60),Vector2(34,34))
	reroll_icon.tooltip_text="刷新卡：在奖励或商店界面使用"
	reroll_icon.mouse_filter=Control.MOUSE_FILTER_PASS
	text(root,str(p.rogue_rerolls),Vector2(1217,62),Vector2(45,34),22,GOLD)
	host.button(root,"×",Vector2(1293,52),Vector2(53,48),host.close_bag,false,28)
	text(root,str(Catalog.HEROES[p.hero].name),Vector2(221,137),Vector2(300,38),29,PAPER).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	text(root,str(Catalog.HEROES[p.hero].title),Vector2(221,179),Vector2(300,25),14,GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var portrait: Sprite2D=host.portrait(root,int(p.hero),Vector2(374,423),430,true)
	if int(p.hero)==3: portrait.texture=load("res://assets/ui/rogue-inventory-muyu-v2.png")
	# Fit every hero inside the equipment niche.
	portrait.scale=Vector2.ONE*minf(447.0/portrait.texture.get_height(),330.0/portrait.texture.get_width())
	portrait.modulate=Color(0.88,0.83,0.84)
	var weapon: Dictionary=p.equipped.get("weapon",{})
	var starter := weapon.is_empty()
	if starter: weapon={"kind":"weapon","weapon":p.weapon,"tier":0}
	equipment(weapon,"主手",Vector2(113,287),starter,0)
	for i in 3:
		equipment(p.equipped.gear[i],["护甲","法器","战靴"][i],[Vector2(536,287),Vector2(113,458),Vector2(536,458)][i],false,i+1)
	health=text(root,"",Vector2(236,664),Vector2(274,27),17,PAPER)
	health.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	host.rect(root,Vector2(251,698),Vector2(244,3),Color("352328"))
	health_bar=host.rect(root,Vector2(251,698),Vector2(244,3),Color("bb5762"))
	host.button(root,"物品",Vector2(746,150),Vector2(160,46),func(): selected_tab="reserve"; host.show_inventory(),selected_tab=="reserve",22)
	host.button(root,"构筑",Vector2(927,150),Vector2(160,46),func(): selected_tab="build"; host.show_inventory(),selected_tab=="build",22)
	text(root,"%d 件" % p.rogue_stash.size(),Vector2(1187,161),Vector2(116,30),16,MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	if selected_tab=="reserve": draw_reserve(p)
	# T1-b (2026-06)：祝福一页隐藏。行囊只有「物品 / 构筑」两个页签，生产路径永远不会把
	# `selected_tab` 设成 "boons"（只有测试会手工注入），所以这里把原先的 `else: draw_boons(p)`
	# 收窄为显式分支：页签名列表、索引顺序、默认选中页（"reserve"）与其它页签渲染全部不变。
	elif selected_tab=="boons": draw_boons(p)
	var supply := socket(root,Vector2(751,624),Vector2(58,58),{"kind":"medicine"})
	bind_item(supply,{"kind":"medicine"},"supply",0,false)
	text(root,"%d%%" % p.flask,Vector2(807,641),Vector2(55,25),15,GOLD)
	medicine_button=host.button(root,"",Vector2(852,632),Vector2(178,42),host.heal_action,false,17)
	state_label=text(root,"",Vector2(1052,640),Vector2(259,27),14,MUTED)
	state_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	for i in 6:
		var x := 145+i*196
		var title: String=["伤害","攻击间隔","移动速度","生命上限","蓝量","综合减伤"][i]
		var title_label := text(root,title,Vector2(x,746),Vector2(166,25),15,MUTED)
		title_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if i==1: stats_label=title_label
		var value := text(root,"",Vector2(x,777),Vector2(166,36),26,PAPER)
		value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		stat_values.append(value)
	text(root,"悬停查看详情   /   右键管理物品",Vector2(88,866),Vector2(650,26),14,MUTED)
	text(root,"TAB / ESC  返回战场",Vector2(1060,866),Vector2(290,26),14,GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	update_live(p)

## T1-b (2026-06)：这一页**不是玩家可见内容** —— 行囊的两个页签是「物品 / 构筑」，没有任何按钮
## 会把 `selected_tab` 设成 "boons"；且 `roguelike.BOONS` 池当前零发放点，`p.rogue_boons` 恒为空。
## 保留渲染器只为旧玩法记录与 `tests/rogue_inventory.gd` 的显式注入，等有了真实发放点再挂页签。
func draw_boons(p: Dictionary) -> void:
	var s=host.session
	for i in 4:
		var boon: Dictionary=s.roguelike.BOONS[i]
		var count: int=int(p.get("rogue_boons",{}).get(boon.stat,0))
		var at := Vector2(771+(i%2)*290,232+(i/2)*192)
		var row := Control.new()
		row.position=at
		row.size=Vector2(246,178)
		host.overlay.add_child(row)
		var icon: TextureRect=host.rogue_icon(row,host.rogue_field.art.offer_icon({"boon":boon}),Vector2(78,3),Vector2(84,84))
		if count==0: icon.modulate=Color(0.5,0.45,0.45,0.45)
		text(row,boon.name,Vector2(0,94),Vector2(246,29),21,GOLD if count>0 else MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var value: String=["伤害 +%d%%" % roundi(float(p.rogue_damage)*100),"生命 +%d" % int(p.rogue_hp),"移速 +%d" % int(p.rogue_speed),"减伤 %d%%" % roundi(minf(0.4,float(p.rogue_defense))*100)][i]
		text(row,"%s  ·  %d 层" % [value,count] if count>0 else "尚未获得",Vector2(0,133),Vector2(246,27),16,PAPER if count>0 else MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		row.tooltip_text=boon.desc+"\n"+("已达到减伤上限。" if i==3 and p.rogue_defense>=0.4 else "本局持续生效。")

func equipment(item: Dictionary, slot: String, at: Vector2, starter: bool, index: int) -> void:
	var row := socket(host.overlay,at,Vector2(92,92),item,["sword","armor","sight","boots"][index])
	text(host.overlay,slot,at+Vector2(-4,101),Vector2(100,27),15,GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if item.is_empty():
		row.tooltip_text=slot+"：尚未装备"
		return
	bind_item(row,item,"equipped",index,starter)

func update_live(p: Dictionary) -> void:
	if not is_instance_valid(health): return
	var s=host.session
	var speed: float=Homestead.bonus(p,"speed")+Catalog.HEROES[p.hero].speed+p.talents[2]*9+float(Catalog.gear_of(int(p.gear)).get("speed",0.0))+s.equipment_speed(p)+float(p.rogue_speed)
	speed*=1.0-float(p.get("rogue_slow",0))
	var values: Array=["%.1f" % s.weapon_damage(p),"%.2f s" % (Catalog.weapon(p.weapon).rate*s.equipment_rate(p)),"%.0f" % speed,str(int(p.max_hp)),"%d / %d" % [p.mana,p.max_mana],"%.1f%%" % ((1.0-s.incoming_damage(p,1.0))*100)]
	for i in stat_values.size(): stat_values[i].text=values[i]
	health.text="%d / %d" % [maxf(0,p.hp),p.max_hp]
	health_bar.size.x=244*clampf(p.hp/maxf(1,p.max_hp),0,1)
	var count: int=s.carried(p,"medicine")
	medicine_button.disabled=p.status!="active" or count<=0 or p.hp>=p.max_hp or p.flask_cd>0 or p.flask_time>0
	medicine_button.text="F  魂灯自救（长按）" if p.status=="down" and p.soul_lamp else "血瓶不足25%" if count<=0 else "%.1fs 后可喝" % p.flask_cd if p.flask_cd>0 else "生命已满" if p.hp>=p.max_hp else "F  喝血瓶"
	state_label.text="战斗中 · 不暂停" if s.raid.phase=="rogue_combat" else "休整中"

func draw_reserve(p: Dictionary) -> void:
	var pages := maxi(1,ceili(p.rogue_stash.size()/12.0))
	reserve_page=clampi(reserve_page,0,pages-1)
	for i in 12:
		var index := reserve_page*12+i
		var item: Dictionary=p.rogue_stash[index] if index<p.rogue_stash.size() else {}
		var tile := socket(host.overlay,Vector2(751+(i%4)*141,222+(i/4)*128),Vector2(110,110),item)
		tile.name="ReserveSlot%d" % i
		if not item.is_empty(): bind_item(tile,item,"reserve",index,false)
	if p.rogue_stash.is_empty(): text(host.overlay,"换下的装备会收纳于此",Vector2(803,607),Vector2(438,28),16,MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	elif pages>1:
		var previous: Button=host.button(host.overlay,"‹",Vector2(943,609),Vector2(56,34),func(): reserve_page-=1; host.show_inventory(),false,24)
		previous.disabled=reserve_page==0
		text(host.overlay,"%d / %d" % [reserve_page+1,pages],Vector2(1008,612),Vector2(86,28),16,MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var next: Button=host.button(host.overlay,"›",Vector2(1105,609),Vector2(56,34),func(): reserve_page+=1; host.show_inventory(),false,24)
		next.disabled=reserve_page>=pages-1

func bind_item(control: Control, item: Dictionary, source: String, index: int, starter: bool) -> void:
	control.set_meta("controller_item","rogue")
	control.mouse_filter=Control.MOUSE_FILTER_STOP
	control.mouse_entered.connect(func(): show_tooltip(item,starter))
	control.mouse_exited.connect(hide_tooltip)
	control.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
			control.accept_event()
			show_menu(item,source,index,starter)
	)

func hide_tooltip() -> void:
	if is_instance_valid(tooltip):
		tooltip.queue_free()
		tooltip=null

func show_tooltip(item: Dictionary, starter: bool) -> void:
	if is_instance_valid(menu): return
	hide_tooltip()
	var p: Dictionary=host.session.players[host.session.my_id()]
	var description := ""
	if item.kind=="weapon":
		var info: Dictionary=Catalog.weapon(int(item.weapon))
		var quality: int=-1 if starter else int(item.get("tier",0))
		var damage: float=host.session.weapon_damage(p,int(item.weapon),quality)
		# The issue weapon has no quality bonus even if another weapon is equipped.
		if starter:
			var preview: Dictionary=p.duplicate(true)
			preview.equipped.weapon={}
			preview.weapon=int(item.weapon)
			damage=host.session.weapon_damage(preview)
		var interval: float=info.rate*host.session.equipment_rate(p)
		description="基础伤害  %.1f\n当前构筑伤害  %.1f   (%+.1f)\n攻击间隔  %.2f 秒\n攻击距离  %.0f   ·   蓝耗  %.0f\n\n%s\n\n%s" % [info.damage,damage,damage-host.session.weapon_damage(p),interval,info.get("reach",0),info.get("mana_cost",0),Catalog.scaling_text(int(item.weapon)),WeaponArts.text(int(item.weapon))]
	elif item.kind=="medicine":
		description="血瓶初始容量100%。\n每次喝下25%容量，回复30%最大生命。\n饮用0.75秒，在0.45秒时生效；受击/闪避可中断。\n每层补充50%容量，清场可补充少量。\n血瓶不可丢弃、不可自救。倒地后长按F两秒使用独立魂灯，每局一次。"
	else:
		description=Catalog.gear_desc(item)+"\n\n"+"装备部位："+Catalog.gear_slot_name(item)+"\n同部位装备互相替换，旧装备自动收纳。"
	if item.has("rogue_id"):
		var design = preload("res://scripts/rogue_equipment.gd")
		description=design.description(item)
		if item.kind=="weapon":
			var preview: Dictionary=p.duplicate(true)
			preview.equipped.weapon=item.duplicate(true)
			preview.weapon=int(item.weapon)
			var damage: float=host.session.weapon_damage(preview)
			description+="\n\n构筑伤害 %.1f（%+.1f）\n攻击间隔 %.2f 秒 · 蓝耗 %.0f\n%s\n%s" % [damage,damage-host.session.weapon_damage(p),Catalog.weapon(int(item.weapon)).rate*host.session.equipment_rate(preview),Catalog.weapon(int(item.weapon)).get("mana_cost",0),Catalog.scaling_text(int(item.weapon)),WeaponArts.text(int(item.weapon))]
		else: description+="\n\n部位："+["护甲","法器 / 瞄具","战靴"][Catalog.gear_slot(item)]+"\n同部位互相替换，旧装备自动收纳。"
		description+="\n\n品质只提升基础属性；条件伤害被动相加。"
	var wide := 430.0 if item.has("rogue_id") else 360.0
	var tall := 520.0 if item.has("rogue_id") else 388.0
	var at: Vector2=host.mouse_point()+Vector2(20,18)
	at.x=clampf(at.x,78,1362-wide)
	at.y=clampf(at.y,76,838-tall)
	tooltip=card(at,Vector2(wide,tall))
	tooltip.z_index=30
	var title := text(tooltip,("初始 · "+str(Catalog.weapon(int(item.weapon)).name)) if starter else Catalog.item_name(item),Vector2(18,14),Vector2(wide-36,46),18 if item.has("rogue_id") else 22,GOLD)
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var body := text(tooltip,description,Vector2(18,65),Vector2(wide-36,tall-115),14 if item.has("rogue_id") else 16)
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	text(tooltip,"角色自带 · 不可丢弃" if starter else "右键：喝血瓶" if item.kind=="medicine" else "右键：装备 / 收回 / 丢弃",Vector2(18,tall-40),Vector2(wide-36,26),15,MINT)

func close_menu() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
		menu=null

func show_menu(item: Dictionary, source: String, index: int, starter: bool) -> void:
	hide_tooltip()
	close_menu()
	var p: Dictionary=host.session.players[host.session.my_id()]
	var version: int=p.rogue_inventory_revision
	menu=Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.z_index=40
	host.overlay.add_child(menu)
	menu.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			menu.accept_event()
			close_menu()
	)
	var at: Vector2=host.mouse_point()
	at.x=clampf(at.x,78,1066)
	at.y=clampf(at.y,76,578)
	var box: Panel=card(at,Vector2(290,262))
	host.overlay.remove_child(box)
	menu.add_child(box)
	box.mouse_filter=Control.MOUSE_FILTER_STOP
	text(box,"初始武器" if starter else Catalog.item_name(item),Vector2(16,12),Vector2(258,30),18,GOLD)
	var act: Button=host.button(box,"角色自带 · 无需收纳" if starter else "喝血瓶" if source=="supply" else "装备" if source=="reserve" else "收回备用背包",Vector2(14,54),Vector2(262,43),func(): manage(source,index,"use" if source=="supply" else "equip" if source=="reserve" else "stow",version),false,16)
	act.disabled=starter or p.status!="active" or (source=="supply" and (p.hp>=p.max_hp or p.flask<25))
	var discard: Button=host.button(box,"丢弃此物品…",Vector2(14,105),Vector2(262,43),func():
		# An inline second step keeps a right-click misfire from destroying gear.
		for child in box.get_children(): child.hide()
		text(box,"丢在地面，队友可按 E 拾取",Vector2(16,14),Vector2(258,32),16,Color("f29b99"))
		text(box,Catalog.item_name(item),Vector2(16,50),Vector2(258,30),16)
		host.button(box,"确认丢弃",Vector2(14,101),Vector2(262,43),func(): manage(source,index,"discard",version),false,16)
		host.button(box,"取消",Vector2(14,156),Vector2(262,43),close_menu,false,16)
	,false,16)
	discard.disabled=starter or p.status!="active" or source=="supply"
	# E1 (2026-10) · 魔晶回收。这是 `rogue_sell` 的**行囊入口**：满 12 格时的自救通道，
	# 与商店面板里的回收区（`main.gd` 的 `_build_rogue_sell_block()`）是多入口同一动作。
	# 服务端 `sell_action()`（`roguelike.gd:996`）的门是
	# `status=="active" && s.running && !raid.ended` → `payload.revision==raid.revision`
	# → `raid.phase=="rogue_shop"` → `version==p.rogue_inventory_revision`
	# → `source=="reserve"` → 序号合法 → 是装备 → 该 instance_id 未被回收过。
	# 所以这里：`revision` 取点击那一刻的 raid.revision 活值、`version` 取点击那一刻的
	# `p.rogue_inventory_revision` 活值（与 `:252` 冻结的那份不同 —— 那个是给既有动作用的，
	# 回收这条走服务端新契约，两处各自独立）。回收价直接问服务端的真实函数
	# `sell_price(s,item)`，客户端不复制公式。
	var sell_price: int=int(host.session.roguelike.sell_price(host.session,item)) if not item.is_empty() else 0
	var sellable: bool=source=="reserve" and not starter and not item.is_empty() and sell_price>0
	var sell: Button=host.button(box,"回收此物品…",Vector2(14,170),Vector2(262,43),func():
		# 与「丢弃」同一套内联二次确认写法：右键误触绝不会直接卖掉装备。
		if not sellable: return
		for child in box.get_children(): child.hide()
		text(box,"卖回给游商，物品永久离开本局行囊",Vector2(16,14),Vector2(258,32),16,Color("f2c98f"))
		text(box,"%s  ·  魔晶 +%d" % [Catalog.item_name(item),sell_price],Vector2(16,50),Vector2(258,30),16)
		host.button(box,"确认回收",Vector2(14,101),Vector2(262,43),func(): sell_item(index),false,16)
		host.button(box,"取消",Vector2(14,156),Vector2(262,43),close_menu,false,16)
	,false,16)
	# 「只有游商处能回收」是设计规则（服务端 rogue_sell 的 phase 门）。禁用态要**看得见**：
	# 光靠 GothicButton 变灰不足以让人明白"点不动"是有条件的，所以非游商时直接把原因写进按钮文字。
	var shop_phase: bool=host.session.raid.phase=="rogue_shop"
	if not shop_phase: sell.text="回收 · 需到游商处"
	sell.disabled=not sellable or p.status!="active" or not shop_phase
	if host.session.raid.phase!="rogue_shop":
		sell.tooltip_text="只有游商处可以回收装备"
	elif starter or source!="reserve":
		sell.tooltip_text="只有备用行囊里的装备可以回收；已装备的物件请先收回行囊"
	elif not item.is_empty() and sell_price<=0:
		sell.tooltip_text="游商不收购这一件"
	else:
		sell.tooltip_text="卖回给游商换取 %d 魔晶（物品永久离开本局行囊）" % sell_price
	host.button(box,"取消",Vector2(14,213),Vector2(262,43),close_menu,false,16)

## E1 · 回收的实际发包。只做两件事：读**活值** revision/version，发 `rogue_sell`。
## `index` 是 `show_menu()` 收下的行囊序号（`draw_reserve()` 传的就是它在 `rogue_stash`
## 里的真实下标），不重新推导。
func sell_item(index: int) -> void:
	close_menu()
	if index<0: return
	var p: Dictionary=host.session.players[host.session.my_id()]
	host.session.action("rogue_sell",{"revision":int(host.session.raid.revision),"version":int(p.rogue_inventory_revision),"source":"reserve","index":index})
	host.show_inventory()

func manage(source: String, index: int, verb: String, version: int) -> void:
	close_menu()
	host.session.action("rogue_inventory",{"source":source,"index":index,"verb":verb,"version":version})
	host.show_inventory()

