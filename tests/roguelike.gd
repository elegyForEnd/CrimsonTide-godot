extends SceneTree
var failures := 0
var checks := 0
## Set as the very last statement of `_body()`. A runtime error aborts `_body()` but the
## `await` in `run()` still resumes, so without this flag an aborted body looked like a
## clean "0 failures" run.
var completed := false
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func _initialize() -> void: call_deferred("run")
func choose(s,kind: String,index: int = 0) -> void:
	s.perform(1,kind,{"index":index,"revision":s.raid.revision})
## `_body()` can abort on a runtime error (for example an out-of-range
## `s.results[1]`), which used to leave this SceneTree spinning until the harness
## killed it. The wrapper always reaches `quit()`, so a broken assertion shows up
## as a red test instead of a silent hang.
func run() -> void:
	await _body()
	check(completed,"the run reached the end of the body (a SCRIPT ERROR aborts `_body()` and skips the rest)")
	print("ROGUELIKE ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)

func _body() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike","rogue_rerolls":2,"rogue_weapon":1})
	s.launch(false,1729)
	var p: Dictionary=s.players[1]
	check(s.roguelike.active(s) and s.enemies.size()==6,"Mode has six opening monsters, no campaign enemies")
	check(s.ruins.interior and s.map_id=="rogue","Independent horizontal map")
	check(s.ruins.blocked(Vector2(330,300)) and not s.ruins.blocked(Vector2(330,s.ruins.lane_center(330))),"Background is blocked while the entry floor is traversable")
	check(not s.can_extract() and not s.can_travel(),"Campaign gates and extraction disabled")
	# 原文：`check(p.weapon==1 and p.rogue_rerolls==2,"Starting purchases applied")`
	# 1) `p.weapon` 在装备武器后是 **Content 域**（`Content.WEAPON_BASE+index` = 600+i），
	#    不再是 Catalog 索引，所以 `==1` 永远不成立。改用稳定的 `build_id` 表达同一意图：
	#    营地配置的第 1 把武器（Catalog 1 = 绯红单手剑 = Content W001）真的进了这一局。
	# 2) `rogue_rerolls==2` 现在真的成立：`Build.reset()` 不再把调用方显式配置的刷新卡覆盖成 3。
	check(str(p.equipped.get("weapon",{}).get("build_id",""))=="W001" and p.rogue_rerolls==2,"Starting purchases applied")
	var base_damage: float=s.weapon_damage(p)
	var base_ultimate: float=s.ultimate_damage(p,100)
	p.rogue_damage=0.12
	check(s.weapon_damage(p)>base_damage and s.ultimate_damage(p,100)>base_ultimate,"Damage boon benefits attacks and ultimate")
	p.rogue_damage=0.0
	var themes: Dictionary={}
	var expected_cleared := 0
	# 原文用 `reward_chest.opened` 判断"这是第一份奖励包"；非战斗房没有宝箱，改用本地一次性标记。
	var stale_checked := false
	var steps := 0
	while s.running:
		steps+=1
		if steps%50==0: print("ROGUELIKE PROGRESS step=%d floor=%d phase=%s cleared=%d" % [steps,int(s.raid.floor),str(s.raid.phase),int(s.raid.cleared)])
		# 新增兜底：这个循环不会向引擎让帧，所以 `--quit-after` 对它无效——一旦某个阶段不再推进
		# （例如 `rogue_next` 被拒），旧代码会永远空转、表现成 TIMEOUT。超过上限就判红并退出。
		if steps>600:
			check(false,"the run advanced on every step (stalled at step %d, floor %d, phase %s, cleared %d)" % [steps,int(s.raid.floor),str(s.raid.phase),int(s.raid.cleared)])
			break
		if not themes.has(s.raid.floor): expected_cleared+=int(s.roguelike.depth_count(s))
		themes[s.raid.floor]=true
		if s.raid.phase=="rogue_prepare":
			# 新增分支（原文没有）：节点图改造后，开局必须由玩家本人从三选一里拿一把开局武器，
			# `launch()` 结束时 phase 就是 `rogue_prepare`。测试此前从不派发它，于是首轮直接落到
			# 下面的 `else` → "Unexpected phase" → break → `s.results[1]` 越界 → 挂死。
			var opening: Dictionary=p.get("rogue_selection",{})
			if not opening.is_empty():
				check(str(opening.get("category",""))=="starter","Opening weapon choice is offered")
				s.perform(1,"rogue_selection_take",{"id":opening.id,"version":opening.version,"index":0})
			# `roguelike.tick()` 里 prepare 的收尾条件是「所有在场玩家选完且奖励队列为空」，所以要
			# 推进一帧它才会切到 `rogue_combat`；原文没有这一步，也是首轮卡住的第二个原因。
			s.simulate(0.01)
			check(s.raid.phase=="rogue_combat","Opening weapon choice starts the first encounter")
		elif s.raid.phase=="rogue_combat":
			for e in s.enemies: e.hp=0
			s.simulate(0.01)
			if s.raid.wave==3:
				check(s.raid.phase=="rogue_reward","Final encounter grants one reward roll")
			else:
				check(s.raid.phase=="rogue_combat","First encounters require more exploration")
				p.p=Vector2(1200 if s.raid.wave==1 else 2100,580)
				s.simulate(0.01)
		elif s.raid.phase=="rogue_reward":
			# 原文：`var first_packet: bool=not s.raid.reward_chest.opened`
			# 非战斗房（灵契圣坛 / 商店 / 宝藏等）也会直接进 `rogue_reward`，但那时
			# `reward_chest` 里没有 `opened` 键，直接访问会抛运行期错误并把整个 `_body()` 中断
			# ——表面上仍是 "0 failures"，实际只跑了十几条断言就提前退出。改成一发性的本地
			# 标记，语义不变：只在第一份奖励包上演练一次"过期点击领不走刷新后的奖励"。
			var first_packet: bool=not stale_checked and not bool(s.raid.get("reward_chest",{}).get("opened",false))
			preload("res://tests/rogue_reward_flow.gd").pick(s,p)
			check(p.rogue_selection.offers.size()==3,"Three rewards after chest pickup")
			if s.raid.cleared==1 and first_packet:
				stale_checked=true
				var stale: Dictionary={"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0}
				s.perform(1,"rogue_selection_reroll",stale)
				check(p.rogue_rerolls==1,"Reroll consumes one card")
				s.perform(1,"rogue_selection_take",stale)
				check(s.raid.phase=="rogue_reward","Stale offer click cannot claim refreshed reward")
			s.perform(1,"rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})
			if not p.get("rogue_selection",{}).is_empty():
				# 取不走（最典型：备用行囊满 12 件时 `equip()` 返回 false，`selection_action`
				# 直接 return 且**不清空选择**）→ 走真实 UI 的"丢弃"动作（rogue_reward_ui.gd:192），
				# 把报价放回地面。否则待定选择会永久卡住奖励房。
				s.perform(1,"rogue_selection_drop",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})
			# 有界收尾（原文用 `rogue_reward_flow.claim()`）：那个助手内部是
			# `while s.raid.phase=="rogue_reward"`，任何一次 take 被拒都会让它永远转下去
			# ——这就是本用例旧代码 TIMEOUT 的直接原因。这里改成有界循环，并复用同一条逃生路径。
			for settle in 24:
				if s.raid.phase!="rogue_reward": break
				preload("res://tests/rogue_reward_flow.gd").pick(s,p)
				var cur: Dictionary=p.get("rogue_selection",{})
				if cur.is_empty(): continue
				s.perform(1,"rogue_selection_take",{"id":cur.id,"version":cur.version,"index":0})
				if not p.get("rogue_selection",{}).is_empty():
					s.perform(1,"rogue_selection_drop",{"id":cur.id,"version":cur.version,"index":0})
			check(s.raid.phase=="rogue_exit","Reward taken once, exit unlocked")
		elif s.raid.phase=="rogue_shop":
			# 原文硬编码 `before-50`：商店报价现在由 `roll_offers()` 按
			# `maxi(1, scale_int(65+10*floor, 1+shop_price))` 计算（roguelike.gd:709），
			# 不再固定 50（还会被变数 `shop_price` 缩放）。改成读**报价本身**，断言不变：
			# 花掉的正好是标价、且同一格不能重复购买。顺带把"选哪一格"改成第一个买得起且未售出的格子。
			# 夹具：备用行囊满 12 件时 `equip()` 会拒绝装备类商品，先腾出一格（等同于玩家分享/丢弃一件备用），
			# 否则计价断言会被"满仓拒绝"掩盖。
			if p.get("rogue_stash",[]).size()>=12: p.rogue_stash.pop_back()
			var slot := -1
			for i in p.get("rogue_shop_offers",[]).size():
				var quoted: Dictionary=p.rogue_shop_offers[i]
				if not quoted.get("sold",false) and int(p.rogue_gold)>=int(quoted.get("price",0)): slot=i; break
			check(slot>=0,"the shop quotes at least one affordable offer")
			if slot>=0:
				var price := int(p.rogue_shop_offers[slot].get("price",0))
				var before: int=p.rogue_gold
				choose(s,"rogue_take",slot)
				check(p.rogue_gold==before-price,"Shop spends the quoted price (%d)" % price)
				choose(s,"rogue_take",slot)
				check(p.rogue_gold==before-price,"Sold item cannot be purchased twice")
			p.p=s.ruins.exit_position(0)
			choose(s,"rogue_next")
		elif s.raid.phase=="rogue_exit":
			p.p=s.ruins.exit_position(0)
			choose(s,"rogue_next")
		else: check(false,"Unexpected phase"); break
	check(themes.size()==5 and expected_cleared>=35 and s.raid.cleared==expected_cleared,"All five floors and every graph row completed")
	check(s.results[1].escaped and s.results[1].coins==expected_cleared*12+250,"Final reward settles exactly once")
	check(not s.results[1].has("pocket") and not s.results[1].has("bags"),"Existing storage preserved")
	s.roguelike.settle(s)
	check(s.results[1].coins==expected_cleared*12+250,"Settlement idempotent")
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,123)
	p=s.players[1]
	# 新增：`launch()` 结束后停在 `rogue_prepare`（开局武器三选一），必须先派发它、再让 tick 推进一帧，
	# 否则"死亡结束本局"发生在准备阶段，`s.running` 不会翻转。
	var opening: Dictionary=p.get("rogue_selection",{})
	if not opening.is_empty():
		s.perform(1,"rogue_selection_take",{"id":opening.id,"version":opening.version,"index":0})
	s.simulate(0.01)
	p.status="dead"
	# `session.gd:2783-2788`：魔境是"没人站着持续 ≥3 秒"（`raid.party_down_time`）才 `roguelike.settle()`，
	# 原文只推进了 0.1 秒，永远等不到结算。改成推进 4 秒（沿用 0.1 的步长）。
	for step in 40: s.simulate(0.1)
	check(not s.running and not s.results[1].escaped,"Death ends run")
	s.solo({"hero":0})
	s.launch(false,1729)
	check(not s.roguelike.active(s) and s.raid.phase=="explore","Original expedition still launches")

	var Map = preload("res://scripts/rogue_map.gd")
	var map=Map.new()
	map.generate(1729)
	map.configure(1,1,true)
	check(map.width>1440 and map.obstacles.size()>=5,"Scrolling level retains physical obstacles")
	check(map.terrain_hazards.size()==3,"Forge has three lava pools")
	check(map.blocked(map.obstacles[0].p),"Scenic rock has collision")
	check(map.on_lava(map.terrain_hazards[0].p),"Lava detection matches visual pool")
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,1729)
	s.raid.floor=2
	s.roguelike.enter(s)
	p=s.players[1]
	p.p=s.ruins.terrain_hazards[0].p
	var hp: float=p.hp
	s.roguelike.tick(s,1.0)
	check(p.hp<hp and p.rogue_lava,"Standing in lava causes damage")
	p.p=Vector2(330,580)
	hp=p.hp
	s.roguelike.tick(s,1.0)
	check(p.hp==hp and not p.rogue_lava,"Safe ground stops lava damage")
	s.queue_free()
	await process_frame
	completed=true

