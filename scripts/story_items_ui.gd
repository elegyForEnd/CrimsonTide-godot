extends Control
## Rendered Controls over authoritative campaign inventory. No economy mutations here.
const Items = preload("res://scripts/story_inventory.gd")
const Grid = preload("res://scripts/story_item_grid.gd")
const UISkin = preload("res://scripts/story_ui_skin.gd")
const PAPER := Color("e9dfcd")
const GOLD := Color("d5b67a")
const MUTED := Color("9aa6b5")
var screen
var campaign
var inventory
var tab := "bag"
var selected_source := "bag"
var selected_uid := ""
var selected_product := ""
var buyback := false
var shop_page := 0
var status := "左键选择 · 拖拽移动 · 拖拽时 R 旋转 · 右键或双击快捷操作"
var content: Control
var details: Label
var detail_title: Label
var status_label: Label
var action_bar: Control
var forge_preview: Control
var grids: Array=[]
var atlas: Texture2D
var skin: Texture2D
var textures: Dictionary={}
var icon_regions: Dictionary={}
var confirmation: ConfirmationDialog

func _ready() -> void:
	size=Vector2(1296,760); mouse_filter=MOUSE_FILTER_STOP
	campaign=screen.campaign; inventory=campaign.inventory; inventory.initialize()
	atlas=load("res://assets/story/items/inventory-atlas-v2.png")
	icon_regions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/story/items/icon-regions.json"))
	skin=load("res://assets/story/items/interface-sanctum-v1.png")
	var frame := TextureRect.new(); frame.texture=skin; frame.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; frame.size=size; frame.mouse_filter=MOUSE_FILTER_IGNORE; add_child(frame)
	content=Control.new(); content.size=size; add_child(content)
	render()

func box_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color=bg; style.border_color=border; style.set_border_width_all(1); style.set_corner_radius_all(3)
	return style

func text(parent: Node, value: String, at: Vector2, extent: Vector2, font_size: int = 17, color: Color = PAPER) -> Label:
	var node: Label=screen.label(parent,value,at,extent,font_size); node.add_theme_color_override("font_color",color)
	return node

func button(parent: Node, value: String, at: Vector2, extent: Vector2, action: Callable, disabled: bool = false) -> Button:
	var node: Button=screen.button(parent,value,at,extent,action); node.disabled=disabled
	UISkin.button(node)
	return node

func box(at: Vector2, extent: Vector2) -> Panel:
	var p := Panel.new(); p.position=at; p.size=extent; p.add_theme_stylebox_override("panel",box_style(Color("070e1a35"),Color("00000000"))); p.mouse_filter=MOUSE_FILTER_IGNORE; content.add_child(p); return p

func picture(parent: Node, base: String, at: Vector2, extent: Vector2) -> TextureRect:
	var image := TextureRect.new(); image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture=icon({"base":base}); image.position=at; image.size=extent; image.mouse_filter=MOUSE_FILTER_IGNORE
	parent.add_child(image); return image

func stat_card(title: String, value: String, base: String, at: Vector2, ratio: float = -1) -> void:
	var card := Panel.new(); card.position=at; card.size=Vector2(229,67); card.clip_contents=true; card.add_theme_stylebox_override("panel",UISkin.frame(4)); content.add_child(card)
	picture(card,base,Vector2(8,7),Vector2(42,49))
	text(card,title,Vector2(61,7),Vector2(156,21),14,MUTED)
	text(card,value,Vector2(61,29),Vector2(156,28),22,PAPER)
	if ratio>=0:
		var bar := ProgressBar.new(); bar.show_percentage=false; bar.position=Vector2(6,61); bar.size=Vector2(217,3); bar.value=clampf(ratio,0,1)*100; bar.mouse_filter=MOUSE_FILTER_IGNORE; card.add_child(bar)

func icon(item: Dictionary) -> Texture2D:
	var index := int(Items.BASES[item.base].icon)
	if not textures.has(index):
		var texture := AtlasTexture.new(); texture.atlas=atlas
		var region: Array=icon_regions.regions[index]
		texture.region=Rect2(region[0],region[1],region[2],region[3])
		textures[index]=texture
	return textures[index]

