class_name Catalog
extends RefCounted

const HEROES = [
	{"name":"绯月", "title":"赤刃守夜姬", "desc":"黑铁短剑：攻击距离短、攻速快、伤害低。红莲月华贯穿近处敌群。", "color":Color("da6474"), "hair":Color("e8dce0"), "hp":110.0, "speed":220.0, "damage":23.0, "rate":0.23, "clip":16, "skill":"红莲月华"},
	{"name":"雪璃", "title":"晨钟祈愿者", "desc":"祭祀短杖：远程法术攻击，伤害低，释放前需要短暂吟唱。拂晓之祈治疗附近的所有队友。", "color":Color("70c4bc"), "hair":Color("c9e0ef"), "hp":95.0, "speed":230.0, "damage":32.0, "rate":0.42, "clip":10, "skill":"拂晓之祈"},
	{"name":"鸦羽", "title":"黑羽处刑人", "desc":"破碎大剑：攻速慢、伤害略高、范围大。夜鸦断罪清除周围敌人并短暂护身。", "color":Color("b397de"), "hair":Color("56516e"), "hp":130.0, "speed":250.0, "damage":42.0, "rate":0.36, "clip":0, "skill":"夜鸦断罪"}
]
const ITEMS = {
	"crystal":{"name":"血晶", "size":Vector2i(1,1), "value":18, "color":Color("e45c74"), "desc":"血香 +8；按 B 可燃烧一枚，驱散血香并恢复理智。"},
	"scrap":{"name":"古城零件", "size":Vector2i(2,1), "value":32, "color":Color("b0b6c5"), "desc":"晨钟城工坊急需的机械零件。"},
	"relic":{"name":"月蚀遗物", "size":Vector2i(2,2), "value":125, "color":Color("d2ac66"), "desc":"占据四格的珍贵遗物；拾取时优先沉入次元口袋，永不掉落。"},
	"medicine":{"name":"急救针", "size":Vector2i(1,2), "value":25, "color":Color("78cbb5"), "desc":"按 F 消耗一支，恢复 45 生命；倒地时可用于自救。"},
	"charm":{"name":"银鸦护符", "size":Vector2i(1,2), "value":70, "color":Color("b79ade"), "desc":"拾取后，本局伤害提高 12%，最多叠加三枚。"},
	"ammo":{"name":"弹药匣", "size":Vector2i(2,1), "value":20, "color":Color("c4ad82"), "desc":"按 F 优先治疗；弹药不足时自动消耗弹药匣补充 48 发。"},
	"backpack":{"name":"背包", "size":Vector2i(1,1), "value":40, "color":Color("cfc6bb"), "desc":"可背在身上的独立储物空间；阵亡时连同包内物资一起掉落。"},
	"weapon":{"name":"武器", "size":Vector2i(2,2), "value":85, "color":Color("c9a06a"), "desc":"战场上捡到的武器。只有装备到武器槽后才会握在手里；拿着它攻击时获得品质加成。阵亡会掉落。"},
	"gear":{"name":"装备", "size":Vector2i(1,2), "value":55, "color":Color("8fb6d8"), "desc":"护甲 / 瞄具 / 轻靴。装备到对应槽位后本局提升生命、火力或移速。阵亡会掉落。"}
}
const TALENTS = ["生命强化", "火力校准", "轻装步伐"]
# The four weapons that exist in the world. They are loot and nothing else: a
# Watcher can only ever hold one of them by finding it and putting it on, so the
# index below is also the index a looted weapon stores in its "weapon" field.
const WEAPONS = [
	{"name":"守夜步枪", "rate":0.23, "windup":0.0, "damage":23.0, "reach":680.0, "knock":9.0},
	{"name":"绯红单手剑", "rate":0.38, "windup":0.10, "damage":38.0, "reach":112.0, "knock":20.0},
	{"name":"破晓双手剑", "rate":0.88, "windup":0.34, "damage":88.0, "reach":158.0, "knock":58.0},
	{"name":"星辉法杖", "rate":0.62, "windup":0.22, "damage":46.0, "reach":700.0, "knock":16.0}
]
# The temporary weapon every hero sets out with, one per hero, appended after the
# four field weapons so the whole game keeps addressing a weapon by a single int.
# They exist so a Watcher can fight on the way to their first pickup and nothing
# more: each one is strictly weaker than the field weapon it imitates, it can
# never be found, never drops and never takes a quality bonus. "family" names the
# field weapon whose attack art, slash VFX and impact audio it borrows.
#
# STARTER_BASE is the first issue index. GDScript will not fold WEAPONS.size()
# into a constant, so this literal has to track the table above; tests/systems.gd
# asserts the two stay equal.
const STARTER_BASE := 4
const STARTER_WEAPONS = [
	{"name":"黑铁短剑", "rate":0.30, "windup":0.05, "damage":13.0, "reach":84.0, "knock":10.0, "family":1},
	{"name":"祭祀短杖", "rate":0.58, "windup":0.20, "damage":15.0, "reach":520.0, "knock":8.0, "family":3},
	{"name":"破碎大剑", "rate":0.98, "windup":0.34, "damage":30.0, "reach":150.0, "knock":40.0, "family":2}
]
const GEAR = [
	{"name":"守夜护甲", "desc":"最大生命 +20", "hp":20.0,"damage":0.0,"speed":0.0},
	{"name":"血月瞄具", "desc":"武器伤害 +15%", "hp":0.0,"damage":0.15,"speed":0.0},
	{"name":"渡鸦轻靴", "desc":"移动速度 +20", "hp":0.0,"damage":0.0,"speed":20.0}
]
# In-run loot uses the same six qualities as the backpacks. A weapon only pays
# out while the player is actually holding that weapon; the three gear slots
# (armour / sight / boots) always pay out.
const QUALITY_KEYS := ["white","green","blue","purple","gold","red"]
const WEAPON_DAMAGE_BONUS := [0.0,0.10,0.22,0.36,0.52,0.72]
const WEAPON_RATE_BONUS := [0.0,0.05,0.10,0.15,0.21,0.28]
const GEAR_HP := [12.0,20.0,30.0,42.0,58.0,78.0]
const GEAR_DAMAGE := [0.05,0.08,0.12,0.17,0.23,0.30]
const GEAR_SPEED := [8.0,13.0,19.0,26.0,35.0,46.0]
const WEAPON_ICONS := ["rifle","sword","heavy","staff"]
const GEAR_ICONS := ["armor","sight","boots"]
# Keys that must survive a JSON save round trip. Items other than the six loot
# kinds stay inert; without this list a reload would drop stack counts, backpack
# quality and every weapon/gear field.
const SAVED_ITEM_KEYS := ["count","quality","provision","weapon","gear","tier"]

