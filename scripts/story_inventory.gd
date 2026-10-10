extends RefCounted
## Campaign-only item authority. Every transfer is planned on copies before committing.
const BAG := Vector2i(10,6)
const VAULT := Vector2i(12,10)
const SLOTS := ["blade","armor","charm"]
const SLOT_NAMES := {"blade":"主手","armor":"护衣","charm":"护符"}
const HEROES := ["绯月","雪璃","鸦羽"]
const QUALITY := ["朴素","附魔","珍稀"]
const TONES := [Color("dbd5c6"),Color("88c4eb"),Color("dbad65")]
const BASES := {
	"sword":{"name":"赤晶长剑","slot":"blade","w":1,"h":4,"icon":0,"hero":0},
	"staff":{"name":"晨星法杖","slot":"blade","w":2,"h":4,"icon":1,"hero":1},
	"dagger":{"name":"夜鸦曲刃","slot":"blade","w":1,"h":3,"icon":2,"hero":2},
	"plate":{"name":"守夜胸甲","slot":"armor","w":2,"h":3,"icon":3,"hero":0},
	"robe":{"name":"月纱法衣","slot":"armor","w":2,"h":3,"icon":4,"hero":1},
	"coat":{"name":"巡林皮衣","slot":"armor","w":2,"h":3,"icon":5,"hero":2},
	"ruby":{"name":"赤晶吊坠","slot":"charm","w":1,"h":2,"icon":6,"hero":-1},
	"frost":{"name":"霜铃护符","slot":"charm","w":1,"h":2,"icon":7,"hero":-1},
	"raven":{"name":"鸦羽信物","slot":"charm","w":2,"h":2,"icon":8,"hero":-1},
	"potion":{"name":"晨灯药剂","slot":"consumable","w":1,"h":1,"icon":9,"stack":5},
	"scrap":{"name":"锻造铁料","slot":"material","w":2,"h":1,"icon":10,"stack":20},
	"crystal":{"name":"导光晶石","slot":"material","w":1,"h":1,"icon":11,"stack":10}
}
var _host: WeakRef
var campaign:
	get: return _host.get_ref()
var last_message := ""

func _init(host = null) -> void: _host=weakref(host) if host!=null else null

static func dimensions(item: Dictionary) -> Vector2i:
	var base: Dictionary=BASES.get(str(item.get("base","")),BASES.sword)
	var value := Vector2i(int(base.w),int(base.h))
	return Vector2i(value.y,value.x) if item.get("rotated",false) else value

static func bounds(container: String) -> Vector2i: return BAG if container=="bag" else VAULT

static func rect(item: Dictionary) -> Rect2i: return Rect2i(Vector2i(int(item.get("x",0)),int(item.get("y",0))),dimensions(item))

static func fits(items: Array, item: Dictionary, size: Vector2i, ignore: String = "") -> bool:
	var box := rect(item)
	if box.position.x<0 or box.position.y<0 or box.end.x>size.x or box.end.y>size.y: return false
	for other in items:
		if str(other.get("uid",""))!=ignore and box.intersects(rect(other)): return false
	return true

static func place(items: Array, item: Dictionary, size: Vector2i) -> bool:
	var candidate := item.duplicate(true)
	for y in size.y:
		for x in size.x:
			candidate.x=x; candidate.y=y
			if fits(items,candidate,size): items.append(candidate); return true
	return false

static func insert(items: Array, item: Dictionary, size: Vector2i) -> bool:
	# Atomic stack merging: a rejected arrival must not partially alter the container.
	var planned := items.duplicate(true)
	var incoming := item.duplicate(true)
	var limit := int(BASES[incoming.base].get("stack",1))
	if limit>1:
		for other in planned:
			if other.base!=incoming.base or int(other.get("count",1))>=limit: continue
			var amount := mini(limit-int(other.get("count",1)),int(incoming.get("count",1)))
			other.count=int(other.get("count",1))+amount; incoming.count=int(incoming.get("count",1))-amount
			if incoming.count==0: break
	if int(incoming.get("count",1))>0 and not place(planned,incoming,size): return false
	items.assign(planned); return true

static func find(items: Array, uid: String) -> int:
	for i in items.size():
		if str(items[i].get("uid",""))==uid: return i
	return -1

static func power(item: Dictionary) -> int: return int(item.get("tier",0))+int(item.get("upgrade",0))