func draw_icon(node: Control, item: Dictionary, target: Rect2) -> void:
	var texture := icon(item); var extent := texture.get_size()
	var ratio := minf(target.size.x/extent.x,target.size.y/extent.y)
	var draw_size := extent*ratio
	node.draw_texture_rect(texture,Rect2(target.get_center()-draw_size*0.5,draw_size),false)

func grid(source: String, at: Vector2, dims: Vector2i, cell: float) -> Control:
	var g := Grid.new(); g.ui=self; g.source=source; g.position=at; g.grid_size=dims; g.cell=cell
	content.add_child(g); grids.append(g); return g

func render() -> void:
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	grids.clear()
	forge_preview=null
	text(content,"守 望 者 行 装",Vector2(62,18),Vector2(500,40),28,GOLD)
	text(content,"银币  %d     铁料  %d + %d     导光晶石  %d" % [campaign.state.coins,campaign.state.materials,inventory.count("scrap"),inventory.count("crystal")],Vector2(690,28),Vector2(490,26),16,GOLD)
	button(content,"×",Vector2(1220,17),Vector2(46,38),screen.close_panel)
	var tabs := {"bag":"行囊","character":"人物","stash":"仓库","shop":"交易 / 商店","forge":"锻造"}
	var x := 56.0
	for key in tabs:
		var key_copy: String=key
		var active: bool=key==tab
		var node := button(content,tabs[key],Vector2(x,74),Vector2(168,40),func(): tab=key_copy; shop_page=0; render(),key in ["stash","shop","forge"] and int(campaign.state.stage)!=0)
		if active: UISkin.button(node,true)
		x+=175
	text(content,"营地服务" if int(campaign.state.stage)==0 else "野外仅开放行囊与人物",Vector2(964,84),Vector2(290,30),16,MUTED)
	box(Vector2(28,132),Vector2(536,540))
	box(Vector2(585,132),Vector2(682,540))
	text(content,"血月行囊  ·  10 × 6",Vector2(610,145),Vector2(340,28),20,GOLD)
	button(content,"整理",Vector2(1115,145),Vector2(125,32),func(): perform(func(): return inventory.tidy("bag")))
	grid("bag",Vector2(635,185),Items.BAG,57)
	var occupied := 0
	for item in campaign.state.bag: occupied+=Items.dimensions(item).x*Items.dimensions(item).y
	text(content,"%d / 60 格     %d 件     药剂栏 %d / 15" % [occupied,campaign.state.bag.size(),campaign.state.potions],Vector2(635,537),Vector2(610,26),15,MUTED)
	detail_title=text(content,"选择物品查看详情",Vector2(635,571),Vector2(600,28),19,GOLD)
	details=text(content,"",Vector2(635,603),Vector2(598,68),15,PAPER)
	action_bar=Control.new(); action_bar.position=Vector2(610,681); action_bar.size=Vector2(630,39); content.add_child(action_bar)
	match tab:
		"bag","character": character_panel()
		"stash": stash_panel()
		"shop": shop_panel()
		"forge": forge_panel()
	status_label=text(content,status,Vector2(58,723),Vector2(1182,30),15,GOLD)
	update_selection()

func hero_row() -> void:
	for hero in 3:
		var index: int=hero
		var b := button(content,Items.HEROES[hero],Vector2(47+hero*163,148),Vector2(150,37),func(): campaign.switch_hero(index); render())
		if hero==int(campaign.state.hero): UISkin.button(b,true)

