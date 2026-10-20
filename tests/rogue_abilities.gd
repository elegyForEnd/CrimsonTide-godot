extends SceneTree
## 雷霆十二式：池、三选一、同名 3 次上限、数值读取口。
const Abilities = preload("res://scripts/rogue_abilities.gd")
var checks := 0
var failures := 0
var s: TideSession

func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func run() -> void:
	s=TideSession.new(); root.add_child(s); s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,9021)
	var p: Dictionary=s.players[1]
	p.rogue_selection={}; p.build_reward_queue=[]
	check(Abilities.TRACKS.size()==12,"Twelve independent abilities")
	var ids := {}
	for entry in Abilities.TRACKS:
		check(not ids.has(str(entry.id)) and not ids.has(str(entry.key)),"Unique ability id/key: "+str(entry.id))
		ids[str(entry.id)]=true
		check(entry.ranks.size()==3,"Three numeric ranks per ability: "+str(entry.id))
		for rank in 3:
			check(not str(entry.ranks[rank].get("text","")).is_empty(),"Rank text is readable: "+str(entry.id))

	var offers: Array=Abilities.roll_offers(s,p,3)
	check(offers.size()==3,"Popup rolls three cards")
	var seen := {}
	for offer in offers:
		seen[str(offer.ability_id)]=true
		check(int(offer.rank)==1,"Fresh player is offered rank I")
	check(seen.size()==3,"Three different abilities, never three ranks of one")

	# 同名 3 次：0→1→2→3，满后从池中消失。
	var key := str(offers[0].ability_key)
	p.build_abilities={}
	for rank in [1,2,3]:
		check(Abilities.rank(p,key)==rank-1,"Rank before pick is %d" % (rank-1))
		check(Abilities.offer_for(p,key).get("rank",0)==rank,"Next offer is rank %d" % rank)
		p.build_abilities[key]=rank
	check(Abilities.offer_for(p,key).is_empty(),"No offer after the third acquisition")
	check(not Abilities.next_offers(p).any(func(o): return str(o.ability_key)==key),"Maxed ability leaves the pool")
	check(Abilities.rank(p,key)==3,"Rank caps at 3")

	# 数值读取口：抽查五条代表性的曲线。
	p.build_abilities={"attack":3,"art":2,"crit":1,"guard":1,"speed":1,"summon":1}
	check(is_equal_approx(Abilities.attack_interval(p),.92),"Attack rank III gives -8% interval")
	check(is_equal_approx(Abilities.art_damage(p),.16),"Art rank II gives +16%")
	check(is_equal_approx(Abilities.crit_chance(p),.03),"Crit rank I gives +3%")
	check(is_equal_approx(Abilities.guard(p),.03),"Guard rank I gives 3% reduction")
	check(is_equal_approx(Abilities.move_speed(p),6.0),"Speed rank I gives +6")
	check(Abilities.summon_every(p)==5 and Abilities.summon_ratio(p)>.0,"Summon rank I has a cadence and ratio")

	# 全满：无候选，由 Build 层折算魔晶。
	p.build_abilities={}
	for entry in Abilities.TRACKS: p.build_abilities[str(entry.key)]=3
	check(Abilities.is_maxed(p),"All twelve at 3/3 is maxed")
	check(Abilities.roll_offers(s,p,3).is_empty(),"No cards once every ability is maxed")

	# 旧字典缺键/空值按 0 读。
	check(Abilities.rank({},"attack")==0,"Missing map reads zero")
	check(Abilities.rank({"build_abilities":null},"attack")==0,"Null map reads zero")

	s.queue_free(); await process_frame
	print("ROGUE ABILITIES: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
