extends RefCounted
## 血潮猎场 · 静态内容表
##
## 这里只有数据与纯查询，不建节点、不写存档、不碰 TideSession。
## 时间、地区、热点、配方、敌人、立绘全部集中在这一个文件，规则层
## `hunt_run.gd` 只读它，UI 只读规则层。以后加地区/配方只动这张表。
##
## 坐标约定：地区内的 `at` 是 0..1 的屏幕坐标，x 向右、y 向下；
## 0.72 以下留给左下立绘与底部操作栏，热点不要压在那里。

const DAYS := 3
const DAY_SECONDS := 480.0
const EXTRACT_AFTER := 240.0
const CAMP_AREA := "old_town"
const MAX_LOGS := 40

const PHASES := [
	{"id": "day", "name": "白昼", "from": 0.0, "to": 0.5},
	{"id": "dusk", "name": "黄昏", "from": 0.5, "to": 0.75},
	{"id": "night", "name": "夜晚", "from": 0.75, "to": 1.0},
]

## 八个地区。`unlock_day` 是第一次可以进入的天数；`neighbors` 是地图连线。
## `hotspots` 的 `uses` 是每天可搜索次数，搜空后会显示"已被搜空"。
## `loot` 的键是物品 kind，值是权重；权重越高越常见。
const AREAS := {
	"old_town": {
		"name": "旧城街区",
		"short": "旧城",
		"sub": "OLD TOWN",
		"desc": "塌了半边的木筋屋沿街挤着，湿石板把唯一一盏油灯的光拖得很长。",
		"unlock_day": 1,
		"neighbors": ["black_pines", "hospital", "bell_square"],
		"map_at": Vector2(0.400, 0.440),
		"theme": "street",
		"palette": Color("8c7a74"),
		"hotspots": [
			{"id": "car", "name": "倾覆的手推车", "kind": "search", "at": Vector2(0.16, 0.58), "tier": 1, "uses": 3,
				"loot": {"branch": 4, "cloth": 3, "resin": 2, "iron": 1, "dirty_water": 2}},
			{"id": "shop", "name": "塌了顶的店铺", "kind": "search", "at": Vector2(0.42, 0.52), "tier": 2, "uses": 3,
				"loot": {"cloth": 4, "paper": 3, "glass": 2, "honey": 2, "herbal_bandage": 1}},
			{"id": "mailbox", "name": "钉死的木信箱", "kind": "search", "at": Vector2(0.68, 0.60), "tier": 1, "uses": 2,
				"loot": {"paper": 4, "nail": 3, "resin": 2, "key": 1}},
			{"id": "alley", "name": "后巷杂物堆", "kind": "search", "at": Vector2(0.84, 0.54), "tier": 2, "uses": 2,
				"loot": {"iron": 3, "rope": 2, "leather": 2, "relic": 1}},
		],
		"enemies": [
			{"kind": "scavenger", "at": Vector2(0.55, 0.66), "day": 1},
			{"kind": "hound", "at": Vector2(0.78, 0.70), "day": 2},
		],
	},
	"black_pines": {
		"name": "黑松林",
		"short": "松林",
		"sub": "BLACK PINES",
		"desc": "松针把月光筛成细碎的灰，林间没有鸟声。",
		"unlock_day": 1,
		"neighbors": ["old_town", "catacombs", "bell_square"],
		"map_at": Vector2(0.240, 0.410),
		"theme": "forest",
		"palette": Color("6f8374"),
		"hotspots": [
			{"id": "camp", "name": "废弃营地", "kind": "search", "at": Vector2(0.20, 0.56), "tier": 2, "uses": 2,
				"loot": {"cloth": 3, "rope": 3, "leather": 2, "oil": 1}},
			{"id": "stump", "name": "雷击树桩", "kind": "search", "at": Vector2(0.47, 0.60), "tier": 1, "uses": 3,
				"loot": {"branch": 5, "wild_herb": 3, "honey": 2, "stone": 2}},
			{"id": "shrine", "name": "林间石龛", "kind": "search", "at": Vector2(0.72, 0.50), "tier": 3, "uses": 2,
				"loot": {"wild_herb": 3, "paper": 2, "crystal": 1, "charm": 1}},
			{"id": "hollow", "name": "空心巨木", "kind": "search", "at": Vector2(0.86, 0.58), "tier": 2, "uses": 2,
				"requires": {"torch": true}, "loot": {"branch": 4, "honey": 3, "leather": 2, "relic": 1}},
		],
		"enemies": [
			{"kind": "hound", "at": Vector2(0.40, 0.68), "day": 1},
			{"kind": "scavenger", "at": Vector2(0.66, 0.66), "day": 2},
			{"kind": "nightmare", "at": Vector2(0.62, 0.64), "day": 2, "phase": "night"},
		],
	},
	"hospital": {
		"name": "圣玛丽医务所",
		"short": "医院",
		"sub": "ST. MARY",
		"desc": "拱廊尽头的窗透进灰光，病床上还留着发黑的麻布。",
		"unlock_day": 1,
		"neighbors": ["old_town", "institute", "bell_square"],
		"map_at": Vector2(0.535, 0.215),
		"theme": "hospital",
		"palette": Color("7a9b8f"),
		"hotspots": [
			{"id": "reception", "name": "修士值班台", "kind": "search", "at": Vector2(0.18, 0.54), "tier": 2, "uses": 3,
				"loot": {"herbal_bandage": 2, "cloth": 3, "paper": 2, "glass": 2}},
			{"id": "ward", "name": "废弃病房", "kind": "search", "at": Vector2(0.43, 0.58), "tier": 2, "uses": 3,
				"loot": {"cloth": 4, "wild_herb": 3, "herbal_bandage": 1, "leather": 2}},
			{"id": "cabinet", "name": "上锁药柜", "kind": "locked", "at": Vector2(0.66, 0.52), "tier": 3, "uses": 2,
				"loot": {"herbal_bandage": 3, "poppy_syrup": 2, "glass": 2, "relic": 1}},
			{"id": "morgue", "name": "停尸架", "kind": "search", "at": Vector2(0.84, 0.60), "tier": 3, "uses": 1,
				"requires": {"mask": true}, "loot": {"leather": 3, "paper": 2, "charm": 1, "crystal": 1}},
		],
		"enemies": [
			{"kind": "guard", "at": Vector2(0.56, 0.66), "day": 2},
			{"kind": "nightmare", "at": Vector2(0.34, 0.64), "day": 3, "phase": "night"},
		],
	},
	"docks": {
		"name": "雾港码头",
		"short": "码头",
		"sub": "FOG HARBOR",
		"desc": "系船柱上的麻绳泡得发胀，雾里只剩木吊轮偶尔吱一声。",
		"unlock_day": 2,
		"neighbors": ["bell_square", "catacombs", "old_town"],
		"map_at": Vector2(0.150, 0.660),
		"theme": "docks",
		"palette": Color("6c879b"),
		"hotspots": [
			{"id": "container", "name": "半开的货箱", "kind": "search", "at": Vector2(0.18, 0.56), "tier": 2, "uses": 2,
				"loot": {"iron": 4, "rope": 3, "resin": 2, "oil": 2}},
			{"id": "crate", "name": "泡水货箱", "kind": "search", "at": Vector2(0.42, 0.60), "tier": 1, "uses": 3,
				"loot": {"branch": 3, "cloth": 3, "leather": 2, "dirty_water": 2}},
			{"id": "crane", "name": "木吊轮机房", "kind": "search", "at": Vector2(0.66, 0.50), "tier": 3, "uses": 2,
				"requires": {"torch": true}, "loot": {"storm_phial": 3, "iron": 3, "glass": 2, "spirit_horn": 1}},
			{"id": "net", "name": "破渔网", "kind": "search", "at": Vector2(0.85, 0.58), "tier": 1, "uses": 2,
				"loot": {"rope": 4, "cloth": 2, "wild_herb": 2, "relic": 1}},
		],
		"enemies": [
			{"kind": "scavenger", "at": Vector2(0.50, 0.68), "day": 2},
			{"kind": "guard", "at": Vector2(0.74, 0.64), "day": 2},
		],
	},
	"institute": {
		"name": "白鸦炼金塔",
		"short": "炼金塔",
		"sub": "WHITE CROW",
		"desc": "蒸馏瓶碎了一地，炼金炉里的余烬还红着，像谁刚离开。",
		"unlock_day": 2,
		"neighbors": ["hospital", "bell_square", "catacombs"],
		"map_at": Vector2(0.860, 0.270),
		"theme": "institute",
		"palette": Color("8a809f"),
		"hotspots": [
			{"id": "lab", "name": "主炼金室", "kind": "search", "at": Vector2(0.16, 0.54), "tier": 3, "uses": 2,
				"loot": {"storm_phial": 3, "glass": 3, "paper": 2, "brimstone": 2}},
			{"id": "locker", "name": "学徒储物柜", "kind": "locked", "at": Vector2(0.40, 0.58), "tier": 2, "uses": 3,
				"loot": {"resin": 3, "cloth": 3, "herbal_bandage": 2, "storm_phial": 2}},
			{"id": "vault", "name": "封蜡样本窖", "kind": "search", "at": Vector2(0.64, 0.48), "tier": 3, "uses": 2,
				"requires": {"mask": true}, "loot": {"crystal": 2, "relic": 2, "glass": 2, "charm": 1}},
			{"id": "vent", "name": "通风竖井", "kind": "search", "at": Vector2(0.85, 0.62), "tier": 1, "uses": 2,
				"loot": {"iron": 3, "nail": 3, "resin": 2, "key": 1}},
		],
		"enemies": [
			{"kind": "guard", "at": Vector2(0.54, 0.66), "day": 2},
			{"kind": "nightmare", "at": Vector2(0.78, 0.60), "day": 3, "phase": "night"},
		],
	},
	"catacombs": {
		"name": "沉钟墓道",
		"short": "墓道",
		"sub": "SUNKEN CRYPT",
		"desc": "石棺沿墙排到看不见的深处，烛火被地下水汽压得很低。",
		"unlock_day": 2,
		"neighbors": ["black_pines", "docks", "altar", "institute"],
		"map_at": Vector2(0.560, 0.595),
		"theme": "catacombs",
		"palette": Color("7c6d79"),
		"hotspots": [
			{"id": "coffin", "name": "裂开的石棺", "kind": "search", "at": Vector2(0.18, 0.56), "tier": 2, "uses": 3,
				"loot": {"stone": 4, "paper": 2, "relic": 2, "charm": 1}},
			{"id": "altar", "name": "无名祭台", "kind": "search", "at": Vector2(0.43, 0.54), "tier": 3, "uses": 2,
				"loot": {"crystal": 2, "wild_herb": 3, "oil": 2, "relic": 2}},
			{"id": "ossuary", "name": "骨瓮", "kind": "search", "at": Vector2(0.66, 0.60), "tier": 1, "uses": 3,
				"requires": {"torch": true}, "loot": {"stone": 3, "iron": 2, "nail": 3, "leather": 2}},
			{"id": "gate", "name": "封死的铁门", "kind": "locked", "at": Vector2(0.86, 0.52), "tier": 3, "uses": 1,
				"loot": {"brimstone": 2, "iron": 3, "crystal": 2, "key": 1}},
		],
		"enemies": [
			{"kind": "nightmare", "at": Vector2(0.56, 0.66), "day": 2, "phase": "night"},
			{"kind": "guard", "at": Vector2(0.78, 0.62), "day": 3},
		],
	},
	"bell_square": {
		"name": "晨钟广场",
		"short": "广场",
		"sub": "BELL SQUARE",
		"desc": "钟楼停在三时十七分。广场中央的裂隙里，风一直往上吹。",
		"unlock_day": 1,
		"neighbors": ["old_town", "black_pines", "hospital", "docks", "institute", "altar"],
		"map_at": Vector2(0.730, 0.435),
		"theme": "square",
		"palette": Color("9a8a78"),
		"hotspots": [
			{"id": "fountain", "name": "干涸喷泉", "kind": "search", "at": Vector2(0.20, 0.58), "tier": 2, "uses": 2,
				"loot": {"stone": 4, "glass": 2, "crystal": 1, "relic": 1}},
			{"id": "bench", "name": "长椅背包", "kind": "search", "at": Vector2(0.44, 0.62), "tier": 1, "uses": 3,
				"loot": {"cloth": 3, "paper": 3, "resin": 2, "honey": 2}},
			{"id": "tower", "name": "钟楼入口", "kind": "search", "at": Vector2(0.68, 0.46), "tier": 3, "uses": 2,
				"loot": {"iron": 3, "storm_phial": 2, "paper": 2, "charm": 1}},
			{"id": "relief", "name": "撤离点浮雕", "kind": "search", "at": Vector2(0.87, 0.56), "tier": 2, "uses": 1,
				"loot": {"herbal_bandage": 2, "lead_shot": 2, "relic": 1}},
		],
		"enemies": [
			{"kind": "scavenger", "at": Vector2(0.57, 0.68), "day": 1},
			{"kind": "guard", "at": Vector2(0.34, 0.70), "day": 2},
		],
	},
	"altar": {
		"name": "血月祭坛",
		"short": "祭坛",
		"sub": "BLOOD ALTAR",
		"desc": "第三夜才会出现的裂口。石阶向下，尽头是一轮贴着地面的红月。",
		"unlock_day": 3, "unlock_item": "blood_sigil",
		"neighbors": ["catacombs", "bell_square"],
		"map_at": Vector2(0.880, 0.655),
		"theme": "altar",
		"palette": Color("a06570"),
		"hotspots": [
			{"id": "basin", "name": "血池", "kind": "search", "at": Vector2(0.24, 0.54), "tier": 3, "uses": 2,
				"requires": {"blood_sigil": true}, "loot": {"crystal": 3, "relic": 2, "charm": 2, "herbal_bandage": 2}},
			{"id": "steps", "name": "祭坛阶梯", "kind": "search", "at": Vector2(0.49, 0.58), "tier": 2, "uses": 2,
				"loot": {"stone": 4, "iron": 3, "oil": 2, "brimstone": 2}},
			{"id": "effigy", "name": "无面神像", "kind": "locked", "at": Vector2(0.72, 0.48), "tier": 3, "uses": 2,
				"loot": {"relic": 3, "crystal": 3, "brimstone": 2, "charm": 2}},
		],
		"enemies": [
			{"kind": "nightmare", "at": Vector2(0.58, 0.64), "day": 3, "phase": "night"},
			{"kind": "apostle", "at": Vector2(0.78, 0.58), "day": 3, "phase": "night", "boss": true},
		],
	},
}

