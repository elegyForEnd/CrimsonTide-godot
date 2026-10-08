extends RefCounted
## The camp bag panel behind TAB: 「远征行囊 / 守夜人仓库」.
##
## It is the raid bag panel with the vault bolted on: the same worn sockets, the same
## carried backpack and dimensional pocket, the same socket artwork (through
## `item_tile.gd`), and on the right the 15x15 vault the player dragged things in and
## out of. The two halves sit on one screen so loot moves between them by dragging.
##
## Presentation only, like `extraction_inventory.gd`: it registers its grids and
## sockets with `main.gd`'s drag controller (`host.grids`, `host.equip_zones`,
## `host.cabinet_zones`) and never edits storage itself. The edits belong to
## `camp_storage.gd`, and the save file is written there after every accepted change.
##
## Geometry follows `assets/ui/camp-pack-vault-v1.png` (the placeholder backdrop built
## by `tools/make_camp_pack_backdrop.gd`): three columns separated by two gold rails,
## so the drawn positions below line up with what the image already frames.
const ItemTile := preload("res://scripts/item_tile.gd")

const GOLD := Color("cbb087")
const INK := Color("ede5d8")
const MUTED := Color("9d9791")
const POCKET_TONE := Color("b7a3d3")
const BAG_TONE := Color("bdab81")
const VAULT_TONE := Color("c2a06a")

# The backdrop is drawn at this size and offset; every column below is expressed in
# the same on-screen space.
const PANEL_AT := Vector2(36,28)
const PANEL_SIZE := Vector2(1368,828)
# Columns, from the generator's source coordinates.
const PORTRAIT_X := 168.0
const CARRIED_X := 503.0
const VAULT_X := 802.0
const VAULT_CELL := 30.0
const VAULT_GAP := 2.0
const CELL := 29.0
const GAP := 2.0
const CABINET_SLOTS := 4
const CABINET_CELL := 44.0

var host
var zones: Array = []
var focus_vault := false
var vault_scroll := 0
## The full-screen sheet that owns every click the columns do not use. `main.gd` clears the
## overlay before each repaint, so this node is rebuilt with the panel.
var shield: Control

func text(value: String, at: Vector2, size: Vector2, font_size: int = 17, color: Color = INK) -> Label:
	return host.label(host.overlay,value,at,font_size,color,size)

func draw(app, p: Dictionary) -> void:
	host=app
	zones.clear()
	host.grids.clear()
	host.equip_zones.clear()
	host.cabinet_zones.clear()
	host.slot_zone_rects.clear()
	var player := p
	# The panel owns the screen, so the camp's own Controls (the 家园设施 rows, the 出发 button,
	# the station markers) must not answer a click that was aimed at a socket. They live behind
	# the overlay, and Godot hands a click to the topmost Control that does not ignore the mouse
	# — the panel is drawn with plain nodes, so nothing was claiming the empty space and the
	# click fell through to the page below (clicking 主手 also warped to 晨光菜园). One
	# transparent sheet, added before everything else, claims it instead. `home_screen.gd` does
	# the same thing with the full-rect MOUSE_FILTER_STOP root of the 炉边厨房 / 家园商店 pages.
	shield=Control.new()
	shield.name="CampPackShield"
	shield.mouse_filter=Control.MOUSE_FILTER_STOP
	shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.overlay.add_child(shield)
	var backdrop := TextureRect.new()
	backdrop.texture=load("res://assets/ui/camp-pack-vault-v1.png")
	backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	backdrop.position=PANEL_AT
	backdrop.size=PANEL_SIZE
	backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	host.overlay.add_child(backdrop)
	text("远 征 行 囊",Vector2(90,50),Vector2(420,50),31,GOLD)
	text("携带价值  %d ◈" % host.loot_total(player),Vector2(560,70),Vector2(260,30),20,GOLD)
	host.button(host.overlay,"×",Vector2(1320,46),Vector2(52,48),host.close_bag,false,28)
	worn_kit(player)
	carried(player)
	vault(player)
	text("拖拽搬运 · R / 右键旋转 · 双击收纳或换装 · 仓库即存档",Vector2(87,862),Vector2(820,26),14,MUTED)
	text("快捷道具只能拖进 [1][2][3]",Vector2(560,862),Vector2(300,26),14,MUTED)
	text("TAB / ESC  关闭",Vector2(1230,862),Vector2(190,26),14,GOLD)
	# An accidental drop outside the three columns is a miss, not a throw on the
	# ground: the camp has no ground to throw things on.
	# Protect the three columns from an accidental drop outside their grids, and tell
	# the drag system where the panel ends: outside the backdrop a released item is
	# dropped on the camp floor, and the frosted sheet says so before the player lets go.
	host.panel_rects.append(Rect2(60,130,PANEL_SIZE.x-30,700))
	host.drop_region=Rect2(PANEL_AT,PANEL_SIZE)
	host.drop_art="res://assets/ui/camp-pack-vault-v1.png"
	host.update_frost_art()

