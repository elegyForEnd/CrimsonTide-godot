class_name Catalog
extends RefCounted

const HEROES = [
	{"name":"绯月", "title":"赤刃守夜姬", "desc":"黑铁短剑：攻击距离短、攻速快、伤害低。红莲月华贯穿近处敌群。", "color":Color("da6474"), "hair":Color("e8dce0"), "hp":110.0, "speed":220.0, "damage":23.0, "rate":0.23, "clip":16, "skill":"红莲月华"},
	{"name":"雪璃", "title":"晨钟祈愿者", "desc":"祭祀短杖：远程法术攻击，伤害低，释放前需要短暂吟唱。拂晓之祈治疗附近的所有队友。", "color":Color("70c4bc"), "hair":Color("c9e0ef"), "hp":95.0, "speed":230.0, "damage":32.0, "rate":0.42, "clip":10, "skill":"拂晓之祈"},
	{"name":"鸦羽", "title":"黑羽处刑人", "desc":"破碎大剑：攻速慢、伤害略高、范围大。夜鸦断罪清除周围敌人并短暂护身。", "color":Color("b397de"), "hair":Color("56516e"), "hp":130.0, "speed":250.0, "damage":42.0, "rate":0.36, "clip":0, "skill":"夜鸦断罪"}
]
const ITEMS = {
	"crystal":{"name":"血晶", "size":Vector2i(1,1), "value":18, "color":Color("e45c74"), "desc":"拾取后直接计入血晶数量，不占背包格子；靠近即可自动吸附。"},
	"scrap":{"name":"古城零件", "size":Vector2i(2,1), "value":32, "color":Color("b0b6c5"), "desc":"晨钟城工坊急需的机械零件。"},
	"relic":{"name":"月蚀遗物", "size":Vector2i(2,2), "value":125, "color":Color("d2ac66"), "desc":"占据四格的珍贵遗物；双击收纳时和其他白色物资一样先进背包，金色与红色的高品质装备才会优先沉入次元口袋。"},
	"medicine":{"name":"急救针", "size":Vector2i(1,2), "value":25, "color":Color("78cbb5"), "desc":"按 F 消耗一支，恢复 45 生命；倒地时可用于自救。"},
	"charm":{"name":"银鸦护符", "size":Vector2i(1,2), "value":70, "color":Color("b79ade"), "desc":"拾取后，本局伤害提高 12%，最多叠加三枚。"},
	"ammo":{"name":"弹药匣", "size":Vector2i(2,1), "value":20, "color":Color("c4ad82"), "desc":"按 F 优先治疗；弹药不足时自动消耗弹药匣补充 48 发。"},
	"backpack":{"name":"背包", "size":Vector2i(1,1), "value":40, "color":Color("cfc6bb"), "desc":"可背在身上的独立储物空间，本身就是一件装备：双击或 Ctrl+左键即可换装，换下的旧包进背包柜。紫色及以上品质的包占 2×2 格。"},
	"weapon":{"name":"武器", "size":Vector2i(2,2), "value":85, "color":Color("c9a06a"), "desc":"战场上捡到的武器。只有装备到武器槽后才会握在手里；拿着它攻击时获得品质加成。阵亡会掉落。"},
	"gear":{"name":"装备", "size":Vector2i(1,2), "value":55, "color":Color("8fb6d8"), "desc":"护甲 / 瞄具 / 轻靴。装备到对应槽位后本局提升生命、火力或移速。阵亡会掉落。"}
}
const TALENTS = ["生命强化", "火力校准", "轻装步伐"]
# Field weapons are loot and nothing else: a
# Watcher can only ever hold one of them by finding it and putting it on, so the
# index below is also the index a looted weapon stores in its "weapon" field.
const WEAPONS = [
	{"name":"守夜步枪", "rate":0.23, "windup":0.0, "damage":23.0, "reach":680.0, "knock":9.0},
	{"name":"绯红单手剑", "rate":0.38, "windup":0.10, "damage":38.0, "reach":112.0, "knock":20.0},
	{"name":"破晓双手剑", "rate":0.88, "windup":0.34, "damage":88.0, "reach":158.0, "knock":58.0},
	{"name":"星辉法杖", "rate":0.62, "windup":0.22, "damage":46.0, "reach":700.0, "knock":16.0},
	{"name":"赤陨法杖", "family":3, "spell":"meteor", "desc":"陨石命中后爆炸，波及附近敌人。", "rate":1.38, "windup":0.72, "damage":145.0, "reach":650.0, "knock":48.0, "speed":430.0},
	{"name":"霜针短杖", "family":3, "spell":"needle", "desc":"短吟唱高速连射冰针，单发伤害低。", "rate":0.20, "windup":0.045, "damage":14.0, "reach":690.0, "knock":5.0, "speed":1050.0},
	{"name":"鸣雷之杖", "family":3, "spell":"chain", "desc":"雷击命中后向最多三名附近敌人跳跃。", "rate":0.68, "windup":0.27, "damage":53.0, "reach":660.0, "knock":16.0, "speed":700.0},
	{"name":"月弧法杖", "family":3, "spell":"moon", "desc":"月刃穿过最多四名敌人。", "rate":0.76, "windup":0.30, "damage":39.0, "reach":720.0, "knock":12.0, "speed":700.0},
	{"name":"曦光棱镜杖", "family":3, "spell":"prism", "desc":"释放瞬间贯穿直线上的所有敌人。", "rate":0.96, "windup":0.45, "damage":79.0, "reach":640.0, "knock":25.0},
	{"name":"烬羽散华杖", "family":3, "spell":"scatter", "desc":"一次射出五枚扇形火羽，近距可集中命中。", "rate":0.55, "windup":0.16, "damage":21.0, "reach":550.0, "knock":8.0, "speed":670.0},
	{"name":"虚涡法杖", "family":3, "spell":"vortex", "desc":"制造范围爆发，并将附近敌人卷向中心。", "rate":1.08, "windup":0.46, "damage":68.0, "reach":570.0, "knock":0.0, "speed":390.0},
	{"name":"蚀月长枪杖", "family":3, "spell":"eclipse", "desc":"漫长蓄力后发射贯穿最多五名敌人的重型魔枪。", "rate":1.58, "windup":0.95, "damage":210.0, "reach":850.0, "knock":65.0, "speed":920.0},
	{"name":"鸦喙刺剑", "family":1, "pattern":"thrust", "desc":"狭长突刺，贯穿前方一线敌人。", "rate":0.42, "windup":0.13, "damage":51.0, "reach":174.0, "knock":24.0},
	{"name":"回环弯刀", "family":1, "pattern":"spin", "desc":"旋身环斩，命中身边所有敌人。", "rate":0.64, "windup":0.23, "damage":42.0, "reach":118.0, "knock":20.0},
	{"name":"断潮巨刃", "family":2, "pattern":"cleave", "desc":"向前横扫宽阔扇面，击退敌群。", "rate":1.02, "windup":0.39, "damage":105.0, "reach":192.0, "knock":72.0},
	{"name":"裂地重剑", "family":2, "pattern":"quake", "desc":"蓄力砸地，震伤周身敌人。", "rate":1.24, "windup":0.56, "damage":122.0, "reach":140.0, "knock":85.0},
	{"name":"暮羽长弓", "family":0, "spell":"arrow", "desc":"拉弓射出贯穿两名敌人的箭矢；消耗弹药。", "rate":0.56, "windup":0.18, "damage":58.0, "reach":820.0, "knock":24.0, "speed":1050.0}
]
# The temporary weapon every hero sets out with, one per hero, appended after the
# field weapons so the whole game keeps addressing a weapon by a single int.
# They exist so a Watcher can fight on the way to their first pickup and nothing
# more: each one is strictly weaker than the field weapon it imitates, it can
# never be found, never drops and never takes a quality bonus. "family" names the
# field weapon whose attack art, slash VFX and impact audio it borrows.
#
# STARTER_BASE is the first issue index. GDScript will not fold WEAPONS.size()
# into a constant, so this literal has to track the table above; tests/systems.gd
# asserts the two stay equal.
const STARTER_BASE := 17
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
const WEAPON_ICONS := ["rifle","sword","heavy","staff","staff_meteor","staff_needle","staff_chain","staff_moon","staff_prism","staff_scatter","staff_vortex","staff_eclipse","sword_thrust","sword_spin","heavy_cleave","heavy_quake","bow"]
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
# One int addresses every weapon a player can hold: 0..STARTER_BASE-1 are field weapons a
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
		return clampi(int(weapon(index).family),0,3)
	return int(weapon(index).get("family",clampi(index,0,3)))