## 新增物品（材料、消耗品、工具、武器、防具）。Catalog.ITEMS 会追加这些行，
## 所以仓库、交易行、图标解析都能直接复用现有管线。
## `cat` 只给猎场合成界面分类用。
const ITEMS := {
	# ---- 材料 ----
	"branch": {"name": "树枝", "size": Vector2i(1, 1), "value": 3, "color": Color("8d6f4d"), "cat": "material", "desc": "干燥的硬枝，能做柄也能当柴。"},
	"stone": {"name": "石块", "size": Vector2i(1, 1), "value": 4, "color": Color("8b8a84"), "cat": "material", "desc": "边缘锋利的碎石，猎场里最不缺的东西。"},
	"cloth": {"name": "碎布", "size": Vector2i(1, 1), "value": 5, "color": Color("b9ad9b"), "cat": "material", "desc": "从旧衣和窗帘上撕下来的布条。"},
	"dirty_water": {"name": "污水", "size": Vector2i(1, 1), "value": 2, "color": Color("6f8077"), "cat": "material", "desc": "混着泥沙的脏水，滤过之后还能用。"},
	"clean_water": {"name": "净水", "size": Vector2i(1, 1), "value": 8, "color": Color("9fd1d2"), "cat": "material", "desc": "滤掉泥沙的清水，能直接喝。"},
	"honey": {"name": "蜂蜜", "size": Vector2i(1, 1), "value": 12, "color": Color("d5a33f"), "cat": "material", "desc": "从废弃蜂箱里刮下来的浓稠蜂蜜。"},
	"wild_herb": {"name": "野草", "size": Vector2i(1, 1), "value": 7, "color": Color("7da77b"), "cat": "material", "desc": "气味苦涩的草药，能止血也能提神。"},
	"iron": {"name": "铁片", "size": Vector2i(1, 1), "value": 14, "color": Color("9da6b2"), "cat": "material", "desc": "从旧铁器上敲下来的铁片，边缘还带着锈。"},
	"nail": {"name": "钉子", "size": Vector2i(1, 1), "value": 6, "color": Color("b7b3a8"), "cat": "material", "desc": "生锈但还算直的铁钉。"},
	"leather": {"name": "兽皮", "size": Vector2i(1, 1), "value": 16, "color": Color("9a6f52"), "cat": "material", "desc": "从猎场野兽身上剥下的皮，还带着腥气。"},
	"rope": {"name": "绳索", "size": Vector2i(1, 1), "value": 10, "color": Color("b7a27a"), "cat": "material", "desc": "几股旧麻绳拧成的结实绳子。"},
	"resin": {"name": "松脂", "size": Vector2i(1, 1), "value": 8, "color": Color("c7b98d"), "cat": "material", "desc": "从松树里熬出的黏稠树胶，能粘合木石。"},
	"storm_phial": {"name": "封雷瓶", "size": Vector2i(1, 1), "value": 18, "color": Color("c9b45c"), "cat": "material", "desc": "封着一小团雷的玻璃瓶，炼金术士用它代替火种。"},
	"glass": {"name": "玻璃", "size": Vector2i(1, 1), "value": 6, "color": Color("9fc6c8"), "cat": "material", "desc": "教堂彩窗的碎片，边缘锋利得能割开皮肉。"},
	"paper": {"name": "纸页", "size": Vector2i(1, 1), "value": 4, "color": Color("d0c7b5"), "cat": "material", "desc": "受潮的羊皮纸页，能引火也能包东西。"},
	"oil": {"name": "灯油", "size": Vector2i(1, 1), "value": 15, "color": Color("c7a35b"), "cat": "material", "desc": "从教堂长明灯里倒出来的灯油。"},
	"brimstone": {"name": "硫磺", "size": Vector2i(1, 1), "value": 22, "color": Color("8f7b6d"), "cat": "material", "desc": "磨碎的硫磺与炭，炼金火器的引药。"},

	# ---- 恢复 ----
	"bandage": {"name": "绷带", "size": Vector2i(1, 1), "value": 14, "color": Color("d8c9b5"), "cat": "recovery", "heal": 28, "desc": "碎布缠成的绷带，恢复 28 生命。"},
	"mead": {"name": "蜜酒", "size": Vector2i(1, 1), "value": 20, "color": Color("d9b25c"), "cat": "recovery", "stamina": 45, "desc": "蜂蜜兑水的粗酿，恢复 45 体力。"},
	"herbal_tea": {"name": "草药汤", "size": Vector2i(1, 1), "value": 18, "color": Color("8fb88a"), "cat": "recovery", "heal": 16, "stamina": 20, "desc": "苦味压住了恐慌，恢复 16 生命与 20 体力。"},
	"poppy_syrup": {"name": "罂粟膏", "size": Vector2i(1, 1), "value": 30, "color": Color("b8c9d8"), "cat": "recovery", "heal": 42, "desc": "罂粟熬出的黑膏，压住疼痛，恢复 42 生命。"},
	"blood_draught": {"name": "血酿", "size": Vector2i(1, 1), "value": 26, "color": Color("d3a45f"), "cat": "recovery", "stamina": 60, "desc": "一小瓶温热的血酿，恢复 60 体力，喝下去心跳发慌。"},
	"salve": {"name": "药膏", "size": Vector2i(1, 1), "value": 24, "color": Color("9cbe8a"), "cat": "recovery", "heal": 34, "desc": "草药和油脂熬成的药膏，恢复 34 生命。"},
	"herbal_bandage": {"name": "草药绷带", "size": Vector2i(1, 1), "value": 28, "color": Color("b7c9a4"), "cat": "recovery", "heal": 46, "desc": "浸过草汁的绷带，恢复 46 生命。"},
	"frenzy_phial": {"name": "狂血药剂", "size": Vector2i(1, 1), "value": 35, "color": Color("d27f65"), "cat": "recovery", "buff": "attack", "desc": "炼金术士的狂血药剂，短时间提高攻击力，代价是体力见底。"},

	# ---- 武器 ----
	"stone_axe": {"name": "燧石斧", "size": Vector2i(1, 1), "value": 30, "color": Color("9a7b5d"), "cat": "weapon", "desc": "燧石绑在树枝上，粗糙但劈得开骨头。"},
	"spear": {"name": "长矛", "size": Vector2i(1, 1), "value": 34, "color": Color("a98a62"), "cat": "weapon", "desc": "两根白蜡木接成的长杆，前端削尖烤黑。"},
	"spiked_club": {"name": "钉头棒", "size": Vector2i(1, 1), "value": 38, "color": Color("8b7a68"), "cat": "weapon", "desc": "钉满铁钉的木棒，挥起来带着风声。"},
	"iron_mace": {"name": "铁头槌", "size": Vector2i(1, 1), "value": 36, "color": Color("9da6ad"), "cat": "weapon", "desc": "锻铁槌头装在木柄上，缠着防滑的麻布。"},
	"machete": {"name": "砍刀", "size": Vector2i(1, 1), "value": 48, "color": Color("b2a18b"), "cat": "weapon", "desc": "铁片磨出的刀身，缠着皮革刀柄。"},
	"crossbow": {"name": "十字弩", "size": Vector2i(1, 1), "value": 60, "color": Color("a98963"), "cat": "weapon", "desc": "白蜡木和绳索拼成的弩，近距离很致命。"},
	"hand_cannon": {"name": "手铳", "size": Vector2i(1, 1), "value": 72, "color": Color("8d9199"), "cat": "weapon", "desc": "短铁管缠上铁箍，用硫磺点火；打一发要重新装填。"},
	"heavy_axe": {"name": "战斧", "size": Vector2i(1, 1), "value": 78, "color": Color("9d8064"), "cat": "weapon", "desc": "燧石斧加铁箍加固，挥空会露出破绽。"},
	"iron_maul": {"name": "铁槌", "size": Vector2i(1, 1), "value": 70, "color": Color("8c7b6a"), "cat": "weapon", "desc": "钉头棒外箍铁环，砸下去像一记闷雷。"},

	# ---- 防具 ----
	"cloth_armor": {"name": "衬垫甲", "size": Vector2i(1, 1), "value": 32, "color": Color("b9aa94"), "cat": "armor", "desc": "多层碎布缝成的护身衣。"},
	"leather_armor": {"name": "皮胸甲", "size": Vector2i(1, 1), "value": 46, "color": Color("997055"), "cat": "armor", "desc": "兽皮裁成的硬皮护胸。"},
	"ring_mail": {"name": "环甲", "size": Vector2i(1, 1), "value": 64, "color": Color("9aa3ad"), "cat": "armor", "desc": "铁环缝在皮甲外侧，沉得压肩。"},
	"hunter_cloak": {"name": "猎人斗篷", "size": Vector2i(1, 1), "value": 58, "color": Color("7d6d5e"), "cat": "armor", "desc": "带兜帽的厚斗篷，夜里能挡住一些视线。"},
	"armor_patch": {"name": "甲片补丁", "size": Vector2i(1, 1), "value": 20, "color": Color("a99a86"), "cat": "armor", "desc": "使用后永久提高 1 点防御，最多叠 5 层。"},

	# ---- 工具 ----
	"torch": {"name": "火把", "size": Vector2i(1, 1), "value": 22, "color": Color("d39a52"), "cat": "tool", "desc": "夜里搜索不再摸黑，敌人也更早发现你。"},
	"lockpick": {"name": "开锁针", "size": Vector2i(1, 1), "value": 26, "color": Color("b9b1a0"), "cat": "tool", "desc": "能打开一次上锁的容器。"},
	"snare": {"name": "捕兽夹", "size": Vector2i(1, 1), "value": 28, "color": Color("8f7a5e"), "cat": "tool", "desc": "战斗中使用，造成 40 伤害并让敌人停顿。"},
	"alchemist_flare": {"name": "炼金焰筒", "size": Vector2i(1, 1), "value": 30, "color": Color("d76b5f"), "cat": "tool", "desc": "战斗中使用，必定脱离战斗。"},
	"smoke_pouch": {"name": "烟囊", "size": Vector2i(1, 1), "value": 32, "color": Color("9a9a9a"), "cat": "tool", "desc": "战斗中使用，降低敌人下一次攻击的伤害。"},
	"armor_kit": {"name": "修甲工具", "size": Vector2i(1, 1), "value": 34, "color": Color("a6a08e"), "cat": "tool", "desc": "使用后恢复 20 生命并提高 1 点防御。"},
	"lead_shot": {"name": "铅弹", "size": Vector2i(1, 1), "value": 20, "color": Color("c4ad82"), "cat": "tool", "desc": "手铳与弩用的铅弹；也可以直接卖掉。"},
	"spirit_horn": {"name": "通灵骨笛", "size": Vector2i(1, 1), "value": 44, "color": Color("8d9a9d"), "cat": "tool", "desc": "吹响后能听见远处的动静：揭示所有地区，下一次换区不会遇袭。"},
	"pack_straps": {"name": "行囊背带", "size": Vector2i(1, 1), "value": 40, "color": Color("b2a084"), "cat": "tool", "desc": "使用后背包容量 +4 格。"},
	"plague_mask": {"name": "瘟疫面具", "size": Vector2i(1, 1), "value": 12, "color": Color("c8c3b7"), "cat": "tool", "desc": "遮住口鼻，减少毒气与陷阱带来的伤害。"},
	"key": {"name": "铁钥匙", "size": Vector2i(1, 1), "value": 18, "color": Color("c0b28d"), "cat": "tool", "desc": "可以打开一次上锁的容器。"},
	"blood_sigil": {"name": "血契石", "size": Vector2i(1, 1), "value": 0, "color": Color("c95666"), "cat": "tool", "desc": "刻满凹槽的黑石。带着它才能走进血月祭坛。"},
	"hunt_bait": {"name": "血饵", "size": Vector2i(1, 1), "value": 10, "color": Color("b39a6d"), "cat": "tool", "desc": "抹了血的饵料，能引开当前地区的敌人。"},
	"charcoal_filter": {"name": "炭滤器", "size": Vector2i(1, 1), "value": 24, "color": Color("9fb1a6"), "cat": "tool", "desc": "持有后每份污水可多滤出一份净水。"},
}

