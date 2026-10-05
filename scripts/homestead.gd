extends RefCounted
## Persistent homestead rules. All currency/inventory mutations save atomically.
const CROPS := {
	"wheat": {"name":"晨光麦", "price":12, "seconds":120, "yield":3, "sell":9, "color":"e8c678"},
	"carrot": {"name":"赤霞萝卜", "price":18, "seconds":240, "yield":3, "sell":14, "color":"e99856"},
	"herb": {"name":"月露草", "price":26, "seconds":360, "yield":3, "sell":21, "color":"94d8bf"},
}
const FISH := {
	"silver": {"name":"银鳞鲫", "sell":16},
	"moon": {"name":"月纹鲈", "sell":32},
	"gold": {"name":"金冠锦鲤", "sell":65},
}
const MEALS := {
	"bread": {"name":"晨光面包", "needs":{"wheat":3}, "desc":"本次远征最大生命 +24", "hp":24, "damage":0.0, "speed":0},
	"stew": {"name":"赤霞炖鱼", "needs":{"carrot":2,"silver":1}, "desc":"本次远征伤害 +12%", "hp":0, "damage":0.12, "speed":0},
	"tea": {"name":"月露鱼汤", "needs":{"herb":2,"moon":1}, "desc":"本次远征生命 +12、移速 +24", "hp":12, "damage":0.0, "speed":24},
}
var profile
var active_cast := false

func _init(owner) -> void:
	profile = owner
	profile.data["home"] = clean(profile.data.get("home", {}))

static func number(value: Variant, low: int, high: int, fallback: int = 0) -> int:
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	return clampi(int(value), low, high)

static func clean(raw: Variant) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	var result := {"seeds":{}, "stock":{}, "meals":{}, "plots":[], "rod":0, "bait":0,
		"beds":6, "prepared":"", "casts":0, "last_cast":0, "harvests":0}
	for key in CROPS:
		result.seeds[key] = number(source.get("seeds",{}).get(key,0) if source.get("seeds") is Dictionary else 0,0,9999)
	for key in CROPS.keys() + FISH.keys():
		result.stock[key] = number(source.get("stock",{}).get(key,0) if source.get("stock") is Dictionary else 0,0,9999)
	for key in MEALS:
		result.meals[key] = number(source.get("meals",{}).get(key,0) if source.get("meals") is Dictionary else 0,0,9999)
	result.rod = number(source.get("rod",0),0,2)
	result.bait = number(source.get("bait",0),0,9999)
	result.beds = 9 if number(source.get("beds",6),6,9)==9 else 6
	result.casts = number(source.get("casts",0),0,1000000)
	result.harvests = number(source.get("harvests",0),0,1000000)
	result.last_cast = number(source.get("last_cast",0),0,4102444800)
	var prepared := str(source.get("prepared",""))
	if MEALS.has(prepared) and result.meals[prepared]>0: result.prepared = prepared
	var plots: Array = source.get("plots",[]) if source.get("plots") is Array else []
	for i in 9:
		var plot: Dictionary = plots[i] if i<plots.size() and plots[i] is Dictionary else {}
		var crop := str(plot.get("crop",""))
		result.plots.append({"crop":crop if CROPS.has(crop) and i<result.beds else "",
			"planted":number(plot.get("planted",0),0,4102444800), "watered":bool(plot.get("watered",false))})
	return result

func state() -> Dictionary:
	return profile.data.home

func now() -> int:
	return int(Time.get_unix_time_from_system())

func commit() -> void:
	profile.save_profile()

func buy(key: String) -> String:
	var cost := 0
	if CROPS.has(key): cost = int(CROPS[key].price)
	elif key=="rod":
		if state().rod>=2: return "钓竿已升至最高等级。"
		cost = 70 if state().rod==0 else 180
	elif key=="bait": cost = 15
	elif key=="beds":
		if state().beds==9: return "菜园已全部开垦。"
		cost = 120
	else: return "商品不存在。"
	if profile.data.coins<cost: return "金币不足，出售收获或远征获取金币。"
	if (CROPS.has(key) and state().seeds[key]>=9999) or (key=="bait" and state().bait>9994): return "库存已满。"
	profile.data.coins -= cost
	if CROPS.has(key): state().seeds[key] += 1
	elif key=="rod": state().rod += 1
	elif key=="bait": state().bait += 5
	elif key=="beds": state().beds = 9
	commit()
	return "购买成功，花费 %d 金币。" % cost

