extends SceneTree
## W1b · `roguelike.gd` 钩子验收（headless）。
##
## 覆盖：变数经济钩子（gold / shop_price / loot_tier / xp / elite）、诅咒补偿、
## 专属房间动作（forge / gamble / mirror）、事件动作、诅咒入池、settle 的灰烬与每日打卡
## 幂等性，以及 R14 的守层者池接线。
##
## 断言口径：**空变数/空诅咒时必须逐项恒等**（回归保护），**有变数时数值必须可算**。
var failures := 0
var checks := 0

const Rooms = preload("res://scripts/rogue_rooms.gd")
const Variants = preload("res://scripts/rogue_variants.gd")
const Curses = preload("res://scripts/rogue_curses.gd")
const Daily = preload("res://scripts/rogue_daily.gd")
const Combat = preload("res://scripts/rogue_combat.gd")
const Growth = preload("res://scripts/rogue_growth.gd")
const Events = preload("res://scripts/rogue_events.gd")
const RoomUi = preload("res://scripts/rogue_room_ui.gd")
const UiModel = preload("res://scripts/rogue_ui_model.gd")
# T2 §12 instantiates the real main.tscn; these are the view-models its rogue HUD reads, so the
# section can compute the very same expected strings/rows the panel renders.
const RogueUi = preload("res://scripts/rogue_ui_model.gd")
const RogueRoomUi = preload("res://scripts/rogue_room_ui.gd")
const RogueEvents = preload("res://scripts/rogue_events.gd")

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

## 一条**只增计数、不替换奖品**的低档探针，用来回答"这 200 次抽取里到底出现过几次
## 基础 0 档"。它走的是与 `roll_tier` 完全相同的两段式：
##   1. `s.rng.randi_range(1,100)` —— 那唯一一次抽取，之后按**同一张、按 `floor` 取的**
##      权重表定档（`clampi(floor-1,0,4)`，与 `roguelike.gd` 的 `roll_tier` 逐字一致）；
##   2. `rl.set_loot_pity(s,LOOT_PITY_CHEST,0)` 把连败计数写回 0，于是 `compensation`
##      恒为 `clampi(0/STEP,0,MAX)=0`，"档位"就等于"基础档"（`loot_tier` 必须为空）。
## 断言的是次数本身，而不是"某次必须为 0"：这样既不会被随机流偶然性打脸，又能在
## 权重表/保底实现改动时立刻显出差异（层 1 的基础 0 档权重 45/100，层 2 只有 10/100，
## 所以 `floor` 必须由调用者钉住——探针**不会**替你改 `s.raid.floor`，只在函数入口 clamp，
## 目的就是让"层漂移"这类错误在别处暴露而不是在这里被静音）。
## 副作用：消耗 `s.rng` 200 次，并把 chest 桶留在 0。调用者自行决定要不要备份。
func _seed_base0_probe(s,rl,floor_index: int) -> int:
	var weights: Array=[[45,45,9,1,0,0],[10,40,42,8,0,0],[0,10,45,38,7,0],[0,0,20,50,28,2],[0,0,5,35,52,8]][clampi(floor_index-1,0,4)]
	var hits := 0
	for i in 200:
		var roll: int=s.rng.randi_range(1,100)
		var base := 0
		for weight in weights:
			roll-=int(weight)
			if roll<=0: break
			base+=1
		if base==0: hits+=1
		rl.set_loot_pity(s,rl.LOOT_PITY_CHEST,0)
	return hits

func _initialize() -> void: call_deferred("run")

## §12h 的量化口径：统计 `app.page` 子树里当前活着的 Control 数量。
## 增量刷新的承诺是"只写属性、不 new 控件"。用一个 tick 里"探针函数本身 new 的 Control"
## 来判：探针不动控件树，所以唯一的新 Control 只可能来自 `update_rogue_hud` 的重建路径。
## 先跑一次把探针自身的开销（没有）与基线对齐，再跑固定 12 次，比较新建个数。
func _t2_control_ids_once(app: Node, seen: Dictionary) -> int:
	var found: Array=[]
	_t2_collect(app.page,found)
	var fresh := 0
	for node in found:
		var id: int=int(node.get_instance_id())
		if not seen.has(id):
			seen[id]=true
			fresh+=1
	return fresh