func character_panel() -> void:
	hero_row()
	var hero := int(campaign.state.hero)
	text(content,"Lv.%d   %s   ·   %s" % [campaign.level(),Items.HEROES[hero],["赤晶剑士","晨星术士","夜鸦游侠"][hero]],Vector2(52,199),Vector2(480,32),22,GOLD)
	if tab=="bag":
		var portrait := TextureRect.new(); portrait.texture=load("res://assets/portrait-%d.png" % hero); portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.position=Vector2(175,236); portrait.size=Vector2(218,325); portrait.mouse_filter=MOUSE_FILTER_IGNORE; content.add_child(portrait)
		for i in 3:
			var slot: String=Items.SLOTS[i]
			var at: Vector2=[Vector2(54,274),Vector2(438,274),Vector2(438,432)][i]
			text(content,Items.SLOT_NAMES[slot],at-Vector2(0,28),Vector2(95,26),16,MUTED)
			grid("equipped:%d:%s" % [hero,slot],at,Vector2i.ONE,94)
		var health := ProgressBar.new(); health.show_percentage=false; health.position=Vector2(58,572); health.size=Vector2(465,8); health.max_value=campaign.max_hp(); health.value=campaign.state.hp; content.add_child(health)
		text(content,"伤害 %.0f     生命 %.0f / %.0f" % [campaign.damage(),campaign.state.hp,campaign.max_hp()],Vector2(53,590),Vector2(484,28),19,PAPER)
		text(content,"拖入装备槽换装 · 双击装备卸下\n三位守望者各自保存装备与专精",Vector2(53,628),Vector2(484,39),14,MUTED)
	else:
		stat_card("攻击伤害","%.0f" % campaign.damage(),"sword",Vector2(55,243))
		stat_card("最大生命","%.0f" % campaign.max_hp(),"potion",Vector2(299,243),campaign.state.hp/campaign.max_hp())
		stat_card("护衣减伤",str(int(campaign.state.gear.armor)*2),"plate",Vector2(55,315))
		stat_card("技能冷却","%.2f 秒" % maxf(2,5-int(campaign.state.gear.charm)*0.15-campaign.specialty(2)*0.2),"frost",Vector2(299,315))
		stat_card("战役经验",str(campaign.state.xp),"crystal",Vector2(55,387),campaign.state.xp/pow(campaign.level()/0.3,2))
		stat_card("专精点",str(campaign.skill_points()),"raven",Vector2(299,387))
		for i in 3:
			var rank: int=i
			var line: String=["锋刃 · 伤害 +4 / 级","守夜 · 生命 +8 / 级","相位 · 冷却 -0.2秒 / 级"][i]
			text(content,line+"   %d / 10" % campaign.specialty(i),Vector2(53,464+i*52),Vector2(375,35),16,PAPER)
			button(content,"＋",Vector2(464,464+i*52),Vector2(64,35),func():
				status="专精已学习。" if campaign.learn(rank) else "需要回营地，且有可用专精点。"; render(),int(campaign.state.stage)!=0 or campaign.skill_points()<=0 or campaign.specialty(i)>=10)
		button(content,"重置专精 · 100银币",Vector2(54,625),Vector2(471,34),func():
			status="专精已重置。" if campaign.reset_specialty() else "需要100银币并完成第三幕祭场准备 A3-M05。"; render(),int(campaign.state.stage)!=0)

func stash_panel() -> void:
	text(content,"战役保管箱  ·  12 × 10",Vector2(53,150),Vector2(360,30),22,GOLD)
	button(content,"整理",Vector2(443,149),Vector2(91,32),func(): perform(func(): return inventory.tidy("stash")))
	grid("stash",Vector2(53,199),Items.VAULT,40)
	text(content,"双击存取 · 可跨两侧拖拽 · 满格会拒绝移动",Vector2(53,606),Vector2(480,27),15,MUTED)
	button(content,"领取暂存区 · %d 件" % campaign.state.overflow.size(),Vector2(53,638),Vector2(481,32),show_overflow,campaign.state.overflow.is_empty())

func show_overflow() -> void:
	var dialog := AcceptDialog.new(); dialog.title="奖励暂存 · 物品不会丢失"; dialog.size=Vector2i(620,440); add_child(dialog)
	var scroll := ScrollContainer.new(); scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scroll.offset_bottom=-45; dialog.add_child(scroll)
	var column := VBoxContainer.new(); column.size_flags_horizontal=SIZE_EXPAND_FILL; scroll.add_child(column)
	for item in campaign.state.overflow:
		var uid: String=item.uid
		var b := Button.new(); b.text=item.name+" · 取到行囊"; b.custom_minimum_size=Vector2(560,38); column.add_child(b)
		b.pressed.connect(func():
			perform(func(): return inventory.transfer("overflow",uid,"bag")); dialog.queue_free())
	dialog.popup_centered()