## 武器数值。`rate` 是攻击间隔（秒），`damage` 是加在角色基础攻击上的固定值。
const WEAPONS := {
	"fist": {"name": "空手", "damage": 0.0, "rate": 0.9, "reach": 0.0},
	"stone_axe": {"name": "燧石斧", "damage": 9.0, "rate": 0.95, "reach": 0.0},
	"spear": {"name": "长矛", "damage": 11.0, "rate": 1.05, "reach": 0.0},
	"spiked_club": {"name": "钉头棒", "damage": 13.0, "rate": 1.1, "reach": 0.0},
	"iron_mace": {"name": "铁头槌", "damage": 12.0, "rate": 0.9, "reach": 0.0},
	"machete": {"name": "砍刀", "damage": 16.0, "rate": 0.85, "reach": 0.0},
	"crossbow": {"name": "十字弩", "damage": 20.0, "rate": 1.4, "reach": 0.0},
	"hand_cannon": {"name": "手铳", "damage": 24.0, "rate": 1.5, "reach": 0.0},
	"heavy_axe": {"name": "战斧", "damage": 22.0, "rate": 1.35, "reach": 0.0},
	"iron_maul": {"name": "铁槌", "damage": 18.0, "rate": 1.15, "reach": 0.0},
}

## 防具数值：`defense` 是减伤比例，`hp` 是额外生命。
const ARMORS := {
	"cloth_armor": {"name": "衬垫甲", "defense": 0.04, "hp": 8.0},
	"leather_armor": {"name": "皮胸甲", "defense": 0.08, "hp": 14.0},
	"ring_mail": {"name": "环甲", "defense": 0.13, "hp": 22.0},
	"hunter_cloak": {"name": "猎人斗篷", "defense": 0.06, "hp": 10.0},
}

