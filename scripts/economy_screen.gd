extends Control
## 晨钟交易行：the vault *and* the pack the Watcher is wearing, picked from directly.
##
## The exchange used to be a card list of every banked item, which stopped matching the
## storage it sells once the vault became a real 15x15 grid. It is a grid here too: the
## player clicks the pieces they want to sell, in the same cells they sit in inside the
## camp bag panel.
##
## The left half is now two stacked shelves, each with its own scrollbar: the vault on
## top, the carried 血月背包 under it. Both are bigger than the window can show (15x15 is
## 540 px of grid; a red pack is 8x8), and carried loot used to be reachable only by
## stowing it into the vault first. The scrolling is `ui_scroller.gd` — the one recipe the
## raid panel already uses, kept in a single place so the two panels cannot drift.
##
## Selection is one index space over both shelves: `vault_entries()` and `bag_entries()`
## build it, and `split()` says which shelf an index came from. Selling stays on the two
## paths the rest of the camp uses — `Profile.sell_items()` for vault stock, and
## `CampStorage.sell_backpack()` for what the Watcher carries, which is storage code and
## therefore not this window's business.
##
## Buying a vault *view* is gone with it — TAB's远征行囊 has the vault on its right
## half, with drag, withdrawal and deposit — so this window is the market and nothing
## else.
##
## The screen draws its cells through `item_tile.gd`, the same renderer the bag panels
## use, so a red weapon looks identical in the bag, in the vault and here.
const ItemTile := preload("res://scripts/item_tile.gd")
const CampStorage := preload("res://scripts/camp_storage.gd")
const Scroller := preload("res://scripts/ui_scroller.gd")

## A backpack is carried storage, and `Catalog` treats it as equipment worth carrying home
## (`item_value()` prices its tier), so the exchange files it under 武器与装备 rather than
## giving a container a shelf of its own next to the pieces that go inside it.
const CATEGORIES := ["全部藏品","武器与装备","补给物资","遗物与珍宝"]
const CELL := 34.0
const GAP := 2.0
## The two shelves. The grid content stays at the old 15x15 size; only the window onto it
## shrinks, so both blocks fit stacked inside the 725 px window with the spill shelf and
## the status line under them.
const VAULT_AT := Vector2(200,82)
const VAULT_VIEWPORT := Vector2(556,286)
const BAG_AT := Vector2(200,402)
const BAG_VIEWPORT := Vector2(304,216)

var host: Node
var query := ""
var category := 0
var selected: Array = []
var focused := -1
var confirming := false
var notice := ""
## `item_tile.gd` adds every cell to `host.overlay`, so this is "the node the tiles are
## currently landing in": pointed at the shelf being drawn, and never at more than one.
var overlay: Control
var details: Control
var status: Label
var balance: Label
var filters: Array = []
var spill_row: HBoxContainer
## Each shelf is a persistent `MarketGrid` living inside a persistent `ScrollContainer`.
## Both are built once in `build()` and only their *tiles* are redrawn, so a refresh never
## moves a node between parents — the mistake that made Godot reject the tree with a cyclic
## dependency (a node had been re-parented inside a scroller that was itself a child of it).
var vault_view: MarketGrid
var bag_view: MarketGrid
var vault_caption: Label
var bag_caption: Label

func _ready() -> void:
	position=Vector2(80,115)
	size=Vector2(1280,725)
	build()

func text(value: String, at: Vector2, font_size: int = 18, color: Color = Color("e7dfd5"), dimensions: Vector2 = Vector2(700,40), parent: Node = null) -> Label:
	return host.label(self if parent==null else parent,value,at,font_size,color,dimensions)

## The two helpers `item_tile.gd` asks its host for. They exist so the market can draw
## the shared cells into its own window instead of the main overlay.
func item_icon(parent: Node, kind: String, at: Vector2, dimensions: Vector2) -> TextureRect:
	return host.item_icon(parent,kind,at,dimensions)

func label(parent: Node, value: String, at: Vector2, font_size: int = 18, color: Color = Color.WHITE, dimensions: Vector2 = Vector2(700,40)) -> Label:
	return host.label(parent,value,at,font_size,color,dimensions)

