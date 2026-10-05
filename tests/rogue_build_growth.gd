extends SceneTree
const Build = preload("res://scripts/rogue_build.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var s := TideSession.new(); root.add_child(s); s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,912)
	var p: Dictionary=s.players[1]
	p.rogue_selection={}; p.build_reward_queue=[]; s.raid.phase="rogue_combat"
	check(p.build_level==1 and p.build_xp==0 and p.build_attribute_points==0,"Fresh run has level one, no free points")
	p.hp=p.max_hp*.5
	var hp: float=p.hp
	Build.add_experience(s,p,39)
	check(p.build_level==1 and p.build_xp==39 and p.build_attribute_points==0,"XP below threshold grants no points")
	Build.add_experience(s,p,1)
	check(p.build_level==2 and p.build_xp==0 and p.build_attribute_points==2,"First level needs 40 XP and grants two points")
	Build.add_experience(s,p,125)
	check(p.build_level==4 and p.build_xp==0 and p.build_attribute_points==6,"Large XP grant crosses multiple thresholds exactly")
	check(p.hp==hp,"Level-up does not heal")
	Build.floor_enter(p)
	check(p.build_level==4 and p.build_xp_total==165 and p.build_attribute_points==6,"Floor entry preserves XP and grants no points")
	var ally: Dictionary=s.make_player(2,{"hero":1,"mode":"roguelike"})
	s.players[2]=ally; Build.reset(s,ally); ally.status="down"
	var enemy := {"hp":0.0,"build_xp_reward":6}
	Build.enemy_experience(s,enemy); Build.enemy_experience(s,enemy)
	check(p.build_xp==6 and ally.build_xp==6,"XP shared with downed teammate once, independent of killer")
	for flag in ["rogue_summoned","boss_construct","build_no_rewards"]:
		var excluded := {"hp":0.0,"build_xp_reward":20}; excluded[flag]=true
		Build.enemy_experience(s,excluded)
	check(p.build_xp==6,"Summons and constructs grant no XP")
	Build.enemy_experience(s,{"hp":1.0,"build_xp_reward":20})
	Build.enemy_experience(s,{"hp":0.0})
	check(p.build_xp==6,"Alive and unbudgeted enemies grant no XP")
	ally.connected=false; Build.enemy_experience(s,{"hp":0.0,"build_xp_reward":2})
	check(ally.build_xp==6 and p.build_xp==8,"Disconnected players do not receive new XP")
	s.players.erase(2); s.enemies.clear()
	s.spawn_enemy(p.p+Vector2(450,0),0)
	var victim: Dictionary=s.enemies.back(); victim.hp=0; victim.last=-1; victim["build_xp_reward"]=2
	s.simulate(.016)
	check(p.build_xp==10 and not s.enemies.has(victim),"Actual death settlement awards XP without last-hit ownership")
	var points: int=p.build_attribute_points
	for area in range(1,6):
		s.raid.area=area; s.raid.room="combat"; Build.award(s,p)
	check(p.build_attribute_points==points,"Area awards grant no attributes")
	# Measure actual opened-chest RNG, not a parallel formula.
	var counts := []
	for room in ["combat","boss"]:
		var drops := 0
		for trial in 1000:
			p.build_chest_attribute_drops=0; s.raid.room=room
			s.raid.reward_chest={"p":p.p,"opened":false,"tier":0}; s.raid.reward_drops=[]
			s.roguelike.loot_interact(s,p)
			var shards: Array=s.raid.reward_drops.filter(func(drop): return drop.category=="attribute")
			drops+=shards.size()
			check(shards.size()<=1,"Each chest has at most one personal attribute drop")
			var packets: int=s.raid.reward_drops.size()
			s.roguelike.loot_interact(s,p)
			check(s.raid.reward_drops.size()==packets,"Reopening chest cannot reroll attribute drop")
		counts.append(drops)
	check(counts[0] in range(140,261) and counts[1] in range(420,581),"Observed normal/boss drop rates match 20%/50%: "+str(counts))
	for trial in 50:
		p.build_chest_attribute_drops=2; s.raid.reward_chest={"p":p.p,"opened":false,"tier":0}; s.raid.reward_drops=[]
		s.roguelike.loot_interact(s,p)
		check(not s.raid.reward_drops.any(func(drop): return drop.category=="attribute"),"Two drops per floor cap enforced")
	Build.floor_enter(p)
	check(p.build_chest_attribute_drops==0,"Next floor resets only drop cap")
	s.raid.reward_chest={}; s.raid.reward_drops=[]; s.elapsed+=2
	s.roguelike.add_reward_drop(s,p.p,0,{"name":"属性灵晶 +1","attribute_points":1},0,1,"attribute")
	s.raid.reward_drops[0]["personal"]=true
	ally.connected=true; ally.status="active"; ally.p=p.p; s.players[2]=ally
	s.roguelike.loot_interact(s,ally)
	check(s.raid.reward_drops.size()==1,"Attribute shard bound to personal owner")
	points=p.build_attribute_points
	s.roguelike.loot_interact(s,p); s.roguelike.loot_interact(s,p)
	check(p.build_attribute_points==points+1 and s.raid.reward_drops.is_empty(),"Physical pickup grants one point exactly once")
	print("BUILD GROWTH: %d checks, %d failures; chest samples %s" % [checks,failures,str(counts)])
	s.queue_free(); quit(1 if failures>0 else 0)
