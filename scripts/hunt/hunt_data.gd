extends RefCounted
## 血潮深潜 · 静态内容表
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
## `cat` 只给深潜合成界面分类用。
const ITEMS := {
	# ---- 材料 ----
	"branch": {"name": "树枝", "size": Vector2i(1, 1), "value": 3, "color": Color("8d6f4d"), "cat": "material", "desc": "干燥的硬枝，能做柄也能当柴。"},
	"stone": {"name": "石块", "size": Vector2i(1, 1), "value": 4, "color": Color("8b8a84"), "cat": "material", "desc": "边缘锋利的碎石，血潮漫过的地方最不缺这种东西。"},
	"cloth": {"name": "碎布", "size": Vector2i(1, 1), "value": 5, "color": Color("b9ad9b"), "cat": "material", "desc": "从旧衣和窗帘上撕下来的布条。"},
	"dirty_water": {"name": "污水", "size": Vector2i(1, 1), "value": 2, "color": Color("6f8077"), "cat": "material", "desc": "混着泥沙的脏水，滤过之后还能用。"},
	"clean_water": {"name": "净水", "size": Vector2i(1, 1), "value": 8, "color": Color("9fd1d2"), "cat": "material", "desc": "滤掉泥沙的清水，能直接喝。"},
	"honey": {"name": "蜂蜜", "size": Vector2i(1, 1), "value": 12, "color": Color("d5a33f"), "cat": "material", "desc": "从废弃蜂箱里刮下来的浓稠蜂蜜。"},
	"wild_herb": {"name": "野草", "size": Vector2i(1, 1), "value": 7, "color": Color("7da77b"), "cat": "material", "desc": "气味苦涩的草药，能止血也能提神。"},
	"iron": {"name": "铁片", "size": Vector2i(1, 1), "value": 14, "color": Color("9da6b2"), "cat": "material", "desc": "从旧铁器上敲下来的铁片，边缘还带着锈。"},
	"nail": {"name": "钉子", "size": Vector2i(1, 1), "value": 6, "color": Color("b7b3a8"), "cat": "material", "desc": "生锈但还算直的铁钉。"},
	"leather": {"name": "兽皮", "size": Vector2i(1, 1), "value": 16, "color": Color("9a6f52"), "cat": "material", "desc": "从血潮野兽身上剥下的皮，还带着腥气。"},
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

static func enemy(kind: String) -> Dictionary:
	return ENEMIES.get(kind, {})

static func enemy_art(kind: String) -> String:
	return "res://assets/enemies/" + str(enemy(kind).get("art", "banished-knight.png"))

static func is_weapon(kind: String) -> bool:
	return WEAPONS.has(kind) and kind != "fist"

static func is_armor(kind: String) -> bool:
	return ARMORS.has(kind)

## ---------------------------------------------------------------- 随机事件
##
## 事件表（2026-10-20 起取代旧的固定 SITES）。规则：
## * 事件标题与描述在对局里是**黑箱**，只有点开才揭示；地图上只显示问号圆环。
## * 每天每区随机抽 2~3 个，特殊事件按地区/天数/时段额外出现；同一局同一天
##   用过的事件不再刷新（`events_used`）。
## * 事件不是一次结算，而是一串 `steps`：调查、撬锁、拆解、下井……每一步花
##   `time` 秒**局内时间**（窗口暂停时也照走），失败可能受伤、惊动怪物。
## * `live: true` 的事件全程不暂停——在你读文本、做选择的时候，猎人也在被靠近。
## * 奖励分白/绿/蓝三档（`tier` 0..2），出现在过程里和结局里。
## * 需要道具的分支**不会直说**要什么，只给模糊暗示（`items` 只在点下去失败时
##   用一句人话回应），让玩家自己联想世界观与用途。
const EVENT_LOOT := {
	"common": {"branch": 4, "stone": 4, "cloth": 4, "paper": 4, "nail": 3, "glass": 3, "dirty_water": 2},
	"salvage": {"iron": 4, "rope": 3, "resin": 2, "oil": 2, "leather": 2, "nail": 2},
	"medicine": {"wild_herb": 4, "bandage": 2, "herbal_bandage": 2, "salve": 1, "poppy_syrup": 1, "clean_water": 2},
	"provisions": {"honey": 3, "clean_water": 3, "mead": 2, "herbal_tea": 2, "herbal_bandage": 1},
	"valuables": {"crystal": 3, "relic": 3, "charm": 2, "glass": 2, "paper": 2},
	"tools": {"lockpick": 2, "key": 2, "torch": 1, "lead_shot": 3, "plague_mask": 1, "snare": 1, "armor_kit": 1},
	"alchemy": {"storm_phial": 3, "brimstone": 2, "glass": 2, "oil": 2, "paper": 2},
	"arsenal": {"machete": 2, "crossbow": 1, "hand_cannon": 1, "ring_mail": 1, "iron_maul": 1, "heavy_axe": 1},
}

## 事件生成点：每区 5 个画面锚点（0..1，避开左下立绘与底部操作栏）。
const EVENT_SPAWNS := {
	"old_town": [Vector2(0.10, 0.46), Vector2(0.30, 0.62), Vector2(0.52, 0.50), Vector2(0.70, 0.66), Vector2(0.86, 0.48)],
	"black_pines": [Vector2(0.14, 0.52), Vector2(0.32, 0.66), Vector2(0.50, 0.48), Vector2(0.70, 0.68), Vector2(0.84, 0.54)],
	"hospital": [Vector2(0.12, 0.50), Vector2(0.30, 0.64), Vector2(0.50, 0.46), Vector2(0.68, 0.66), Vector2(0.84, 0.50)],
	"docks": [Vector2(0.12, 0.54), Vector2(0.30, 0.46), Vector2(0.48, 0.64), Vector2(0.68, 0.50), Vector2(0.84, 0.66)],
	"institute": [Vector2(0.12, 0.48), Vector2(0.30, 0.62), Vector2(0.50, 0.44), Vector2(0.68, 0.64), Vector2(0.84, 0.50)],
	"catacombs": [Vector2(0.12, 0.52), Vector2(0.30, 0.64), Vector2(0.48, 0.46), Vector2(0.66, 0.66), Vector2(0.84, 0.52)],
	"bell_square": [Vector2(0.14, 0.48), Vector2(0.32, 0.62), Vector2(0.50, 0.44), Vector2(0.68, 0.66), Vector2(0.86, 0.52)],
	"altar": [Vector2(0.16, 0.52), Vector2(0.34, 0.64), Vector2(0.50, 0.46), Vector2(0.66, 0.64), Vector2(0.82, 0.50)],
}

const EVENTS := {
	# ---------------------------------------------------------------- 旧城
	"torn_poster": {
		"name": "撕剩半张的告示", "art": "ledger", "areas": ["old_town"], "weight": 5, "min_day": 1,
		"reveal": "浆糊还是湿的，告示却已经褪成了尸皮的颜色。",
		"steps": {
			"start": {
				"text": "有人把这张告示贴了又撕，撕掉的部分正好是落款。你能看清的只剩几行字：『……第三夜之后，不要应门。』",
				"options": [
					{"label": "把剩下的半张揭下来", "time": 4, "next": "peel"},
					{"label": "对着灯看纸背的压痕", "time": 7, "next": "trace"},
					{"label": "算了", "next": ""},
				],
			},
			"peel": {
				"text": "纸一揭就碎。碎片里掉出一小截干枯的指节，缠着写字的线。",
				"reward": {"table": "common", "tier": 0, "rolls": [1, 2]},
				"options": [
					{"label": "把线抽出来", "time": 5, "next": "thread"},
					{"label": "走开", "next": ""},
				],
			},
			"thread": {
				"text": "线在指节上绕了十七圈，正好是这条街的门牌数。线头是新的。",
				"reward": {"table": "tools", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "收好", "next": ""}],
			},
			"trace": {
				"text": "纸背的压痕是一枚印：一只闭着的眼睛。印泥不是红的，是锈的。",
				"reward": {"table": "common", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "再看一眼", "time": 4, "next": "eye"}],
			},
			"eye": {
				"text": "你数了数印上的睫毛。十七根。和那根线上的圈数一样。",
				"reward": {"table": "valuables", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "离开", "next": ""}],
			},
		},
	},
	"cellar_door": {
		"name": "地窖铁门", "art": "reliquary", "areas": ["old_town"], "weight": 4, "min_day": 1,
		"reveal": "门缝里往外渗凉气，铁锈味里混着一点甜。",
		"steps": {
			"start": {
				"text": "铁门被从里面闩住了，闩槽里塞着一团发硬的布。门上没有锁孔，只有一个巴掌大的凹槽。",
				"options": [
					{"label": "摸摸那个凹槽", "time": 4, "next": "shape"},
					{"label": "用肩膀撞门", "time": 8, "hp": -6, "noise": 0.5,
						"check": {"chance": 0.35, "success": "open", "fail": "bruised"}},
					{"label": "蹲下看门缝", "time": 6, "next": "seam"},
					{"label": "离开", "next": ""},
				],
			},
			"shape": {
				"text": "凹槽的形状像一枚扁平的钥匙，也像谁把掌心按进铁里留下的印。边缘有反复摩擦的亮痕。",
				"options": [
					{"label": "找件薄而硬的东西塞进去", "time": 10, "items": ["iron", "nail"],
						"check": {"chance": 0.70, "success": "open", "fail": "stuck"}},
					{"label": "把手指按进去", "time": 3, "hp": -3, "next": "warm"},
					{"label": "退开", "next": ""},
				],
			},
			"warm": {
				"text": "凹槽是温的。你的指印留在铁上，比别人的小一圈。门后有人把闩拉开了一半。",
				"options": [
					{"label": "推门", "time": 4, "next": "open"},
					{"label": "抽手走开", "next": ""},
				],
			},
			"seam": {
				"text": "门缝里能看到一只倒扣的木桶，桶上坐着一双没有脚的靴子。靴尖朝着门。",
				"hp": -4,
				"options": [
					{"label": "再看一眼", "time": 3, "hp": -5, "next": "boots"},
					{"label": "退开", "next": ""},
				],
			},
			"boots": {
				"text": "靴子不见了。门里的潮气忽然变得很暖，像有人贴着门板在呼吸。",
				"options": [{"label": "立刻离开", "next": ""}],
			},
			"bruised": {
				"text": "门纹丝不动。你的肩膀麻了半天，门后的东西倒是安静了下来。",
				"options": [{"label": "换个法子", "next": "shape"}, {"label": "离开", "next": ""}],
			},
			"stuck": {
				"text": "铁片卡死在凹槽里，抽不出来。门后的黑暗往门缝这边靠了靠。",
				"options": [{"label": "松手", "next": ""}],
			},
			"open": {
				"text": "门后是地窖。潮湿的台阶下堆着旧坛子，坛口蒙着写字的布。",
				"reward": {"table": "salvage", "tier": 1, "rolls": [1, 2]},
				"options": [
					{"label": "下去翻坛子", "time": 8, "next": "jars"},
					{"label": "只拿走门口的东西", "next": ""},
				],
			},
			"jars": {
				"text": "最里面那只坛子装着油布包。包得很仔细——仔细得像不想让人找到，也不想让它出来。",
				"reward": {"table": "tools", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "收好，上台阶", "next": ""}],
			},
		},
	},
	"collapsed_wall": {
		"name": "塌墙下的轮廓", "art": "cage", "areas": ["old_town"], "weight": 4, "min_day": 2,
		"reveal": "砖缝里卡着一截布角，风向不对。",
		"steps": {
			"start": {
				"text": "半面墙塌在巷口，碎砖下压着某个轮廓。你踢松一块砖，下面的东西没有动。",
				"options": [
					{"label": "用手扒开碎砖", "time": 14, "hp": -5, "stamina": -8, "next": "dig"},
					{"label": "找根结实的棍子撬", "time": 9, "items": ["branch", "iron"], "next": "lever"},
					{"label": "走开", "next": ""},
				],
			},
			"dig": {
				"text": "砖下是个被压扁的行囊。你的指甲缝里全是灰，灰里有细小的白点。",
				"reward": {"table": "salvage", "tier": 1, "rolls": [1, 2]},
				"options": [
					{"label": "继续往下挖", "time": 8, "hp": -4, "next": "deeper"},
					{"label": "停手", "next": ""},
				],
			},
			"lever": {
				"text": "砖块翻下去，行囊的皮带被撬断了。里面的东西比你想的整齐。",
				"reward": {"table": "salvage", "tier": 2, "rolls": [1, 2]},
				"options": [
					{"label": "检查内衬的夹层", "time": 7, "next": "hidden"},
					{"label": "收手", "next": ""},
				],
			},
			"deeper": {
				"text": "再往下是空的。砖下的洞刚好容得下一个人蜷着，洞壁上有抓痕——从里面抓的。",
				"reward": {"table": "valuables", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "爬出来", "next": ""}],
			},
			"hidden": {
				"text": "夹层里是一张折了四折的名单，名字被划掉，最后一个名字的墨还没干。你的名字不在上面——至少现在不在。",
				"reward": {"table": "tools", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "折好收起来", "next": ""}],
			},
		},
	},
	"watchman_booth": {
		"name": "值夜人的岗亭", "art": "music_box", "areas": ["old_town"], "weight": 4, "min_day": 1,
		"reveal": "岗亭的窗玻璃从里面糊了纸，纸上有指头戳的洞。",
		"steps": {
			"start": {
				"text": "岗亭里挂着一件还在轻轻晃的外套。桌上的灯是灭的，灯芯却烧到了根。",
				"options": [
					{"label": "翻桌上的抽屉", "time": 8, "next": "drawer"},
					{"label": "按一下值夜的铃", "time": 4, "noise": 0.7, "next": "bell"},
					{"label": "看外套的口袋", "time": 6, "next": "coat"},
				],
			},
			"drawer": {
				"text": "抽屉里是半盒火柴、一枚磨平了字的徽章，还有一小卷没写完的值班记录。最后一行写着：『今晚不用换班。』",
				"reward": {"table": "tools", "tier": 1, "rolls": [1, 1]},
				"options": [
					{"label": "往前翻记录", "time": 6, "next": "log"},
					{"label": "收好", "next": ""},
				],
			},
			"log": {
				"text": "每一页的签名都是同一个人的笔迹，日期却隔了四十年。最后一页的墨迹被水洇开，像有人哭过。",
				"reward": {"table": "common", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "合上记录", "next": ""}],
			},
			"bell": {
				"text": "铃声只响了一声，余音却拖得很长。街对面的窗后有人影动了一下，又不动了。",
				"options": [
					{"label": "再按一次", "time": 3, "hp": -6, "next": "bell2"},
					{"label": "离开", "next": ""},
				],
			},
			"bell2": {
				"text": "第二声没有人听见——包括你。你的耳朵里只剩下自己的心跳。",
				"options": [{"label": "走开", "next": ""}],
			},
			"coat": {
				"text": "外套的内袋里有一块硬糖，糖纸是新的。外套是干的，外面的雨已经下了三天。",
				"reward": {"table": "salvage", "tier": 0, "rolls": [1, 1]},
				"options": [{"label": "把糖放回去", "next": ""}],
			},
		},
	},

	# ---------------------------------------------------------------- 黑松林
	"hanging_bundle": {
		"name": "树上挂的布包", "art": "surgery", "areas": ["black_pines"], "weight": 5, "min_day": 1,
		"reveal": "布包挂在高处，绳子是新的，树是旧的。",
		"steps": {
			"start": {
				"text": "布包被绳子吊在一根横枝上，离地两丈。风一吹，包里的东西就轻轻碰一下，像在数数。",
				"options": [
					{"label": "顺着树皮爬上去", "time": 14, "stamina": -10,
						"check": {"chance": 0.65, "success": "reach", "fail": "fall"}},
					{"label": "用长东西把它够下来", "time": 9, "items": ["branch", "rope"], "next": "hook"},
					{"label": "离开", "next": ""},
				],
			},
			"reach": {
				"text": "你够到布包的一角。包比看上去重，里面像装着一只蜷起来的小动物。",
				"reward": {"table": "provisions", "tier": 1, "rolls": [1, 2]},
				"options": [
					{"label": "解开绳结", "time": 6, "next": "knot"},
					{"label": "拿着就下树", "next": ""},
				],
			},
			"hook": {
				"text": "布包掉下来，闷响里夹着一声细小的、像叹息的动静。",
				"reward": {"table": "medicine", "tier": 1, "rolls": [1, 2]},
				"options": [
					{"label": "摊开布包", "time": 5, "next": "knot"},
					{"label": "踢到一边", "next": ""},
				],
			},
			"knot": {
				"text": "布包里是几味晒干的草、一小罐蜂蜜，和一枚被磨得发亮的乳牙。布的内侧用炭笔写着一行小字：『囡囡别怕。』",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "把乳牙放回去", "next": ""}],
			},
			"fall": {
				"text": "树皮在你手里碎成粉。你摔在湿松针上，半天没听见自己的呼吸。",
				"options": [{"label": "爬起来", "next": ""}],
			},
		},
	},
	"snare_line": {
		"name": "一串捕兽夹", "art": "cage", "areas": ["black_pines"], "weight": 4, "min_day": 1,
		"reveal": "铁齿上还挂着几缕毛，毛是灰白的。",
		"steps": {
			"start": {
				"text": "六只捕兽夹串在一根麻绳上，从树根一直排到灌木里。其中三只已经合上了，齿间夹着不是野兽的东西。",
				"options": [
					{"label": "用树枝一只只压住", "time": 12, "items": ["branch"], "next": "disarm"},
					{"label": "蹲下来用手拆", "time": 12,
						"check": {"chance": 0.55, "success": "disarm", "fail": "snap"}},
					{"label": "绕开", "next": ""},
				],
			},
			"disarm": {
				"text": "夹子一个一个松开。最后一只的弹簧里卡着一小卷油纸，油纸包着铁钉和一段铜丝。",
				"reward": {"table": "salvage", "tier": 1, "rolls": [1, 2]},
				"options": [
					{"label": "顺着绳子找源头", "time": 7, "next": "source"},
					{"label": "收好铁器", "next": ""},
				],
			},
			"source": {
				"text": "绳子的另一头系在一棵刻了记号的松树上。记号是新的，刻痕里渗出的树脂还没凝固。",
				"reward": {"table": "tools", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "抹掉记号", "next": ""}],
			},
			"snap": {
				"text": "铁齿咬进你的指根。你咬着牙把夹子掰开，血滴在松针上，很快被吸干了。",
				"hp": -12,
				"options": [{"label": "包扎一下", "next": ""}],
			},
		},
	},
	"hollow_stump": {
		"name": "空心树桩", "art": "cage", "areas": ["black_pines"], "weight": 4, "min_day": 1,
		"reveal": "树桩里面比外面暖。",
		"steps": {
			"start": {
				"text": "雷劈过的树桩裂成两半，中间是空的。你把脸凑近，能闻到蜂蜜，也能闻到别的什么。",
				"options": [
					{"label": "直接伸手进去", "time": 6,
						"check": {"chance": 0.60, "success": "reach", "fail": "bite"}},
					{"label": "先点个火照一照", "time": 5, "flags": ["torch"], "next": "lit"},
					{"label": "离开", "next": ""},
				],
			},
			"reach": {
				"text": "你的手指碰到一层温热的、会轻轻起伏的东西。它没有动，只是让开了。",
				"reward": {"table": "provisions", "tier": 1, "rolls": [1, 2]},
				"options": [
					{"label": "再往里摸", "time": 5, "next": "deep"},
					{"label": "把手抽出来", "next": ""},
				],
			},
			"lit": {
				"text": "火光里，树桩深处塞满了蜜脾和干草，干草上有一个被睡出来的凹坑，还暖着。",
				"reward": {"table": "provisions", "tier": 2, "rolls": [1, 2]},
				"options": [
					{"label": "把凹坑里的东西拿出来", "time": 6, "next": "deep"},
					{"label": "退开", "next": ""},
				],
			},
			"deep": {
				"text": "凹坑底下压着一枚骨哨，哨口磨得发亮。你把它放到唇边，还没有吹，远处就有什么应了一声。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "收好骨哨", "next": ""}],
			},
			"bite": {
				"text": "有什么咬住了你的指节，又立刻松开。你抽回手，指头上多了一圈很浅的牙印。",
				"hp": -5,
				"options": [{"label": "甩甩手", "next": ""}],
			},
		},
	},
	"wayside_shrine": {
		"name": "林间小龛", "art": "blood_clock", "areas": ["black_pines"], "weight": 3, "min_day": 1,
		"reveal": "龛前供着的东西还很新鲜。",
		"steps": {
			"start": {
				"text": "一座半人高的石龛立在两棵松树之间，龛里没有神像，只有一块被摸得发亮的凹石。供台上摆着半块面包和一枚铜扣。",
				"options": [
					{"label": "拿一点吃的放在供台上", "time": 5, "items": ["honey", "mead", "herbal_tea"], "next": "offer"},
					{"label": "只是低头站一会儿", "time": 8, "next": "pray"},
					{"label": "拿走供台上的铜扣", "time": 3, "next": "take"},
				],
			},
			"offer": {
				"text": "你把食物放下，凹石里的积灰忽然陷下去一小块，像有人在下面接住了。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "再放一样东西", "time": 5, "next": "offer2"}, {"label": "起身", "next": ""}],
			},
			"offer2": {
				"text": "这一次，龛后的松林里传来很轻的、咀嚼的声音。你没有回头。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 2]},
				"options": [{"label": "离开", "next": ""}],
			},
			"pray": {
				"text": "你低头的时候，听见凹石里也传来一声很轻的呼吸。它和你同步。",
				"stamina": 20,
				"options": [{"label": "睁眼", "time": 4, "next": "pray2"}],
			},
			"pray2": {
				"text": "呼吸停了。供台上的面包少了一角，铜扣还在。",
				"reward": {"table": "common", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "走开", "next": ""}],
			},
			"take": {
				"text": "铜扣很轻，扣眼却磨得很深。你把它攥在手里，手心开始发烫。",
				"hp": -6,
				"reward": {"table": "tools", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "扔掉", "next": ""}],
			},
		},
	},

	# ---------------------------------------------------------------- 医院
	"medicine_cabinet": {
		"name": "上锁药柜", "art": "reliquary", "areas": ["hospital"], "weight": 5, "min_day": 1,
		"reveal": "柜门的铁链缠了三圈，锁眼里塞着蜡。",
		"steps": {
			"start": {
				"text": "柜门打不开。铁链上落的灰比其他地方薄，锁眼里的蜡却像是刚封上的。",
				"options": [
					{"label": "先看看锁眼里的蜡", "time": 5, "next": "wax"},
					{"label": "找件能伸进锁眼的东西", "time": 12, "items": ["lockpick", "nail"],
						"check": {"chance": 0.72, "success": "open", "fail": "jammed"}},
					{"label": "用铁器砸开链条", "time": 15, "items": ["iron", "nail"], "noise": 0.6,
						"check": {"chance": 0.55, "success": "open", "fail": "noisy"}},
					{"label": "离开", "next": ""},
				],
			},
			"wax": {
				"text": "蜡是温的。蜡面上按着一个很小的指印，指印的纹路比你的细。",
				"options": [
					{"label": "把蜡抠出来", "time": 4, "next": "wax2"},
					{"label": "去找工具", "next": "start"},
				],
			},
			"wax2": {
				"text": "蜡底下不是锁孔，是一小截折断的针。针尾缠着头发。",
				"reward": {"table": "tools", "tier": 1, "rolls": [1, 1]},
				"options": [
					{"label": "用针试试", "time": 10, "check": {"chance": 0.5, "success": "open", "fail": "jammed"}},
					{"label": "退开", "next": ""},
				],
			},
			"jammed": {
				"text": "锁芯里传来一声轻响，然后彻底卡死了。柜子后面有什么东西挪动了一下。",
				"noise": 0.4,
				"options": [{"label": "放弃", "next": ""}],
			},
			"noisy": {
				"text": "链条断了，铁环砸在地砖上。走廊尽头的门开了一条缝。",
				"noise": 0.8,
				"options": [{"label": "赶紧拿东西", "time": 4, "next": "open"}],
			},
			"open": {
				"text": "柜子里排着几十个玻璃瓶，标签都被撕掉了一半。瓶里的东西颜色不一样，气味却是同一种。",
				"reward": {"table": "medicine", "tier": 2, "rolls": [1, 2]},
				"options": [
					{"label": "翻最里层", "time": 7, "next": "inner"},
					{"label": "拿两瓶就走", "next": ""},
				],
			},
			"inner": {
				"text": "最里层压着一本翻烂的册子，页脚写着『第三病栋 · 不入册』。册子夹着一张手绘的锁簧图，画得比柜子本身还仔细。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "收好", "next": ""}],
			},
		},
	},
	"stained_ledger": {
		"name": "泡烂的病历", "art": "ledger", "areas": ["hospital"], "weight": 4, "min_day": 1,
		"reveal": "纸页粘在一起，翻开时有撕肉的声音。",
		"steps": {
			"start": {
				"text": "窗台上摊着一本病历，雨从破窗打进来，只湿了下半本。上半本的字还能认出一些。",
				"options": [
					{"label": "一页一页翻开", "time": 7, "next": "read"},
					{"label": "找纸页之间的夹层", "time": 10,
						"check": {"chance": 0.6, "success": "hidden", "fail": "torn"}},
					{"label": "离开", "next": ""},
				],
			},
			"read": {
				"text": "病历上写着同一个名字，入院日期却跨越了十一年。每一页的『体温』栏都是空白，只有最后一页写着：『夜间不量。』",
				"reward": {"table": "common", "tier": 1, "rolls": [1, 2]},
				"options": [
					{"label": "翻到最后一页", "time": 5, "next": "last"},
					{"label": "合上", "next": ""},
				],
			},
			"last": {
				"text": "最后一页的背面有一行倒写的字，你把它转过来才看清：『他还在数走廊的灯。』",
				"reward": {"table": "valuables", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "把病历放回窗台", "next": ""}],
			},
			"hidden": {
				"text": "夹层里掉出一枚发黑的钥匙和一张药方。药方上的药名被划掉，改成了一句『回家』。",
				"reward": {"table": "tools", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "收好", "next": ""}],
			},
			"torn": {
				"text": "纸页在你手里碎成絮状。你只来得及看见半行字：『……不要让他听见铃——』",
				"options": [{"label": "站起来", "next": ""}],
			},
		},
	},
	"surgery_tray": {
		"name": "铺开的手术盘", "art": "surgery", "areas": ["hospital"], "weight": 4, "min_day": 1,
		"reveal": "器械摆得像还准备接着用。",
		"steps": {
			"start": {
				"text": "手术盘里的器械按大小排好，最细的那把镊子还在滴水。盘边的白布上有一圈干净的手印。",
				"options": [
					{"label": "辨认这些器械的用途", "time": 8, "next": "study"},
					{"label": "把整盘端走", "time": 5, "noise": 0.3, "next": "take"},
					{"label": "离开", "next": ""},
				],
			},
			"study": {
				"text": "大部分器械你都认得。只有一把说不清用途——它的一端是钩，另一端是极细的针，中间刻着第几根骨头的位置。",
				"reward": {"table": "medicine", "tier": 2, "rolls": [1, 1]},
				"options": [
					{"label": "拿起那把手", "time": 4, "next": "odd_tool"},
					{"label": "放下", "next": ""},
				],
			},
			"odd_tool": {
				"text": "器械很轻，轻得像空心的。你摇了摇，里面有细小的东西在滚。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "装进包里", "next": ""}],
			},
			"take": {
				"text": "盘子比看上去沉。你端起来的时候，手术台下面有什么东西跟着你的动作动了一下。",
				"hp": -3,
				"reward": {"table": "salvage", "tier": 1, "rolls": [1, 2]},
				"options": [{"label": "快步走开", "next": ""}],
			},
		},
	},
	"gas_corridor": {
		"name": "毒气走廊", "art": "surgery", "areas": ["hospital"], "weight": 3, "min_day": 1, "live": true,
		"reveal": "走廊里的雾是绿的，灯罩上结了一层结晶。",
		"steps": {
			"start": {
				"text": "绿雾贴着地面漫过来，退路就在身后。这些东西不急——它们在等你先动。",
				"options": [
					{"label": "屏住呼吸冲过去", "time": 8, "hp": -14, "next": "through"},
					{"label": "找块湿布捂住口鼻", "time": 6, "items": ["cloth", "dirty_water"], "next": "masked"},
					{"label": "贴着火把的烟走", "time": 7, "flags": ["torch"], "next": "through"},
					{"label": "慢慢退回去", "time": 4, "next": ""},
				],
			},
			"masked": {
				"text": "湿布挡得住味道，挡不住刺痛。你的眼睛流泪，脚却没有停。",
				"hp": -4,
				"options": [
					{"label": "往前摸", "time": 6, "next": "through"},
					{"label": "折返", "time": 4, "next": ""},
				],
			},
			"through": {
				"text": "走廊尽头是一间配药室，门虚掩着。你的肺还在烧，但你已经过来了。",
				"reward": {"table": "medicine", "tier": 2, "rolls": [1, 2]},
				"options": [
					{"label": "进配药室", "time": 6, "next": "pharmacy"},
					{"label": "先离开这层", "next": ""},
				],
			},
			"pharmacy": {
				"text": "配药室的柜子全是空的，只有最下面一格锁着。柜门上钉着一张便条：『不要开。开了就得多一个人。』",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "退出去", "next": ""}],
			},
		},
	},

	# ---------------------------------------------------------------- 码头
	"chained_hold": {
		"name": "货舱铁链", "art": "reliquary", "areas": ["docks"], "weight": 4, "min_day": 2,
		"reveal": "铁链的末端没入水里，水面上浮着一层油。",
		"steps": {
			"start": {
				"text": "货舱盖被铁链锁死，链子上的锁是老式的簧锁。盖缝里不断有水渗出来，水是黑的。",
				"options": [
					{"label": "把耳朵贴在盖子上", "time": 5, "next": "listen"},
					{"label": "找细长的东西拨锁", "time": 12, "items": ["lockpick", "nail"],
						"check": {"chance": 0.68, "success": "open", "fail": "slip"}},
					{"label": "拖来一段铁链砸锁", "time": 14, "items": ["iron"], "noise": 0.5,
						"check": {"chance": 0.5, "success": "open", "fail": "slip"}},
					{"label": "离开", "next": ""},
				],
			},
			"listen": {
				"text": "盖子底下有节奏地响，三下、停、两下。不是你心跳的节奏，但和你的呼吸对上了。",
				"options": [
					{"label": "回敲两下", "time": 4, "hp": -5, "next": "knock"},
					{"label": "去撬锁", "next": "start"},
				],
			},
			"knock": {
				"text": "里面的声音停了。过了很久，舱盖从里面被顶起了一寸，又落回去。",
				"noise": 0.6,
				"options": [{"label": "退后", "next": ""}],
			},
			"slip": {
				"text": "锁没开，链子却滑进了水里。水面上的油散开，露出一张朝上的脸。",
				"hp": -8,
				"options": [{"label": "退开", "next": ""}],
			},
			"open": {
				"text": "舱盖掀开，底下不是货，是一排用油布裹好的长条木箱。木箱上写着编号，编号从你的生日开始。",
				"reward": {"table": "alchemy", "tier": 2, "rolls": [1, 2]},
				"options": [
					{"label": "撬开最上面那只", "time": 9, "next": "crate"},
					{"label": "只拿散落的货物", "next": ""},
				],
			},
			"crate": {
				"text": "箱子里是一套保存得很好的工具和一小袋硫磺。箱底压着一张航海图，航线绕开了所有岛屿，终点画着一个圈。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "收好海图", "next": ""}],
			},
		},
	},
	"drowned_sailor": {
		"name": "溺亡水手", "art": "surgery", "areas": ["docks"], "weight": 4, "min_day": 2,
		"reveal": "半个身子泡在水里，手里还攥着绳头。",
		"steps": {
			"start": {
				"text": "水手的脸朝着岸，眼睛是睁着的。他的手攥得很紧，绳子的另一头系在系船柱上，绳结却在水手手里。",
				"options": [
					{"label": "翻他的口袋", "time": 6, "next": "pocket"},
					{"label": "掰开他的手", "time": 10, "stamina": -6,
						"check": {"chance": 0.62, "success": "hand", "fail": "tight"}},
					{"label": "离开", "next": ""},
				],
			},
			"pocket": {
				"text": "口袋里有一小段蜡线和一枚被海水泡胀的饼干。饼干上有一排整齐的牙印。",
				"reward": {"table": "provisions", "tier": 1, "rolls": [1, 1]},
				"options": [
					{"label": "再摸摸内衬", "time": 5, "noise": 0.3, "next": "lining"},
					{"label": "站起来", "next": ""},
				],
			},
			"lining": {
				"text": "内衬缝死了一小块硬物。你拆开线，里面是一枚铜钥匙，钥匙柄上刻着船名的一半。",
				"reward": {"table": "tools", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "收好钥匙", "next": ""}],
			},
			"hand": {
				"text": "他的手松开了。掌心是一枚被汗水泡得发黑的护身符，和一段还没来得及打完的绳结。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "把绳结打完", "time": 6, "next": "knot"}],
			},
			"knot": {
				"text": "绳结打完的瞬间，水里传来一声很长的吐气。绳头从他手里滑出去，沉了。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "离开码头", "next": ""}],
			},
			"tight": {
				"text": "他的手指像铁箍。你用力的时候，他的头慢慢转过来了一点。",
				"hp": -6,
				"options": [{"label": "松手", "next": ""}],
			},
		},
	},
	"tide_gate": {
		"name": "潮闸绞盘", "art": "astrolabe", "areas": ["docks"], "weight": 3, "min_day": 2, "live": true,
		"reveal": "绞盘还在缓慢地空转，链条上挂着湿透的布条。",
		"steps": {
			"start": {
				"text": "潮闸的绞盘卡在一半。闸板下面有水声，水声越来越近。你可以推，也可以让它自己转。",
				"options": [
					{"label": "用力把绞盘推到底", "time": 12, "stamina": -18, "next": "open"},
					{"label": "松开绞盘，让它自己落", "time": 6, "noise": 0.7, "next": "drop"},
					{"label": "退到高处看", "time": 5, "next": "watch"},
				],
			},
			"open": {
				"text": "闸板升起来，水从底下涌出，带着一股铁腥味。水面上漂着几只箱子，箱盖都朝上。",
				"reward": {"table": "salvage", "tier": 2, "rolls": [1, 2]},
				"options": [
					{"label": "捞一只箱子", "time": 8, "stamina": -8, "next": "crate"},
					{"label": "先离开水边", "next": ""},
				],
			},
			"crate": {
				"text": "箱子里塞满了湿透的布和一小罐还没进水的灯油。你抬头时，闸门已经自己降回去了。",
				"reward": {"table": "alchemy", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "上岸", "next": ""}],
			},
			"drop": {
				"text": "绞盘脱手，闸板轰然落下。水声停了，取而代之的是闸门另一侧的、很轻的敲门声。",
				"noise": 0.5,
				"options": [
					{"label": "凑近闸门听", "time": 5, "hp": -6, "next": "knock"},
					{"label": "走开", "next": ""},
				],
			},
			"knock": {
				"text": "敲门声三长两短。和刚才水手的绳结一个数。",
				"options": [{"label": "不再回应", "next": ""}],
			},
			"watch": {
				"text": "你退到高处，看着绞盘自己转完最后一圈。闸门没有开，水位却降了——像有什么在下面把水喝掉了。",
				"reward": {"table": "common", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "离开", "next": ""}],
			},
		},
	},
	"wrecked_boat": {
		"name": "半沉的小艇", "art": "cage", "areas": ["docks"], "weight": 3, "min_day": 2,
		"reveal": "船头朝着岸，缆绳却是从岸上割断的。",
		"steps": {
			"start": {
				"text": "小艇半沉在浅水里，舱里积着黑水。船帮上钉着一块木牌，字被水泡开了，只剩一个『勿』。",
				"options": [
					{"label": "撬开舱底的木板", "time": 12, "items": ["iron", "nail"], "next": "bottom"},
					{"label": "伸手进黑水里摸", "time": 7,
						"check": {"chance": 0.55, "success": "bottom", "fail": "grab"}},
					{"label": "离开", "next": ""},
				],
			},
			"bottom": {
				"text": "舱底压着几只密封的陶罐和一捆油布。油布里裹着一小袋硫磺，袋子是干的。",
				"reward": {"table": "alchemy", "tier": 2, "rolls": [1, 2]},
				"options": [
					{"label": "把陶罐也搬上来", "time": 9, "stamina": -10, "next": "jars"},
					{"label": "只拿油布", "next": ""},
				],
			},
			"jars": {
				"text": "陶罐里不是水，是熬得很稠的油。罐底刻着一行小字：『给下一个来的人。』",
				"reward": {"table": "salvage", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "盖上罐子", "next": ""}],
			},
			"grab": {
				"text": "水下的手抓住了你的手腕，冰得像铁。你抽回手，腕上留下五道发白的印。",
				"hp": -9,
				"options": [{"label": "退上岸", "next": ""}],
			},
		},
	},

	# ---------------------------------------------------------------- 炼金塔
	"sealed_vault": {
		"name": "封蜡样本窖", "art": "reliquary", "areas": ["institute"], "weight": 5, "min_day": 2,
		"reveal": "门缝被蜡封死，蜡上按着不止一个人的指印。",
		"steps": {
			"start": {
				"text": "窖门上的蜡封有好几层，颜色一层比一层深。最里面那层还是软的。",
				"options": [
					{"label": "读蜡面上的印记", "time": 6, "next": "seal"},
					{"label": "顺着蜡的裂缝撬开", "time": 12, "items": ["lockpick", "nail"],
						"check": {"chance": 0.65, "success": "open", "fail": "crack"}},
					{"label": "用火把把蜡烤化", "time": 9, "flags": ["torch"], "next": "melt"},
					{"label": "转动门边的三道铜环", "next": "rings"},
					{"label": "离开", "next": ""},
				],
			},
			"rings": {
				"text": "门框内侧嵌着三道铜环，环上各刻着一个血纹字。蜡封上那只衔尾鸟的羽毛恰好把三个字连了起来。",
				"puzzle": {"kind": "dial", "rings": 3, "glyphs": 6, "attempts": 3,
					"intro": "你把手按在铜环上。指尖下的铁很凉，像刚从水里捞出来。",
					"success_log": "三道铜环同时咬合，蜡封底下传来一声很轻的『咔』。"},
				"next": "open",
			},
			"seal": {
				"text": "印记是一只衔着自己尾巴的鸟。你数了数，它衔了不止一圈。",
				"options": [
					{"label": "照着印记的顺序剥蜡", "time": 10, "next": "open"},
					{"label": "换别的法子", "next": "start"},
				],
			},
			"melt": {
				"text": "蜡化成一条条往下淌，露出底下的铁门。门上有三道划痕，像是有人从里面抓过。",
				"reward": {"table": "alchemy", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "推门", "time": 4, "next": "open"}],
			},
			"crack": {
				"text": "蜡裂了，门却纹丝不动。碎蜡里裹着一小截发黑的指甲。",
				"options": [{"label": "挑出来", "time": 3, "next": "nail_piece"}, {"label": "退开", "next": ""}],
			},
			"nail_piece": {
				"text": "指甲的内侧刻着一个极小的数字：三。你抬头，门上的划痕正好三道。",
				"hp": -4,
				"options": [{"label": "离开", "next": ""}],
			},
			"open": {
				"text": "样本窖里排着一列列封好的玻璃罐。罐里泡着的东西都不像标本，更像是在睡觉。",
				"reward": {"table": "alchemy", "tier": 2, "rolls": [1, 2]},
				"options": [
					{"label": "看罐子上的标签", "time": 8, "next": "labels"},
					{"label": "拿几罐就走", "next": ""},
				],
			},
			"labels": {
				"text": "标签上的日期都在同一天。备注栏只写了一句话：『第九次，仍然醒得太早。』",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "把标签翻过去", "next": ""}],
			},
		},
	},
	"alchemy_balance": {
		"name": "没归零的天平", "art": "astrolabe", "areas": ["institute"], "weight": 4, "min_day": 2,
		"reveal": "天平一端压着一枚砝码，另一端什么也没有。",
		"steps": {
			"start": {
				"text": "黄铜天平摆在工作台正中，两端的托盘一高一低。空着的那端压着一张纸：『称对了，它才肯开。』",
				"options": [
					{"label": "研究托盘的刻痕", "time": 8, "next": "study"},
					{"label": "把身上的东西放上去试", "time": 10, "hp": -4, "next": "try"},
					{"label": "离开", "next": ""},
				],
			},
			"study": {
				"text": "两端的托盘底下都有簧片。重的不是砝码，是托盘本身——有一端被人灌了东西。",
				"options": [
					{"label": "找东西把簧片别住", "time": 12, "items": ["iron", "nail"],
						"check": {"chance": 0.6, "success": "open", "fail": "broke"}},
					{"label": "退开", "next": ""},
				],
			},
			"try": {
				"text": "你把随身的零碎一件件放上托盘。天平没有回正，但它的指针在轻轻发抖，像在忍着什么。",
				"reward": {"table": "common", "tier": 1, "rolls": [1, 1]},
				"options": [
					{"label": "再放一样东西", "time": 6, "next": "open"},
					{"label": "收手", "next": ""},
				],
			},
			"broke": {
				"text": "簧片断在托盘里，天平彻底歪了。台面下的抽屉自己滑出来一截。",
				"noise": 0.4,
				"options": [{"label": "拉开抽屉", "time": 4, "next": "open"}],
			},
			"open": {
				"text": "天平底下是一格暗屉。里面铺着绒布，绒布上凹着一个人形，人形的大小和你差不多。",
				"reward": {"table": "alchemy", "tier": 2, "rolls": [1, 2]},
				"options": [
					{"label": "摸绒布下面", "time": 6, "next": "under"},
					{"label": "盖上暗屉", "next": ""},
				],
			},
			"under": {
				"text": "绒布下压着一枚刻满刻度的铜片。铜片背面写着：『第一次称重：七磅四。』你低头看了看自己的手。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "把铜片收好", "next": ""}],
			},
		},
	},
	"distillation_rig": {
		"name": "还在滴的蒸馏器", "art": "astrolabe", "areas": ["institute"], "weight": 4, "min_day": 2,
		"reveal": "火早就熄了，馏出的液体还是温的。",
		"steps": {
			"start": {
				"text": "铜制蒸馏器的冷凝管还在滴。接液瓶里已经积了小半瓶，颜色比血淡，比酒清。",
				"options": [
					{"label": "接一瓶馏出液", "time": 8, "next": "catch"},
					{"label": "检查炉膛里的余烬", "time": 6, "next": "ash"},
					{"label": "离开", "next": ""},
				],
			},
			"catch": {
				"text": "液体装进瓶子后还在轻轻发热。瓶底沉着一点极细的红色，像有人在里面呼吸。",
				"reward": {"table": "alchemy", "tier": 2, "rolls": [1, 1]},
				"options": [
					{"label": "凑近闻一闻", "time": 4, "hp": -6, "next": "smell"},
					{"label": "塞紧瓶塞", "next": ""},
				],
			},
			"smell": {
				"text": "气味像雨后的铁栏杆，也像很久以前的某个人。你想起了一个不该记得的名字。",
				"options": [{"label": "把瓶子拿远", "next": ""}],
			},
			"ash": {
				"text": "炉膛里的灰是白的，摸上去像粉笔。灰里埋着半页烧剩的配方，字迹能认出的部分写着『勿用活物』。",
				"reward": {"table": "alchemy", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "把配方收起来", "next": ""}],
			},
		},
	},
	"apprentice_locker": {
		"name": "学徒储物柜", "art": "reliquary", "areas": ["institute"], "weight": 4, "min_day": 2,
		"reveal": "柜门上贴着名字，名字被划掉了两遍。",
		"steps": {
			"start": {
				"text": "一排储物柜，只有一个还锁着。柜门上的名字被划掉又写上，写上的字迹和前一个一模一样。",
				"options": [
					{"label": "照锁孔的形状找工具", "time": 10, "items": ["lockpick", "nail", "key"],
						"check": {"chance": 0.75, "success": "open", "fail": "stuck"}},
					{"label": "从缝隙往里看", "time": 4, "next": "peek"},
					{"label": "照着被划掉的名字敲柜门", "next": "knock"},
					{"label": "离开", "next": ""},
				],
			},
			"knock": {
				"text": "柜门内侧传来三下轻响，隔一会儿又是三下。你贴着门数，那节奏不像求救，更像有人在报自己的名字。",
				"puzzle": {"kind": "sequence", "length": 3, "glyphs": 6, "attempts": 3,
					"intro": "你把手贴在柜门上，里面的敲击停了。它在等你先敲。",
					"success_log": "你敲完最后一下，柜门自己弹开了一指宽，里面全是纸。"},
				"next": "open",
			},
			"peek": {
				"text": "柜子里没有衣服，只有一层层码好的纸。最上面那张画着一个和你同姿势的人。",
				"options": [
					{"label": "把锁弄开", "next": "start"},
					{"label": "走开", "next": ""},
				],
			},
			"stuck": {
				"text": "锁芯纹丝不动，柜门却自己往里陷了一点，像里面有人松了手。",
				"options": [{"label": "退开", "next": ""}],
			},
			"open": {
				"text": "柜子里码着几十张画。每一张都是同一个人，只是衣服的磨损程度不同。最后一张画的是你此刻的样子。",
				"reward": {"table": "tools", "tier": 2, "rolls": [1, 1]},
				"options": [
					{"label": "翻到画的背面", "time": 6, "next": "back"},
					{"label": "合上柜门", "next": ""},
				],
			},
			"back": {
				"text": "背面写着日期。第一张的日期是四十年前，最后一张是明天。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "把画留在柜子里", "next": ""}],
			},
		},
	},

	# ---------------------------------------------------------------- 墓道
	"blood_sigil_site": {
		"name": "刻满凹槽的黑石", "art": "blood_clock", "areas": ["catacombs"], "weight": 6, "min_day": 1,
		"always": true, "anchor": 0,
		"reveal": "黑石嵌在墙里，凹槽里是干涸的血。",
		"steps": {
			"start": {
				"text": "墙里露着一块巴掌大的黑石，表面刻满细槽。槽里的东西早就干了，但石头本身还是温的。",
				"options": [
					{"label": "用指甲抠掉干血", "time": 6, "hp": -3, "next": "clean"},
					{"label": "把掌心按上去", "time": 5, "hp": -8, "next": "press"},
					{"label": "不碰它", "next": ""},
				],
			},
			"clean": {
				"text": "干血下面还是血。槽里的东西像被石头养着，越抠越多。石头开始轻轻发烫。",
				"options": [
					{"label": "继续", "time": 6, "hp": -5, "next": "press"},
					{"label": "停下", "next": ""},
				],
			},
			"press": {
				"text": "你的血顺着凹槽走了一圈，最后汇进石心。石头松脱下来，落在你手里，还带着你的体温。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "收进怀里", "next": ""}],
			},
		},
	},
	"sealed_ossuary": {
		"name": "封死的骨瓮", "art": "reliquary", "areas": ["catacombs"], "weight": 4, "min_day": 2,
		"reveal": "瓮口封着三层泥，泥上按着掌印。",
		"steps": {
			"start": {
				"text": "骨瓮比看上去沉。封泥干得开裂，裂缝里塞着几根细骨。",
				"options": [
					{"label": "用铁器敲开封泥", "time": 12, "items": ["iron", "nail"], "noise": 0.4, "next": "open"},
					{"label": "徒手把泥掰开", "time": 10, "hp": -7, "next": "open"},
					{"label": "照着封泥上的掌印拨开骨环", "next": "bone_lock"},
					{"label": "离开", "next": ""},
				],
			},
			"bone_lock": {
				"text": "封泥上的掌印少了一根指节。瓮口下方藏着三圈骨环，每一圈都能单独转动，环内侧刻着字。",
				"puzzle": {"kind": "dial", "rings": 3, "glyphs": 6, "attempts": 3,
					"intro": "你捏住第一圈骨环。它转得很涩，像里面卡着什么东西。",
					"success_log": "三圈骨环对齐的瞬间，瓮里传来一声叹息，然后彻底静了。"},
				"next": "open",
			},
			"open": {
				"text": "封泥底下不是骨灰，是一层层叠好的布片，每一片上都绣着同一个名字。最上面那片还很新。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 2]},
				"options": [
					{"label": "把布片全倒出来", "time": 8, "next": "all"},
					{"label": "拿两片就走", "next": ""},
				],
			},
			"all": {
				"text": "瓮底压着一枚铜铃，铃舌是用骨头磨的。你轻轻一摇，声音不是从瓮里出来的，是从你身后。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"noise": 0.7,
				"options": [{"label": "放下铜铃", "next": ""}],
			},
		},
	},
	"nameless_stone": {
		"name": "无字碑", "art": "ledger", "areas": ["catacombs"], "weight": 4, "min_day": 2,
		"reveal": "碑面被摸得发亮，一个字也没有。",
		"steps": {
			"start": {
				"text": "石碑立在两排石棺之间，正面磨得像镜子。你靠近时，碑面上映出的不是你的脸。",
				"options": [
					{"label": "用纸把碑面拓下来", "time": 12, "items": ["paper"], "next": "rub"},
					{"label": "伸手摸碑面", "time": 5, "next": "touch"},
					{"label": "后退", "next": ""},
				],
			},
			"rub": {
				"text": "纸上什么都没有。你把纸举到烛光前，纸背浮出一行反字：『他数完了，轮到你了。』",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "烧掉拓片", "time": 4, "next": "burn"}],
			},
			"burn": {
				"text": "纸烧起来是绿的。灰落在地上，拼成一个你认得的名字——你的。",
				"hp": -6,
				"options": [{"label": "踩灭余烬", "next": ""}],
			},
			"touch": {
				"text": "碑面比冰还凉。你的指印留在上面，慢慢变成了刻痕。",
				"hp": -4,
				"reward": {"table": "common", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "收回手", "next": ""}],
			},
		},
	},
	"collapsed_crypt": {
		"name": "塌了半边的墓室", "art": "cage", "areas": ["catacombs"], "weight": 3, "min_day": 2, "live": true,
		"reveal": "石梁裂着口，灰一直在往下掉。",
		"steps": {
			"start": {
				"text": "墓室塌了半边，剩下的石梁随时会断。对面那半间还亮着一点烛火——这里没有风。",
				"options": [
					{"label": "侧身挤过裂缝", "time": 10, "stamina": -12, "hp": -5, "next": "across"},
					{"label": "先撑住石梁", "time": 8, "items": ["branch", "iron"], "next": "brace"},
					{"label": "绕路", "next": ""},
				],
			},
			"brace": {
				"text": "石梁被撑住了。你能听见它在慢慢开裂，但至少这一小会儿不会塌。",
				"reward": {"table": "salvage", "tier": 1, "rolls": [1, 1]},
				"options": [
					{"label": "快步过去", "time": 6, "next": "across"},
					{"label": "退回来", "next": ""},
				],
			},
			"across": {
				"text": "对面半间里摆着一张石桌，桌上的烛台还在烧。烛泪堆得很高，像有人守了很久。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 2]},
				"options": [
					{"label": "看石桌下面", "time": 7, "next": "under"},
					{"label": "拿上东西就回去", "next": ""},
				],
			},
			"under": {
				"text": "石桌下刻着一行小字：『谢谢你还记得点灯。』",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "把烛火拨亮一点", "time": 4, "next": ""}],
			},
		},
	},

	# ---------------------------------------------------------------- 晨钟广场
	"stopped_clock": {
		"name": "停摆的钟面", "art": "astrolabe", "areas": ["bell_square"], "weight": 5, "min_day": 1,
		"reveal": "指针停在三点十七分，玻璃上有从里面按出来的印子。",
		"steps": {
			"start": {
				"text": "钟楼的钟面停着。你仰头的时候，秒针没有动，但你能听见齿轮在很轻地咬合。",
				"options": [
					{"label": "用手指拨动指针", "time": 10, "next": "hand"},
					{"label": "找机会打开钟匣", "time": 14,
						"check": {"chance": 0.55, "success": "case", "fail": "slip"}},
					{"label": "听钟面里侧的敲击", "next": "chime"},
					{"label": "离开", "next": ""},
				],
			},
			"chime": {
				"text": "钟面玻璃上有一层从里面按出来的雾。雾里慢慢浮出四个字的印子，一个接一个，像有人在里面用指甲划。",
				"puzzle": {"kind": "sequence", "length": 4, "glyphs": 6, "attempts": 3,
					"intro": "你把手按在玻璃上。四个印子淡下去了，钟摆停了一拍，等你。",
					"success_log": "四个字都亮过一遍，钟匣的锁舌自己缩了回去。"},
				"next": "case",
			},
			"hand": {
				"text": "指针很沉，拨到三点十八分时，整座钟楼响了一声，像有人在你耳边叹了口气。",
				"reward": {"table": "valuables", "tier": 1, "rolls": [1, 1]},
				"options": [
					{"label": "继续拨", "time": 8, "hp": -5, "next": "later"},
					{"label": "松手", "next": ""},
				],
			},
			"later": {
				"text": "指针越过三点二十，钟声却没有再响。钟面里的影子多了一个，站在你身后半步的位置。",
				"hp": -4,
				"options": [{"label": "不要回头", "next": ""}],
			},
			"case": {
				"text": "钟匣里塞满了纸条，每一张都写着同一个时刻和不同的日期。最下面压着一小卷用皮绳扎好的银币。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 2]},
				"options": [
					{"label": "抽一张纸条", "time": 4, "next": "note"},
					{"label": "合上钟匣", "next": ""},
				],
			},
			"slip": {
				"text": "你的手指从钟面上滑下来，指腹沾了一层很细的灰。灰是温的。",
				"options": [{"label": "擦掉", "next": ""}],
			},
			"note": {
				"text": "纸条的日期是今天，时刻是三点十七。笔迹很急，最后两个字被划掉了，划痕却很深。",
				"options": [{"label": "收起来", "next": ""}],
			},
		},
	},
	"dry_well": {
		"name": "干涸许愿井", "art": "music_box", "areas": ["bell_square"], "weight": 4, "min_day": 1,
		"reveal": "井底铺满了硬币和骨头。",
		"steps": {
			"start": {
				"text": "井口的绳子断了，断口很新。井底离地面不高，你能看见硬币之间夹着一些白色的东西。",
				"options": [
					{"label": "把绳子接起来下去", "time": 12, "items": ["rope"], "next": "climb"},
					{"label": "直接跳下去", "time": 5, "hp": -10, "next": "bottom"},
					{"label": "往井里扔一枚硬币", "time": 3, "items": ["lead_shot"], "next": "wish"},
					{"label": "离开", "next": ""},
				],
			},
			"climb": {
				"text": "你降到井底。硬币踩在脚下像一层硬壳，壳下面是软的。",
				"reward": {"table": "valuables", "tier": 1, "rolls": [1, 2]},
				"options": [{"label": "往井壁的凹处摸", "time": 7, "next": "niche"}],
			},
			"bottom": {
				"text": "你落在硬币堆上，肋骨震得发麻。井底比上面冷得多，呼出的气看不见。",
				"reward": {"table": "common", "tier": 1, "rolls": [1, 2]},
				"options": [{"label": "尽快爬上去", "time": 8, "stamina": -12, "next": ""}],
			},
			"niche": {
				"text": "井壁的凹处塞着一只小铁盒。盒里的东西被布包着，布上反复绣着一句话：『还给我。』",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "收好铁盒", "next": ""}],
			},
			"wish": {
				"text": "硬币落下去，很久才响。响声之后，井底传来一声很轻的『谢谢』。",
				"stamina": 15,
				"options": [{"label": "离开井边", "next": ""}],
			},
		},
	},
	"refugee_pack": {
		"name": "弃置的行李", "art": "music_box", "areas": ["bell_square"], "weight": 4, "min_day": 1,
		"reveal": "行李摆得很整齐，像主人只是去去就回。",
		"steps": {
			"start": {
				"text": "广场角落摞着三只行李，绳结都朝外，方便再提起来。最近的雨没淋到它们——有人替它们挡过雨。",
				"options": [
					{"label": "翻开最上面那只", "time": 8, "next": "open"},
					{"label": "检查行李的夹层", "time": 12,
						"check": {"chance": 0.6, "success": "hidden", "fail": "empty"}},
					{"label": "离开", "next": ""},
				],
			},
			"open": {
				"text": "行李里是叠好的换洗衣物、半袋干粮和一张折起的路线图。图上标着撤离点，但撤离点被画了个叉。",
				"reward": {"table": "provisions", "tier": 1, "rolls": [1, 2]},
				"options": [
					{"label": "看路线图背面", "time": 5, "next": "map_back"},
					{"label": "把东西放回去", "next": ""},
				],
			},
			"hidden": {
				"text": "夹层里是一小包银币和一枚刻着日期的铜牌。日期是三天后。",
				"reward": {"table": "tools", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "收好", "next": ""}],
			},
			"empty": {
				"text": "夹层是空的，但缝线被拆开又缝回去过。针脚比别处密。",
				"options": [{"label": "算了", "next": ""}],
			},
			"map_back": {
				"text": "背面用铅笔写着：『不要相信钟声。它响的时候，已经在数人了。』",
				"reward": {"table": "valuables", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "折好地图", "next": ""}],
			},
		},
	},
	"bell_rope": {
		"name": "垂下来的钟绳", "art": "music_box", "areas": ["bell_square"], "weight": 3, "min_day": 1,
		"reveal": "绳结里夹着头发，头发还是湿的。",
		"steps": {
			"start": {
				"text": "钟绳从头顶垂下来，末端打了七个结。你伸手一碰，绳子自己晃了一下。",
				"options": [
					{"label": "拉响它", "time": 6, "noise": 0.9, "next": "ring"},
					{"label": "把绳结一个个解开", "time": 10, "next": "knots"},
					{"label": "离开", "next": ""},
				],
			},
			"ring": {
				"text": "钟没有响。广场四周的窗户却同时亮了一下，又同时暗下去。",
				"hp": -5,
				"options": [{"label": "松手", "next": ""}],
			},
			"knots": {
				"text": "每解开一个结，绳子就轻一点。最后一个结里掉出一枚铜铃舌和一缕缠得很紧的头发。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [
					{"label": "把绳结全部解开", "time": 6, "next": "unbound"},
					{"label": "停手", "next": ""},
				],
			},
			"unbound": {
				"text": "绳子落下来，缠在你脚边。钟楼里传来一声很长的、终于松了口的叹息。",
				"stamina": 10,
				"reward": {"table": "tools", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "把绳子收起来", "next": ""}],
			},
		},
	},

	# ---------------------------------------------------------------- 祭坛
	"blood_pool_offering": {
		"name": "缓慢转动的血池", "art": "blood_clock", "areas": ["altar"], "weight": 5, "min_day": 3,
		"reveal": "池子里的血还在缓慢转动，等着有人伸手。",
		"steps": {
			"start": {
				"text": "血池不大，血面却一直在转，像底下有个很慢的漩涡。你把影子投上去，影子没有跟着转。",
				"options": [
					{"label": "把手按进血里", "time": 6, "hp": -15, "next": "gift"},
					{"label": "把一件东西扔进去", "time": 4, "items": ["crystal", "relic", "charm"], "next": "toss"},
					{"label": "退开", "next": ""},
				],
			},
			"gift": {
				"text": "血是温的。有什么东西从池底浮上来，贴着你的掌心停住，像在确认你是不是它等的人。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 2]},
				"options": [
					{"label": "再按深一点", "time": 6, "hp": -15, "next": "deeper"},
					{"label": "抽手", "next": ""},
				],
			},
			"deeper": {
				"text": "池底很软。你摸到一枚环状的东西，拿起来时池水停止转动，整间祭坛安静得像在等你说话。",
				"reward": {"table": "arsenal", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "收好", "next": ""}],
			},
			"toss": {
				"text": "东西沉下去很慢，一直没有到底。血面荡开一圈，浮上来一件你没扔下去的东西。",
				"reward": {"table": "valuables", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "捡起来", "next": ""}],
			},
		},
	},
	"offering_remains": {
		"name": "献祭者遗骸", "art": "surgery", "areas": ["altar"], "weight": 4, "min_day": 3,
		"reveal": "遗骸被摆成跪姿，胸口插着一把没有柄的刀。",
		"steps": {
			"start": {
				"text": "遗骸保存得异常完整，只是没有头发，也没有指甲。那把刀插得很深，刀身却一点锈都没有。",
				"options": [
					{"label": "把刀拔出来", "time": 12,
						"check": {"chance": 0.55, "success": "pull", "fail": "resist"}},
					{"label": "检查遗骸的手", "time": 6, "next": "hands"},
					{"label": "不打扰", "next": ""},
				],
			},
			"pull": {
				"text": "刀拔出来时没有一点声音。刀身上刻着一行字：『第一个自愿的，已经不在了。』",
				"reward": {"table": "arsenal", "tier": 2, "rolls": [1, 1]},
				"options": [
					{"label": "看遗骸的胸口", "time": 5, "hp": -6, "next": "chest"},
					{"label": "收刀离开", "next": ""},
				],
			},
			"chest": {
				"text": "伤口里没有血，塞着一卷用头发编成的绳。绳上系着一枚小小的铜牌，刻着你这一局开始的日子。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "放回去", "next": ""}],
			},
			"hands": {
				"text": "遗骸的手是合十的，掌心夹着一小块蜡。蜡里封着几根针和一枚很旧的硬币。",
				"reward": {"table": "tools", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "掰开蜡", "time": 5, "next": "wax"}],
			},
			"wax": {
				"text": "蜡里的硬币两面都是正面。",
				"reward": {"table": "valuables", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "收好", "next": ""}],
			},
			"resist": {
				"text": "刀像长在骨头里。你用力的时候，遗骸的头慢慢低下来，像是在看你。",
				"hp": -10,
				"options": [{"label": "放手", "next": ""}],
			},
		},
	},
	"faced_effigy": {
		"name": "无面神像", "art": "reliquary", "areas": ["altar"], "weight": 4, "min_day": 3,
		"reveal": "神像的脸被整块磨平，底座上却有新鲜的刮痕。",
		"steps": {
			"start": {
				"text": "神像比人高两头，脸部是一片光滑的凹面。你站在它面前，凹面里映出的东西比你的影子慢半拍。",
				"options": [
					{"label": "用铁器撬底座", "time": 18, "items": ["iron"], "noise": 0.5,
						"check": {"chance": 0.55, "success": "base", "fail": "topple"}},
					{"label": "绕着神像走一圈", "time": 8, "next": "circle"},
					{"label": "离开", "next": ""},
				],
			},
			"base": {
				"text": "底座是空的。里面堆着旧供品、几枚磨平的硬币，和一本没有封面的册子。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 2]},
				"options": [
					{"label": "翻开册子", "time": 7, "next": "book"},
					{"label": "只拿供品", "next": ""},
				],
			},
			"book": {
				"text": "册子记着每一个来过这里的人：名字、日子、带走了什么。你的那一行已经写好了，只差最后一项空着。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "合上册子", "next": ""}],
			},
			"circle": {
				"text": "神像背后刻着一圈很小的字。你逐字读过去，读到最后发现自己一直在倒退着走。",
				"hp": -5,
				"options": [{"label": "停下来", "next": ""}],
			},
			"topple": {
				"text": "底座没开，神像晃了一下，整间祭坛的烛火同时向一个方向倒。你听见石头里有东西在磨牙。",
				"noise": 0.8,
				"hp": -8,
				"options": [{"label": "退到门口", "next": ""}],
			},
		},
	},
	"red_moon_crack": {
		"name": "贴着地面的红月", "art": "blood_clock", "areas": ["altar"], "weight": 3,
		"min_day": 3, "phase": "night", "live": true,
		"reveal": "裂口里的红月贴着地面，像一只没有眼皮的眼睛。",
		"steps": {
			"start": {
				"text": "地板上裂开一道口子，红月就在裂口底下。你蹲下时，红月也跟着转了一点。这里的时间没有停。",
				"options": [
					{"label": "把手伸进裂口", "time": 8, "hp": -15, "next": "reach"},
					{"label": "把血滴在裂缝上", "time": 6, "hp": -10, "next": "blood"},
					{"label": "退开", "next": ""},
				],
			},
			"reach": {
				"text": "裂口里的空气是空的，不冷也不热。你的手穿过了月亮，摸到一件很硬的东西。",
				"reward": {"table": "arsenal", "tier": 2, "rolls": [1, 1]},
				"options": [
					{"label": "再往里伸", "time": 6, "hp": -12, "next": "deeper"},
					{"label": "抽手", "next": ""},
				],
			},
			"deeper": {
				"text": "更里面是一整面嵌满东西的墙。你想看清楚，红月却在这时眨了一下。你的手回来时，少了半片指甲。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "退开", "next": ""}],
			},
			"blood": {
				"text": "血落在裂缝上，没有渗进去，而是被红月吸成一条细线。月亮转过来，正对着你。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 2]},
				"options": [{"label": "立刻离开裂口", "next": ""}],
			},
		},
	},

	# ---------------------------------------------------------------- 通用（任何地区）
	"abandoned_cart": {
		"name": "翻倒的手推车", "art": "music_box", "areas": [], "weight": 3, "min_day": 1,
		"reveal": "车轮还在慢慢转，推车的人不在。",
		"steps": {
			"start": {
				"text": "手推车翻在路中间，车上的东西散了一地，却没有被搜过的痕迹。",
				"options": [
					{"label": "把散落的东西收拢", "time": 7, "next": "gather"},
					{"label": "看车底下", "time": 6, "next": "under"},
					{"label": "离开", "next": ""},
				],
			},
			"gather": {
				"text": "东西大多是些零碎，够用但不值钱。车板背面用炭条写着：『别回头，车会跟上。』",
				"reward": {"table": "common", "tier": 1, "rolls": [1, 2]},
				"options": [{"label": "看看车轮", "time": 4, "next": "wheel"}],
			},
			"under": {
				"text": "车底下压着一只布鞋，鞋里塞着几张折好的纸。纸上的字被汗浸花了。",
				"reward": {"table": "tools", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "收好纸", "next": ""}],
			},
			"wheel": {
				"text": "车轮的辐条里缠着一圈头发。车已经翻了很久，轮子却像刚被人推过。",
				"hp": -3,
				"options": [{"label": "站起来", "next": ""}],
			},
		},
	},
	"shallow_grave": {
		"name": "新翻的土", "art": "cage", "areas": [], "weight": 3, "min_day": 2,
		"reveal": "土是新的，压土的石头却是旧的。",
		"steps": {
			"start": {
				"text": "一小片地被翻过，土堆得不高。旁边放着一把没带走的小铲。",
				"options": [
					{"label": "用手把土扒开", "time": 12, "hp": -4, "next": "dig"},
					{"label": "先用铲子挖", "time": 8, "items": ["iron", "branch"], "next": "shovel"},
					{"label": "不动它", "next": ""},
				],
			},
			"dig": {
				"text": "土里没有尸体，只有一只钉死的木匣。匣盖上留着五个指印，指印比你的手大一圈。",
				"reward": {"table": "salvage", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "撬开木匣", "time": 8, "next": "box"}],
			},
			"shovel": {
				"text": "铲子很趁手，土下很快露出木匣的一角。铲柄上刻着一个小记号，和你刚才在某处见过的一样。",
				"reward": {"table": "salvage", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "把匣子挖出来", "time": 6, "next": "box"}],
			},
			"box": {
				"text": "匣子里是几件叠好的衣服，和一枚还带着体温的护身符。衣服的尺码和你身上的一样。",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "把土填回去", "time": 6, "next": ""}],
			},
		},
	},
	"whispering_pipe": {
		"name": "滴水的管道", "art": "astrolabe", "areas": [], "weight": 3, "min_day": 1,
		"reveal": "水声有节奏，不像漏水。",
		"steps": {
			"start": {
				"text": "墙角的管道锈穿了几个孔，水一滴一滴地落。你听了一会儿，水滴的间隔在变短。",
				"options": [
					{"label": "把耳朵贴到管壁上", "time": 6, "hp": -4, "next": "listen"},
					{"label": "拆开最松的那节", "time": 12, "items": ["iron"], "next": "open"},
					{"label": "走开", "next": ""},
				],
			},
			"listen": {
				"text": "管子里不是水声，是很多人压低了声音在数数。你听清了其中一个声音，它在数你的脚步。",
				"stamina": -10,
				"options": [
					{"label": "再听一次", "time": 5, "hp": -6, "next": "listen2"},
					{"label": "离开", "next": ""},
				],
			},
			"listen2": {
				"text": "数到十七的时候，所有声音一起停了。管道里传来一声很轻的、抿嘴的声音。",
				"options": [{"label": "走开", "next": ""}],
			},
			"open": {
				"text": "管子里塞着一团布和一串用铁丝串起来的东西。布上写着：『下一个人，别听。』",
				"reward": {"table": "valuables", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "收好", "next": ""}],
			},
		},
	},
	"lost_satchel": {
		"name": "遗失的挎包", "art": "music_box", "areas": [], "weight": 3, "min_day": 1,
		"reveal": "包扣是开着的，里面的东西一件没少。",
		"steps": {
			"start": {
				"text": "挎包挂在一根断掉的栏杆上。包里的东西摆放整齐，像主人只是暂时放下。",
				"options": [
					{"label": "翻看包里的东西", "time": 6, "next": "look"},
					{"label": "检查包的夹层", "time": 9,
						"check": {"chance": 0.6, "success": "hidden", "fail": "nothing"}},
					{"label": "离开", "next": ""},
				],
			},
			"look": {
				"text": "包里有干粮、一段麻绳和一本小册子。小册子的最后一页被人撕掉了，撕口很齐。",
				"reward": {"table": "provisions", "tier": 1, "rolls": [1, 2]},
				"options": [{"label": "翻前面的页", "time": 5, "next": "pages"}],
			},
			"hidden": {
				"text": "夹层里缝着一枚铜扣和一小叠纸。纸上画着这一带的地图，几个地方被圈了起来——包括你脚下的这里。",
				"reward": {"table": "tools", "tier": 2, "rolls": [1, 1]},
				"options": [{"label": "收好地图", "next": ""}],
			},
			"pages": {
				"text": "前面记的是些采买的账目。最后一页的墨迹还没干透：『如果包还在，说明我还没走远。』",
				"reward": {"table": "valuables", "tier": 1, "rolls": [1, 1]},
				"options": [{"label": "把包放回栏杆", "next": ""}],
			},
			"nothing": {
				"text": "夹层是空的，只有一股很淡的、像旧香灰的味道。",
				"options": [{"label": "站起来", "next": ""}],
			},
		},
	},
}