static func roll_weapon(rng: RandomNumberGenerator) -> int:
	var category := rng.randf()
	var choices: Array[int] = []
	for index in WEAPONS.size():
		var family := weapon_family(index)
		if (category<0.30 and family==1) or (category>=0.30 and category<0.60 and family==2) or (category>=0.60 and category<0.78 and family==0) or (category>=0.78 and family==3):
			choices.append(index)
	return choices[rng.randi_range(0,choices.size()-1)]

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

# Which kinds the item bar's interact key can actually operate. A lootable relic,
# a stack of scrap or a blood crystal is treasure and nothing else, so a socket
# holding one is deliberately inert: the key falls through to whatever else it
# does rather than swallowing the press for no effect.
static func slot_operable(kind: String) -> bool:
	return is_equipment(kind) or kind=="backpack" or kind=="medicine" or kind=="ammo"

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
		var info: Dictionary=weapon(int(item.get("weapon",0)))
		var rhythm := "前摇 %.2f 秒 · 周期 %.2f 秒 · 基础伤害 %d。" % [float(info.windup),float(info.rate),int(info.damage)]
		return str(info.get("desc",""))+rhythm+"持有时伤害 +%d%%、攻速 +%d%%。" % [int(round(weapon_bonus(item)*100.0)),int(round(weapon_rate_bonus(item)*100.0))]
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

