extends SceneTree
const Campaign = preload("res://scripts/story_campaign.gd")
const Map = preload("res://scripts/story_map.gd")
var checks := 0
var failures := 0
func check(value: bool, text: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(text)
func _initialize() -> void:
	call_deferred("run")

func connected(map, start: Vector2, target: Vector2) -> bool:
	var size := 40
	var begin := Vector2i(start/size)
	var goal := Vector2i(target/size)
	var queue: Array[Vector2i]=[begin]
	var seen: Dictionary={begin:true}
	var cursor := 0
	while cursor<queue.size():
		var cell: Vector2i=queue[cursor]; cursor+=1
		if cell.distance_to(goal)<2: return true
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+direction
			if seen.has(next) or not map.walkable(Vector2(next*size)+Vector2.ONE*20): continue
			seen[next]=true; queue.append(next)
	return false

func run() -> void:
	var c = Campaign.new(); c.save_enabled=false; c.load_campaign("user://story-unit-unused.json")
	check(c.content.quests.size()==73,"73 stable quests")
	check(c.content.main_order.size()==40,"40 main nodes")
	check(not c.valid_save({"version":1,"completed":[],"steps":{},"gear":{}}),"incomplete save rejected")
	var corrupt := c.new_state(); corrupt.accepted=["nonexistent"]
	check(not c.valid_save(corrupt),"unknown task ids in save rejected")
	check(not c.travel(1,1),"undiscovered field cannot be teleported into")
	check(c.south_gate(),"camp south gate opens without NPC prerequisites")
	check(c.state.stage==1 and c.state.completed.size()==3,"south gate records prologue once")
	check(c.current_main().id=="A1-M01","first field quest")
	check(not c.complete("A2-M01"),"locked quest rejected")
	var rewards := 0
	for id in c.content.main_order:
		if id in c.state.completed: continue
		if id=="E-M01": c.choose_rescue(false)
		var q: Dictionary=c.content.quests[id]
		c.enter(q.act,q.stage)
		for e in c.enemies: c.hit(e,100000)
		var guard := 0
		while not id in c.state.completed and guard<12:
			guard+=1
			var nodes := c.objective_nodes()
			for node in nodes:
				if node.id==id:
					c.hero_at=node.p; c.interact_object(node); break
		check(id in c.state.completed,"main task completes through world objects: "+id)
		var coins: int=c.state.coins
		check(not c.complete(id) and c.state.coins==coins,"reward is idempotent: "+id)
		rewards+=1
	check(c.current_main().is_empty(),"entire six act campaign reaches epilogue")
	check(c.state.unlocked_act==6,"sixth camp unlocked")
	check(not c.prepared_routes() and not c.prepared_rescue(),"main completion does not fake optional preparation")
	for id in c.content.quests:
		var q: Dictionary=c.content.quests[id]
		if q.kind=="main": continue
		check(c.accept(id),"optional prerequisite eligible "+id)
		c.enter(q.act,q.stage)
		for e in c.enemies: c.hit(e,100000)
		var guard := 0
		while not id in c.state.completed and guard<12:
			guard+=1
			for node in c.objective_nodes():
				if node.id==id: c.hero_at=node.p; c.interact_object(node); break
		check(id in c.state.completed,"optional task completes through world objects: "+id)
	check(c.state.completed.size()==73,"all 73 tasks can be completed")
	check(c.prepared_rescue() and c.prepared_routes(),"preparation predicates reflect actual tasks")
	# Save/reload uses a separate test slot and checks JSON numeric conversions.
	c.save_enabled=true; c.path="user://story-test-roundtrip.json"
	check(c.save_campaign(),"atomic save succeeds")
	var loaded = Campaign.new(); loaded.load_campaign(c.path)
	check(loaded.state.completed==c.state.completed,"completion survives reload")
	check(loaded.state.xp==c.state.xp and loaded.state.coins==c.state.coins,"numeric state survives reload")
	check(loaded.state.steps==c.state.steps,"partial objective progress survives reload")
	check(loaded.level()<=50,"campaign growth caps at 50")
	loaded.enter(1,0)
	loaded.state.potions=0; loaded.state.hp=1
	check(loaded.service("heal") and loaded.state.potions==5 and loaded.state.hp==loaded.max_hp(),"camp provides recovery without soft lock")
	loaded.state.bag=[{"slot":"armor","tier":3,"name":"test"}]
	loaded.equip(0)
	check(loaded.state.gear.armor==3,"equipment applies stat tier")
	loaded.switch_hero(1)
	check(loaded.state.gear.armor==0,"each hero has independent equipment")
	loaded.switch_hero(0)
	check(loaded.state.gear.armor==3,"switching restores the same hero's equipment")
	check(loaded.learn(0),"earned levels provide specialty points")
	var rank := loaded.specialty(0)
	loaded.switch_hero(1)
	check(loaded.specialty(0)==0,"specialty allocation is per hero")
	loaded.switch_hero(0)
	check(loaded.specialty(0)==rank,"specialty allocation survives hero switching")
	# Actual combat respects geometry, cooldowns, telegraphs, dodge and death recovery.
	var combat = Campaign.new(); combat.save_enabled=false; combat.load_campaign("user://story-combat-unused.json")
	combat.south_gate(); combat.enemies.clear()
	combat.hero_at=combat.map.regions[1].origin+Vector2(2400,1450); combat.state.hero=1
	combat.spawn_enemy(combat.map.regions[1].origin+Vector2(2400,1150),1,"probe")
	var foe: Dictionary=combat.enemies[0]
	var hp: float=foe.hp
	combat.map.regions[1].obstacles.append(Rect2(2200,1300,400,30))
	check(combat.attack(Vector2.UP) and foe.hp==hp,"attack cannot damage through a wall")
	check(not combat.attack(Vector2.UP),"primary cooldown prevents duplicate attack")
	combat.map.regions[1].obstacles.clear(); combat.attack_cd=0
	combat.attack(Vector2.UP)
	check(foe.hp<hp,"unobstructed attack causes real damage")
	foe.windup=0.05; foe.target=combat.hero_at; foe.radius=380; foe.shape="ring"
	hp=combat.state.hp
	combat.update(0.06,Vector2.ZERO)
	check(combat.state.hp==hp,"ring centre is a safe zone")
	foe.windup=0.05; foe.shape="circle"; foe.target=combat.hero_at
	combat.dodge(Vector2.RIGHT); combat.update(0.06,Vector2.ZERO)
	check(combat.state.hp==hp,"dodge avoids telegraphed impact")
	combat.dodge_time=0; combat.hurt_time=0; combat.state.hp=1
	foe.windup=0.05; foe.shape="circle"; foe.target=combat.hero_at
	combat.update(0.06,Vector2.ZERO)
	check(combat.state.stage==0 and combat.state.hp==combat.max_hp(),"death returns to camp safely")
	check("P-M03" in combat.state.completed,"death keeps completed campaign tasks")
	# Rescue prerequisites are frozen at battle entry, and checkpoint restoration is real.
	c.state.completed.erase("A6-M06"); c.state.completed.erase("E-M01")
	c.state.steps["A6-M06"]=0; c.state.steps["E-M01"]=0
	c.state.final_started=false; c.state.ending_seen=false
	c.enter(6,5); c.save_campaign(); c.enter(6,6)
	check(c.state.rescue_prepared_at_battle,"prepared rescue is captured before battle")
	check(FileAccess.file_exists(c.path+".before-finale"),"final battle retains a checkpoint file")
	c.complete("A6-M06",false)
	check(c.choose_rescue(true),"prepared tools enable queen rescue")
	check(c.complete("E-M01",false),"epilogue follows an explicit queen choice")
	check(c.restore_before_finale(),"checkpoint can be restored")
	check(c.state.stage==5 and not "A6-M06" in c.state.completed,"restore returns to the pre-battle campaign state")
	check(FileAccess.file_exists(c.path+".after-finale"),"restoration preserves the previous ending save")
	print("story campaign: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
