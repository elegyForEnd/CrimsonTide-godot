class_name Catalog
extends RefCounted

const HEROES = [
	{"name":"绯月", "title":"赤刃守夜姬", "desc":"绯红剑舞。猩红齐射贯穿近处敌群；可切换四类武器。", "color":Color("da6474"), "hair":Color("e8dce0"), "hp":110.0, "speed":220.0, "damage":23.0, "rate":0.23, "clip":16, "skill":"猩红齐射"},
	{"name":"雪璃", "title":"晨钟祈愿者", "desc":"星辉法杖。晨光祈愿治疗附近的所有队友。", "color":Color("70c4bc"), "hair":Color("c9e0ef"), "hp":95.0, "speed":230.0, "damage":32.0, "rate":0.42, "clip":10, "skill":"晨光祈愿"},
	{"name":"鸦羽", "title":"黑羽处刑人", "desc":"重剑处刑。夜鸦斩清除周围敌人并短暂护身。", "color":Color("b397de"), "hair":Color("56516e"), "hp":130.0, "speed":250.0, "damage":42.0, "rate":0.36, "clip":0, "skill":"夜鸦斩"}
]
const ITEMS = {
	"crystal":{"name":"血晶", "size":Vector2i(1,1), "value":18, "color":Color("e45c74"), "desc":"血香 +8；按 B 可燃烧一枚，驱散血香并恢复理智。"},
	"scrap":{"name":"古城零件", "size":Vector2i(2,1), "value":32, "color":Color("b0b6c5"), "desc":"晨钟城工坊急需的机械零件。"},
	"relic":{"name":"月蚀遗物", "size":Vector2i(2,2), "value":125, "color":Color("d2ac66"), "desc":"占据四格的珍贵遗物；深处教堂更易发现。"},
	"medicine":{"name":"急救针", "size":Vector2i(1,2), "value":25, "color":Color("78cbb5"), "desc":"按 F 消耗一支，恢复 45 生命；倒地时可用于自救。"},
	"charm":{"name":"银鸦护符", "size":Vector2i(1,2), "value":70, "color":Color("b79ade"), "desc":"拾取后，本局伤害提高 12%，最多叠加三枚。"},
	"ammo":{"name":"弹药匣", "size":Vector2i(2,1), "value":20, "color":Color("c4ad82"), "desc":"按 F 优先治疗；弹药不足时自动消耗弹药匣补充 48 发。"}
}
const TALENTS = ["生命强化", "火力校准", "轻装步伐"]
const WEAPONS = [
	{"name":"守夜步枪", "rate":0.23, "windup":0.0, "damage":23.0, "reach":680.0, "knock":9.0},
	{"name":"绯红单手剑", "rate":0.38, "windup":0.10, "damage":38.0, "reach":112.0, "knock":20.0},
	{"name":"破晓双手剑", "rate":0.88, "windup":0.34, "damage":88.0, "reach":158.0, "knock":58.0},
	{"name":"星辉法杖", "rate":0.62, "windup":0.22, "damage":46.0, "reach":700.0, "knock":16.0}
]
const GEAR = [
	{"name":"守夜护甲", "desc":"最大生命 +20", "hp":20.0,"damage":0.0,"speed":0.0},
	{"name":"血月瞄具", "desc":"武器伤害 +15%", "hp":0.0,"damage":0.15,"speed":0.0},
	{"name":"渡鸦轻靴", "desc":"移动速度 +20", "hp":0.0,"damage":0.0,"speed":20.0}
]

static func item_size(item: Dictionary) -> Vector2i:
	var s: Vector2i = ITEMS[item.kind].size
	return Vector2i(s.y,s.x) if item.get("rot",false) else s

static func can_place(bag: Array, item: Dictionary, at: Vector2i, ignore: int = -1) -> bool:
	var s := item_size(item)
	if at.x < 0 or at.y < 0 or at.x+s.x > 6 or at.y+s.y > 4:
		return false
	var rect := Rect2i(at,s)
	for i in bag.size():
		if i != ignore and rect.intersects(Rect2i(Vector2i(bag[i].x,bag[i].y),item_size(bag[i]))):
			return false
	return true

static func insert(bag: Array, kind: String) -> bool:
	var item := {"kind":kind,"x":0,"y":0,"rot":false}
	for rotate in [false,true]:
		item.rot = rotate
		for y in 4:
			for x in 6:
				if can_place(bag,item,Vector2i(x,y)):
					item.x=x
					item.y=y
					bag.append(item)
					return true
	return false

static func count(bag: Array, kind: String) -> int:
	var n := 0
	for item in bag:
		if item.kind == kind:
			n += 1
	return n

static func consume(bag: Array, kind: String) -> bool:
	for i in bag.size():
		if bag[i].kind == kind:
			bag.remove_at(i)
			return true
	return false

static func bag_value(bag: Array) -> int:
	var value := 0
	for item in bag:
		if not item.get("provision",false):
			value += ITEMS[item.kind].value
	return value