func shop_panel() -> void:
	text(content,screen.npc_name(4)+" · 第%d幕货架" % campaign.state.act,Vector2(52,149),Vector2(480,32),22,GOLD)
	button(content,"购买",Vector2(53,196),Vector2(229,36),func(): buyback=false; shop_page=0; selected_product=""; render())
	button(content,"回购（最近12件）",Vector2(297,196),Vector2(235,36),func(): buyback=true; shop_page=0; selected_product=""; render())
	var products: Array=campaign.state.buyback if buyback else inventory.stock()
	var pages := maxi(1,ceili(products.size()/5.0)); shop_page=clampi(shop_page,0,pages-1)
	for row in mini(5,maxi(0,products.size()-shop_page*5)):
		var item: Dictionary=products[shop_page*5+row]; var uid: String=item.uid
		var cost: int=int(item.repurchase) if buyback else Items.price(item)
		var at := Vector2(54,246+row*65)
		var b := button(content,"",at,Vector2(478,60),func(): selected_product=uid; selected_uid=""; update_selection())
		b.add_theme_stylebox_override("normal",UISkin.frame(6))
		var art := TextureRect.new(); art.texture=icon(item); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; art.position=Vector2(6,3); art.size=Vector2(58,54); art.mouse_filter=MOUSE_FILTER_IGNORE; b.add_child(art)
		text(b,item.name,Vector2(77,5),Vector2(265,25),17,Items.tone(item))
		text(b,"%d 银币  ·  %s" % [cost,"整堆回购 ×%d" % item.count if buyback else "库存 %d" % item.stock],Vector2(77,30),Vector2(375,25),15,MUTED)
	button(content,"上一页",Vector2(55,585),Vector2(130,35),func(): shop_page-=1; render(),shop_page==0)
	text(content,"%d / %d" % [shop_page+1,pages],Vector2(243,592),Vector2(95,26),17,GOLD)
	button(content,"下一页",Vector2(400,585),Vector2(130,35),func(): shop_page+=1; render(),shop_page==pages-1)
	text(content,"选货架商品查看属性并购买。\n选择右侧行囊物品，按「出售」交易整堆。",Vector2(55,635),Vector2(480,42),15,MUTED)

func forge_panel() -> void:
	text(content,screen.npc_name(2)+" · 炉火工坊",Vector2(53,150),Vector2(480,32),23,GOLD)
	text(content,"打造 / 强化 / 导光镶嵌 / 分解",Vector2(53,193),Vector2(480,28),19,PAPER)
	forge_preview=Control.new(); forge_preview.position=Vector2(55,235); forge_preview.size=Vector2(474,113); content.add_child(forge_preview)
	var hero := int(campaign.state.hero)
	var bases: Array=[["sword","plate"],["staff","robe"],["dagger","coat"]][hero]
	for i in 2:
		var base: String=bases[i]
		button(content,"打造"+str(Items.BASES[base].name),Vector2(55+i*244,357),Vector2(233,36),func(): perform(func(): return inventory.craft(base)))
	for i in 3:
		var slot: String=Items.SLOTS[i]
		var at := Vector2(58+i*163,437)
		text(content,Items.SLOT_NAMES[slot],at-Vector2(0,30),Vector2(140,24),16,MUTED)
		grid("equipped:%d:%s" % [hero,slot],at,Vector2i.ONE,126)
	text(content,"铁料优先扣材料钱包，再扣行囊铁料。\n资源不够时，原物品与所有资源保持完整。",Vector2(54,601),Vector2(477,58),16,MUTED)
	text(content,"打造费用：%d 银币 / %d 铁料" % [90+int(campaign.state.act)*35,6+int(campaign.state.act)*2],Vector2(54,569),Vector2(477,28),16,GOLD)

func select(source: String, uid: String) -> void:
	selected_source=source; selected_uid=uid; selected_product=""; update_selection()