static func event(id: String) -> Dictionary:
	return EVENTS.get(id, {})

static func event_art_key(id: String) -> String:
	return str(event(id).get("art", "reliquary"))

## 天气/天数/地区的可用性判断。`areas` 为空表示任何地区都能刷。
static func event_matches(ev: Dictionary, area: String, day: int, phase: String) -> bool:
	if ev.is_empty():
		return false
	var areas: Array = ev.get("areas", [])
	if not areas.is_empty() and not area in areas:
		return false
	if int(ev.get("min_day", 1)) > day:
		return false
	var want_phase := str(ev.get("phase", ""))
	if not want_phase.is_empty() and want_phase != phase:
		return false
	return true

static func event_spawns(area: String) -> Array:
	if EVENT_SPAWNS.has(area):
		return EVENT_SPAWNS[area]
	return EVENT_SPAWNS["old_town"]

## 奖励表 → 一件物品 kind（与搜索共用同一套权重抽取）。
static func roll_event_loot(table_name: String, rng: RandomNumberGenerator) -> String:
	var table: Dictionary = EVENT_LOOT.get(table_name, {})
	if table.is_empty():
		return ""
	var total := 0.0
	for kind in table:
		total += float(table[kind])
	var roll := rng.randf() * total
	for kind in table:
		roll -= float(table[kind])
		if roll <= 0.0:
			return str(kind)
	return str(table.keys().back())

static func tier_name(tier: int) -> String:
	return ["白色", "绿色", "蓝色", "紫色", "金色", "红色"][clampi(tier, 0, 5)]

static func tier_color(tier: int) -> Color:
	return [Color("cfc6bb"), Color("8fc39a"), Color("8fb6d8"), Color("b48fd4"), Color("dcbd7e"), Color("dd6c7c")][clampi(tier, 0, 5)]