static func price(item: Dictionary) -> int:
	if item.base=="potion": return 20
	if item.base=="scrap": return 12
	if item.base=="crystal": return 60
	return 65+int(item.tier)*55+int(item.quality)*65+int(item.get("upgrade",0))*45+int(item.get("socket",false))*60

static func sale_price(item: Dictionary) -> int: return maxi(1,int(price(item)*0.35))*int(item.get("count",1))

static func tone(item: Dictionary) -> Color: return TONES[clampi(int(item.get("quality",0)),0,2)]

static func stats(item: Dictionary) -> Dictionary:
	var rank := power(item)
	var socket := bool(item.get("socket",false))
	return {"damage":(rank*11 if item.get("slot")=="blade" else rank*3 if item.get("slot")=="charm" else 0)+int(item.get("bonus_damage",0))+(8 if socket else 0),"hp":(rank*18 if item.get("slot")=="armor" else 0)+int(item.get("bonus_hp",0))+(12 if socket else 0)}

static func describe(item: Dictionary) -> String:
	var dims := dimensions(item)
	var lines := "%s · %s\n占格 %d × %d  /  %s\n" % [item.name,QUALITY[int(item.quality)],dims.x,dims.y,SLOT_NAMES.get(item.slot,"材料" if item.slot=="material" else "补给")]
	if item.slot in SLOTS:
		lines+="装备阶级 %d  ·  强化 +%d / 5\n" % [item.tier,item.upgrade]
		if item.slot=="blade": lines+="伤害 +%d\n" % (power(item)*11)
		elif item.slot=="armor": lines+="生命 +%d · 减伤 %d\n" % [power(item)*18,power(item)*2]
		else: lines+="伤害 +%d · 技能冷却 -%.2f秒\n" % [power(item)*3,power(item)*0.15]
		lines+="额外伤害 +%d · 额外生命 +%d\n" % [item.get("bonus_damage",0),item.get("bonus_hp",0)]
		lines+="导光镶嵌："+("伤害 +8 / 生命 +12" if item.get("socket",false) else "未镶嵌")+"\n"
		lines+="适用："+("所有守望者" if int(BASES[item.base].get("hero",-1))<0 else HEROES[int(BASES[item.base].hero)])+"\n"
	elif item.base=="potion": lines+="使用一瓶恢复 50% 最大生命；生命全满时补入药剂栏（上限15）。\n"
	elif item.base=="scrap": lines+="使用整堆加入锻造材料钱包；铁匠也可直接消耗背包铁料。\n"
	else: lines+="镶嵌单件装备，消耗一枚晶石；每件只能镶嵌一次。\n"
	return lines+"出售整堆：%d 银币" % sale_price(item)

func make(base: String, tier: int = 1, quality: int = 0, count: int = 1) -> Dictionary:
	var s: Dictionary=campaign.state
	s.item_serial=int(s.get("item_serial",0))+1
	var b: Dictionary=BASES[base]
	return {"uid":"item-%d" % s.item_serial,"base":base,"name":b.name,"slot":b.slot,"tier":maxi(1,tier),"quality":clampi(quality,0,2),"count":clampi(count,1,int(b.get("stack",1))),"upgrade":0,"socket":false,"bonus_damage":quality*(2+tier),"bonus_hp":quality*(3+tier*2),"x":0,"y":0,"rotated":false}

func normalize(item: Dictionary) -> Dictionary:
	var base: String=str(item.get("base",""))
	if not BASES.has(base): base={"blade":"sword","armor":"plate","charm":"ruby"}.get(str(item.get("slot","blade")),"sword")
	var result := make(base,int(item.get("tier",1)),clampi(int(item.get("quality",0)),0,2),int(item.get("count",1)))
	for key in result:
		if item.has(key) and typeof(item[key])==typeof(result[key]): result[key]=item[key]
		elif item.has(key) and result[key] is int and (item[key] is int or item[key] is float): result[key]=int(item[key])
	result.base=base; result.slot=BASES[base].slot; result.tier=clampi(int(result.tier),1,20)
	result.upgrade=clampi(int(result.upgrade),0,5); result.quality=clampi(int(result.quality),0,2)
	result.count=clampi(int(result.count),1,int(BASES[base].get("stack",1)))
	result.bonus_damage=clampi(int(result.bonus_damage),0,100); result.bonus_hp=clampi(int(result.bonus_hp),0,200)
	return result