# The dimensional pocket is a permanent 4x4 container: it is written into the
# save file and its contents never drop, no matter how the expedition ends.
const POCKET_GRID := Vector2i(4,4)
const POCKET_NAME := "次元口袋"
# Backpack quality decides the size of the extra, droppable storage grid.
const BAG_TIERS = [
	{"key":"white", "name":"破损背包", "quality":"白色", "grid":Vector2i(3,3), "color":Color("cfc6bb")},
	{"key":"green", "name":"巡林背包", "quality":"绿色", "grid":Vector2i(4,4), "color":Color("8fc39a")},
	{"key":"blue", "name":"守夜背包", "quality":"蓝色", "grid":Vector2i(5,5), "color":Color("8fb6d8")},
	{"key":"purple", "name":"秘仪背包", "quality":"紫色", "grid":Vector2i(6,6), "color":Color("b48fd4")},
	{"key":"gold", "name":"圣血背包", "quality":"金色", "grid":Vector2i(7,7), "color":Color("dcbd7e")},
	{"key":"red", "name":"血月背包", "quality":"红色", "grid":Vector2i(8,8), "color":Color("dd6c7c")}
]
const DEFAULT_BAG_KEY := "white"

static func tier_index(key: String) -> int:
	for i in BAG_TIERS.size():
		if BAG_TIERS[i].key==key:
			return i
	return 0

static func tier(key: String) -> Dictionary:
	return BAG_TIERS[tier_index(key)]

static func bag_key(bag: Dictionary) -> String:
	var key := str(bag.get("key",DEFAULT_BAG_KEY))
	return key if has_tier(key) else DEFAULT_BAG_KEY

static func has_tier(key: String) -> bool:
	for entry in BAG_TIERS:
		if entry.key==key:
			return true
	return false

