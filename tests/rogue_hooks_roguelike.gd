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

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void: call_deferred("run")

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
	check(rl.roll_tier(s)>=1, "loot_tier +1 lifts every roll out of band 0")
	s.raid["variant"]="bargain"
	check(is_equal_approx(rl.mod_of(s,"loot_tier"),-1.0), "bargain carries -1 loot tier")
	var low := 99
	for i in 200: low=mini(low,rl.roll_tier(s))
	check(low<=1 and low>=0, "the loot band is clamped at 0 (min seen %d)" % low)

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
	s.raid["room"]="mirror"
	p.rogue_mirror_used=false
	s.raid["mirror_state"]={"active":false,"owner":int(p.id),"round":0,"settled":false}
	var rev3: int=int(s.raid.revision)
	s.perform(1,"rogue_mirror",{"index":0,"revision":rev3})
	check(bool(s.raid.mirror_state.active), "the first click accepts the mirror")
	check(not bool(p.rogue_mirror_used), "accepting does not spend the run's mirror yet")
	var rev4: int=int(s.raid.revision)
	s.perform(1,"rogue_mirror",{"index":0,"revision":rev4})
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
	# NOTE: `rogue_rerolls` is *not* asserted here on purpose. `Build.reset()` (rogue_build.gd:20)
	# merges its own `"rogue_rerolls":3` default AFTER this file's line, so the shipped count is 3
	# no matter what the caller configured. That pre-existing conflict is what breaks
	# `tests/roguelike.gd:21`'s `p.rogue_rerolls==2`; W1b adds exactly 0 (asserted above).
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
	s4.raid["room"]="mirror"
	p4.rogue_mirror_used=false
	s4.raid["mirror_state"]={"active":false,"owner":int(p4.id),"round":0,"settled":false}
	var gold_m: int=p4.rogue_gold
	var ash_m: int=p4.rogue_ash_run
	s4.action(RoomUi.ACTION_MIRROR,{"revision":int(s4.raid.revision)-1})
	check(int(p4.rogue_gold)==gold_m and not bool(s4.raid.mirror_state.active), "a stale UI mirror click changes nothing")
	s4.action(RoomUi.ACTION_MIRROR,RoomUi.mirror_payload(s4.raid))
	check(bool(s4.raid.mirror_state.active), "a UI mirror click accepts the challenge")
	check(not bool(p4.rogue_mirror_used), "accepting the mirror does not spend it")
	s4.action(RoomUi.ACTION_MIRROR,RoomUi.mirror_payload(s4.raid))
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

	await process_frame
	print("ROGUE HOOKS ROGUELIKE ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