func update_selection() -> void:
	for g in grids: g.queue_redraw()
	for child in action_bar.get_children(): action_bar.remove_child(child); child.queue_free()
	if is_instance_valid(forge_preview):
		for child in forge_preview.get_children(): forge_preview.remove_child(child); child.queue_free()
	var item: Dictionary={}
	if selected_product!="":
		var products: Array=campaign.state.buyback if buyback else inventory.stock()
		var index := Items.find(products,selected_product)
		if index>=0: item=products[index]
	else: item=inventory.item_at(selected_source,selected_uid)
	if item.is_empty():
		detail_title.text="选择物品查看详情"; details.text="不同装备占格不同。拖拽时绿色为可放，红色为放不下。"
		if is_instance_valid(forge_preview): text(forge_preview,"选择行囊或身上的装备\n查看强化前后属性与费用",Vector2(30,28),Vector2(410,75),20,GOLD)
		return
	detail_title.text=item.name+"  ·  "+Items.QUALITY[int(item.quality)]+"  ·  %d×%d 格" % [Items.dimensions(item).x,Items.dimensions(item).y]
	detail_title.add_theme_color_override("font_color",Items.tone(item))
	# Compact two-column summary; full description is available as a tooltip.
	details.tooltip_text=Items.describe(item); details.mouse_filter=MOUSE_FILTER_PASS
	if item.slot in Items.SLOTS:
		var old: Dictionary=campaign.state.equipment[int(campaign.state.hero)].get(item.slot,{})
		var current := Items.stats(item); var previous := Items.stats(old)
		details.text="伤害 +%d    生命 +%d    强化 +%d    %s\n对比当前%s：伤害 %+d / 生命 %+d\n%s   ·   出售 %d 银币" % [current.damage,current.hp,item.upgrade,"已镶嵌" if item.socket else "未镶嵌",Items.SLOT_NAMES[item.slot],int(current.damage)-int(previous.damage),int(current.hp)-int(previous.hp),"通用" if int(Items.BASES[item.base].hero)<0 else "适用 "+Items.HEROES[int(Items.BASES[item.base].hero)],Items.sale_price(item)]
		if is_instance_valid(forge_preview):
			picture(forge_preview,item.base,Vector2(0,2),Vector2(85,109))
			text(forge_preview,item.name+"   +%d" % item.upgrade,Vector2(104,0),Vector2(368,29),20,Items.tone(item))
			var next := item.duplicate(true); next.upgrade=mini(5,int(item.upgrade)+1)
			var upgraded := Items.stats(next)
			text(forge_preview,"伤害 %d → %d    生命 %d → %d" % [current.damage,upgraded.damage,current.hp,upgraded.hp],Vector2(104,34),Vector2(368,25),16,PAPER)
			var track := EnhancementTrack.new(); track.rank=int(item.upgrade); track.position=Vector2(112,72); track.size=Vector2(320,30); forge_preview.add_child(track)
	else:
		details.text={"potion":"使用：恢复50%最大生命；满血时装入药剂栏。","scrap":"整堆使用加入铁料钱包；也可直接作为锻造材料。","crystal":"导光镶嵌材料 · 每件装备可镶嵌一次。"}[item.base]+"\n持有 ×%d   ·   堆叠上限 %d   ·   出售整堆 %d 银币" % [item.count,Items.BASES[item.base].stack,Items.sale_price(item)]
	var x := 0.0
	if selected_product!="":
		var cost := int(item.repurchase) if buyback else Items.price(item)
		button(action_bar,"回购整堆 · %d" % cost if buyback else "购买一件 · %d" % cost,Vector2.ZERO,Vector2(290,36),func(): perform(func(): return inventory.buy(selected_product,buyback))); return
	if tab=="forge" and item.slot in Items.SLOTS:
		var cost: Dictionary=inventory.forge_cost(item)
		button(action_bar,"强化 · %d币 / %d料" % [cost.coins,cost.materials],Vector2.ZERO,Vector2(237,36),func(): perform(func(): return inventory.forge(selected_source,selected_uid,"upgrade")),int(item.upgrade)>=5)
		button(action_bar,"镶嵌 · 80币 / 1晶",Vector2(245,0),Vector2(231,36),func(): perform(func(): return inventory.forge(selected_source,selected_uid,"socket")),bool(item.socket))
		var salvage := button(action_bar,"分解",Vector2(485,0),Vector2(140,36),func(): confirm_salvage(),selected_source!="bag"); UISkin.button(salvage,false,true); return
	if tab=="shop" and selected_source=="bag":
		button(action_bar,"出售整堆 · %d银币" % Items.sale_price(item),Vector2.ZERO,Vector2(295,36),func(): perform(func(): return inventory.sell(selected_uid))); return
	if selected_source.begins_with("equipped:"):
		var parts := selected_source.split(":")
		button(action_bar,"卸到行囊",Vector2.ZERO,Vector2(175,36),func(): perform(func(): return inventory.unequip(int(parts[1]),parts[2]))); return
	if selected_source=="bag":
		if item.slot in Items.SLOTS:
			button(action_bar,"装备",Vector2.ZERO,Vector2(135,36),func(): perform(func(): return inventory.equip("bag",selected_uid))); x=145
		elif item.base in ["potion","scrap"]:
			button(action_bar,"使用",Vector2.ZERO,Vector2(135,36),func(): perform(func(): return inventory.use(selected_uid))); x=145
		button(action_bar,"旋转 R",Vector2(x,0),Vector2(135,36),func(): perform(func(): return inventory.rotate("bag",selected_uid))); x+=145
		if tab=="stash": button(action_bar,"存入仓库",Vector2(x,0),Vector2(175,36),func(): perform(func(): return inventory.transfer("bag",selected_uid,"stash")))
	elif selected_source=="stash": button(action_bar,"取回行囊",Vector2.ZERO,Vector2(175,36),func(): perform(func(): return inventory.transfer("stash",selected_uid,"bag")))