static func bag_grid(bag: Dictionary) -> Vector2i:
	return tier(bag_key(bag)).grid

static func bag_name(bag: Dictionary) -> String:
	return tier(bag_key(bag)).name

static func bag_quality(bag: Dictionary) -> String:
	return tier(bag_key(bag)).quality

static func bag_color(bag: Dictionary) -> Color:
	return tier(bag_key(bag)).color

# --- the weapon in hand ------------------------------------------------------
# One int addresses every weapon a player can hold: 0..3 are the field weapons a
# raid can hand out, STARTER_BASE.. are the three temporary issue weapons. Every
# combat, animation and audio consumer reads stats through weapon() and reads the
# four-way art/effect family through weapon_family(), so a hero issue weapon
# behaves like the field weapon it imitates without ever being one.
static func starter_index(hero: int) -> int:
	return STARTER_BASE+clampi(hero,0,STARTER_WEAPONS.size()-1)

static func is_starter(index: int) -> bool:
	return index>=STARTER_BASE and index<STARTER_BASE+STARTER_WEAPONS.size()

static func weapon(index: int) -> Dictionary:
	if is_starter(index):
		return STARTER_WEAPONS[index-STARTER_BASE]
	return WEAPONS[clampi(index,0,WEAPONS.size()-1)]

static func weapon_name(index: int) -> String:
	return str(weapon(index).name)

static func weapon_family(index: int) -> int:
	if is_starter(index):
		return clampi(int(weapon(index).family),0,WEAPONS.size()-1)
	return clampi(index,0,WEAPONS.size()-1)

# --- weapons and gear found in the field ------------------------------------
# Quality index 0..5 follows BAG_TIERS. A looted weapon remembers which of the
# four weapons it upgrades, a looted gear piece which of the three slots it fills.
static func tier_of(value: int) -> int:
	return clampi(value,0,QUALITY_KEYS.size()-1)

static func quality_name(value: int) -> String:
	return BAG_TIERS[tier_of(value)].quality

static func quality_color(value: int) -> Color:
	return BAG_TIERS[tier_of(value)].color

static func is_equipment(kind: String) -> bool:
	return kind=="weapon" or kind=="gear"

# A piece of loot is always one of the four field weapons: the hero issue weapons
# have no item form and can neither be found nor dropped.
static func make_equipment(kind: String, index: int, tier: int) -> Dictionary:
	if kind=="weapon":
		return {"kind":"weapon","weapon":clampi(index,0,WEAPONS.size()-1),"tier":tier_of(tier),"x":0,"y":0,"rot":false}
	return {"kind":"gear","gear":clampi(index,0,GEAR.size()-1),"tier":tier_of(tier),"x":0,"y":0,"rot":false}

static func weapon_bonus(item: Dictionary) -> float:
	return WEAPON_DAMAGE_BONUS[tier_of(int(item.get("tier",0)))]

static func weapon_rate_bonus(item: Dictionary) -> float:
	return WEAPON_RATE_BONUS[tier_of(int(item.get("tier",0)))]

static func gear_slot(item: Dictionary) -> int:
	return clampi(int(item.get("gear",0)),0,GEAR.size()-1)

static func gear_bonus(item: Dictionary) -> float:
	var table: Array = [GEAR_HP,GEAR_DAMAGE,GEAR_SPEED][gear_slot(item)]
	return table[tier_of(int(item.get("tier",0)))]

static func gear_desc(item: Dictionary) -> String:
	var bonus := gear_bonus(item)
	match gear_slot(item):
		0: return "最大生命 +%d" % int(round(bonus))
		1: return "武器伤害 +%d%%" % int(round(bonus*100.0))
		_: return "移动速度 +%d" % int(round(bonus))

static func gear_slot_name(item: Dictionary) -> String:
	return ["护甲","瞄具","轻靴"][gear_slot(item)]

static func item_name(item: Dictionary) -> String:
	var kind := str(item.get("kind",""))
	if kind=="weapon":
		return "%s %s" % [quality_name(int(item.get("tier",0))),WEAPONS[clampi(int(item.get("weapon",0)),0,WEAPONS.size()-1)].name]
	if kind=="gear":
		return "%s %s" % [quality_name(int(item.get("tier",0))),GEAR[gear_slot(item)].name]
	return str(ITEMS.get(kind,{"name":kind}).name)