func initialize() -> void:
	var s: Dictionary=campaign.state
	if int(s.get("items_revision",0))>=1: return
	s["item_serial"]=int(s.get("item_serial",0)); s["equipment"]=[{},{},{}]
	s["buyback"]=[]; s["merchant_stock"]={}; s["overflow"]=[]
	for hero in 3:
		for slot in SLOTS:
			var rank := int(s.kits[hero].get(slot,0))
			if rank<=0: continue
			var base: String=(["sword","staff","dagger"][hero] if slot=="blade" else ["plate","robe","coat"][hero] if slot=="armor" else "ruby")
			s.equipment[hero][slot]=make(base,rank)
	var incoming: Array=[]
	for container in ["bag","stash"]:
		var originals: Array=s[container].duplicate(true); s[container]=[]
		for raw in originals:
			var item := normalize(raw)
			if not insert(s[container],item,bounds(container)): incoming.append(item)
	for item in incoming:
		if not insert(s.stash,item,VAULT): s.overflow.append(item)
	s["items_revision"]=1
	sync_gear()

func sync_gear() -> void:
	var s: Dictionary=campaign.state
	for hero in 3:
		for slot in SLOTS: s.kits[hero][slot]=power(s.equipment[hero].get(slot,{}))
	s.gear=s.kits[int(s.hero)]

func restore_numeric() -> void:
	# JSON numbers are floats; canonicalize saved instances without allocating new ids.
	for container in ["bag","stash","overflow","buyback"]:
		for item in campaign.state[container]: canonical_numbers(item)
	for worn in campaign.state.equipment:
		for item in worn.values(): canonical_numbers(item)
	for products in campaign.state.merchant_stock.values():
		for item in products: canonical_numbers(item)
	sync_gear()

static func canonical_numbers(item: Dictionary) -> void:
	for key in ["tier","quality","upgrade","count","bonus_damage","bonus_hp","x","y","stock","repurchase"]:
		if item.has(key): item[key]=int(item[key])

func bonus(stat: String, hero: int = -1) -> int:
	initialize()
	hero=int(campaign.state.hero) if hero<0 else hero
	var total := 0
	for item in campaign.state.equipment[hero].values():
		total+=int(item.get("bonus_"+stat,0))+(8 if stat=="damage" else 12 if stat=="hp" else 0) if item.get("socket",false) else int(item.get("bonus_"+stat,0))
	return total

static func valid_data(s: Dictionary) -> bool:
	if int(s.get("items_revision",0))==0: return true
	if int(s.get("items_revision",0))!=1 or not s.get("equipment") is Array or s.equipment.size()!=3: return false
	var seen: Dictionary={}
	for container in ["bag","stash","overflow","buyback"]:
		if not s.get(container) is Array: return false
		var checked: Array=[]
		for item in s[container]:
			if not valid_item(item,seen): return false
			if container=="buyback":
				if not item.get("repurchase") is int and not item.get("repurchase") is float: return false
				if int(item.repurchase)!=sale_price(item): return false
			if container in ["bag","stash"] and not fits(checked,item,bounds(container)): return false
			checked.append(item)
	for hero in 3:
		if not s.equipment[hero] is Dictionary: return false
		for slot in s.equipment[hero]:
			var item: Variant=s.equipment[hero][slot]
			if not slot in SLOTS or not valid_item(item,seen) or item.slot!=slot: return false
			if int(BASES[item.base].get("hero",-1))>=0 and int(BASES[item.base].hero)!=hero: return false
	if not s.get("merchant_stock") is Dictionary: return false
	for act in s.merchant_stock:
		if not str(act) in ["1","2","3","4","5","6"] or not s.merchant_stock[act] is Array: return false
		for product in s.merchant_stock[act]:
			if not valid_item(product,seen) or not product.get("stock") is float and not product.get("stock") is int: return false
			if int(product.stock)<0 or int(product.stock)>25: return false
	for uid in seen:
		if not str(uid).begins_with("item-") or not str(uid).trim_prefix("item-").is_valid_int() or int(str(uid).trim_prefix("item-"))>int(s.get("item_serial",0)): return false
	return true

