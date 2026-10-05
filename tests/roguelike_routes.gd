extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,1729)
	var p: Dictionary=s.players[1]
	check(s.raid.exits.size()==2,"Two destinations are prepared")
	s.enemies.clear()
	s.roguelike.clear_room(s)
	s.perform(1,"rogue_next",{"index":1,"revision":s.raid.revision})
	check(s.raid.area==1,"Cannot leave before claiming reward")
	preload("res://tests/rogue_reward_flow.gd").claim(s,p)
	var revision: int=s.raid.revision
	s.perform(1,"rogue_next",{"index":1,"revision":revision})
	check(s.raid.area==1,"Remote exit requests rejected")
	p.p=s.ruins.exit_position(0)
	s.perform(1,"rogue_next",{"index":1,"revision":revision})
	check(s.raid.area==1,"Cannot select the other doorway from this doorway")
	p.p=s.ruins.exit_position(1)
	var expected: String=s.raid.exits[1].room
	s.perform(1,"rogue_next",{"index":1,"revision":revision})
	check(s.raid.area==2 and s.raid.room==expected,"Second exit enters its advertised destination")
	s.perform(1,"rogue_next",{"index":1,"revision":revision})
	check(s.raid.area==2,"Stale exit input cannot skip rooms")
	s.raid.area=4
	s.roguelike.enter(s)
	s.enemies.clear()
	s.roguelike.clear_room(s)
	preload("res://tests/rogue_reward_flow.gd").claim(s,p)
	p.p=s.ruins.exit_position(1)
	s.perform(1,"rogue_next",{"index":1,"revision":s.raid.revision})
	check(s.raid.room=="boss" and s.raid.challenge,"Challenge gate keeps required floor guardian")
	s.enemies.clear()
	s.raid.wave=3
	s.roguelike.spawn_wave(s)
	var challenge_hp: float=s.enemies[0].max_hp
	s.enemies.clear()
	s.raid.challenge=false
	s.roguelike.spawn_wave(s)
	check(is_equal_approx(challenge_hp,s.enemies[0].max_hp*1.25),"Challenge guardian has advertised health")
	s.enemies.clear()
	s.roguelike.clear_room(s)
	preload("res://tests/rogue_reward_flow.gd").claim(s,p)
	p.p=s.ruins.exit_position(1)
	s.perform(1,"rogue_next",{"index":1,"revision":s.raid.revision})
	check(s.raid.floor==2 and s.raid.area==1 and s.raid.room=="shop","Floor transition supports shop route")
	check(not s.raid.challenge,"Challenge modifier does not leak into following room")
	for floor_index in 5:
		var silhouettes: Dictionary={}
		for area in range(1,6):
			var map=preload("res://scripts/rogue_map.gd").new()
			map.generate(1729+(floor_index+1)*100+area)
			map.configure(floor_index,area,true)
			silhouettes[str(map.floor_polygon)]=true
			var peer=preload("res://scripts/rogue_map.gd").new()
			peer.generate(map.map_seed)
			peer.configure(floor_index,area,true)
			check(map.floor_polygon==peer.floor_polygon and map.obstacles==peer.obstacles,"Peer reconstructs identical geometry")
			for index in 2: check(not map.blocked(map.exit_position(index),20),"Doorway has clear collision space")
			# A continuous central lane guarantees every encounter and exit is reachable.
			for x in range(330,2781,12): check(map.inside_floor(Vector2(x,map.lane_center(x))),"Ground corridor remains connected before obstacle avoidance")
		check(silhouettes.size()==5,"All five areas have distinct silhouettes")
	for long_room in [false,true]:
		var map=preload("res://scripts/rogue_map.gd").new()
		map.generate(1742)
		map.configure(0,2,long_room)
		for index in 2:
			var start := Vector2(map.fork_start,map.lane_center(map.fork_start))
			var destination: Vector2=map.exit_position(index)
			var at := start
			# The diagonal path bends around the scenery wedge; walking a
			# straight shortcut across that wedge should remain blocked.
			var route: Array[Vector2]=[destination]
			if index==1:
				route.push_front(Vector2(map.width*.88,map.ground_y(.425)))
			for waypoint in route:
				var leg_start := at
				for step in 100:
					at=map.move(at,(waypoint-leg_start)/100.0,20)
			check(at.distance_to(destination)<1,"Player can walk continuously along each branch in long and compact rooms")
	s.queue_free()
	await process_frame
	print("ROGUE ROUTES ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