# A loose backpack is a piece of equipment the player can wear, so it occupies
# cells like one: the roomier packs are physical objects rather than a 1x1 token.
# Purple is where they start taking a 2x2 block.
const BULKY_BAG_TIER := 3

static func backpack_cells(key: String) -> Vector2i:
	return Vector2i(2,2) if tier_index(key)>=BULKY_BAG_TIER else Vector2i(1,1)

# A bag on the floor or in a container remembers its quality in "quality"; the
# equipped one keeps it in "key". Reading both is what makes a loose purple pack
# really take its 2x2 block instead of claiming a single cell.
static func bag_key_of_item(item: Dictionary) -> String:
	return bag_key({"key":str(item.get("quality",item.get("key",DEFAULT_BAG_KEY)))})

static func item_size(item: Dictionary) -> Vector2i:
	if str(item.get("kind",""))=="backpack":
		return backpack_cells(bag_key_of_item(item))
	var s: Vector2i = ITEMS[item.kind].size
	return Vector2i(s.y,s.x) if item.get("rot",false) else s

# Two items overlap when they share a cell. This is spelled out as four integer
# comparisons rather than handed to Rect2i.intersects(), which in this build
# answers false for rectangles that plainly share cells — a 1x2 beside a 1x2,
# and a 2x1 scrap lying across the top of one. The whole packing rule stands on
# this one answer, so it is computed here and nowhere else.
static func overlaps(at: Vector2i, size: Vector2i, other: Dictionary) -> bool:
	var other_at := Vector2i(int(other.x),int(other.y))
	var other_size := item_size(other)
	if at.x+size.x <= other_at.x or other_at.x+other_size.x <= at.x:
		return false
	if at.y+size.y <= other_at.y or other_at.y+other_size.y <= at.y:
		return false
	return true

static func can_place(bag: Array, item: Dictionary, at: Vector2i, ignore: int = -1, grid: Vector2i = Vector2i.ZERO) -> bool:
	var dims := grid_of(grid)
	var s := item_size(item)
	if at.x < 0 or at.y < 0 or at.x+s.x > dims.x or at.y+s.y > dims.y:
		return false
	for i in bag.size():
		if i != ignore and overlaps(at,s,bag[i]):
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

# Which container should receive a piece of loot: high quality is worth the safe
# pocket, everything else fills the backpack the player is carrying. The quality
# is read from the fields loot really carries — a weapon or a gear piece stores
# it in "tier", a loose backpack in "quality" — so plain supplies such as
# crystals, scrap and relics are white by default and go to the bag.
const POCKET_TIER := 4

