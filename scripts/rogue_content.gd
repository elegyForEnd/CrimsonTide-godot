extends RefCounted
## Stable, run-only weapon indices leave campaign inventory/save indices intact.
const WEAPON_BASE := 600
const QUALITY := [1.0,1.08,1.16,1.24,1.32,1.40]
const SCHOOLS := ["赤刃出血","破势重刃","猎印远射","余烬灼烧","星霜控制","雷链机动","星泉施法","空鸣战技","壁垒反击","逐风闪击","引魂召唤","晨钟协作"]
static var data: Dictionary = _load_data()

static func _load_data() -> Dictionary:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://resources/rogue_build_content.json"))
	assert(parsed is Dictionary,"Build catalog is missing or invalid")
	return parsed

static func weapon(index: int) -> Dictionary:
	return data.weapons[index-WEAPON_BASE] if index>=WEAPON_BASE and index<WEAPON_BASE+48 else {}

static func entry(id: String) -> Dictionary:
	var category: String="cores" if id.begins_with("WC") else {"W":"weapons","E":"gear","T":"talents","I":"engravings"}.get(id.left(1),"")
	if category.is_empty(): return {}
	var n := int(id.substr(2 if category=="cores" else 1))-1
	return data[category][n] if n>=0 and n<data[category].size() else {}

static func make_weapon(n: int, tier: int) -> Dictionary:
	return {"kind":"weapon","weapon":WEAPON_BASE+clampi(n,0,47),"tier":clampi(tier,0,5),"build_id":"W%03d" % (clampi(n,0,47)+1)}

static func player_text(value: String) -> String:
	return value.replace("普攻根命中","一次普攻命中").replace("根命中","有效命中").replace("单目标每根一次","同次攻击每名敌人最多一次").replace("直击 C+","直接伤害+").replace("普攻 C+","普攻伤害+").replace("右键 C+","战技伤害+").replace("C+","条件伤害+").replace("局部 A+","伤害+").replace("A+","攻击+").replace("不提高 P","不提高额外机制伤害").replace("ICD","间隔").replace("CDR","冷却缩减").replace("MP","蓝量").replace("HP","生命").replace("Q","奥义").replace("右键","战技").replace("DoT","持续伤害").replace("P","倍基础威力")