# The same name without the quality prefix, for cells too narrow to show it. The
# quality is already carried by the slot colour and the border.
static func item_short_name(item: Dictionary) -> String:
	var kind := str(item.get("kind",""))
	if kind=="weapon":
		return WEAPONS[clampi(int(item.get("weapon",0)),0,WEAPONS.size()-1)].name
	if kind=="gear":
		return GEAR[gear_slot(item)].name
	return item_name(item)

static func item_desc(item: Dictionary) -> String:
	var kind := str(item.get("kind",""))
	if kind=="weapon":
		return "装备后换用这把武器；持有时伤害 +%d%%、攻速 +%d%%。" % [int(round(weapon_bonus(item)*100.0)),int(round(weapon_rate_bonus(item)*100.0))]
	if kind=="gear":
		return "装备到%s槽：本局%s。" % [gear_slot_name(item),gear_desc(item)]
	return str(ITEMS.get(kind,{"desc":""}).desc)

# Quality raises the sale value of field equipment, so a red weapon is worth
# carrying home as well as wearing.
static func item_value(item: Dictionary) -> int:
	var kind := str(item.get("kind",""))
	var info: Dictionary=ITEMS.get(kind,{"value":0})
	if is_equipment(kind):
		return int(round(float(info.value)*(1.0+0.45*float(tier_of(int(item.get("tier",0)))))))
	return int(info.value)

static func item_color(item: Dictionary) -> Color:
	var kind := str(item.get("kind",""))
	if is_equipment(kind):
		return quality_color(int(item.get("tier",0)))
	if kind=="backpack":
		return tier(bag_key(item)).color
	return ITEMS[kind].color

static func item_icon(item: Dictionary) -> String:
	var kind := str(item.get("kind",""))
	if kind=="weapon":
		return WEAPON_ICONS[clampi(int(item.get("weapon",0)),0,WEAPON_ICONS.size()-1)]
	if kind=="gear":
		return GEAR_ICONS[gear_slot(item)]
	return kind

# Icons for a bare kind, used by the code that preloads one texture per item
# kind; a concrete weapon or gear item resolves through item_icon() instead.
static func kind_icon(kind: String) -> String:
	if kind=="weapon":
		return WEAPON_ICONS[0]
	if kind=="gear":
		return GEAR_ICONS[0]
	return kind

static func slot_count(key: String) -> int:
	var grid: Vector2i=tier(key).grid
	return grid.x*grid.y

# Raw grid calls with no size fall back to the original 6x4 field backpack so a
# stray call can never silently inherit some tier's size.
const LEGACY_GRID := Vector2i(6,4)

static func pocket_grid(pocket: Dictionary) -> Vector2i:
	return Vector2i(int(pocket.get("gw",POCKET_GRID.x)),int(pocket.get("gh",POCKET_GRID.y)))

static func grid_of(grid: Vector2i) -> Vector2i:
	return LEGACY_GRID if grid==Vector2i.ZERO else grid

static func make_bag(key: String = DEFAULT_BAG_KEY) -> Dictionary:
	return {"key":key if not key.is_empty() else DEFAULT_BAG_KEY,"items":[],"next":1}

static func item_size(item: Dictionary) -> Vector2i:
	var s: Vector2i = ITEMS[item.kind].size
	return Vector2i(s.y,s.x) if item.get("rot",false) else s

static func can_place(bag: Array, item: Dictionary, at: Vector2i, ignore: int = -1, grid: Vector2i = Vector2i.ZERO) -> bool:
	var dims := grid_of(grid)
	var s := item_size(item)
	if at.x < 0 or at.y < 0 or at.x+s.x > dims.x or at.y+s.y > dims.y:
		return false
	var rect := Rect2i(at,s)
	for i in bag.size():
		if i != ignore and rect.intersects(Rect2i(Vector2i(bag[i].x,bag[i].y),item_size(bag[i]))):
			return false
	return true

static func insert(bag: Array, kind: String, grid: Vector2i = Vector2i.ZERO) -> bool:
	var item := {"kind":kind,"x":0,"y":0,"rot":false}
	var dims := grid_of(grid)
	for rotate in [false,true]:
		item.rot = rotate
		for y in dims.y:
			for x in dims.x:
				if can_place(bag,item,Vector2i(x,y),-1,grid):
					item.x=x
					item.y=y
					bag.append(item)
					return true
	return false