static func item_tier(item: Dictionary) -> int:
	if item.has("tier"):
		return tier_of(int(item.get("tier",0)))
	if str(item.get("kind",""))=="backpack":
		return tier_index(str(item.get("quality",DEFAULT_BAG_KEY)))
	return 0

static func high_quality(item: Dictionary) -> bool:
	return item_tier(item)>=POCKET_TIER

# Which container field loot belongs in: valuable relics are sunk into the safe
# pocket, everything else stays in the backpack it was found with. Unchanged by
# the quality rule below, which only steers the double click in the search
# window.
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

# A fingerprint of where every item sits. A tidy that turns out not to help is
# rolled back to this exact layout, so a refusal never leaves a half-sorted bag
# behind — comparing the fingerprint is how the caller sees that it changed.
static func container_state(container: Dictionary) -> String:
	var text := ""
	for item in container_items(container):
		text+=str(item)
	return text

# --- auto storage ------------------------------------------------------------
# One search rules every automatic placement in the game: the first cell that
# fits when the grid is read top to bottom, left to right. An item is measured
# upright first and only then turned, so a shape that would fit either way keeps
# the orientation it was found in. This differs from can_place() by taking the
# raw item list every caller already holds.
static func first_cell(bag: Array, item: Dictionary, grid: Vector2i) -> Vector2i:
	var dims := grid_of(grid)
	for y in dims.y:
		for x in dims.x:
			var at := Vector2i(x,y)
			if can_place(bag,item,at,-1,dims):
				return at
	return Vector2i(-1,-1)

static func empty_cells(grid: Vector2i) -> Array:
	var taken: Array = []
	taken.resize(grid.x*grid.y)
	taken.fill(false)
	return taken

# Throws a placed item over every cell it covers.
static func mark_cells(taken: Array, grid: Vector2i, entry: Dictionary, at: Vector2i) -> void:
	var size := item_size(entry)
	for y in range(at.y,at.y+size.y):
		for x in range(at.x,at.x+size.x):
			taken[y*grid.x+x]=true

# The first free cells of a given shape, scanning top to bottom and left to
# right. This is the single placement rule every automatic fill is built on.
static func first_cell_in(taken: Array, grid: Vector2i, size: Vector2i) -> Vector2i:
	for y in range(0,grid.y-size.y+1):
		for x in range(0,grid.x-size.x+1):
			var free := true
			for cy in range(y,y+size.y):
				for cx in range(x,x+size.x):
					if taken[cy*grid.x+cx]:
						free=false
						break
				if not free:
					break
			if free:
				return Vector2i(x,y)
	return Vector2i(-1,-1)

# Where one item would sit: the first free cells it fits, or the same cells
# turned. Returns {at, rot}, or an empty dictionary when it cannot be seated at
# all. Everything below works in these plain positions, so a fill that runs out
# of room never leaves a stray coordinate on a real item.
static func find_seat(taken: Array, grid: Vector2i, kind: String) -> Dictionary:
	var base: Vector2i=ITEMS[kind].size
	for rotate in [false,true]:
		var size := Vector2i(base.y,base.x) if rotate else base
		var spot := first_cell_in(taken,grid,size)
		if spot.x>=0:
			return {"at":spot,"rot":rotate}
	return {}

# Seats one item where find_seat() says it goes, and covers those cells.
static func seat_item(taken: Array, grid: Vector2i, entry: Dictionary) -> bool:
	var seat := find_seat(taken,grid,str(entry.kind))
	if seat.is_empty():
		return false
	entry["x"]=seat.at.x
	entry["y"]=seat.at.y
	entry["rot"]=seat.rot
	mark_cells(taken,grid,entry,seat.at)
	return true

# Can this arriving piece of loot still be squeezed in without moving anything?
# Returns where it would land, so the caller never has to search twice. Each
# orientation is confirmed against the real grid before the cell is answered
# with: two sizes can share a first free cell, and only one of them really fits.
static func fits(container: Dictionary, entry: Dictionary) -> Dictionary:
	var grid := container_grid(container)
	var list: Array=container_items(container)
	var probe: Dictionary=entry.duplicate()
	for rotate in [false,true]:
		probe["rot"]=rotate
		var spot := first_cell(list,probe,grid)
		if spot.x>=0 and can_place(list,probe,spot,-1,grid):
			return {"at":spot,"rot":rotate}
	return {}