## 36 条配方。`inputs` 的键是物品 kind；`out` 是产物 kind 与数量。
## `time` 是合成耗时（秒）——首版只做提示，不阻塞时间。
const RECIPES := [
	# 恢复 9
	{"id": "bandage", "cat": "recovery", "out": "bandage", "count": 1, "inputs": {"cloth": 2}},
	{"id": "mead", "cat": "recovery", "out": "mead", "count": 1, "inputs": {"honey": 1, "clean_water": 1}},
	{"id": "herbal_tea", "cat": "recovery", "out": "herbal_tea", "count": 1, "inputs": {"wild_herb": 1, "clean_water": 1}},
	{"id": "poppy_syrup", "cat": "recovery", "out": "poppy_syrup", "count": 1, "inputs": {"wild_herb": 2, "cloth": 1}},
	{"id": "blood_draught", "cat": "recovery", "out": "blood_draught", "count": 1, "inputs": {"honey": 1, "wild_herb": 1, "clean_water": 1}},
	{"id": "salve", "cat": "recovery", "out": "salve", "count": 1, "inputs": {"wild_herb": 1, "oil": 1}},
	{"id": "clean_water", "cat": "recovery", "out": "clean_water", "count": 1, "inputs": {"dirty_water": 1, "cloth": 1, "stone": 1}},
	{"id": "herbal_bandage", "cat": "recovery", "out": "herbal_bandage", "count": 1, "inputs": {"bandage": 1, "wild_herb": 1}},
	{"id": "frenzy_phial", "cat": "recovery", "out": "frenzy_phial", "count": 1, "inputs": {"honey": 1, "wild_herb": 2, "clean_water": 1}},
	# 武器 9
	{"id": "stone_axe", "cat": "weapon", "out": "stone_axe", "count": 1, "inputs": {"branch": 1, "stone": 1, "rope": 1}},
	{"id": "spear", "cat": "weapon", "out": "spear", "count": 1, "inputs": {"branch": 2, "stone": 1}},
	{"id": "spiked_club", "cat": "weapon", "out": "spiked_club", "count": 1, "inputs": {"branch": 1, "nail": 3}},
	{"id": "iron_mace", "cat": "weapon", "out": "iron_mace", "count": 1, "inputs": {"iron": 1, "resin": 1}},
	{"id": "machete", "cat": "weapon", "out": "machete", "count": 1, "inputs": {"iron": 1, "leather": 1}},
	{"id": "crossbow", "cat": "weapon", "out": "crossbow", "count": 1, "inputs": {"branch": 2, "rope": 1, "iron": 1}},
	{"id": "hand_cannon", "cat": "weapon", "out": "hand_cannon", "count": 1, "inputs": {"iron": 2, "brimstone": 1, "resin": 1}},
	{"id": "heavy_axe", "cat": "weapon", "out": "heavy_axe", "count": 1, "inputs": {"stone_axe": 1, "iron": 1, "rope": 1}},
	{"id": "iron_maul", "cat": "weapon", "out": "iron_maul", "count": 1, "inputs": {"spiked_club": 1, "iron": 1, "resin": 1}},
	# 防具 5
	{"id": "cloth_armor", "cat": "armor", "out": "cloth_armor", "count": 1, "inputs": {"cloth": 3, "rope": 1}},
	{"id": "leather_armor", "cat": "armor", "out": "leather_armor", "count": 1, "inputs": {"leather": 3, "rope": 1}},
	{"id": "ring_mail", "cat": "armor", "out": "ring_mail", "count": 1, "inputs": {"iron": 2, "leather": 1}},
	{"id": "hunter_cloak", "cat": "armor", "out": "hunter_cloak", "count": 1, "inputs": {"leather": 2, "cloth": 1, "rope": 1}},
	{"id": "armor_patch", "cat": "armor", "out": "armor_patch", "count": 1, "inputs": {"leather": 1, "resin": 1}},
	# 工具 13
	{"id": "torch", "cat": "tool", "out": "torch", "count": 1, "inputs": {"branch": 1, "cloth": 1, "oil": 1}},
	{"id": "lockpick", "cat": "tool", "out": "lockpick", "count": 1, "inputs": {"iron": 1, "nail": 1}},
	{"id": "snare", "cat": "tool", "out": "snare", "count": 1, "inputs": {"branch": 1, "rope": 1, "iron": 1}},
	{"id": "alchemist_flare", "cat": "tool", "out": "alchemist_flare", "count": 1, "inputs": {"paper": 1, "brimstone": 1}},
	{"id": "smoke_pouch", "cat": "tool", "out": "smoke_pouch", "count": 1, "inputs": {"paper": 1, "wild_herb": 1, "oil": 1}},
	{"id": "armor_kit", "cat": "tool", "out": "armor_kit", "count": 1, "inputs": {"iron": 1, "resin": 1}},
	{"id": "lead_shot", "cat": "tool", "out": "lead_shot", "count": 3, "inputs": {"iron": 1, "brimstone": 1}},
	{"id": "spirit_horn", "cat": "tool", "out": "spirit_horn", "count": 1, "inputs": {"storm_phial": 1, "iron": 1, "resin": 1}},
	{"id": "pack_straps", "cat": "tool", "out": "pack_straps", "count": 1, "inputs": {"cloth": 2, "rope": 1}},
	{"id": "plague_mask", "cat": "tool", "out": "plague_mask", "count": 1, "inputs": {"cloth": 1, "wild_herb": 1}},
	{"id": "key", "cat": "tool", "out": "key", "count": 1, "inputs": {"iron": 1, "nail": 1}},
	{"id": "hunt_bait", "cat": "tool", "out": "hunt_bait", "count": 1, "inputs": {"wild_herb": 1, "clean_water": 1}},
	{"id": "charcoal_filter", "cat": "tool", "out": "charcoal_filter", "count": 1, "inputs": {"cloth": 1, "stone": 1}},
]