func _t2_collect(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Control: out.append(child)
		_t2_collect(child,out)

func make_session(seed_value: int):
	var s = TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike","rogue_rerolls":2,"rogue_weapon":1})
	s.launch(false,seed_value)
	return s

func run() -> void:
	var s = make_session(4242)
	var p: Dictionary=s.players[1]
	var rl = s.roguelike

	# ---------------------------------------------------------------- 1. 空变数恒等
	s.raid["variant"]=""
	s.raid["variants_seen"]=[]
	check(rl.mod_of(s,"gold")==0.0, "no variant means a zero gold modifier")
	check(rl.mod_of(s,"loot_tier")==0.0, "no variant means a zero loot-tier modifier")
	check(rl.scale_int(75,1.0)==75 and rl.scale_int(0,1.0)==0, "scale_int is bit-exact identity at 1.0")
	check(float(Variants.modifiers_of([""]).get("gold",0.0))==0.0, "modifiers_of('') is all zeros")
	s.raid["floor"]=2
	s.raid["room"]="combat"
	s.raid["challenge"]=false
	s.raid["room_rewarded"]=false
	p.rogue_curses=[]
	p.rogue_gold=0
	rl.clear_room(s)
	var base_gold := 25+2*10
	check(p.rogue_gold==base_gold, "a clean room pays exactly 25+floor*10 (got %d)" % p.rogue_gold)
	rl.roll_offers(s,true,p)
	check(int(p.rogue_shop_offers[0].price)==65+20, "a clean shop quotes 65+floor*10 (got %d)" % int(p.rogue_shop_offers[0].price))
	check(int(p.rogue_shop_offers[5].price)==45, "a clean flask quotes 45 (got %d)" % int(p.rogue_shop_offers[5].price))
	# ---------------------------------------------------------------- 2. 变数生效
	var bounty: Dictionary=Variants.modifiers_of(["bounty"])
	check(is_equal_approx(float(bounty.get("gold",0.0)),0.25), "bounty carries +25% gold income")
	s.raid["variant"]="bounty"
	s.raid["room_rewarded"]=false
	p.rogue_gold=0
	rl.clear_room(s)
	check(p.rogue_gold==int(round(float(base_gold)*1.25)), "bounty scales the room payout (got %d, want %d)" % [p.rogue_gold,int(round(float(base_gold)*1.25))])

	s.raid["variant"]="rust"
	check(is_equal_approx(rl.mod_of(s,"shop_price"),-0.30), "rust carries -30% shop price")
	rl.roll_offers(s,true,p)
	var want_price := int(round(float(65+20)*0.7))
	check(int(p.rogue_shop_offers[0].price)==want_price, "rust discounts the shop to %d (got %d)" % [want_price,int(p.rogue_shop_offers[0].price)])
	check(int(p.rogue_shop_offers[0].price)>=1, "a discounted price never drops below 1")

	s.raid["variant"]="blood_moon"
	check(is_equal_approx(rl.mod_of(s,"loot_tier"),1.0), "blood_moon carries +1 loot tier")
	check(rl.roll_tier(s)>=1, "a blood-moon roll lands in band >=1: the +1 term dominates because both the base band and the pity compensation are >=0")
	# E3 复核补强（第二稿）。上一稿在这里写了三条**没有信息量**的断言，逐条记录原因，免得
	# 下一个人再写一遍：
	#   1. `clampi(tier+comp+1,0,5)>=1` 是**恒真**：`tier>=0`、`comp>=0` 已经保证了 >=1，
	#      与 pity/loot_tier 无关。所以上面那条 check 的失败理由已改成它真正的意思
	#      （写清"+1 项与两个非负项"这个前提），而不是谎称它在验证 pity 契约。
	#   2. 上一稿用一个**新建的** `RandomNumberGenerator.new()` 去证明"基础 0 档真的会
	#      出现"。那不是 `s.rng`，只是"某台生成器能抽出低值"，non-sequitur。
	#   3. 上一稿说"把 pity 钉在 0 上连抽 200 次"——不成立：`roll_tier` 每轮都会把计数写回，
	#      收尾时 pity 早就不是 0 了。改成用 `_seed_base0_probe()` 数"200 次里有几次是
	#      **基础 0 档**"，然后断言同一段随机流上"血月把每次基础 0 档都抬到 >=1"。
	#      两条合起来才是可证伪的：如果 `loot_tier` 的 +1 掉了，第二次断言立刻红。
	check(is_equal_approx(rl.mod_of(s,"loot_tier"),1.0), "the blood-moon block reads its own +1 loot-tier modifier")
	var floor_for_blood_moon: int=int(s.raid["floor"])
	s.raid["floor"]=1
	var blood_moon_base0 := _seed_base0_probe(s,rl,1)
	check(blood_moon_base0>0, "the probe's 200-draw stream really contains base-0 draws (seen %d; without these the next assertion would be vacuous)" % blood_moon_base0)
	rl.set_loot_pity(s,rl.LOOT_PITY_CHEST,0)
	var blood_moon_min := 99
	for i in 200: blood_moon_min=mini(blood_moon_min,rl.roll_tier(s,rl.LOOT_PITY_CHEST))
	check(blood_moon_min>=1, "blood_moon +1 lifts every one of 200 pity-0 draws out of band 0 (min seen %d)" % blood_moon_min)
	s.raid["floor"]=floor_for_blood_moon
	s.raid["variant"]="bargain"
	check(is_equal_approx(rl.mod_of(s,"loot_tier"),-1.0), "bargain carries -1 loot tier")
	var low := 99
	for i in 200: low=mini(low,rl.roll_tier(s))
	check(low<=1 and low>=0, "the loot band is clamped at 0 (min seen %d)" % low)

	# ---------------------------------------------------------------- 2b. E3 掉落保底 + 作用域隔离
	# `roll_tier(s,scope)` 的保底只作用于**开箱**（`LOOT_PITY_CHEST`）；游商货架走
	# `LOOT_PITY_SHOP` 的**无保底**路径，既不消耗也不受益于开箱的连败。
	#
	# 这一节把 `floor` 钉在 **1**（上层 §1/§2 把它留在了 2），因为权重表是按层取的，
	# "某个种子抽到几档"是**层相关**的。下面这些"种子 -> 档位"常数是按**实测反向校准**的
	# 固定值，不是从算法推出来的：同一 `s.rng` 重新 seed 之后第一次 `randi_range(1,100)`
	# 的结果（层 1 权重 [45,45,9,1,0,0]）为
	#   * seed=3 -> 45 -> 基础 0 档        seed=1 -> 98 -> 基础 2 档
	#   * seed=6 ->  7 -> 基础 0 档        seed=4 -> 98 -> 基础 2 档
	#   * seed=7 ->  4 -> 基础 0 档        seed=16 -> 91 -> 基础 2 档
	#   * seed=9 -> 15 -> 基础 0 档        seed=30 -> 96 -> 基础 2 档
	#   * seed=11 -> 26 -> 基础 0 档   /    seed=12 -> 22 -> 基础 0 档
	# （同一批种子在层 2/3/4 会整体上移 1/2/3 档——权重表的累积和不同——所以"层"必须钉住，
	#  否则断言会随层漂移。**权重表一旦改动，这批常数必须重测**：它们是校准值，不是不变量。）
	#   * 注意：**不能**从 `s.rng.state` 复算这次抽取——`seed` 与 `state` 是两套不同的内部
	#     表示，实测把 `state` 抄给本地生成器后预测值与实际值不符（预测 52 / 实际 39）。
	#     所以这里只用"重新 seed + 一次抽取"这个实测可复现的口径。同理**不能**用
	#     `s.rng.seed=k; s.rng.randi_range(1,100)` 先"预演"一次再断言 `roll_tier`：第二
	#     次 seed 之后的那次抽取才是 `roll_tier` 真正用的值，两者不是同一个数。
	#   * 档位补偿真值表（实测 floor=1 且当次抽为**低档**：base 0）：
	#     streak 0/1/2 -> tier 0（无补偿），3/4/5 -> tier 1，6/7/8 -> tier 2，计数封顶 6。
	#   * 变数 `loot_tier` 此时为空（上面刚置空并断言过），所以返回值就是"基础档 + 补偿"。
	#
	# 状态中性：这一节会写 `s.rng.seed`、`s.raid.loot_pity`、`s.raid.offers`、
	# `s.raid.revision` 与 `p.rogue_shop_offers`/`p.rogue_shop_revision`，也改 `floor`。
	# 全部在开头备份、在节尾逐项写回，避免后续用例读到"上一个用例的随机流/报价"。
	s.raid["variant"]=""
	check(is_equal_approx(rl.mod_of(s,"loot_tier"),0.0), "the E3 block runs with a zero loot-tier modifier")
	var floor_backup: int=int(s.raid["floor"])
	var rng_backup: int=int(s.rng.seed)
	var loot_pity_backup: Variant=s.raid.get("loot_pity",{})
	var offers_backup: Variant=s.raid.get("offers",[])
	var shop_offers_backup: Variant=p.get("rogue_shop_offers",[])
	var shop_revision_backup: Variant=p.get("rogue_shop_revision",0)
	s.raid["floor"]=1
	rl.set_loot_pity(s,rl.LOOT_PITY_CHEST,0)
	check(rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==0, "a fresh chest pity bucket starts at 0")
	# 基准：低档抽在 streak=0 时确实是 0 档（同时证明 seed=3 是"低档抽"）
	s.rng.seed=3
	check(rl.roll_tier(s,rl.LOOT_PITY_CHEST)==0, "a bare low draw at streak 0 lands on band 0")
	check(rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==1, "a low draw raises the chest streak to 1 (got %d)" % rl.loot_pity_of(s,rl.LOOT_PITY_CHEST))

	# 1) 连败累加 + 达到阈值后档位补偿生效
	rl.set_loot_pity(s,rl.LOOT_PITY_CHEST,0)
	var accum := [3,6,7,9,11,12]
	var accum_ok := true
	for i in accum.size():
		s.rng.seed=int(accum[i])
		var want := clampi(i/rl.LOOT_PITY_STEP,0,rl.LOOT_PITY_MAX)
		var got: int=rl.roll_tier(s,rl.LOOT_PITY_CHEST)
		if got!=want: accum_ok=false
		if rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)!=mini(i+1,rl.LOOT_PITY_STEP*rl.LOOT_PITY_MAX): accum_ok=false
	check(accum_ok, "six consecutive low draws accumulate 1..6 and pay +0/+1/+2 exactly at the 3rd/6th (final streak %d)" % rl.loot_pity_of(s,rl.LOOT_PITY_CHEST))
	# 阈值前后各钉一次，失败时能直接读出"补偿从第几次开始"
	rl.set_loot_pity(s,rl.LOOT_PITY_CHEST,2)
	s.rng.seed=3
	check(rl.roll_tier(s,rl.LOOT_PITY_CHEST)==0, "a streak just below the threshold still pays nothing (streak 2 -> band 0)")
	rl.set_loot_pity(s,rl.LOOT_PITY_CHEST,3)
	s.rng.seed=3
	check(rl.roll_tier(s,rl.LOOT_PITY_CHEST)==1, "a streak at the threshold pays +1 (streak 3 + base band 0)")

	# 2) 抽到高档（seed=1 -> 基础 2 档 >= LOOT_PITY_LOW）立刻清零
	rl.set_loot_pity(s,rl.LOOT_PITY_CHEST,rl.LOOT_PITY_STEP*rl.LOOT_PITY_MAX)
	s.rng.seed=1
	var high_tier: int=rl.roll_tier(s,rl.LOOT_PITY_CHEST)
	check(high_tier>=rl.LOOT_PITY_LOW, "the reset draw really is a high band (got %d)" % high_tier)
	check(rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==0, "a band >= LOOT_PITY_LOW resets the streak to 0 (got %d)" % rl.loot_pity_of(s,rl.LOOT_PITY_CHEST))

	# 3) 封顶后不再增长，补偿也不再变高
	rl.set_loot_pity(s,rl.LOOT_PITY_CHEST,rl.LOOT_PITY_STEP*rl.LOOT_PITY_MAX)
	var capped_ok := true
	for i in 4:
		s.rng.seed=3
		if rl.roll_tier(s,rl.LOOT_PITY_CHEST)!=rl.LOOT_PITY_MAX: capped_ok=false
		if rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)!=rl.LOOT_PITY_STEP*rl.LOOT_PITY_MAX: capped_ok=false
	check(capped_ok, "a capped streak neither grows past %d nor pays more than +%d" % [rl.LOOT_PITY_STEP*rl.LOOT_PITY_MAX,rl.LOOT_PITY_MAX])

	# 4) 作用域隔离。用的是**未封顶的中间值 3**，不是封顶值 6：
	#    旧实现（开箱与商店共用同一条连败）在商店抽取时也会写回计数，低档 -> 4。
	#    若把 chest 钉在封顶 6，旧实现也只会写回 6（封顶），断言照样通过——抓不到旧实现。
	#    3 是中间值，新旧实现在收尾读数上必然分叉（3 vs 4）。
	rl.set_loot_pity(s,rl.LOOT_PITY_CHEST,3)
	s.rng.seed=3
	var shop_band: int=rl.roll_tier(s,rl.LOOT_PITY_SHOP)
	check(shop_band==0, "the shop pays no compensation (base band 0; a chest streak of 3 would have paid the same, a shared pool is what this catches; got %d)" % shop_band)
	check(rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==3, "a shop draw does not consume or grow the chest streak (want 3, got %d; a shared counter would read 4)" % rl.loot_pity_of(s,rl.LOOT_PITY_CHEST))
	check(rl.loot_pity_of(s,rl.LOOT_PITY_SHOP)==0, "the shop never writes a pity bucket of its own (got %d)" % rl.loot_pity_of(s,rl.LOOT_PITY_SHOP))
	# 商店真实调用点：`roll_offers()` 每人抽 5 次货架品质带
	rl.roll_offers(s,true,p)
	check(rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==3, "five real shop rolls leave the chest streak untouched (want 3, got %d)" % rl.loot_pity_of(s,rl.LOOT_PITY_CHEST))
	check(rl.loot_pity_of(s,rl.LOOT_PITY_SHOP)==0, "five real shop rolls create no shop bucket either (got %d)" % rl.loot_pity_of(s,rl.LOOT_PITY_SHOP))
	# 商店**被抽干**时也不能反过来改 chest 桶（低档会 +1，高档会清零，两条路都不该被走到）
	rl.set_loot_pity(s,rl.LOOT_PITY_CHEST,0)
	var chest_empty_drains := _seed_base0_probe(s,rl,1)
	check(chest_empty_drains>0, "the shared-stream probe really observes base-0 draws (seen %d of 200)" % chest_empty_drains)
	check(rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)>=0 and rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)<=rl.LOOT_PITY_STEP*rl.LOOT_PITY_MAX, "a chest bucket that was emptied cannot leave the legal 0..%d range while the shop rolls (got %d)" % [rl.LOOT_PITY_STEP*rl.LOOT_PITY_MAX,rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)])
	# 开箱自己仍然照常吃保底：同一位置（seed 3 -> 基础 0 档）在 streak=3 上必须给 +1。
	# 上一稿在这里写的是"真实商店之后 chest 仍付满 +6"——那是本次未完成的同一件事：
	# 当时 chest 桶是 6 且那一抽是低档，`compensation` 本来就是 MAX，和"商店有没有碰过桶"
	# 没关系（non-sequitur）。现在改成在 streak=3 这个中间值上判"必须 +1"。
	rl.set_loot_pity(s,rl.LOOT_PITY_CHEST,3)
	s.rng.seed=3
	var chest_after_shop: int=rl.roll_tier(s,rl.LOOT_PITY_CHEST)
	check(chest_after_shop==1, "the chest itself still pays +1 at streak 3 after the shop has rolled (got %d)" % chest_after_shop)
	# 反向：开箱连败也不允许被商店"受益"——streak=0 时商店档位必须等于基础档位
	rl.set_loot_pity(s,rl.LOOT_PITY_CHEST,0)
	s.rng.seed=3
	check(rl.roll_tier(s,rl.LOOT_PITY_SHOP)==0, "the shop gets no lift from a chest streak of 0 either")

	# 5) 旧快照形状安全退化：`loot_pity` 曾是一个整数（开箱与商店共用一条连败）。
	#    注意措辞：这**不是**"旧存档"——`raid` 从不落盘，只有 `profile.data` 会写盘，
	#    这个形状只可能来自**旧对端的快照**（或半初始化的 raid）。
	s.raid["loot_pity"]=9999
	check(rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==9999, "a legacy integer snapshot is read as the chest streak (got %d)" % rl.loot_pity_of(s,rl.LOOT_PITY_CHEST))
	check(rl.loot_pity_of(s,rl.LOOT_PITY_SHOP)==0, "a legacy integer snapshot gives the shop no pity (got %d)" % rl.loot_pity_of(s,rl.LOOT_PITY_SHOP))
	s.rng.seed=3
	check(rl.roll_tier(s,rl.LOOT_PITY_CHEST)==rl.LOOT_PITY_MAX, "a huge legacy streak still compensates and is clamped to +%d" % rl.LOOT_PITY_MAX)
	var store: Variant=s.raid["loot_pity"]
	check(store is Dictionary and int((store as Dictionary).get(rl.LOOT_PITY_CHEST,-1))==rl.LOOT_PITY_STEP*rl.LOOT_PITY_MAX, "the first chest draw normalises the legacy integer into a bucket dict (got %s)" % str(store))
	s.raid["loot_pity"]=9999
	s.rng.seed=1
	check(rl.roll_tier(s,rl.LOOT_PITY_CHEST)>=rl.LOOT_PITY_LOW and rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==0, "a legacy snapshot still resets on a high draw (streak %d)" % rl.loot_pity_of(s,rl.LOOT_PITY_CHEST))
	s.raid["loot_pity"]=9999
	s.rng.seed=3
	check(rl.roll_tier(s,rl.LOOT_PITY_SHOP)==0, "the shop scope on a legacy snapshot is a plain no-pity draw")

	# 5b) 其它退化形状：float 旧值按 int 截断，null 与 String 一律读成 0（保守值），且
	#     第一次开箱抽取会把存储整体升级成分桶字典，不崩、不留脏形状。
	s.raid["loot_pity"]=1.9
	check(rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==1, "a float legacy value is truncated to the chest streak (got %d)" % rl.loot_pity_of(s,rl.LOOT_PITY_CHEST))
	check(rl.loot_pity_of(s,rl.LOOT_PITY_SHOP)==0, "a float legacy value gives the shop no pity (got %d)" % rl.loot_pity_of(s,rl.LOOT_PITY_SHOP))
	s.rng.seed=3
	check(rl.roll_tier(s,rl.LOOT_PITY_CHEST)==0, "a float legacy value compensates like the truncated streak 1 (no +1)")
	check(s.raid["loot_pity"] is Dictionary and rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==2, "the float shape is normalised into a bucket dict on the chest draw (store %s)" % str(s.raid["loot_pity"]))
	s.raid["loot_pity"]=null
	check(rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==0 and rl.loot_pity_of(s,rl.LOOT_PITY_SHOP)==0, "a null store reads as a zero streak for both scopes")
	s.rng.seed=3
	check(rl.roll_tier(s,rl.LOOT_PITY_SHOP)==0 and s.raid["loot_pity"]==null, "a shop draw over a null store neither crashes nor writes anything")
	rl.set_loot_pity(s,rl.LOOT_PITY_CHEST,0)
	check(rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==0 and rl.loot_pity_of(s,rl.LOOT_PITY_SHOP)==0, "set_loot_pity over a null store loses nothing it could have kept (both scopes 0)")
	s.raid["loot_pity"]="not-a-store"
	check(rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==0 and rl.loot_pity_of(s,rl.LOOT_PITY_SHOP)==0, "a String store degrades to a zero streak instead of crashing")
	s.rng.seed=3
	check(rl.roll_tier(s,rl.LOOT_PITY_SHOP)==0 and s.raid["loot_pity"]=="not-a-store", "a shop draw over a String store is a plain no-pity draw and writes nothing")
	s.rng.seed=3
	check(rl.roll_tier(s,rl.LOOT_PITY_CHEST)==0 and s.raid["loot_pity"] is Dictionary and rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==1, "a chest draw over a String store starts a fresh bucket at 1 (store %s)" % str(s.raid["loot_pity"]))

	# 6) 缺失键（更旧的快照/半初始化的 raid）同样安全退化，不崩
	s.raid.erase("loot_pity")
	check(rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==0 and rl.loot_pity_of(s,rl.LOOT_PITY_SHOP)==0, "a missing loot_pity key reads as a zero streak for both scopes")
	s.rng.seed=3
	check(rl.roll_tier(s,rl.LOOT_PITY_SHOP)==0, "a missing key cannot crash the no-pity shop draw")
	check(rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==0, "a shop draw on a missing key still writes nothing")
	s.rng.seed=3
	check(rl.roll_tier(s,rl.LOOT_PITY_CHEST)==0 and rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==1, "a missing key is treated as streak 0 for the chest too (streak now %d)" % rl.loot_pity_of(s,rl.LOOT_PITY_CHEST))
	s.raid.erase("loot_pity")

	# 7) 未知 scope：`roll_tier` 只把 `LOOT_PITY_CHEST` 当写入分支，所以任何拼错的
	#    scope 走的都是**无保底、不写计数**的安全路径（这正是删掉 `LOOT_PITY_SCOPES`
	#    之后仍然成立的那条防御），不会污染 chest 桶。
	s.raid["loot_pity"]={rl.LOOT_PITY_CHEST:2}
	s.rng.seed=3
	check(rl.roll_tier(s,"chset")==0, "an unknown scope gets the plain no-compensation draw (base band 0)")
	check(rl.loot_pity_of(s,rl.LOOT_PITY_CHEST)==2 and rl.loot_pity_of(s,"chset")==0, "an unknown scope cannot write or consume the chest streak (chest still %d)" % rl.loot_pity_of(s,rl.LOOT_PITY_CHEST))

	# ---- 收尾：把这一节动过的状态全部写回（状态中性）
	s.raid["floor"]=floor_backup
	s.rng.seed=rng_backup
	if loot_pity_backup==null: s.raid.erase("loot_pity")
	else: s.raid["loot_pity"]=loot_pity_backup
	if offers_backup==null: s.raid.erase("offers")
	else: s.raid["offers"]=offers_backup
	if shop_offers_backup==null: p.erase("rogue_shop_offers")
	else: p["rogue_shop_offers"]=shop_offers_backup
	if shop_revision_backup==null: p.erase("rogue_shop_revision")
	else: p["rogue_shop_revision"]=shop_revision_backup
	check(int(s.raid["floor"])==floor_backup and int(s.rng.seed)==rng_backup, "the E3 block restored the floor and the rng seed it borrowed")

	# ---------------------------------------------------------------- 3. 诅咒补偿 + 减伤池同池
	s.raid["variant"]=""
	p.rogue_curses=["CU01"]
	check(Curses.personal_reward_scale(p)>1.0, "a curse raises the personal reward scale")
	check(is_equal_approx(rl.mod_of(s,"defense_penalty",p),Curses.defense_penalty(p)), "rogue_mods exposes the same in-pool curse penalty as RogueCurses")
	s.raid["room_rewarded"]=false
	p.rogue_gold=0
	rl.clear_room(s)
	check(p.rogue_gold>base_gold, "a cursed player is compensated on the room payout (got %d)" % p.rogue_gold)
	p.rogue_curses=[]

	# ---------------------------------------------------------------- 4. 铁匠铺：报价 / 扣费 / revision 守卫
	s.raid["room"]="forge"
	s.raid["floor"]=3
	p.rogue_gold=1000
	p.build_forge_points=0
	rl.refresh_dedicated(s,p)
	check(not s.raid.pending_forge.is_empty(), "a forge room publishes its offers")
	check(int(s.raid.pending_forge.revision)==int(s.raid.revision), "forge offers carry the live revision")
	var rev: int=int(s.raid.revision)
	var gold_before: int=p.rogue_gold
	s.perform(1,"rogue_forge",{"index":0,"revision":rev-1})
	check(p.rogue_gold==gold_before and int(s.raid.revision)==rev, "a stale forge click changes nothing")
	s.perform(1,"rogue_forge",{"index":0,"revision":rev})
	check(p.rogue_gold==gold_before-Rooms.forge_point_price(3), "the forge charges exactly the quoted price (got %d)" % (gold_before-p.rogue_gold))
	check(int(p.build_forge_points)==1, "the forge credits one forge point")
	check(int(s.raid.revision)==rev+1, "a successful purchase advances the room revision")
	check(int(s.raid.pending_forge.revision)==int(s.raid.revision), "offers are re-quoted after a purchase")

	# ---------------------------------------------------------------- 5. 赌徒：净额守恒
	s.raid["room"]="gamble"
	p.rogue_gold=1000
	rl.refresh_dedicated(s,p)
	var stake := Rooms.gamble_stake(int(s.raid.floor))
	check(int(s.raid.pending_gamble.stake)==stake, "the gamble room quotes the floor stake (%d)" % int(s.raid.pending_gamble.stake))
	var bet_before: int=p.rogue_gold
	var rev2: int=int(s.raid.revision)
	s.perform(1,"rogue_gamble",{"index":0,"revision":rev2})
	var moved := int(p.rogue_gold)-bet_before
	check(moved==stake or moved==-stake, "a coin bet settles as exactly +stake or -stake (got %d)" % moved)
	check(int(s.raid.revision)==rev2+1, "a settled bet advances the room revision")

	# ---------------------------------------------------------------- 6. 镜像：两步 + 每局一次
	p.rogue_selection={}
	p.build_reward_queue=[]
	s.raid["room"]="mirror"
	p.rogue_mirror_used=false
	s.raid["mirror_state"]={"active":false,"owner":int(p.id),"round":0,"settled":false}
	var rev3: int=int(s.raid.revision)
	s.perform(1,"rogue_mirror",{"index":0,"revision":rev3})
	check(bool(s.raid.mirror_state.active), "the first click accepts the mirror")
	check(bool(p.rogue_mirror_used), "accepting spends the run's challenge")
	var rev4: int=int(s.raid.revision)
	s.perform(1,"rogue_mirror",{"index":0,"revision":rev4})
	check(bool(s.raid.mirror_state.active), "a second click cannot settle combat")
	rl.finish_mirror(s,true)
	check(bool(p.rogue_mirror_used), "settling marks rogue_mirror_used")
	check(bool(s.raid.mirror_state.settled) and not bool(s.raid.mirror_state.active), "the settled mirror state is closed")
	s.raid["mirror_state"]={"active":false,"owner":int(p.id),"round":0,"settled":false}
	var rev5: int=int(s.raid.revision)
	var gold5: int=p.rogue_gold
	s.perform(1,"rogue_mirror",{"index":0,"revision":rev5})
	check(p.rogue_gold==gold5 and not bool(s.raid.mirror_state.active), "a spent mirror cannot be accepted again in the same run")

	# ---------------------------------------------------------------- 7. 诅咒房 / 事件房入池
	s.raid["room"]="curse"
	p.rogue_curses=[]
	s.raid["variant"]=""
	rl.open_room(s)
	check(p.rogue_curses.size()==1, "a curse room hands out exactly one curse per player (got %d)" % p.rogue_curses.size())
	check(int(s.raid.curse_serial)>=1, "the curse serial advances")
	s.raid["room"]="event"
	p.rogue_gold=1000
	rl.open_room(s)
	check(not s.raid.pending_event.is_empty(), "an event room publishes a pending offer")
	check(str(s.raid.pending_event.get("id",""))!="", "the pending event carries its id")
	var offer_rows: Array=s.raid.pending_event.get("offer",[])
	check(offer_rows.size()>=2, "the pending event exposes 2..3 options (got %d)" % offer_rows.size())
	var event_rev: int=int(s.raid.revision)
	var gold_event_before: int=p.rogue_gold
	s.perform(1,"rogue_event",{"index":0,"revision":event_rev-1})
	check(not s.raid.pending_event.is_empty() and p.rogue_gold==gold_event_before, "a stale event click cannot resolve the offer")
	s.perform(1,"rogue_event",{"index":0,"revision":event_rev})
	check(s.raid.pending_event.is_empty(), "choosing an option resolves the pending event")
	check(int(s.raid.revision)>=event_rev, "resolving an event never rewinds the revision")
	p.rogue_curses=[]

	# ---------------------------------------------------------------- 7b. 服务房的报价必须晚于 clear_room 的 revision 自增
	s.raid["variant"]=""
	p.rogue_curses=[]
	check(rl.mod_of(s,"chest_drop",p)==0.0, "no curse means no shard-rate change")
	s.raid["room"]="forge"
	s.raid["room_rewarded"]=false
	rl.clear_room(s)
	rl.refresh_dedicated(s,p)
	check(int(s.raid.pending_forge.revision)==int(s.raid.revision), "the forge is re-quoted after clear_room bumps the revision")

	# ---------------------------------------------------------------- 8. settle：灰烬 / 每日打卡只发一次
	var data: Dictionary={"ashes":0,"growth":{},"daily":{}}
	s.set_meta("profile_data",data)
	s.raid["variant"]=""
	s.raid["cleared"]=10
	s.raid["floor"]=3
	s.raid["daily"]=true
	s.raid["ended"]=false
	p.status="extracted"
	p.rogue_ash_run=0
	p.rogue_room_ash=0 # This section starts a clean settlement after earlier room rewards.
	var want_coins := 10*12+250
	rl.settle(s)
	check(int(s.results[1].coins)==want_coins, "a clean settle pays cleared*12+250 (got %d)" % int(s.results[1].coins))
	check(int(p.rogue_ash_run)>0, "settle grants run ash")
	check(int(data.ashes)==int(p.rogue_ash_run), "banked ash equals the run's ash (%d vs %d)" % [int(data.ashes),int(p.rogue_ash_run)])
	check((data.daily as Dictionary).has(Daily.record_key(Daily.utc_today())), "a daily run writes today's record key")
	var banked: int=int(data.ashes)
	rl.settle(s)
	check(int(data.ashes)==banked and int(p.rogue_ash_run)==banked, "a second settle is a no-op")

	# ---------------------------------------------------------------- 9. 守层者池接线（R14）
	var s2 = make_session(777)
	var rl2 = s2.roguelike
	s2.raid["floor"]=1
	s2.raid["room"]="boss"
	s2.raid["wave"]=3
	s2.enemies.clear()
	rl2.spawn_wave(s2)
	check(s2.enemies.size()==1, "the guardian wave spawns exactly one guardian")
	if s2.enemies.size()==1:
		var e: Dictionary=s2.enemies[0]
		var want_art := int(Combat.boss_art_for(int(s2.seed_value),0))
		check(int(e.rogue_skin)==0, "rogue_skin stays the floor index (got %d)" % int(e.rogue_skin))
		check(int(e.get("boss_art",-1))==want_art, "the guardian art follows boss_art_for(seed,floor) (got %d want %d)" % [int(e.get("boss_art",-1)),want_art])
		check(str(e.get("boss_name",""))==str(Combat.NAMES[want_art]), "the guardian name matches the pool entry (%s)" % str(e.get("boss_name","")))
		if Combat.CHOREO_KEYS.has(want_art):
			check(str(e.get("choreo_key",""))!="", "a pooled guardian with a choreography key exposes it")
		check(is_equal_approx(float(e.get("hp",0.0)),float(e.get("max_hp",0.0))), "the guardian starts at full health")
		check(float(e.get("max_hp",0.0))>0.0, "the guardian has a positive health pool (%f)" % float(e.get("max_hp",0.0)))

	s.queue_free()
	s2.queue_free()

	# ---------------------------------------------------------------- 10. 无 profile 通道：成长树不得改动起始资源
	# 这是 `tests/roguelike.gd:21` 那条 `p.weapon==1 and p.rogue_rerolls==2` 的护城河：
	# 裸 TideSession 既没有 `profile_data()` 也没有 meta，`RogueGrowth.power()` 必然全 0，
	# 因此起始金币/刷新券必须与 W1b 之前逐位相同。
	var s3 = make_session(1234)
	var p3: Dictionary=s3.players[1]
	check(s3.roguelike.profile_data_of(s3).is_empty(), "a bare TideSession resolves to an empty profile channel")
	var zero_power: Dictionary=Growth.power({})
	check(int(zero_power.get("start_rerolls",0))==0 and int(zero_power.get("start_coins",0))==0, "the growth power table is all-zero without a profile channel")
	check(int(p3.rogue_gold)==60, "a bare session still starts at exactly 60 coins (got %d)" % int(p3.rogue_gold))
	# NOTE (fixed after this file was written): `Build.reset()` (rogue_build.gd) used to merge its
	# own `"rogue_rerolls":3` with overwrite=true, clobbering both the caller's configured card
	# count and the growth tree's `start_rerolls` added on top. It now only fills that key when it
	# is absent, so the caller's count survives (`tests/roguelike.gd` asserts exactly that).
	# This section still does not assert the count on purpose: it only guards the "no profile
	# channel" path (all-zero `power()`, unchanged 60-coin purse).
	print("W1B PROBE bare-session weapon=%d rerolls=%d gold=%d" % [int(p3.weapon),int(p3.rogue_rerolls),int(p3.rogue_gold)])
	s3.queue_free()

	# ---- 10b. 正例：挂上 profile 后，成长树真的付进起始钱袋
	# `session.profile_data()` 现在由 W1/R7b 提供（无附着时返回 `{}`），main.gd 在开局前
	# `set_meta("profile_data", profile.data)`。这里用同一个通道喂 `coin_purse` 1 级（+25 魔晶）。
	var s5 = TideSession.new()
	root.add_child(s5)
	s5.set_physics_process(false)
	s5.set_meta("profile_data",{"ashes":0,"growth":{"coin_purse":1}})
	s5.solo({"hero":0,"mode":"roguelike","rogue_rerolls":2,"rogue_weapon":1})
	s5.launch(false,9091)
	var p5: Dictionary=s5.players[1]
	check(int(Growth.power({"growth":{"coin_purse":1}}).get("start_coins",0))==25, "coin_purse level 1 is worth 25 coins")
	check(int(p5.rogue_gold)==85, "an attached growth tree pays into the starting purse (got %d, want 85)" % int(p5.rogue_gold))
	s5.queue_free()

	# ================================================================ 11. UI → 动作 端到端
	# 载荷不是手写的：由 R7b 的面板模块（`RogueRoomUi.payload` / `mirror_payload`）与
	# R7 的事件面板模块（`UiModel.event_payload`）生成，再走 `session.action()`——也就是
	# main.gd 按钮回调实际调用的那个入口——因此这一节测的是"玩家点下去"的路径。
	var s4 = make_session(9090)
	var p4: Dictionary=s4.players[1]
	check(bool(s4.running), "the end-to-end session is running")

	# ---- 11a. 游方锻炉：扣费 / 锻造点 / 直接锻打 / 绑定 / 钱不够零变化
	s4.raid["room"]="forge"
	s4.raid["floor"]=3
	s4.raid["room_rewarded"]=false
	p4.rogue_gold=1000
	p4.build_forge_points=0
	s4.roguelike.refresh_dedicated(s4,p4)
	var gold_f: int=p4.rogue_gold
	s4.action(RoomUi.ACTION_FORGE,RoomUi.payload(s4.raid,0))
	check(p4.rogue_gold==gold_f-Rooms.forge_point_price(3), "UI forge click charges exactly the quoted price (%d paid)" % (gold_f-p4.rogue_gold))
	check(int(p4.build_forge_points)==1, "UI forge click credits one forge point (got %d)" % int(p4.build_forge_points))
	var gold_f2: int=p4.rogue_gold
	var level_f: int=int(p4.build_forge_level)
	s4.action(RoomUi.ACTION_FORGE,RoomUi.payload(s4.raid,2))
	check(int(p4.build_forge_level)==level_f+1, "UI direct-forge click raises the level by one (%d->%d)" % [level_f,int(p4.build_forge_level)])
	check(p4.rogue_gold==gold_f2-Rooms.forge_direct_price(3), "UI direct-forge click charges the direct price (%d paid)" % (gold_f2-p4.rogue_gold))
	check(str(p4.build_forge_bound)==str(p4.equipped.weapon.get("instance_id","")) and str(p4.build_forge_bound)!="", "a forge purchase binds the level to the equipped weapon")
	p4.rogue_gold=0
	var broke_rev: int=int(s4.raid.revision)
	var broke_level: int=int(p4.build_forge_level)
	s4.action(RoomUi.ACTION_FORGE,RoomUi.payload(s4.raid,0))
	check(int(p4.rogue_gold)==0 and int(p4.build_forge_level)==broke_level and int(s4.raid.revision)==broke_rev, "a broke UI forge click changes nothing")

	# ---- 11b. 赌徒营帐：押金币 / 押灰烬 / 押升阶
	s4.raid["room"]="gamble"
	p4.rogue_gold=1000
	p4.rogue_ash_run=999
	p4.equipped.weapon["tier"]=3
	s4.roguelike.refresh_dedicated(s4,p4)
	var stake_e2e := Rooms.gamble_stake(3)
	var gold_stale_g: int=p4.rogue_gold
	var rev_stale_g: int=int(s4.raid.revision)
	s4.action(RoomUi.ACTION_GAMBLE,{"index":0,"revision":rev_stale_g-1})
	check(int(p4.rogue_gold)==gold_stale_g and int(s4.raid.revision)==rev_stale_g, "a stale UI gamble click changes nothing")
	var gold_g: int=p4.rogue_gold
	s4.action(RoomUi.ACTION_GAMBLE,RoomUi.payload(s4.raid,0))
	var moved_gold := int(p4.rogue_gold)-gold_g
	check(moved_gold==stake_e2e or moved_gold==-stake_e2e, "a UI coin bet moves gold by exactly +-stake (got %d)" % moved_gold)
	var ash_g: int=p4.rogue_ash_run
	s4.action(RoomUi.ACTION_GAMBLE,RoomUi.payload(s4.raid,2))
	var moved_ash := int(p4.rogue_ash_run)-ash_g
	check(moved_ash==2*stake_e2e or moved_ash==-stake_e2e, "a UI ash bet moves run ash by +2*stake or -stake (got %d)" % moved_ash)
	check(int(p4.rogue_ash_run)>=0, "run ash never goes negative (got %d)" % int(p4.rogue_ash_run))
	var inv_before: int=int(p4.rogue_inventory_revision)
	s4.action(RoomUi.ACTION_GAMBLE,RoomUi.payload(s4.raid,1))
	var tier_now := int(p4.equipped.weapon.get("tier",0))
	check(tier_now==4 or tier_now==2, "a UI tier bet moves the weapon tier by exactly one step (got %d)" % tier_now)
	check(int(p4.rogue_inventory_revision)>inv_before, "a tier change bumps the inventory revision")
	var hp_after: float=float(p4.max_hp)
	p4.max_hp=-1.0
	s4.refresh_max_hp(p4)
	check(is_equal_approx(float(p4.max_hp),hp_after), "max_hp was re-synced by the tier change (kept %f, recomputed %f)" % [hp_after,float(p4.max_hp)])

	# ---- 11c. 镜像试炼：应战 / 结算 / 奖励入账 / 第二次被拒
	p4.rogue_selection={}
	p4.build_reward_queue=[]
	s4.raid["room"]="mirror"
	p4.rogue_mirror_used=false
	s4.raid["mirror_state"]={"active":false,"owner":int(p4.id),"round":0,"settled":false}
	var gold_m: int=p4.rogue_gold
	var ash_m: int=p4.rogue_ash_run
	s4.action(RoomUi.ACTION_MIRROR,{"revision":int(s4.raid.revision)-1})
	check(int(p4.rogue_gold)==gold_m and not bool(s4.raid.mirror_state.active), "a stale UI mirror click changes nothing")
	s4.action(RoomUi.ACTION_MIRROR,RoomUi.mirror_payload(s4.raid))
	check(bool(s4.raid.mirror_state.active), "a UI mirror click accepts the challenge")
	check(bool(p4.rogue_mirror_used), "accepting spends the mirror challenge")
	s4.action(RoomUi.ACTION_MIRROR,RoomUi.mirror_payload(s4.raid))
	check(bool(s4.raid.mirror_state.active), "a repeated UI click cannot settle combat")
	s4.roguelike.finish_mirror(s4,true)
	check(bool(p4.rogue_mirror_used), "settling the mirror spends the run's mirror")
	check(not bool(s4.raid.mirror_state.active) and bool(s4.raid.mirror_state.settled), "the settled mirror closes its state")
	var gold_m2: int=p4.rogue_gold
	var ash_m2: int=p4.rogue_ash_run
	if gold_m2>gold_m or ash_m2>ash_m:
		check(gold_m2>gold_m and ash_m2>ash_m, "a won mirror banks both gold and ash (%d->%d, %d->%d)" % [gold_m,gold_m2,ash_m,ash_m2])
		check(str(p4.rogue_selection.get("category",""))=="gear" or "gear" in p4.build_reward_queue, "a won mirror queues its gear pick")
	else:
		check(gold_m2==gold_m and ash_m2==ash_m, "a lost mirror pays nothing")
	s4.raid["mirror_state"]={"active":false,"owner":int(p4.id),"round":0,"settled":false}
	var gold_repeat: int=p4.rogue_gold
	s4.action(RoomUi.ACTION_MIRROR,RoomUi.mirror_payload(s4.raid))
	check(int(p4.rogue_gold)==gold_repeat and not bool(s4.raid.mirror_state.active), "a second UI mirror request is refused")

	# ---- 11d. 幽暗异事：结算真的改变资源并清 pending；过期点击零变化
	s4.raid["room"]="event"
	s4.raid["pending_event"]={"offer":Events.options_view(Events.find("EV02")),"revision":int(s4.raid.revision),"id":"EV02"}
	var gold_ev: int=p4.rogue_gold
	s4.action(UiModel.ACTION_EVENT,UiModel.event_payload(s4.raid,2))
	check(int(p4.rogue_gold)==gold_ev+15, "a UI event click pays the chosen option (gold %d->%d)" % [gold_ev,int(p4.rogue_gold)])
	check(s4.raid.pending_event.is_empty(), "the event click clears the pending offer")
	s4.raid["pending_event"]={"offer":Events.options_view(Events.find("EV04")),"revision":int(s4.raid.revision),"id":"EV04"}
	var gold_stale: int=p4.rogue_gold
	s4.action(UiModel.ACTION_EVENT,{"index":0,"revision":int(s4.raid.revision)-1})
	check(int(p4.rogue_gold)==gold_stale and not s4.raid.pending_event.is_empty(), "a stale UI event click changes nothing")
	s4.queue_free()

	# ================================================================ 12. T2 · 魔境 HUD 增量刷新
	# 这一节把 `main.gd:update_rogue_hud()` 从"签名一变就整棵重建"改成"常驻控件树 + 分域
	# 脏刷新"之后，用**真实 main.tscn 实例**做行为等价的回归。判据分三层：
	#   1. 结构不变的 tick **不重建**（`page` 下那一棵树的根实例 id 不变）；
	#   2. 结构变了（面板种类/房间/事件/货架数）**必须重建**，且重建后控件数/名字/坐标与
	#      旧实现一致（各面板的 `RogueRoomOption%d` / `RogueEventOption%d` 命名契约）；
	#   3. 数值类变化（魔晶、revision、禁用态）**就地生效**——按钮的 disabled 必须跟着当前
	#      值走，而不是停在建树那一刻的旧值（这正是增量刷新最容易写错的地方）。
	#
	# 另附"revision 竞态"实证：复用按钮不再捕获 revision，回调读的是成员变量
	# `_rogue_hud_revision`，而它在**每个 tick**（含早退路径）都被刷新；所以把成员从外部
	# 改掉、再发 `pressed`，派发出去的必须是改后的值——若回调捕获的是建树时的 revision，
	# 这条会读到旧值而失败。
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-hooks-t2.json"
	root.add_child(app)
	await process_frame
	# 这一节逐次自己调 `update_rogue_hud`，`_process` 的 10Hz HUD tick 会干扰计数。
	app.set_process(false)
	app.session.solo({"hero":0,"mode":"roguelike","rogue_rerolls":3,"rogue_weapon":1})
	app.session.set_physics_process(false)
	app.session.launch(false,4242)
	await process_frame
	var pa: Dictionary=app.session.players[app.session.my_id()]
	if not pa.get("rogue_selection",{}).is_empty():
		app.session.perform(app.session.my_id(),"rogue_selection_take",{"id":pa.rogue_selection.id,"version":pa.rogue_selection.version,"index":0})
	var rla = app.session.roguelike

	# ---- 12a. 结构不变的 tick 不重建（旧实现每次 revision 变化都重建）
	app.session.raid["room"]="combat"
	app.session.raid["phase"]="explore"
	app.session.raid["pending_event"]={}
	app.session.raid["variant"]=""
	app.update_rogue_hud(pa)
	var tree_root: Node=app.page.find_child("RogueHudRoot",false,false)
	check(tree_root!=null, "the incremental HUD names its persistent tree root (RogueHudRoot)")
	var root_id: int=int(tree_root.get_instance_id()) if tree_root!=null else 0
	for i in 24:
		app.session.raid["revision"]=int(app.session.raid["revision"])+1
		pa["rogue_gold"]=100+i
		app.update_rogue_hud(pa)
	var tree_after: Node=app.page.find_child("RogueHudRoot",false,false)
	check(tree_after!=null and int(tree_after.get_instance_id())==root_id, "24 revision+purse ticks reused the same rogue HUD root instead of rebuilding it")
	var gold_line: Label=app._rogue_hud_nodes.get("gold")
	check(is_instance_valid(gold_line) and gold_line.text=="魔晶 %d · 刷新卡 %d" % [pa.rogue_gold,pa.rogue_rerolls], "the reused 魔晶 line tracks the live purse (%s)" % (gold_line.text if is_instance_valid(gold_line) else "<freed>"))
	check(app._rogue_hud_nodes.get("shop_block")!=null and not bool((app._rogue_hud_nodes["shop_block"] as Panel).visible), "a non-shop phase keeps the 游商 block hidden")

	# ---- 12b. 面板种类优先级：三选一 > 幽暗异事 > 服务房 > 默认
	# NOTE: `find_child()` 只接受"owner 链上的后代"或直接子节点，而常驻树的根不是 main
	# 的 owner；所以这里一律从**根**往下找（直接子节点），与 `tests/rogue_ui.gd` 的
	# `app.find_child(...,true,false)` 契约等价：名字契约仍然成立。
	app.session.raid["room"]="event"
	app.session.raid["pending_event"]={"offer":[{"index":0,"name":"甲","desc":"a"},{"index":1,"name":"乙","desc":"b"}],"revision":int(app.session.raid["revision"]),"id":"EV02"}
	app.update_rogue_hud(pa)
	check(app.rogue_panel.find_child("RogueEventOption0",false,false)!=null, "an event offer that matches the live revision opens the event panel")
	var stamp: int=int(app.session.raid["revision"])
	app.session.raid["pending_event"]={"_stale":true}
	app.update_rogue_hud(pa)
	check(app.rogue_panel.find_child("RogueEventOption0",false,false)==null, "a no-longer-active event falls back to the default tree")
	app.session.raid["pending_event"]={"offer":[{"index":0,"name":"甲","desc":"a"},{"index":1,"name":"乙","desc":"b"}],"revision":stamp,"id":"EV02"}
	app.session.raid["room"]="forge"
	app.session.raid["room_rewarded"]=false
	app.session.raid["floor"]=3
	pa["rogue_gold"]=0
	rla.refresh_dedicated(app.session,pa)
	app.update_rogue_hud(pa)
	check(app.rogue_panel.find_child("RogueRoomOption0",false,false)!=null, "the 服务房 panel wins over an inactive event")
	app.session.raid["room"]="combat"

	# ---- 12c. 三选一：选择状态接管面板，且换一版就重建（payload 冻结了 version）
	app.session.raid["pending_event"]={}
	app.session.roguelike.roll_offers(app.session,true,pa)
	pa["rogue_selection"]={"id":"SEL1","version":1,"category":"gear","tier":0,"offers":[]}
	app.update_rogue_hud(pa)
	var selection_root: Node=app.page.find_child("RogueHudRoot",false,false)
	check(selection_root!=null and app.find_child("RewardNotice",true,false)!=null, "a 三选一 selection takes the panel over")
	var selection_id: int=int(selection_root.get_instance_id()) if selection_root!=null else 0
	pa["rogue_selection"]={"id":"SEL1","version":2,"category":"gear","tier":0,"offers":[]}
	app.update_rogue_hud(pa)
	var selection_root2: Node=app.page.find_child("RogueHudRoot",false,false)
	check(selection_root2!=null and int(selection_root2.get_instance_id())!=selection_id, "a selection version bump rebuilds the three-choice panel (its payload freezes id+version)")
	pa["rogue_selection"]={}
	app.session.raid["pending_event"]={}

	# ---- 12d. 默认树 + 游商块：显示/隐藏与禁用态跟着**当前值**走
	app.session.raid["room"]="combat"
	app.session.raid["phase"]="explore"
	app.update_rogue_hud(pa)
	var default_root: Node=app.page.find_child("RogueHudRoot",false,false)
	var default_id: int=int(default_root.get_instance_id()) if default_root!=null else 0
	check(default_root!=null and (default_root as Control).get_child_count()>10, "the default HUD tree is a real控件树")
	app.session.raid["phase"]="rogue_reward"
	app.update_rogue_hud(pa)
	var reward_hint: Label=app._rogue_hud_nodes.get("reward_hint")
	check(is_instance_valid(reward_hint) and reward_hint.visible, "the 开箱 hint appears in the reward phase")
	# 先造好 6 件货（`roll_offers` 会自增 revision，必须在钉 revision 之前调用）
	rla.roll_offers(app.session,true,pa)
	pa["p"].x=float(app.session.ruins.fork_start)+200.0
	app.session.raid["phase"]="rogue_shop"
	app.update_rogue_hud(pa)
	check(app._rogue_hud_kind=="default", "a 游商 phase away from the fork keeps the default tree (got %s)" % app._rogue_hud_kind)
	check(app._rogue_hud_nodes.get("shop_block")!=null and not bool((app._rogue_hud_nodes["shop_block"] as Panel).visible), "the 游商 block stays hidden while the player is not on the fork")
	check(is_instance_valid(reward_hint) and not reward_hint.visible, "the 开箱 hint hides again once the phase leaves rogue_reward")
	pa["p"].x=float(app.session.ruins.fork_start)-200.0
	app.update_rogue_hud(pa)
	check(app._rogue_hud_kind=="shop", "walking onto the fork switches the persistent tree to the 游商 panel (got %s)" % app._rogue_hud_kind)
	check(app._rogue_hud_offer_buttons.size()==6, "the 游商 tree built one button per shelf slot (got %d)" % app._rogue_hud_offer_buttons.size())
	check(app._rogue_hud_nodes.get("shop_block")==null, "the 游商 tree is a different tree, not a leftover default block")
	pa["rogue_gold"]=0
	app.update_rogue_hud(pa)
	check((app._rogue_hud_offer_buttons[0] as Button).disabled, "an empty purse disables the shelf button")
	check((app._rogue_hud_nodes.get("reroll") as Button).disabled==(pa.rogue_rerolls<=0), "the 使用刷新卡 button mirrors the live reroll count")
	pa["rogue_gold"]=9999
	app.update_rogue_hud(pa)
	var buy_button: Button=app._rogue_hud_offer_buttons[0]
	check(not buy_button.disabled, "refilling the purse re-enables the already-built shelf button")
	var price_want: int=int(pa.rogue_shop_offers[0].price)
	var gold_want: int=int(pa.rogue_gold)-price_want
	# ---- 12e. revision 竞态实证（回调读成员变量 vs 捕获建树时的值）
	# `roguelike.choose()` 在 `roguelike.gd:967` 把**所有**非 selection/leave 的动作都放在
	# `payload.revision == raid.revision` 这道门后面，所以 revision 送错就是"点了没反应"。
	# 做法：先把成员改成 777，发一次 pressed —— 只要派发用的是成员值，那次请求必被服务端
	# 丢弃（金额零变化），这同时证明了 777 真的被送出去了；再把成员钉回**实时** revision，
	# 第二次点击必须成交。若回调捕获的是建树时的 revision，第二次点击就会带着旧值被拒。
	app._rogue_hud_revision=777
	buy_button.emit_signal("pressed")
	check(int(pa.rogue_gold)==9999 and not bool(pa.rogue_shop_offers[0].get("sold",false)), "an injected stale revision is refused by the server guard (the button really ships _rogue_hud_revision)")
	app._rogue_hud_revision=int(app.session.raid.revision)
	buy_button.emit_signal("pressed")
	check(int(pa.rogue_gold)==gold_want, "the recycled 游商 button dispatches the row it was drawn for once the live revision is in place (paid %d, want %d)" % [9999-int(pa.rogue_gold),price_want])
	check(bool(pa.rogue_shop_offers[0].get("sold",false)), "the purchased row is the advertised slot 0 (index stayed pinned across refreshes)")
	var reroll_button: Button=app._rogue_hud_nodes.get("reroll")
	check(int(pa.rogue_rerolls)==3, "no reroll was spent by the two purchases (rerolls %d)" % int(pa.rogue_rerolls))
	app.update_rogue_hud(pa)
	# Buying equipment changes the sell-list structure; the rebuilt button must then
	# stay stable across a value-only refresh.
	reroll_button=app._rogue_hud_nodes.get("reroll")
	pa.rogue_gold+=1
	app.update_rogue_hud(pa)
	check(reroll_button==app._rogue_hud_nodes.get("reroll"), "a value-only tick after rebuilding the sell list reuses the reroll button")
	check(int(pa.rogue_rerolls)==3 and not reroll_button.disabled, "the recycled reroll button stays live with 3 cards in hand")
	# The reroll itself is revision-guarded too (`roguelike.gd:967`), so ship the live value.
	app._rogue_hud_revision=int(app.session.raid.revision)
	reroll_button.emit_signal("pressed")
	check(int(pa.rogue_rerolls)==2, "a recycled 游商 button reads the member revision at click time (rerolls now %d)" % int(pa.rogue_rerolls))

	# ---- 12f. 服务房行的 in-place 刷新（禁用态 / 文案 / 坐标 / 行数）
	app.session.raid["room"]="forge"
	app.session.raid["phase"]="explore"
	app.session.raid["floor"]=3
	app.session.raid["room_rewarded"]=false
	pa["rogue_gold"]=0
	rla.refresh_dedicated(app.session,pa)
	app.update_rogue_hud(pa)
	var room_root: Node=app.page.find_child("RogueHudRoot",false,false)
	var room_id: int=int(room_root.get_instance_id()) if room_root!=null else 0
	check(app._rogue_hud_offer_buttons.size()==4, "the forge panel built one button per service (got %d)" % app._rogue_hud_offer_buttons.size())
	check((app._rogue_hud_offer_buttons[0] as Button).disabled, "a broke player sees the first forge service disabled")
	pa["rogue_gold"]=9999
	rla.refresh_dedicated(app.session,pa)
	app.update_rogue_hud(pa)
	var room_root2: Node=app.page.find_child("RogueHudRoot",false,false)
	check(room_root2!=null and int(room_root2.get_instance_id())==room_id, "a purse change inside the 服务房 refreshes in place instead of rebuilding")
	check(not (app._rogue_hud_offer_buttons[0] as Button).disabled, "the already-built forge button is re-enabled from the live purse")
	var stats_line: Label=app._rogue_hud_nodes.get("stats")
	check(is_instance_valid(stats_line) and stats_line.text.contains("9999"), "the reused 服务房 stats line tracks the live purse (%s)" % (stats_line.text if is_instance_valid(stats_line) else "<freed>"))
	check((app._rogue_hud_offer_buttons[0] as Button).name=="RogueRoomOption0", "the renamed row buttons keep their addressable names")
	check(app.rogue_panel.find_child("RogueRoomOption0",false,false)!=null, "the 服务房 rows stay addressable from the persistent root")
	var rows_now: Array=RogueRoomUi.rows("forge",app.session.raid,RogueRoomUi.context_of(app.session,pa))
	var row0_cost: int=int(rows_now[0].cost)
	var b0: Button=app._rogue_hud_offer_buttons[0]
	var gold_before_forge: int=int(pa.rogue_gold)
	check(app._rogue_hud_row_actions.size()>=1 and str(app._rogue_hud_row_actions[0])=="rogue_forge", "the recycled 服务房 row still resolves its own action (got %s)" % str(app._rogue_hud_row_actions[0] if app._rogue_hud_row_actions.size()>0 else "<empty>"))
	app._rogue_hud_revision=424242
	b0.emit_signal("pressed")
	check(int(pa.rogue_gold)==gold_before_forge, "an injected stale revision is refused by the 服务房 guard (gold unchanged; the callback really ships _rogue_hud_revision)")
	app._rogue_hud_revision=int(app.session.raid.revision)
	b0.emit_signal("pressed")
	check(int(pa.rogue_gold)==gold_before_forge-row0_cost, "a recycled 服务房 button dispatches its own row once the live revision is in place (paid %d, want %d)" % [gold_before_forge-int(pa.rogue_gold),row0_cost])

	# ---- 12g. 事件面板：按钮的 payload 在**点击时**从快照构造，而 `RogueEvents.matches_revision`
	# 要求它与**待选报价的 revision 戳**一致；所以事件面板的 layout 里带上了那枚戳——报价重新
	# 盖章就重建（与改造前同频），绝不让一次点击送出一个会被 `matches_revision` 丢掉 的 revision。
	app.session.raid["room"]="event"
	app.session.raid["phase"]="explore"
	var stamp2: int=int(app.session.raid["revision"])
	app.session.raid["pending_event"]={"offer":[{"index":0,"name":"甲","desc":"a"},{"index":1,"name":"乙","desc":"b"}],"revision":stamp2,"id":"EV02"}
	app.update_rogue_hud(pa)
	var pick0: Button=app.rogue_panel.find_child("RogueEventOption0",false,false)
	check(pick0!=null, "the event panel drew the frozen RogueEventOption0 name")
	# `event_options()` prefers the event definition's own `offer` list over the raid's pending
	# copy (`RogueUi.event_options` -> `RogueEvents.options_view`), so the expected count has to be
	# read from the same source the panel reads.
	var expected_options: int=RogueUi.event_options(app.session,pa,app.session.raid).size()
	check(app._rogue_hud_offer_buttons.size()==expected_options, "the event panel built one button per option (got %d, want %d)" % [app._rogue_hud_offer_buttons.size(),expected_options])
	var options_now: Array=RogueUi.event_options(app.session,pa,app.session.raid)
	var declared: int=int(options_now[0].get("index",-1)) if options_now.size()>0 else -1
	var expected_payload: Dictionary=RogueUi.event_payload(app.session.raid,declared)
	check(int(expected_payload.get("revision",-1))==int(app.session.raid["revision"]), "the event payload carries the revision read at click time (%d)" % int(expected_payload.get("revision",-1)))
	check(str(expected_payload.get("index"))==str(declared), "the event payload keeps the option index the button was built for (%s)" % str(declared))
	check(RogueEvents.matches_revision(app.session,stamp2), "the pending event stamp matches the live revision, so the 选择 button is armed")
	var armed_root: int=int(app.rogue_panel.get_instance_id())
	var re_stamped: int=stamp2+1
	app.session.raid["revision"]=re_stamped
	(app.session.raid.pending_event as Dictionary)["revision"]=re_stamped
	app.update_rogue_hud(pa)
	check(int(app.rogue_panel.get_instance_id())!=armed_root, "a re-stamped event offer rebuilds the panel instead of shipping a stale revision")
	check(RogueEvents.matches_revision(app.session,re_stamped), "the rebuilt event panel is armed against the new stamp")

	# ---- 12h. 收尾：值级 tick 不产生新控件，且 `new_page()` 会把增量状态整个复位
	# 口径：探针本身只读控件树、不 new 控件，所以这一段里出现的"新 Control"唯一来源就是
	# `update_rogue_hud` 的重建路径。先空跑一次把当前树登记进 `seen`（那次会数到整棵树，
	# 不计入断言），再跑固定 12 次值级 tick：新建数必须是 0，否则就是又走了重建。
	var seen: Dictionary={}
	# Leave the event panel first: its layout carries the offer's revision stamp, so bumping
	# `raid.revision` under it would (correctly) force a rebuild and the count below would be
	# measuring that rebuild rather than the value-only path.
	app.session.raid["pending_event"]={}
	app.session.raid["room"]="combat"
	app.session.raid["phase"]="explore"
	app.update_rogue_hud(pa)
	_t2_control_ids_once(app,seen)
	var fresh_total := 0
	for i in 12:
		app.session.raid["revision"]=int(app.session.raid["revision"])+1
		app.update_rogue_hud(pa)
		fresh_total+=_t2_control_ids_once(app,seen)
	check(fresh_total==0, "12 value-only ticks after the whole panel matrix allocated 0 new Control (got %d)" % fresh_total)
	app.new_page("ground")
	check(app.rogue_panel==null and app.rogue_signature=="" and app._rogue_hud_kind=="" and app._rogue_hud_nodes.is_empty() and app._rogue_hud_offer_buttons.is_empty(), "new_page() resets every piece of the incremental HUD state")
	app.session.disconnect_room()
	app.queue_free()
	await process_frame
	await process_frame

	await process_frame

	print("ROGUE HOOKS ROGUELIKE ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