# Working copies of a haul: every attempt is laid out on these, so a pass that
# runs out of room can never leave a stray coordinate on a real item.
static func layout_copies(items: Array) -> Array:
	var copies: Array = []
	for item in items:
		var copy: Dictionary=item.duplicate()
		copy["rot"]=bool(item.get("rot",false))
		copies.append(copy)
	return copies

# The same copies, in the order the fill works through them: largest shape
# first, so the piece that needs the most room reserves it before the small ones
# fill the gaps, and equal sizes keep the order they were recorded in.
static func layout_order(copies: Array) -> Array:
	var plan: Array = []
	for i in copies.size():
		var size := item_size(copies[i])
		plan.append({"index":i,"area":size.x*size.y})
	plan.sort_custom(func(a, b): return a.area>b.area if a.area!=b.area else a.index<b.index)
	var order: Array = []
	for step in plan:
		order.append(copies[int(step.index)])
	return order

# Writes a worked-out layout back onto the haul it came from, keeping every item
# exactly where the tidied grid showed it.
static func commit_layout(items: Array, copies: Array) -> void:
	for i in copies.size():
		items[i]["x"]=copies[i].x
		items[i]["y"]=copies[i].y
		items[i]["rot"]=copies[i].rot

# Pack a player's container after an arrival. Keep item order and every item's
# fields, and decline a layout that uses more rows than the current one. Manual
# drags within a container remain where the player put them.
static func compact_arrivals(container: Dictionary) -> void:
	var items: Array=container_items(container)
	if items.size()<2:
		return
	var grid := container_grid(container)
	var packed := fill(items,grid)
	if packed.size()==items.size() and (rows_used(packed)<rows_used(items) or occupied_score(packed,grid)<occupied_score(items,grid)):
		commit_layout(items,packed)

# Compare layouts by the cells their footprints occupy, so a fully packed first
# row stays where the player can find it even if the greedy fill picks a new
# order for equal-sized groups.
static func occupied_score(items: Array, grid: Vector2i) -> int:
	var score := 0
	for item in items:
		var size := item_size(item)
		for cy in size.y:
			for cx in size.x:
				score+=int(item.y+cy)*grid.x+int(item.x+cx)
	return score

# How far down the grid the haul reaches. A refill that does not beat this has
# left the haul spread out exactly as it was, which would only turn a tidy hole
# into scattered ones — so place_arrival() throws such a refill away.
static func rows_used(items: Array) -> int:
	var rows := 0
	for item in items:
		rows=maxi(rows,int(item.y)+item_size(item).y)
	return rows

# The whole haul, each item seated by size. An arriving item is laid out with it
# — "probe" is copied in at "reserve" if it is given one — so the caller can try a
# tidy with and without the newcomer without disturbing the container. "measure"
# receives the row count the fill reached, which is how the caller tells a refill
# that helped from one that merely reshuffled the same haul.
static func fill(items: Array, grid: Vector2i, probe: Dictionary = {}, reserve: Vector2i = Vector2i(-1,-1), measure: Dictionary = {}) -> Array:
	var copies := layout_copies(items)
	if not probe.is_empty():
		var copy: Dictionary=probe.duplicate()
		copy["x"]=reserve.x
		copy["y"]=reserve.y
		copies.append(copy)
	var taken := empty_cells(grid)
	for entry in layout_order(copies):
		if not seat_item(taken,grid,entry):
			return []
	measure["rows"]=rows_used(copies)
	return copies