static func valid_item(item: Variant, seen: Dictionary) -> bool:
	if not item is Dictionary or not item.get("uid") is String or not item.get("name") is String: return false
	if item.uid=="" or seen.has(item.uid) or not BASES.has(str(item.get("base",""))): return false
	if item.get("slot")!=BASES[item.base].slot: return false
	for field in ["tier","quality","upgrade","count","bonus_damage","bonus_hp","x","y"]:
		if not item.get(field) is int and not item.get(field) is float: return false
	if not item.get("rotated") is bool or not item.get("socket") is bool: return false
	if int(item.tier)<1 or int(item.tier)>20 or int(item.quality)<0 or int(item.quality)>2 or int(item.upgrade)<0 or int(item.upgrade)>5: return false
	if int(item.count)<1 or int(item.count)>int(BASES[item.base].get("stack",1)): return false
	if int(item.bonus_damage)<0 or int(item.bonus_damage)>100 or int(item.bonus_hp)<0 or int(item.bonus_hp)>200: return false
	seen[item.uid]=true; return true

func finish(message: String) -> bool:
	last_message=message; sync_gear(); campaign.state.hp=minf(campaign.state.hp,campaign.max_hp())
	campaign.changed.emit(); campaign.save_campaign(); return true

func fail(message: String) -> bool: last_message=message; return false

func receive(item: Dictionary) -> void:
	initialize()
	if not insert(campaign.state.bag,item,BAG) and not insert(campaign.state.stash,item,VAULT): campaign.state.overflow.append(item.duplicate(true))

func item_at(source: String, uid: String) -> Dictionary:
	initialize()
	if source.begins_with("equipped:"):
		var parts := source.split(":")
		var item: Dictionary=campaign.state.equipment[int(parts[1])].get(parts[2],{})
		return item if str(item.get("uid",""))==uid else {}
	if not source in ["bag","stash","overflow","buyback"]: return {}
	var i := find(campaign.state[source],uid)
	return campaign.state[source][i] if i>=0 else {}

func plan_move(source: String, uid: String, target: String, at: Vector2i, rotated: bool) -> Dictionary:
	var item := item_at(source,uid)
	if item.is_empty() or not target in ["bag","stash"]: return {}
	if (source!="bag" or target!="bag") and int(campaign.state.stage)!=0: return {}
	var containers := {"bag":campaign.state.bag.duplicate(true),"stash":campaign.state.stash.duplicate(true),"overflow":campaign.state.overflow.duplicate(true)}
	var copy := item.duplicate(true); copy.x=at.x; copy.y=at.y; copy.rotated=rotated
	if source in containers: containers[source].remove_at(find(containers[source],uid))
	elif not source.begins_with("equipped:"): return {}
	# Exact drop cell, including exact-cell stack merging.
	for other in containers[target]:
		if rect(other).has_point(at) and other.base==copy.base and int(BASES[copy.base].get("stack",1))>1:
			var total := int(other.count)+int(copy.count)
			if total>int(BASES[copy.base].stack): return {}
			other.count=total; return containers
	if not fits(containers[target],copy,bounds(target)): return {}
	containers[target].append(copy); return containers

func move(source: String, uid: String, target: String, at: Vector2i, rotated: bool = false) -> bool:
	var planned := plan_move(source,uid,target,at,rotated)
	if planned.is_empty(): return fail("这里放不下，或需要回营地操作仓库。")
	for key in planned: campaign.state[key]=planned[key]
	if source.begins_with("equipped:"):
		var parts := source.split(":"); campaign.state.equipment[int(parts[1])].erase(parts[2])
	return finish("物品已移动。")

func transfer(source: String, uid: String, target: String) -> bool:
	if int(campaign.state.stage)!=0: return fail("仓库仅在营地可用。")
	var item := item_at(source,uid)
	if item.is_empty() or not source in ["bag","stash","overflow"] or not target in ["bag","stash"] or source==target: return fail("无效移动。")
	var planned: Array=campaign.state[target].duplicate(true)
	if not insert(planned,item,bounds(target)): return fail("目标容器空间不足。")
	campaign.state[target]=planned; campaign.state[source].remove_at(find(campaign.state[source],uid))
	return finish("已取回行囊。" if target=="bag" else "已存入仓库。")

func can_equip(source: String, uid: String, hero: int, slot: String) -> bool:
	if hero<0 or hero>2: return false
	var item := item_at(source,uid)
	if item.is_empty() or not source=="bag" or item.slot!=slot or not slot in SLOTS: return false
	var required := int(BASES[item.base].get("hero",-1))
	if required>=0 and required!=hero: return false
	var planned: Array=campaign.state.bag.duplicate(true)
	planned.remove_at(find(planned,uid))
	var old: Dictionary=campaign.state.equipment[hero].get(slot,{})
	return old.is_empty() or insert(planned,old,BAG)