func action(value: String, at: Vector2, dimensions: Vector2, callback: Callable, primary: bool = false, parent: Node = null) -> Button:
	return host.button(self if parent==null else parent,value,at,dimensions,callback,primary,17)

func build() -> void:
	balance=text("",Vector2(955,5),23,host.GOLD,Vector2(310,36))
	text("NIGHTWATCH  /  EXCHANGE",Vector2(0,10),12,host.MUTED)
	text("商会按标价即时收购 · 无手续费 · 点击格子选中，二次确认后出售",Vector2(0,40),14,host.GOLD)
	host.rect(self,Vector2(0,72),Vector2(1280,1),host.GOLD)
	for i in CATEGORIES.size():
		var b := action(CATEGORIES[i],Vector2(0,92+i*52),Vector2(185,44),func(): category=i; confirming=false; refresh())
		filters.append(b)
	text("筛选只影响可选中：\n不合分类的藏品会变暗。",Vector2(10,92+CATEGORIES.size()*52+16),14,host.MUTED,Vector2(175,80))
	action("全选筛选结果",Vector2(0,470),Vector2(185,44),func():
		selected=selectable_indices()
		confirming=false
		refresh())
	action("清空选择",Vector2(0,520),Vector2(185,44),func(): selected.clear(); confirming=false; refresh())
	action("← 返回",Vector2(0,660),Vector2(185,44),func(): host.close_modal())
	var search := LineEdit.new()
	search.placeholder_text="搜索物品名称…"
	search.position=Vector2(200,14)
	search.size=Vector2(430,42)
	search.add_theme_font_override("font",host.root.theme.default_font)
	search.add_theme_font_size_override("font_size",17)
	add_child(search)
	search.text_changed.connect(func(value): query=value; refresh())
	# Two framed shelves. The frames are static, so they are built once and only the
	# cells inside them are redrawn.
	host.rect(self,VAULT_AT-Vector2(6,6),VAULT_VIEWPORT+Vector2(12,12),host.PANEL,Color("665469"))
	host.rect(self,BAG_AT-Vector2(6,6),BAG_VIEWPORT+Vector2(12,12),host.PANEL,Color("665469"))
	vault_caption=text("",Vector2(200,54),19,Color("c2a06a"),Vector2(730,26))
	bag_caption=text("",Vector2(200,374),19,Color("bdab81"),Vector2(730,26))
	# One click reporter per shelf, each knowing which container it shows. Both the
	# scroller and the grid inside it are built here, once, under `self`: the grid is a
	# child of its scroller and nothing moves them after that, so a redraw that clears the
	# grid's tiles can never rebuild the parent chain and create a cycle.
	vault_view=make_view(CampStorage.VAULT,VAULT_AT,Vector2(Catalog.WAREHOUSE_GRID)*(CELL+GAP)-Vector2.ONE*GAP,VAULT_VIEWPORT)
	vault_view.cell_clicked.connect(func(cell): click_cell(CampStorage.VAULT,cell))
	bag_view=make_view("backpack",BAG_AT,Vector2(Catalog.bag_grid(host.camp_player().get("backpack",{})))*(CELL+GAP)-Vector2.ONE*GAP,BAG_VIEWPORT)
	bag_view.cell_clicked.connect(func(cell): click_cell("backpack",cell))
	details=Control.new()
	details.position=Vector2(950,14)
	details.size=Vector2(310,640)
	add_child(details)
	status=text("",Vector2(200,674),16,host.GOLD,Vector2(730,36))
	refresh()

## A shelf that reports the cell a click landed on. `source` is the container it shows,
## `content_size` the whole grid and `viewport_size` the window onto it. The grid is the
## scroller's only child, sized to the full grid so the container has something to scroll;
## the extra bar width is added to the viewport so the scrollbar sits beside the tiles, not
## on top of them.
func make_view(source: String, at: Vector2, content_size: Vector2, viewport_size: Vector2) -> MarketGrid:
	var scroll := Scroller.make(self,at,viewport_size+Vector2(Scroller.BAR_WIDTH,0))
	var grid := MarketGrid.new()
	grid.source=source
	grid.size=content_size
	grid.custom_minimum_size=content_size
	grid.cell_size=CELL
	grid.gap=GAP
	grid.mouse_filter=Control.MOUSE_FILTER_STOP
	scroll.add_child(grid)
	return grid