const RECIPE_CATEGORIES := [
	{"id": "all", "name": "全部"},
	{"id": "recovery", "name": "恢复"},
	{"id": "weapon", "name": "武器"},
	{"id": "armor", "name": "防具"},
	{"id": "tool", "name": "工具"},
]

## 敌人。`art` 指向 assets/enemies/ 里的立绘；`loot` 与搜索表同格式。
const ENEMIES := {
	"scavenger": {"name": "拾荒者", "hp": 52.0, "damage": 7.0, "interval": 1.7, "aggression": 0.8, "art": "banished-knight.png",
		"desc": "裹着破布的人形，手里拎着半截铁管。", "loot": {"cloth": 2, "nail": 2, "resin": 1}},
	"hound": {"name": "猎犬", "hp": 38.0, "damage": 6.0, "interval": 1.15, "aggression": 1.3, "art": "crystal-hare.png",
		"desc": "肋骨外翻的猎犬，喉咙里没有声音。", "loot": {"leather": 2, "wild_herb": 1}},
	"guard": {"name": "守卫", "hp": 92.0, "damage": 12.0, "interval": 2.0, "aggression": 1.0, "art": "lantern-executioner.png",
		"desc": "还穿着旧制服的守卫，眼里只剩一盏灯。", "loot": {"iron": 2, "storm_phial": 1, "brimstone": 1}},
	"nightmare": {"name": "夜魇", "hp": 130.0, "damage": 18.0, "interval": 2.2, "aggression": 0.6, "art": "drowned-bell-wraith.png",
		"desc": "只在夜里出现的影子，靠近时连呼吸都会结冰。", "loot": {"crystal": 2, "charm": 1, "relic": 1}},
	"apostle": {"name": "血月使徒", "hp": 420.0, "damage": 26.0, "interval": 2.4, "aggression": 1.5, "art": "blood-coffin-warden.png",
		"desc": "祭坛尽头的最后一位守夜人，披着整片红月。", "boss": true,
		"loot": {"crystal": 4, "relic": 3, "charm": 2, "brimstone": 3}},
}