# --- container helpers -------------------------------------------------------
# A "container" is a grid dictionary: {"items":[...], "gw":w, "gh":h}.
# The equipped backpack stores its quality in "key"; the pocket uses 4x4.

static func make_container(items: Array = [], grid: Vector2i = POCKET_GRID, key: String = DEFAULT_BAG_KEY) -> Dictionary:
	return {"key":key,"items":items,"gw":grid.x,"gh":grid.y,"next":1}

static func container_items(container: Dictionary) -> Array:
	return container.get("items",[])

static func container_grid(container: Dictionary) -> Vector2i:
	# Player containers carry their size as gw/gh; a loot container on the map
	# carries it as "grid". Reading both keeps the packing rules honest: a small
	# drop stays small and the 5x5 cathedral chest really does have 25 cells.
	var grid = container.get("grid",null)
	if grid is Vector2i:
		return grid
	return Vector2i(int(container.get("gw",POCKET_GRID.x)),int(container.get("gh",POCKET_GRID.y)))

static func container_free(container: Dictionary) -> int:
	var total := container_grid(container).x*container_grid(container).y
	for item in container_items(container):
		var size := item_size(item)
		total-=size.x*size.y
	return total

static func clean_container(container: Dictionary, grid: Vector2i) -> Dictionary:
	var list: Array = container.get("items",[])
	var result: Array = []
	for entry in list:
		if not entry is Dictionary:
			continue
		var kind := str(entry.get("kind",""))
		if not ITEMS.has(kind):
			continue
		var item := {"kind":kind,"x":int(entry.get("x",0)),"y":int(entry.get("y",0)),"rot":bool(entry.get("rot",false))}
		for key in SAVED_ITEM_KEYS:
			if entry.has(key):
				item[key]=entry[key]
		if kind=="weapon":
			item["weapon"]=clampi(int(entry.get("weapon",0)),0,WEAPONS.size()-1)
			item["tier"]=tier_of(int(entry.get("tier",0)))
		elif kind=="gear":
			item["gear"]=clampi(int(entry.get("gear",0)),0,GEAR.size()-1)
			item["tier"]=tier_of(int(entry.get("tier",0)))
		elif kind=="backpack":
			item["quality"]=bag_key({"key":entry.get("quality",DEFAULT_BAG_KEY)})
		if can_place(result,item,Vector2i(item.x,item.y),-1,grid):
			result.append(item)
	if container.has("key"):
		container["key"]=bag_key(container)
	container["items"]=result
	# Player storage is sized by gw/gh only: a stray "grid" left in a hand-edited
	# save must not be able to resize a backpack.
	container.erase("grid")
	container["gw"]=grid.x
	container["gh"]=grid.y
	container["next"]=maxi(int(container.get("next",1)),1)
	return container

static func add_item(container: Dictionary, kind: String) -> bool:
	var list: Array = container.get("items",[])
	if not insert(list,kind,container_grid(container)):
		return false
	list.back()["id"]=int(container.get("next",1))
	container["next"]=int(container.get("next",1))+1
	return true

# Which container should receive a piece of loot: valuable relics are sunk into
# the safe pocket, everything else stays in the backpack it was found with.
static func prefers_pocket(kind: String) -> bool:
	return kind=="relic"

# Loot containers are searched, and their contents are laid out as a tidy grid
# instead of being packed wherever they fit.
static func chest_grid(class_index: int) -> Vector2i:
	return Vector2i(5,5) if class_index>=2 else Vector2i(4,4)

const STACK_KINDS := ["crystal","scrap","medicine","ammo","charm"]

static func stacks(kind: String) -> bool:
	return kind in STACK_KINDS

static func max_stack(kind: String) -> int:
	return 6 if stacks(kind) else 1

# Places one unit of loot in the first free cell of a row-major layout. Stackable
# kinds grow their counter in place, which keeps a searched chest readable.
static func place_loot(container: Dictionary, kind: String) -> bool:
	var list: Array = container.get("items",[])
	if stacks(kind):
		for item in list:
			if item.kind==kind and int(item.get("count",1))<max_stack(kind):
				item["count"]=int(item.get("count",1))+1
				return true
	return place_item(container,{"kind":kind,"rot":false,"count":1})

