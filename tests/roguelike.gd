extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func _initialize() -> void: call_deferred("run")
func choose(s,kind: String,index: int = 0) -> void:
	s.perform(1,kind,{"index":index,"revision":s.raid.revision})
func run() -> void:
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
	check(p.weapon==1 and p.rogue_rerolls==2,"Starting purchases applied")
	var base_damage: float=s.weapon_damage(p)
	var base_ultimate: float=s.ultimate_damage(p,100)
	p.rogue_damage=0.12
	check(s.weapon_damage(p)>base_damage and s.ultimate_damage(p,100)>base_ultimate,"Damage boon benefits attacks and ultimate")
	p.rogue_damage=0.0
	var themes: Dictionary={}
	while s.running:
		themes[s.raid.floor]=true
		if s.raid.phase=="rogue_combat":
			for e in s.enemies: e.hp=0
			s.simulate(0.01)
			if s.raid.wave==3:
				check(s.raid.phase=="rogue_reward","Final encounter grants one reward roll")
			else:
				check(s.raid.phase=="rogue_combat","First encounters require more exploration")
				p.p=Vector2(1200 if s.raid.wave==1 else 2100,580)
				s.simulate(0.01)
		elif s.raid.phase=="rogue_reward":
			var first_packet: bool=not s.raid.reward_chest.opened
			preload("res://tests/rogue_reward_flow.gd").pick(s,p)
			check(p.rogue_selection.offers.size()==3,"Three rewards after chest pickup")
			if s.raid.cleared==1 and first_packet:
				var stale: Dictionary={"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0}
				s.perform(1,"rogue_selection_reroll",stale)
				check(p.rogue_rerolls==1,"Reroll consumes one card")
				s.perform(1,"rogue_selection_take",stale)
				check(s.raid.phase=="rogue_reward","Stale offer click cannot claim refreshed reward")
			s.perform(1,"rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})
			preload("res://tests/rogue_reward_flow.gd").claim(s,p)
			check(s.raid.phase=="rogue_exit","Reward taken once, exit unlocked")
		elif s.raid.phase=="rogue_shop":
			var before: int=p.rogue_gold
			choose(s,"rogue_take",1)
			check(p.rogue_gold==before-50,"Shop spends run currency")
			choose(s,"rogue_take",1)
			check(p.rogue_gold==before-50,"Sold item cannot be purchased twice")
			p.p=s.ruins.exit_position(0)
			choose(s,"rogue_next")
		elif s.raid.phase=="rogue_exit":
			p.p=s.ruins.exit_position(0)
			choose(s,"rogue_next")
		else: check(false,"Unexpected phase"); break
	check(themes.size()==5 and s.raid.cleared==25,"All five floors and 25 areas completed")
	check(s.results[1].escaped and s.results[1].coins==550,"Final reward settles exactly once")
	check(not s.results[1].has("pocket") and not s.results[1].has("bags"),"Existing storage preserved")
	s.roguelike.settle(s)
	check(s.results[1].coins==550,"Settlement idempotent")
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,123)
	p=s.players[1]
	p.status="dead"
	s.simulate(0.1)
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
	print("ROGUELIKE ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