## 一次性互动点：每个地区 2 个。`kind` 决定效果，`requires` 是前置条件，
## `at` 是 0..1 的归一化画面坐标（与热点同一套场景矩形）。
## 只在本局生效，用 `sites_done` 记录，换日不重置（一次性 = 一局一次）。
const SITES := {
	"old_town": [
		{"id": "shrine", "name": "街角神龛", "kind": "shrine", "at": Vector2(0.12, 0.44),
			"desc": "一尊被雨水泡烂的木像，前面还摆着发黑的面包。"},
		{"id": "sinkhole", "name": "塌陷路面", "kind": "trap", "at": Vector2(0.58, 0.78),
			"desc": "石板下面空了，踩上去会整块翻下去。"},
	],
	"black_pines": [
		{"id": "hunter", "name": "猎人尸体", "kind": "corpse", "at": Vector2(0.34, 0.66),
			"desc": "挂在树根上的猎人，背包还扣在腰间。"},
		{"id": "wish_well", "name": "林间许愿井", "kind": "well", "at": Vector2(0.62, 0.72),
			"desc": "井口结着白霜，往里面扔东西会听见很远的回声。"},
	],
	"hospital": [
		{"id": "medicine_cabinet", "name": "上锁的药柜", "kind": "cache", "requires": ["key", "lockpick"],
			"at": Vector2(0.30, 0.60), "desc": "柜门被铁链缠了三圈，锁眼里塞着蜡。"},
		{"id": "gas_hall", "name": "毒气走廊", "kind": "trap", "at": Vector2(0.78, 0.66), "mask_saves": true,
			"desc": "走廊里的雾是绿的，灯罩上结了一层结晶。"},
	],
	"docks": [
		{"id": "sailor", "name": "溺亡水手", "kind": "corpse", "at": Vector2(0.44, 0.70),
			"desc": "半个身子泡在水里，手里还攥着绳头。"},
		{"id": "hold_cache", "name": "船坞暗格", "kind": "cache", "requires": ["key", "lockpick"],
			"at": Vector2(0.74, 0.56), "desc": "地板上有一圈被反复撬开的划痕。"},
	],
	"institute": [
		{"id": "lab_cache", "name": "实验台暗格", "kind": "cache", "requires": ["key", "lockpick"],
			"at": Vector2(0.26, 0.58), "desc": "台面下有一层不该存在的夹层。"},
		{"id": "burst_pipe", "name": "破损管道", "kind": "trap", "at": Vector2(0.70, 0.74), "mask_saves": true,
			"desc": "管道里还在往外渗冷雾，金属上全是霜。"},
	],
	"catacombs": [
		{"id": "blood_sigil", "name": "血契石", "kind": "sigil", "at": Vector2(0.36, 0.62),
			"desc": "一块刻满凹槽的黑石，槽里是干涸的血。"},
		{"id": "nameless_stone", "name": "无字碑", "kind": "shrine", "at": Vector2(0.72, 0.68),
			"desc": "碑面被磨得发亮，一个字也没有。"},
	],
	"bell_square": [
		{"id": "dry_well", "name": "干涸许愿井", "kind": "well", "at": Vector2(0.36, 0.62),
			"desc": "井底铺满了硬币和骨头。"},
		{"id": "tower_shrine", "name": "钟楼神龛", "kind": "shrine", "at": Vector2(0.66, 0.54),
			"desc": "钟绳垂在神龛前，绳结里夹着头发。"},
	],
	"altar": [
		{"id": "blood_pool", "name": "血池祭坛", "kind": "blood", "at": Vector2(0.42, 0.64),
			"desc": "池子里的血还在缓慢转动，等着有人伸手。"},
		{"id": "offering", "name": "献祭者遗骸", "kind": "corpse", "at": Vector2(0.62, 0.70),
			"desc": "被摆成跪姿的遗骸，胸口插着一把没有柄的刀。"},
	],
}