# --- sources ------------------------------------------------------------------
## The vault's own entries: the grid plus the spill list behind it.
func vault_entries() -> Array:
	return host.profile.warehouse_items()

## The carried 血月背包 as a list, empty when no Watcher is standing in the camp. The
## player dictionary is the camp's source of truth (see `camp_storage.gd`), so this reads
## the same live container the TAB panel draws.
func bag_entries() -> Array:
	var p: Dictionary=host.camp_player()
	if p.is_empty(): return []
	return Catalog.container_items(p.get("backpack",{}))

## One index space for both shelves: the vault first (its own numbering, so every call
## `Profile.sell_items()` already answers stays untouched), then the backpack.
func entry_count() -> int:
	return vault_entries().size()+bag_entries().size()

func entry_at(index: int) -> Dictionary:
	var vault: int=vault_entries().size()
	if index<vault: return {"slot":CampStorage.VAULT,"index":index,"item":vault_entries()[index]}
	var list: Array=bag_entries()
	var at := index-vault
	return {"slot":"backpack","index":at,"item":list[at]} if at>=0 and at<list.size() else {}

func split(index: int) -> Dictionary:
	return entry_at(index)

# --- filtering ----------------------------------------------------------------
func matches(item: Dictionary) -> bool:
	if not query.is_empty() and not Catalog.item_name(item).to_lower().contains(query.to_lower()): return false
	var kind := str(item.kind)
	match category:
		1: return kind in ["weapon","gear","charm","backpack"]
		2: return kind in ["medicine","ammo","crystal"]
		3: return kind not in ["weapon","gear","charm","medicine","ammo","crystal","backpack"]
	return true

## Which entry the exchange will actually take: matched by the filters, worth
## something (a camp-issued supply is not), and never the ones already picked.
func sellable(index: int) -> bool:
	var entry := entry_at(index)
	if entry.is_empty(): return false
	var item: Dictionary=entry.item
	return matches(item) and Catalog.market_value(item)>0

func selectable_indices() -> Array:
	var result: Array = []
	for index in entry_count():
		if sellable(index): result.append(index)
	return result

## Which entry of a shelf covers one of its cells. The spill list is not on the grid, so
## the shelf's own drawn list is what a click can hit.
func index_at_cell(slot: String, cell: Vector2i) -> int:
	var list: Array=vault_entries() if slot==CampStorage.VAULT else bag_entries()
	for i in list.size():
		var item: Dictionary=list[i]
		if slot==CampStorage.VAULT and (int(item.get("x",-1))<0 or int(item.get("y",-1))<0): continue
		var dims := Catalog.item_size(item)
		if Rect2i(Vector2i(int(item.get("x",0)),int(item.get("y",0))),dims).has_point(cell):
			return i
	return -1

func click_cell(slot: String, cell: Vector2i) -> void:
	var local := index_at_cell(slot,cell)
	if local<0: return
	var index := local if slot==CampStorage.VAULT else vault_entries().size()+local
	focused=index
	if not sellable(index):
		notice="这件藏品商会不收：营地补给或不符合当前筛选。"
		confirming=false
		refresh()
		return
	if index in selected: selected.erase(index)
	else: selected.append(index)
	notice=""
	confirming=false
	refresh()