# --- left column: the Watcher and what they are wearing ------------------------
func worn_kit(p: Dictionary) -> void:
	text(str(Catalog.HEROES[p.hero].name),Vector2(PORTRAIT_X,150),Vector2(287,35),27,INK).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var portrait: Sprite2D=host.portrait(host.overlay,int(p.hero),Vector2(PORTRAIT_X+144,395),340,true)
	if int(p.hero)==3: portrait.texture=load("res://assets/ui/rogue-inventory-muyu-v2.png")
	portrait.scale=Vector2.ONE*minf(340.0/portrait.texture.get_height(),228.0/portrait.texture.get_width())
	portrait.modulate=Color(0.85,0.82,0.82)
	var rows: Array=[{"item":host.session.kit_weapon(p),"type":"weapon","index":0,"title":"主手"}]
	for i in 3: rows.append({"item":host.session.kit_gear(p)[i],"type":"gear","index":i,"title":["护甲","瞄具","轻靴"][i]})
	for i in 2: rows.append({"item":host.session.kit_charms(p)[i],"type":"charm","index":i,"title":"饰品"})
	for i in rows.size():
		var row: Dictionary=rows[i]
		var at := Vector2(PORTRAIT_X if i%2==0 else PORTRAIT_X+204,249+int(i/2)*123)
		var item: Dictionary=row.item
		var node := ItemTile.tile(host,at,Vector2(67,67),item)
		var key: String="weapon" if row.type=="weapon" else "%s%d" % [row.type,row.index]
		host.equip_zones[key]=Rect2(at,Vector2(67,67))
		text(row.title,at+Vector2(-5,72),Vector2(77,24),14,GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if not item.is_empty():
			zones.append({"rect":Rect2(at,Vector2(67,67)),"item":item,"key":key})
			var off: Button=host.button(host.overlay,"卸",at+Vector2(46,-4),Vector2(22,21),func(): host.camp_unequip(row.type,row.index),false,11)
			off.tooltip_text="卸下 "+Catalog.item_name(item)
		elif row.type=="weapon":
			host.item_icon(node,Catalog.weapon_icon(int(p.weapon)),Vector2(8,8),Vector2(51,51)).modulate=Color(1,1,1,0.35)
	text("生命  %d / %d" % [maxf(0,p.hp),p.max_hp],Vector2(PORTRAIT_X,592),Vector2(287,26),17,INK).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	text("攻击 %.1f  ·  减伤 %.0f%%" % [host.session.weapon_damage(p),(1.0-host.session.incoming_damage(p,1))*100],Vector2(PORTRAIT_X,622),Vector2(287,26),15,MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	quick_slots(p)
	cabinet(p)

func quick_slots(p: Dictionary) -> void:
	text("快捷道具 · 1/2/3 直接使用 · 只能拖入",Vector2(PORTRAIT_X,660),Vector2(287,27),17,GOLD)
	host._slot_origin=Vector2(PORTRAIT_X,688)
	host._slot_loot=false
	for i in 3:
		var at := Vector2(PORTRAIT_X+i*99,688)
		var item: Dictionary=host.session.item_slot(p,i)
		var body := ItemTile.tile(host,at,Vector2(84,84),item)
		if host.selected_item_slot==i: body.selected=true
		var area := Rect2(at,Vector2(84,84))
		host.slot_zone_rects.append(area)
		host.equip_zones["slot%d" % i]=area
		text("[%d]" % (i+1),at+Vector2(0,87),Vector2(84,20),12,MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if not item.is_empty():
			zones.append({"rect":area,"item":item,"key":"slot%d" % i})
			host.button(host.overlay,"收回",at+Vector2(43,65),Vector2(40,18),func(): host.camp_take_slot(i),false,10)

## The spare-bag cabinet. In a raid it is never drawn, which is why a pack swapped off
## the back seems to vanish; here every spare is a tile the player can drag into the
## vault and sell.
func cabinet(p: Dictionary) -> void:
	text("背包柜",Vector2(PORTRAIT_X,790),Vector2(120,24),15,GOLD)
	var cabinet: Array=p.get("bags",[])
	for i in mini(cabinet.size(),CABINET_SLOTS):
		var at := Vector2(PORTRAIT_X+78+i*(CABINET_CELL+8),786)
		var key := str(cabinet[i].get("key",Catalog.DEFAULT_BAG_KEY))
		var item: Dictionary=host.session.bag_as_item(key)
		ItemTile.tile(host,at,Vector2(CABINET_CELL,CABINET_CELL),item)
		host.cabinet_zones[i]=Rect2(at,Vector2(CABINET_CELL,CABINET_CELL))
		zones.append({"rect":Rect2(at,Vector2(CABINET_CELL,CABINET_CELL)),"item":item,"key":"cab%d" % i})
	if cabinet.is_empty():
		text("（空）",Vector2(PORTRAIT_X+78,792),Vector2(120,22),13,MUTED)

# --- middle column: the carried backpack and the pocket ------------------------
func carried(p: Dictionary) -> void:
	var grid: Vector2i=Catalog.bag_grid(p.backpack)
	text(Catalog.bag_name(p.backpack),Vector2(CARRIED_X,150),Vector2(251,30),22,BAG_TONE)
	text("%s · %d 格空闲 · 阵亡掉落" % [Catalog.bag_quality(p.backpack),Catalog.container_free(p.backpack)],Vector2(CARRIED_X,184),Vector2(251,24),13,MUTED)
	grid_cells("backpack",p.backpack,Vector2(CARRIED_X,214),CELL,GAP,grid,BAG_TONE)
	text("次元口袋",Vector2(CARRIED_X,486),Vector2(251,30),22,POCKET_TONE)
	text("阵亡保留 · 固定 4×4",Vector2(CARRIED_X,518),Vector2(251,24),13,MUTED)
	grid_cells("pocket",p.pocket,Vector2(CARRIED_X,548),CELL,GAP,Catalog.container_grid(p.pocket),POCKET_TONE)
	var at := Vector2(CARRIED_X,690)
	ItemTile.tile(host,at,Vector2(58,58),{"kind":"backpack","quality":p.backpack.key})
	host.equip_zones["bag"]=Rect2(at,Vector2(58,58))
	text("当前背包",at+Vector2(-8,65),Vector2(88,24),13,GOLD)
	host.button(host.overlay,"脱下",at+Vector2(66,36),Vector2(52,22),func(): host.camp_unwear_bag(),false,12).tooltip_text="把背包脱下来变成仓库里的一件物品，可以出售"

# --- right column: the vault ---------------------------------------------------
func vault(p: Dictionary) -> void:
	text("守夜人仓库",Vector2(VAULT_X,150),Vector2(300,30),24,VAULT_TONE)
	text("15×15  ·  实时总价值 %d ◈  ·  %d 件" % [host.profile.warehouse_value(),host.profile.warehouse_count()],Vector2(VAULT_X,184),Vector2(478,24),13,MUTED)
	if focus_vault:
		text("← 这里",Vector2(VAULT_X,214),Vector2(120,22),14,GOLD)
	grid_cells("warehouse",host.profile.data.get("warehouse",{}),Vector2(VAULT_X,214),VAULT_CELL,VAULT_GAP,Catalog.WAREHOUSE_GRID,VAULT_TONE)
	var spill: int = host.profile.warehouse_count()-host.profile.vault_items().size()
	if spill>0:
		text("溢出暂存 %d 件（网格已满，仍可取出/出售）" % spill,Vector2(VAULT_X,712),Vector2(478,24),13,Color("d3a06a"))
	host.button(host.overlay,"全部携行入库",Vector2(VAULT_X,730),Vector2(150,38),func(): host.camp_bank_all(),true,15)
	host.button(host.overlay,"整理",Vector2(VAULT_X+160,730),Vector2(90,38),func(): host.camp_tidy(),false,15)
	host.button(host.overlay,"交易行",Vector2(VAULT_X+260,730),Vector2(100,38),func(): host.close_bag(); host.show_economy(true),false,15)
	host.button(host.overlay,"关闭",Vector2(VAULT_X+370,730),Vector2(108,38),host.close_bag,false,15)

# --- shared grid drawing -------------------------------------------------------
## One grid of cells plus the items sitting on them, registered with the drag
## controller as `slot`. Empty cells are drawn first so an item always lands on top of
## its own cells, and the vault's drag preview is answered by `main.gd` from the same
## registration.
func grid_cells(slot: String, container: Dictionary, at: Vector2, cell: float, gap: float, grid: Vector2i, tone: Color) -> void:
	var step := cell+gap
	var items: Array=Catalog.container_items(container) if container is Dictionary else []
	var grid_items: Array = host.profile.warehouse_items() if slot=="warehouse" else items
	host.grids[slot]={"origin":at,"cell":cell,"gap":gap,"grid":grid}
	for y in grid.y:
		for x in grid.x:
			ItemTile.tile(host,at+Vector2(x,y)*step,Vector2(cell,cell),{},Color(tone,0.3),slot=="pocket")
	for i in grid_items.size():
		var item: Dictionary=grid_items[i]
		# The spill list has no cell of its own: those entries are drawn nowhere and
		# are reached through the counters above.
		if int(item.get("x",-1))<0 or int(item.get("y",-1))<0: continue
		if host.drag.active and str(host.drag.slot)==slot and host.drag.source==i: continue
		var dims := Catalog.item_size(item)
		var pos := at+Vector2(int(item.x),int(item.y))*step
		var body := ItemTile.tile(host,pos,Vector2(dims)*step-Vector2.ONE*gap,item)
		if host.selected_slot==slot and host.selected==i: body.selected=true