# Places an already-built item entry, keeping every field it carries: without
# this a re-tidy would quietly strip a weapon's quality, its weapon index or a
# loose backpack's colour.
static func place_item(container: Dictionary, entry: Dictionary) -> bool:
	var grid := container_grid(container)
	var list: Array = container.get("items",[])
	var probe: Dictionary=entry.duplicate()
	probe["rot"]=bool(entry.get("rot",false))
	for y in grid.y:
		for x in grid.x:
			if can_place(list,probe,Vector2i(x,y),-1,grid):
				probe["x"]=x
				probe["y"]=y
				list.append(probe)
				container["next"]=int(container.get("next",1))+1
				return true
	return false

# Rearranges every item into row-major order, so a searched container looks
# tidy and new arrivals always have somewhere obvious to go. Stackable kinds are
# merged back together, everything else keeps its own fields.
static func tidy(container: Dictionary) -> void:
	var pending: Array = []
	for item in container_items(container):
		var kind := str(item.kind)
		if stacks(kind):
			for i in int(item.get("count",1)):
				pending.append(kind)
		else:
			pending.append(item.duplicate())
	container["items"]=[]
	for entry in pending:
		if entry is String:
			place_loot(container,entry)
		else:
			place_item(container,entry)

static func can_hold(container: Dictionary, kind: String) -> bool:
	if not ITEMS.has(kind):
		return false
	var probe: Array = container_items(container).duplicate()
	return insert(probe,kind,container_grid(container))

# Swaps the equipped backpack with a spare from the cabinet. Items already in the
# equipped backpack must still fit, otherwise the swap is refused (not destroyed).
static func swap_bags(p: Dictionary, index: int) -> bool:
	var cabinet: Array = p.get("bags",[])
	if index<0 or index>=cabinet.size():
		return false
	var current: Dictionary = p.get("backpack",make_bag())
	var candidate: Dictionary = cabinet[index]
	var space: Array = current.get("items",[])
	candidate["gw"]=bag_grid(candidate).x
	candidate["gh"]=bag_grid(candidate).y
	var moved: Array = []
	for item in space:
		# Everything the save file knows about an item travels with it: rebuilding
		# the entry from only kind/x/y/rot used to strip stack counts and every
		# equipment field, so swapping bags quietly destroyed loot.
		var entry: Dictionary = {}
		for field in SAVED_ITEM_KEYS:
			if item.has(field):
				entry[field]=item[field]
		entry["kind"]=str(item.get("kind",""))
		entry["x"]=int(item.get("x",0))
		entry["y"]=int(item.get("y",0))
		entry["rot"]=bool(item.get("rot",false))
		if not can_place(moved,entry,Vector2i(entry.x,entry.y),-1,bag_grid(candidate)):
			return false
		moved.append(entry)
	candidate["items"]=moved
	candidate["next"]=maxi(int(candidate.get("next",1)),1)
	current["items"]=[]
	current["next"]=maxi(int(current.get("next",1)),1)
	cabinet[index]=current
	p["backpack"]=candidate
	p["bags"]=cabinet
	return true

static func count(bag: Array, kind: String) -> int:
	var n := 0
	for item in bag:
		if item.kind == kind:
			n += 1
	return n

static func container_count(container: Dictionary, kind: String) -> int:
	return count(container_items(container),kind)

static func consume(bag: Array, kind: String) -> bool:
	var removed := false
	for i in range(bag.size()-1,-1,-1):
		if bag[i].kind == kind:
			bag.remove_at(i)
			removed=true
	return removed

static func consume_container(container: Dictionary, kind: String, limit: int = 0) -> bool:
	var list: Array = container.get("items",[])
	var removed := false
	for i in range(list.size()-1,-1,-1):
		if list[i].kind == kind and (limit<=0 or removed==false):
			list.remove_at(i)
			removed=true
	return removed

static func bag_value(bag: Array) -> int:
	var value := 0
	for item in bag:
		if not item.get("provision",false):
			value += item_value(item)
	return value

static func container_value(container: Dictionary) -> int:
	return bag_value(container_items(container))
