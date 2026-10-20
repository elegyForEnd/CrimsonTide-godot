extends SceneTree
## 升级 / 加点 / 每 3 级能力 / 宝箱金币与概率装备。
const Build = preload("res://scripts/rogue_build.gd")
const Abilities = preload("res://scripts/rogue_abilities.gd")
var checks := 0
var failures := 0
var s: TideSession

func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func take_starter(p: Dictionary) -> void:
	if not p.rogue_selection.is_empty():
		s.perform(p.id,"rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})

func run() -> void:
	s=TideSession.new(); root.add_child(s)
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,8811); s.set_physics_process(false)
	var p: Dictionary=s.players[1]
	take_starter(p); s.roguelike.tick(s,.01)
	p=s.players[1]
	check(p.build_pending_levels==0 and p.build_pending_abilities==0,"Fresh run has no pending choices")
	check(p.build_attribute_points==0,"Levels no longer hand out a bank of points automatically")

	# 连升 3 级：等级 2/3/4，属性选择 3 次，能力 1 次（3 级里程碑）。
	var need: int=Build.xp_needed(1)+Build.xp_needed(2)+Build.xp_needed(3)
	Build.add_experience(s,p,need)
	check(p.build_level==4,"Three level-ups reach Lv.4")
	check(p.build_pending_levels==3,"Every level queues exactly one attribute choice")
	check(p.build_pending_abilities==1,"Every third level queues one ability choice")
	check(p.build_ability_offers.size()==3,"Ability popup has three candidates")
	var ids := {}
	for offer in p.build_ability_offers: ids[str(offer.ability_id)]=true
	check(ids.size()==3,"Three different abilities, never three ranks of one")
	# 加点：每次只 +1，且直接写 build_attributes。
	for stat in ["strength","dexterity","intelligence"]:
		var before := int(p.build_attributes.get(stat,0))
		var reason := Build.level_choice(s,p,stat)
		check(reason=="" and int(p.build_attributes.get(stat,0))==before+1,"Level choice adds exactly one point")
	check(p.build_pending_levels==0 and p.build_pending_abilities==1,"Attribute choices drain before ability popup")
	# 能力：选第一张，rank +1，弹窗次数 -1。
	var first: Dictionary=p.build_ability_offers[0]
	var key := str(first.ability_key)
	check(Build.ability_choice(s,p,0)=="" and Abilities.rank(p,key)==1,"Ability pick grants rank I")
	check(p.build_pending_abilities==0 and p.build_ability_offers.is_empty(),"Ability popup closes after the pick")

	# 同名最多 3 次：直接连拿三次，第四次被拒且不再进池。
	p.build_abilities={}
	for i in 3:
		p.build_pending_abilities=1
		p.build_ability_offers=[Abilities.offer_for(p,key)]
		check(Build.ability_choice(s,p,0)=="","Stack %d accepted" % (i+1))
	check(Abilities.rank(p,key)==3,"Same ability caps at three acquisitions")
	check(not Abilities.next_offers(p).any(func(o): return str(o.ability_key)==key),"Maxed ability leaves the pool")

	# 全满后的能力里程碑折金，不弹空卡。
	p.build_abilities={}
	for entry in Abilities.TRACKS: p.build_abilities[str(entry.key)]=3
	p.build_pending_abilities=2
	p.build_ability_offers=[]
	p.rogue_gold=0
	Build.ensure_ability_offers(s,p)
	check(int(p.rogue_gold)==300 and p.build_pending_abilities==0,"All-maxed milestones convert to gold")

	# 宝箱：金币必得。守层者 100% 装备；普通战斗 25% 但金币一定有。
	s.enemies.clear(); s.raid.room="boss"; s.raid.floor=1; s.raid.area=5; s.raid.phase="rogue_combat"
	s.raid["room_rewarded"]=false; s.raid.reward_chest={}; s.raid.reward_drops=[]
	p.rogue_gold=0; p.rogue_selection={}; p.build_reward_queue=[]
	s.roguelike.clear_room(s)
	var gold_before := int(p.rogue_gold)
	check(gold_before==0,"Chest rooms no longer pay gold on clear")
	p.p=s.raid.reward_chest.p
	s.perform(1,"rogue_loot")
	check(int(p.rogue_gold)>gold_before,"Opening the chest pays gold")
	check(s.raid.reward_drops.size()>=1,"Boss chest guarantees an equipment packet")
	check(s.raid.reward_drops[0].category in ["weapon","gear"],"Equipment packet is weapon or gear")
	check(not s.raid.reward_drops.any(func(d): return d.category=="ability"),"Chest no longer drops ability seals")
	check(not s.raid.reward_drops.any(func(d): return d.category=="attribute"),"Chest no longer drops attribute shards")
	check(p.build_forge_points==0,"No forge points are awarded")

	s.queue_free(); await process_frame
	print("ROGUE LEVEL FLOW: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