func equip(source: String, uid: String, hero: int = -1, slot: String = "") -> bool:
	initialize(); hero=int(campaign.state.hero) if hero<0 else hero
	var item := item_at(source,uid); slot=str(item.get("slot","")) if slot=="" else slot
	if hero<0 or hero>2 or not can_equip(source,uid,hero,slot): return fail("角色或槽位不匹配，或行囊放不下换下的装备。")
	var planned: Array=campaign.state.bag.duplicate(true)
	planned.remove_at(find(planned,uid))
	var old: Dictionary=campaign.state.equipment[hero].get(slot,{})
	if not old.is_empty() and not insert(planned,old,BAG): return fail("无法容纳换下的装备，换装已取消。")
	campaign.state.bag=planned; campaign.state.equipment[hero][slot]=item.duplicate(true)
	return finish("%s已装备%s。" % [HEROES[hero],item.name])

func unequip(hero: int, slot: String) -> bool:
	initialize(); var item: Dictionary=campaign.state.equipment[hero].get(slot,{})
	if item.is_empty(): return fail("这个装备位为空。")
	var planned: Array=campaign.state.bag.duplicate(true)
	if not insert(planned,item,BAG): return fail("行囊没有足够空间，装备保留在身上。")
	campaign.state.bag=planned; campaign.state.equipment[hero].erase(slot)
	return finish("装备已卸入行囊。")

func tidy(container: String) -> bool:
	initialize()
	if not container in ["bag","stash"] or (container=="stash" and int(campaign.state.stage)!=0): return fail("无法整理这个容器。")
	var candidates: Array=campaign.state[container].duplicate(true)
	candidates.sort_custom(func(a,b): return dimensions(a).x*dimensions(a).y>dimensions(b).x*dimensions(b).y)
	var planned: Array=[]
	for item in candidates:
		if not insert(planned,item,bounds(container)): return fail("现有布局较紧凑，保留原位置。")
	campaign.state[container]=planned; return finish("已按物品体积整理；没有丢弃物品。")

func rotate(source: String, uid: String) -> bool:
	var item := item_at(source,uid)
	if item.is_empty(): return fail("请先选择物品。")
	return move(source,uid,source,Vector2i(int(item.x),int(item.y)),not bool(item.rotated))

func use(uid: String) -> bool:
	var item := item_at("bag",uid)
	if item.is_empty(): return fail("物品已经移动。")
	if item.base=="potion":
		if campaign.state.hp>=campaign.max_hp() and campaign.state.potions>=15: return fail("生命与药剂栏都已满。")
		if campaign.state.hp<campaign.max_hp(): campaign.state.hp=minf(campaign.max_hp(),campaign.state.hp+campaign.max_hp()*0.5)
		else: campaign.state.potions+=1
		item.count-=1
		if item.count==0: campaign.state.bag.remove_at(find(campaign.state.bag,uid))
		campaign.audio_cue.emit("heal")
	elif item.base=="scrap": campaign.state.materials+=int(item.count); campaign.state.bag.remove_at(find(campaign.state.bag,uid))
	else: return fail("晶石在铁匠处用于镶嵌。")
	return finish("已使用%s。" % item.name)

func count(base: String) -> int:
	initialize(); var total := 0
	for item in campaign.state.bag:
		if item.base==base: total+=int(item.count)
	return total

func consume(base: String, amount: int) -> void:
	for i in range(campaign.state.bag.size()-1,-1,-1):
		var item: Dictionary=campaign.state.bag[i]
		if item.base!=base: continue
		var taken := mini(amount,int(item.count)); item.count-=taken; amount-=taken
		if item.count==0: campaign.state.bag.remove_at(i)
		if amount==0: break

func stock() -> Array:
	initialize(); var act := str(campaign.state.act)
	if not campaign.state.merchant_stock.has(act):
		var products: Array=[]
		for base in BASES:
			var item := make(base,int(campaign.state.act),1 if BASES[base].slot in SLOTS else 0)
			item["stock"]=3 if BASES[base].slot in SLOTS else 25
			products.append(item)
		campaign.state.merchant_stock[act]=products
	return campaign.state.merchant_stock[act]