# --- drawing ------------------------------------------------------------------
func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func refresh() -> void:
	if spill_row: clear_children(spill_row)
	balance.text="城邦银币  ◈ %d" % host.profile.data.coins
	for i in filters.size(): filters[i].modulate=Color.WHITE if i==category else Color("a6a2ad")
	var items: Array=vault_entries()
	var grid_count: int=host.profile.vault_items().size()
	var bag: Array=bag_entries()
	var bag_grid: Vector2i=Catalog.bag_grid(host.camp_player().get("backpack",{}))
	# The shelf captions tell the player what the window is showing before they scroll.
	vault_caption.text="守夜人仓库 · %d 件 · 实时总价值 %d ◈" % [host.profile.warehouse_count(),host.profile.warehouse_value()]
	bag_caption.text="血月背包 · %s · %d 件（阵亡可保住仓库，卖掉即离开背包）" % [Catalog.bag_name(host.camp_player().get("backpack",{})),bag.size()] if not host.camp_player().is_empty() else "血月背包 · 未编队"
	draw_shelf(vault_view,items,Catalog.WAREHOUSE_GRID,0,grid_count)
	draw_shelf(bag_view,bag,bag_grid,grid_count,bag.size())
	spill_shelf(grid_count,items)
	var total := 0
	for index in selected:
		var entry := entry_at(index)
		if not entry.is_empty(): total+=Catalog.market_value(entry.item)
	status.text=notice if not notice.is_empty() else "仓库 %d 件 · 背包 %d 件 · 实时总价值 %d ◈   /   已选 %d 件 · %d ◈" % [host.profile.warehouse_count(),bag.size(),host.profile.warehouse_value()+Catalog.market_total(bag),selected.size(),total]
	show_details(total)

## One shelf inside its own scrolling window: `base` is the first unified index of this
## shelf, so a tile knows which entry it stands for. Only the tiles are rebuilt here — the
## shelf and its scrollbar already exist from `build()`, which is what keeps the tree
## acyclic across refreshes.
func draw_shelf(view: MarketGrid, list: Array, grid: Vector2i, base: int, drawn: int) -> void:
	overlay=view
	clear_children(view)
	var step := CELL+GAP
	var content := Vector2(grid)*step-Vector2.ONE*GAP
	view.custom_minimum_size=content
	for y in grid.y:
		for x in grid.x:
			ItemTile.tile(self,Vector2(x,y)*step,Vector2(CELL,CELL),{},Color(host.GOLD,0.28),false)
	for i in drawn:
		var item: Dictionary=list[i]
		var cell := Vector2i(int(item.get("x",-1)),int(item.get("y",-1)))
		if cell.x<0 or cell.y<0: continue
		var dims := Catalog.item_size(item)
		var node := ItemTile.tile(self,Vector2(cell)*step,Vector2(dims)*step-Vector2.ONE*GAP,item)
		# The filters dim what they exclude instead of hiding it: an item has to stay
		# where the player last saw it.
		node.modulate.a=1.0 if sellable(base+i) or base+i in selected else 0.32
		node.selected=base+i in selected

## The spill list is not on the grid — it exists precisely because the grid was full —
## so those entries get a shelf of their own. They are ordinary vault stock and can be
## sold like anything else.
func spill_shelf(grid_count: int, items: Array) -> void:
	var spill := items.size()-grid_count
	if spill<=0:
		if spill_row: spill_row.visible=false
		return
	if spill_row==null or not is_instance_valid(spill_row):
		var scroll := ScrollContainer.new()
		scroll.position=Vector2(200,624)
		scroll.size=Vector2(730,44)
		scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)
		spill_row=HBoxContainer.new()
		spill_row.add_theme_constant_override("separation",6)
		scroll.add_child(spill_row)
	spill_row.visible=true
	clear_children(spill_row)
	var title := Label.new()
	title.text="溢出暂存 %d 件" % spill
	title.add_theme_font_size_override("font_size",14)
	title.add_theme_color_override("font_color",Color("d3a06a"))
	title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	spill_row.add_child(title)
	for index in range(grid_count,items.size()):
		var item: Dictionary=items[index]
		var chip := Button.new()
		chip.text=("%s ×%d" % [Catalog.item_short_name(item),int(item.get("count",1))]) if int(item.get("count",1))>1 else Catalog.item_short_name(item)
		chip.add_theme_font_size_override("font_size",13)
		chip.custom_minimum_size=Vector2(0,30)
		chip.disabled=not sellable(index)
		if index in selected: chip.text="✓ "+chip.text
		chip.pressed.connect(func(): click_spill(index))
		spill_row.add_child(chip)

func click_spill(index: int) -> void:
	focused=index
	if not sellable(index):
		notice="这件藏品商会不收。"
	else:
		if index in selected: selected.erase(index)
		else: selected.append(index)
		notice=""
	confirming=false
	refresh()