## 立绘合成：三位基础角色有 body + face 差分；隐藏角色用整张 portrait-3.png。
## face_rect 与 assets/story/portraits/manifest.json 同源，改图时两边一起改。
const PORTRAITS := {
	0: {"key": "feiyue", "body": "res://assets/story/portraits/feiyue/body-regular.png",
		"face": "res://assets/story/portraits/feiyue/face-%s.png", "face_rect": Rect2(850, 500, 450, 335),
		"expressions": ["neutral", "smile", "joy", "shy", "worried", "sad", "angry", "surprised", "tired"]},
	1: {"key": "xueli", "body": "res://assets/story/portraits/xueli/body-regular.png",
		"face": "res://assets/story/portraits/xueli/face-%s.png", "face_rect": Rect2(915, 405, 405, 280),
		"expressions": ["neutral", "smile", "joy", "shy", "worried", "sad", "angry", "surprised", "tired"]},
	2: {"key": "yayu", "body": "res://assets/story/portraits/yayu/body-regular.png",
		"face": "res://assets/story/portraits/yayu/face-%s.png", "face_rect": Rect2(940, 405, 345, 270),
		"expressions": ["neutral", "smile", "joy", "shy", "worried", "sad", "angry", "surprised", "tired"]},
	3: {"key": "muyu", "body": "res://assets/hunt/portraits/portrait_neutral_alpha.png", "face": "", "face_rect": Rect2(),
		"expressions": ["neutral", "joy", "sad", "angry", "afraid", "pain", "smirk", "tired"]},
}