func buy(uid: String, buy_back: bool = false) -> bool:
	if int(campaign.state.stage)!=0: return fail("请回营地与商人交易。")
	var products: Array=campaign.state.buyback if buy_back else stock()
	var index := find(products,uid)
	if index<0: return fail("商品已不在货架上。")
	var product: Dictionary=products[index]
	if not buy_back and int(product.stock)<=0: return fail("该商品已售罄。")
	var cost := int(product.get("repurchase",sale_price(product))) if buy_back else price(product)
	if campaign.state.coins<cost: return fail("银币不足。")
	var item := product.duplicate(true); item.erase("stock"); item.erase("repurchase")
	if not buy_back:
		# Only allocate a new instance once the transaction can succeed.
		item.uid="item-%d" % (int(campaign.state.item_serial)+1); item.count=1
	var planned: Array=campaign.state.bag.duplicate(true)
	if not insert(planned,item,BAG): return fail("行囊没有足够空间，未扣款。")
	campaign.state.coins-=cost; campaign.state.bag=planned
	if buy_back: products.remove_at(index)
	else: campaign.state.item_serial+=1; product.stock-=1
	return finish("已回购%s。" % item.name if buy_back else "购入%s，支付%d银币。" % [item.name,cost])

func sell(uid: String) -> bool:
	if int(campaign.state.stage)!=0: return fail("请回营地交易。")
	var item := item_at("bag",uid)
	if item.is_empty(): return fail("请在行囊选择出售的物品。")
	var sold := item.duplicate(true); sold["repurchase"]=sale_price(item)
	campaign.state.coins+=int(sold.repurchase); campaign.state.bag.remove_at(find(campaign.state.bag,uid))
	campaign.state.buyback.push_front(sold)
	if campaign.state.buyback.size()>12: campaign.state.buyback.resize(12)
	return finish("已出售整堆%s，获得%d银币（可回购）。" % [item.name,sold.repurchase])

func forge_cost(item: Dictionary) -> Dictionary:
	return {"coins":50+int(item.get("tier",1))*20+int(item.get("upgrade",0))*50,"materials":3+int(item.get("upgrade",0))*2}

func craft(base: String) -> bool:
	if int(campaign.state.stage)!=0 or not BASES.has(base) or not BASES[base].slot in SLOTS: return fail("请在营地铁匠处选择打造配方。")
	var tier := int(campaign.state.act)
	var coins := 90+tier*35; var materials := 6+tier*2
	if campaign.state.coins<coins or int(campaign.state.materials)+count("scrap")<materials: return fail("打造需要%d银币与%d铁料。" % [coins,materials])
	var serial := int(campaign.state.item_serial)
	var result := make(base,tier,1)
	var planned: Array=campaign.state.bag.duplicate(true)
	if not insert(planned,result,BAG):
		campaign.state.item_serial=serial; return fail("行囊放不下成品；未扣除材料或银币。")
	campaign.state.bag=planned
	var wallet := mini(int(campaign.state.materials),materials)
	campaign.state.materials-=wallet; consume("scrap",materials-wallet); campaign.state.coins-=coins
	campaign.audio_cue.emit("chest"); return finish("已打造%s（附魔阶级%d）。" % [result.name,tier])

func forge(source: String, uid: String, action: String) -> bool:
	if int(campaign.state.stage)!=0: return fail("锻造需要回到营地。")
	var item := item_at(source,uid)
	if item.is_empty() or not item.slot in SLOTS or not (source=="bag" or source.begins_with("equipped:")): return fail("请选择行囊或身上的装备。")
	if action=="upgrade":
		if int(item.upgrade)>=5: return fail("这件装备已达到强化上限 +5。")
		var cost := forge_cost(item)
		if campaign.state.coins<cost.coins or int(campaign.state.materials)+count("scrap")<cost.materials: return fail("银币或铁料不足；不会扣除任何资源。")
		var wallet := mini(int(campaign.state.materials),int(cost.materials))
		campaign.state.materials-=wallet; consume("scrap",int(cost.materials)-wallet); campaign.state.coins-=cost.coins; item.upgrade+=1
	elif action=="socket":
		if item.socket: return fail("该装备已经镶嵌。")
		if count("crystal")<1 or campaign.state.coins<80: return fail("需要80银币及行囊中的一枚导光晶石。")
		consume("crystal",1); campaign.state.coins-=80; item.socket=true
	elif action=="salvage":
		if source!="bag": return fail("请先卸下装备再分解。")
		campaign.state.materials+=2+int(item.tier)+int(item.quality)*2+int(item.upgrade)
		campaign.state.bag.remove_at(find(campaign.state.bag,uid))
	else: return fail("未知锻造操作。")
	campaign.audio_cue.emit("chest"); return finish({"upgrade":"装备强化完成。","socket":"导光镶嵌完成。","salvage":"已分解装备并回收铁料。"}[action])