func quick_action(source: String, uid: String) -> void:
	if tab=="shop": status="出售请点击底部按钮，避免误卖。"; status_label.text=status; return
	if tab=="forge": return
	if tab=="stash" and source in ["bag","stash"]: perform(func(): return inventory.transfer(source,uid,"stash" if source=="bag" else "bag")); return
	if source.begins_with("equipped:"):
		var parts := source.split(":"); perform(func(): return inventory.unequip(int(parts[1]),parts[2])); return
	var item: Dictionary=inventory.item_at(source,uid)
	if item.is_empty(): return
	if item.slot in Items.SLOTS: perform(func(): return inventory.equip(source,uid))
	elif source=="bag": perform(func(): return inventory.use(uid))

func perform(action: Callable) -> void:
	action.call(); status=inventory.last_message; render(); screen.refresh()

func confirm_salvage() -> void:
	var item: Dictionary=inventory.item_at(selected_source,selected_uid)
	if item.is_empty(): return
	var uid: String=selected_uid
	confirmation=ConfirmationDialog.new(); confirmation.title="确认分解"; confirmation.dialog_text="分解「%s」将永久移除这件装备。\n返还 %d 铁料；镶嵌的晶石不返还。" % [item.name,2+int(item.tier)+int(item.quality)*2+int(item.upgrade)]
	confirmation.confirmed.connect(func(): perform(func(): return inventory.forge("bag",uid,"salvage")); confirmation.queue_free())
	confirmation.canceled.connect(func(): confirmation.queue_free())
	add_child(confirmation); confirmation.popup_centered(Vector2i(560,190))

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode==KEY_R:
		var data: Variant=get_viewport().gui_get_drag_data()
		if data is Dictionary and data.get("story_item",false): data.rotated=not bool(data.rotated); data.offset=Vector2i.ZERO
		elif selected_source in ["bag","stash"]: perform(func(): return inventory.rotate(selected_source,selected_uid))
		get_viewport().set_input_as_handled()

class EnhancementTrack extends Control:
	var rank := 0
	func _draw() -> void:
		draw_line(Vector2(10,14),Vector2(294,14),Color("7b6745"),2)
		for i in 5:
			var p := Vector2(12+i*70,14)
			var corners := PackedVector2Array([p+Vector2(0,-10),p+Vector2(8,0),p+Vector2(0,10),p+Vector2(-8,0)])
			draw_colored_polygon(corners,Color("d99b52") if i<rank else Color("34353f"))
			corners.append(corners[0]); draw_polyline(corners,Color("b09a68"),1,true)