static func phase_at(clock: float) -> Dictionary:
	var ratio := clampf(clock / DAY_SECONDS, 0.0, 0.9999)
	for phase in PHASES:
		if ratio >= float(phase.from) and ratio < float(phase.to):
			return phase
	return PHASES[PHASES.size() - 1]

static func area(id: String) -> Dictionary:
	return AREAS.get(id, {})

static func area_name(id: String) -> String:
	var a: Dictionary = area(id)
	return str(a.get("name", id))

static func item(kind: String) -> Dictionary:
	if ITEMS.has(kind):
		return ITEMS[kind]
	return Catalog.ITEMS.get(kind, {})

static func item_name(kind: String) -> String:
	var entry: Dictionary = item(kind)
	return str(entry.get("name", kind))

static func recipe(id: String) -> Dictionary:
	for entry in RECIPES:
		if str(entry.id) == id:
			return entry
	return {}

static func recipes_for(cat: String) -> Array:
	if cat == "" or cat == "all":
		return RECIPES.duplicate()
	var out: Array = []
	for entry in RECIPES:
		if str(entry.cat) == cat:
			out.append(entry)
	return out

static func weapon(kind: String) -> Dictionary:
	return WEAPONS.get(kind, WEAPONS["fist"])

static func armor(kind: String) -> Dictionary:
	return ARMORS.get(kind, {})

static func sites_for(area: String) -> Array:
	return SITES.get(area, [])

static func site(area: String, id: String) -> Dictionary:
	for entry in SITES.get(area, []):
		if str(entry.get("id", "")) == id:
			return entry
	return {}

static func enemy(kind: String) -> Dictionary:
	return ENEMIES.get(kind, {})

static func enemy_art(kind: String) -> String:
	return "res://assets/enemies/" + str(enemy(kind).get("art", "banished-knight.png"))

static func is_weapon(kind: String) -> bool:
	return WEAPONS.has(kind) and kind != "fist"

static func is_armor(kind: String) -> bool:
	return ARMORS.has(kind)
