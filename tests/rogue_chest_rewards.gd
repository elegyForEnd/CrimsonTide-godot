extends SceneTree
## 奖励节奏 v3：宝箱 = 金币 + 概率装备；能力只从升级弹窗产出。
var checks := 0
var failures := 0
var s: TideSession

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void: call_deferred("run")

func selection_payload(p: Dictionary, index: int = 0) -> Dictionary:
	return {"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":index}

func take_starter(p: Dictionary) -> void:
	if not p.rogue_selection.is_empty():
		s.perform(p.id,"rogue_selection_take",selection_payload(p))

func prepare_room(room: String, floor: int = 1, area: int = 2) -> void:
	s.enemies.clear()
	s.raid.room=room; s.raid.floor=floor; s.raid.area=area; s.raid.phase="rogue_combat"
	s.raid["room_rewarded"]=false
	s.raid.reward_chest={}; s.raid.reward_drops=[]; s.raid["reward_claims"]=[]
	for player in s.players.values():
		player.rogue_selection={}; player.build_reward_queue=[]
	s.roguelike.clear_room(s)

func open_chest(p: Dictionary) -> void:
	p.p=s.raid.reward_chest.p
	s.perform(p.id,"rogue_loot")

func run() -> void:
	s=TideSession.new(); root.add_child(s)
	s.solo({"hero":0,"mode":"roguelike","rogue_rerolls":2})
	s.launch(false,1729); s.set_physics_process(false)
	var p: Dictionary=s.players[1]
	take_starter(p); s.roguelike.tick(s,.01)
	p=s.players[1]

	# 普通战斗：金币必得，装备 25%，绝不掉能力/属性晶。
	prepare_room("combat")
	check(s.roguelike.chest_equipment_chance(s)==0.25,"Combat chest has a 25% equipment chance")
	p.rogue_gold=0
	open_chest(p)
	check(int(p.rogue_gold)>0,"Chest opening pays gold")
	check(s.raid.reward_chest.opened,"Chest opens")
	check(not s.raid.reward_drops.any(func(d): return d.category in ["ability","attribute"]),"Chest never drops ability or attribute shards")
	check(s.raid.reward_drops.size()<=1,"At most one equipment packet per player")
	if not s.raid.reward_drops.is_empty():
		check(s.raid.reward_drops[0].category in ["weapon","gear"],"Drop is weapon or gear")

	# 守层者：100% 装备。
	prepare_room("boss",2,7)
	check(s.roguelike.chest_equipment_chance(s)==1.0,"Boss chest guarantees equipment")
	p.rogue_gold=0
	open_chest(p)
	check(int(p.rogue_gold)>0,"Boss chest pays gold as well")
	check(s.raid.reward_drops.size()==1,"Boss chest drops exactly one equipment packet")
	check(s.raid.reward_drops[0].category in ["weapon","gear"],"Boss equipment identity")
	var packet: Dictionary=s.raid.reward_drops[0]
	s.elapsed+=2
	p.p=packet.p
	s.perform(1,"rogue_loot")
	check(p.rogue_selection.get("category","") in ["weapon","gear"],"Equipment packet opens its category choice")
	check(p.rogue_selection.offers.size()==3,"Three equipment candidates")
	var offer: Dictionary=p.rogue_selection.offers[0]
	s.perform(1,"rogue_selection_drop",selection_payload(p))
	check(p.rogue_selection.is_empty(),"Equipment can be shared")
	check(s.raid.reward_drops.back().offer==offer,"Shared equipment keeps the exact item")

	# 精英：50% 概率，只校验配置。
	prepare_room("elite",1,3)
	check(s.roguelike.chest_equipment_chance(s)==0.5,"Elite chest has a 50% equipment chance")

	# 锻造点不再发放。
	check(p.build_forge_points==0,"No forge points after clearing rooms")
	check(p.build_ability_offers.is_empty(),"Chest rooms never create ability popups")

	s.queue_free(); await process_frame
	print("ROGUE CHEST: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