func show_details(total: int) -> void:
	clear_children(details)
	host.rect(details,Vector2.ZERO,Vector2(310,640),host.PANEL,Color("665469"))
	text("物品档案",Vector2(22,14),22,host.GOLD,Vector2(260,34),details)
	var entry := entry_at(focused)
	if focused>=0 and not entry.is_empty():
		var item: Dictionary=entry.item
		host.item_icon(details,Catalog.item_icon(item),Vector2(104,57),Vector2(102,102))
		var title := text(Catalog.item_name(item),Vector2(22,173),22,Catalog.item_color(item),Vector2(267,65),details)
		title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		text("营地补给 · 不可出售" if item.get("provision",false) else "收购价  ◈ %d" % Catalog.market_value(item),Vector2(22,249),22,host.GOLD,Vector2(267,38),details)
		text("血月背包携带" if str(entry.slot)=="backpack" else "守夜人仓库库存",Vector2(22,279),15,host.MUTED,Vector2(267,26),details)
		var description_scroll := ScrollContainer.new()
		description_scroll.position=Vector2(22,309)
		description_scroll.size=Vector2(267,100)
		description_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		details.add_child(description_scroll)
		var description := text(Catalog.item_desc(item),Vector2.ZERO,15,host.MUTED,Vector2(249,112),description_scroll)
		description.custom_minimum_size.x=249
		description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	else:
		text("点击仓库或背包格子\n挑选要出售的藏品",Vector2(25,118),20,host.MUTED,Vector2(260,80),details)
	text("已选 %d 件 · 合计 %d ◈" % [selected.size(),total],Vector2(22,421),18,host.GOLD,Vector2(268,35),details)
	var sale := action("确认出售 · 不可撤回" if confirming else "出售所选物品",Vector2(20,468),Vector2(270,48),sell,true,details)
	sale.disabled=selected.is_empty()
	var clear := action("清空选择",Vector2(20,524),Vector2(270,40),func(): selected.clear(); confirming=false; notice=""; refresh(),false,details)
	clear.disabled=selected.is_empty()
	text("卖出即离开仓库或背包，装备不会自动出售。",Vector2(22,576),13,host.MUTED,Vector2(268,46),details)

# --- selling ------------------------------------------------------------------
func sell() -> void:
	if selected.is_empty(): return
	if not confirming:
		confirming=true
		notice="请核对所选藏品，再次点击确认出售。稀有物品也会出售。"
		refresh()
		return
	var vault_indices: Array = []
	var bag_indices: Array = []
	for index in selected:
		var entry := entry_at(index)
		if entry.is_empty(): continue
		if str(entry.slot)==CampStorage.VAULT: vault_indices.append(entry.index)
		else: bag_indices.append(entry.index)
	var count := vault_indices.size()+bag_indices.size()
	# The vault is sold by index, exactly as before; the pack goes through the storage
	# module, because a panel must never edit a container of its own.
	var earned: int=host.profile.sell_items(vault_indices)
	if not bag_indices.is_empty():
		var sold: Dictionary=CampStorage.sell_backpack(host.profile,host.session,host.camp_player(),bag_indices)
		earned+=int(sold.get("coins",0))
		count=int(vault_indices.size())+int(sold.get("count",0))
	host.economy_changed()
	selected.clear(); focused=-1; confirming=false
	notice="已出售 %d 件藏品，获得 %d 银币。" % [count,earned]
	refresh()

## The grid control itself: cells are drawn by the screen, this only reports which
## cell a click landed on. It owns the mouse so a click never falls through to the
## modal shade behind the window.
class MarketGrid extends Control:
	signal cell_clicked(cell: Vector2i)
	var cell_size := 34.0
	var gap := 2.0
	## Which container this shelf shows, so a click can be answered without the screen
	## guessing which node the event came from.
	var source := ""

	func cell_at(point: Vector2) -> Vector2i:
		var step := cell_size+gap
		return Vector2i(int(point.x/step),int(point.y/step))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			cell_clicked.emit(cell_at(event.position))
			accept_event()