func remaining(index: int, timestamp: int = -1) -> int:
	if index<0 or index>=state().beds: return 0
	var plot: Dictionary = state().plots[index]
	if not CROPS.has(str(plot.crop)): return 0
	var duration := int(CROPS[plot.crop].seconds * (0.65 if plot.watered else 1.0))
	return maxi(0, int(plot.planted)+duration-(now() if timestamp<0 else timestamp))

func plant(index: int, crop: String) -> String:
	if index<0 or index>=state().beds: return "这块土地尚未开垦。"
	if not CROPS.has(crop) or state().seeds[crop]<=0: return "种子不足，请去家园商店购买。"
	if not str(state().plots[index].crop).is_empty(): return "先收获这块土地上的作物。"
	state().seeds[crop] -= 1
	state().plots[index] = {"crop":crop,"planted":now(),"watered":false}
	commit()
	return "已种下%s，浇水可缩短 35%% 生长时间。" % CROPS[crop].name

func tend(index: int) -> String:
	if index<0 or index>=state().beds: return "土地尚未开垦。"
	var plot: Dictionary = state().plots[index]
	if str(plot.crop).is_empty(): return "选择种子后播种。"
	if remaining(index)==0:
		var crop: String = plot.crop
		if state().stock[crop]>9996: return "仓储已满，请先出售收获。"
		state().stock[crop] += int(CROPS[crop].yield)
		state().harvests += 1
		state().plots[index] = {"crop":"","planted":0,"watered":false}
		commit()
		return "收获%s ×%d！可以烹饪或出售。" % [CROPS[crop].name,CROPS[crop].yield]
	if plot.watered: return "已浇水，还需 %d 秒成熟。" % remaining(index)
	plot.watered = true
	commit()
	return "浇水完成，剩余 %d 秒。" % remaining(index)

func sell(key: String) -> String:
	if not state().stock.has(key) or state().stock[key]<=0: return "没有可出售的收获。"
	var entry: Dictionary = CROPS.get(key,FISH.get(key,{}))
	state().stock[key] -= 1
	profile.data.coins += int(entry.sell)
	commit()
	return "出售%s，获得 %d 金币。" % [entry.name,entry.sell]

func cook(key: String) -> String:
	if not MEALS.has(key): return "食谱不存在。"
	if state().meals[key]>=9999: return "餐食库存已满。"
	for ingredient in MEALS[key].needs:
		if state().stock[ingredient]<MEALS[key].needs[ingredient]: return "食材不足，先种植或钓鱼。"
	for ingredient in MEALS[key].needs: state().stock[ingredient] -= MEALS[key].needs[ingredient]
	state().meals[key] += 1
	commit()
	return "烹饪完成：" + str(MEALS[key].name)

func prepare(key: String) -> String:
	if key=="":
		state().prepared = ""
	elif MEALS.has(key) and state().meals[key]>0:
		state().prepared = key
	else: return "先烹饪这份餐食。"
	commit()
	return "已选择出征餐食；成功开局时消耗一份。"

func consume_started(meal: String) -> void:
	if MEALS.has(meal) and state().meals[meal]>0:
		state().meals[meal] -= 1
	state().prepared = ""
	commit()

func cast() -> String:
	if state().rod==0: return "先购买一支钓竿。"
	if state().bait<=0: return "鱼饵不足，15 金币可购买 5 份。"
	if now()-int(state().last_cast)<8: return "鱼群还未聚拢，稍等片刻再抛竿。"
	active_cast = true
	state().bait -= 1
	state().casts += 1
	state().last_cast = now()
	commit()
	return ""

func cancel_cast() -> void:
	active_cast = false

func catch_fish(quality: float, roll: float) -> String:
	if not active_cast: return "当前没有正在进行的垂钓。"
	active_cast = false
	# Called only by the active cast in the screen; quality comes from timed input.
	if quality<=0.0: return "鱼挣脱了；下一次在绿色区域内收竿。"
	var key := fish_key(quality,roll,int(state().rod))
	state().stock[key] = mini(9999, int(state().stock[key])+1)
	commit()
	return "钓到%s！%s" % [FISH[key].name, "精准收竿，稀有鱼概率提升。" if quality>0.8 else "可出售或用于烹饪。"]

static func meal_id(value: Variant) -> String:
	return str(value) if MEALS.has(str(value)) else ""

static func bonus(player: Dictionary, key: String) -> float:
	var meal := meal_id(player.get("home_meal",""))
	return float(MEALS[meal].get(key,0)) if not meal.is_empty() else 0.0

static func fish_key(quality: float, roll: float, rod: int) -> String:
	var chance := clampf(roll,0,1) + clampf(quality,0,1) * 0.15 + (0.12 if rod==2 else 0.0)
	return "gold" if chance>1.03 else ("moon" if chance>0.68 else "silver")