# The counter-offer for a shape the greedy fill cannot seat: reserve every legal
# spot for the newcomer in turn and fill the haul around it, taking the first
# arrangement that holds. The newcomer is seated from its cell like any other
# item, so the room reserved for it is always the footprint it really covers.
# Row-major order means the spot nearest the top-left corner wins whenever
# several would work. No row budget is needed here: the fill either seats every
# item or it fails, and an arrangement that seats them all is by definition one
# that fits.
static func fill_reserving(items: Array, grid: Vector2i, probe: Dictionary) -> Array:
	# The footprint comes from item_size(), not from the kind's table entry: a
	# turned item, and a backpack whose quality decides its own shape, are both
	# only measurable through it. Reading the raw table here reserved the wrong
	# room — a turned 1x2 asked for a 1x2 — and could refuse an arrival the grid
	# could really hold.
	var base: Vector2i=item_size(probe)
	for rotate in [false,true]:
		var size := Vector2i(base.y,base.x) if rotate else base
		for y in range(0,grid.y-size.y+1):
			for x in range(0,grid.x-size.x+1):
				var seat: Dictionary=probe.duplicate()
				seat["rot"]=rotate
				var filled := fill(items,grid,seat,Vector2i(x,y))
				if not filled.is_empty():
					return filled
	return []

# Where the arriving item ended up in a fill that already seated it. Asking the
# fill itself is what makes a refill usable: searching the finished grid for a
# free hole only works when the hole still has the shape the item needs, which is
# exactly what a solidly packed grid never leaves behind.
static func seated_entry(copies: Array, probe: Dictionary) -> Dictionary:
	for entry in copies:
		if entry==probe:
			return entry
	return {}

# The one-shot tidy behind the double click. Free cells win outright; when
# nothing is free the whole container is refilled from scratch, largest item
# first, with the arriving item considered last, and — only if even that cannot
# house it — considered first with the haul packed around it. The haul keeps its
# slots when the call says no: nothing but a yes ever touches the container.
# Returns "ok":false when this container cannot take the item even after being
# tidied, which is the caller's signal to leave the item where it is.
static func place_arrival(container: Dictionary, entry: Dictionary) -> Dictionary:
	var grid := container_grid(container)
	var list: Array=container_items(container)
	var probe: Dictionary=entry.duplicate()
	# Free cells win outright, and the item keeps every field it was found with.
	var free := fits(container,probe)
	if not free.is_empty():
		probe["x"]=free.at.x
		probe["y"]=free.at.y
		probe["rot"]=free.rot
		return {"ok":true,"items":[],"seat":probe}
	# Pass one: refill the haul with the newcomer laid out last, so it takes what
	# the haul leaves over. A refill that leaves the haul spread exactly as wide as
	# it already is has bought nothing, so it is only adopted when it seats every
	# item within fewer rows than the haul already reaches — that is what turns a
	# grid scattered by a tidy back into a packed one. The frontier is the arrival
	# into an empty container, where "how far down" means nothing.
	var measure: Dictionary = {}
	var refilled := fill(list,grid,probe,Vector2i(-1,-1),measure)
	if not refilled.is_empty():
		var roomy := list.is_empty() or int(measure.get("rows",0))<=rows_used(list)
		if roomy:
			var seat := seated_entry(refilled,probe)
			if not seat.is_empty():
				return {"ok":true,"items":refilled.slice(0,refilled.size()-1),"seat":seat}
	# Pass two: reserve the newcomer's room first and fill the haul around it.
	var reserved := fill_reserving(list,grid,probe)
	if reserved.is_empty():
		return {"ok":false,"items":[],"seat":{}}
	# The fill lays the newcomer out with the haul as its last copy, so its seat
	# comes straight out of that layout.
	return {"ok":true,"items":reserved.slice(0,reserved.size()-1),"seat":reserved[reserved.size()-1]}

# Every item in this container that the arriving one outranks: strictly lower
# quality, and then the cheapest of those first, so a haul of white junk gives
# way before anything worth carrying. Equal quality is never listed, which is
# what keeps one relic from pushing out another.
static func eviction_order(container: Dictionary, entry: Dictionary) -> Array:
	var floor_tier := item_tier(entry)
	var losers: Array = []
	for item in container_items(container):
		var tier := item_tier(item)
		if tier>=floor_tier:
			continue
		losers.append({"tier":tier,"value":item_value(item),"kind":str(item.kind)})
	losers.sort_custom(func(a, b): return a.tier<b.tier if a.tier!=b.tier else a.value<b.value)
	return losers

static func restore_layout(container: Dictionary, snapshot: Array) -> void:
	container["items"]=snapshot
