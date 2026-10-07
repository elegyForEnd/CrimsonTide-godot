extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

const GRID := 6.0
const BODY_RADIUS := 15.0
const BODY_MARGIN := BODY_RADIUS+5.0

# Reachability is planned on the map grid instead of walking a hand-picked polyline:
# a fixed waypoint rots as soon as the region artwork moves (the old
# `(width*.88, ground_y(.425))` waypoint ended up inside the diagonal scenery wedge).
func bfs_path(map, radius: float, start: Vector2, goal: Vector2, step: float) -> Array:
	var cols: int=int(ceil(map.width/step))
	var rows: int=int(ceil(map.extent.y/step))
	var came := PackedInt32Array()
	came.resize(cols*rows)
	came.fill(-1)
	var s := Vector2i(int(start.x/step),int(start.y/step))
	if map.blocked(Vector2(s.x*step,s.y*step),radius): return []
	var goal_cell := Vector2i(int(goal.x/step),int(goal.y/step))
	came[s.y*cols+s.x]=s.y*cols+s.x
	var queue: Array[Vector2i]=[s]
	var head := 0
	var found := -1
	while head<queue.size():
		var cur: Vector2i=queue[head]
		head+=1
		if cur.distance_to(Vector2(goal_cell))<=2.0: found=cur.y*cols+cur.x; break
		for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var n: Vector2i=cur+d
			if n.x<0 or n.y<0 or n.x>=cols or n.y>=rows: continue
			var index: int=n.y*cols+n.x
			if came[index]!=-1: continue
			if map.blocked(Vector2(n.x*step,n.y*step),radius): continue
			came[index]=cur.y*cols+cur.x
			queue.append(n)
	if found==-1: return []
	var cell := Vector2i(found%cols,int(found/cols))
	var path: Array=[]
	while true:
		path.push_front(Vector2(cell.x*step,cell.y*step))
		var parent: int=came[cell.y*cols+cell.x]
		var previous := Vector2i(parent%cols,int(parent/cols))
		if previous==cell: break
		cell=previous
	return path

func max_passable_radius(map, start: Vector2, goal: Vector2, step: float) -> float:
	if not bfs_path(map,90.0,start,goal,step).is_empty(): return 90.0
	var low := 0.0
	var high := 90.0
	for i in 11:
		var mid := (low+high)*.5
		if bfs_path(map,mid,start,goal,step).is_empty(): high=mid
		else: low=mid
	return low

func replay_path(map, radius: float, path: Array) -> Dictionary:
	var at: Vector2=path[0]
	var stalled := false
	for i in range(1,path.size()):
		var waypoint: Vector2=path[i]
		var guard := 0
		while at.distance_to(waypoint)>.5:
			guard+=1
			if guard>400: stalled=true; break
			var delta := waypoint-at
			var next: Vector2=map.move(at,delta.normalized()*minf(delta.length(),4.0),radius)
			if next.distance_to(at)<.01: stalled=true; break
			at=next
		if stalled: break
	return {"at":at,"stalled":stalled}

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,1729)
	var p: Dictionary=s.players[1]
	# Both visible branches lead to the next row of the node graph.
	var doors: int=s.raid.exits.size()
	check(doors==2,"Both branches have usable doors")
	var door := doors-1
	s.enemies.clear()
	s.roguelike.clear_room(s)
	s.perform(1,"rogue_next",{"index":door,"revision":s.raid.revision})
	check(s.raid.area==1,"Cannot leave before claiming reward")
	preload("res://tests/rogue_reward_flow.gd").claim(s,p)
	var revision: int=s.raid.revision
	s.perform(1,"rogue_next",{"index":door,"revision":revision})
	check(s.raid.area==1,"Remote exit requests rejected")
	if doors==2:
		p.p=s.ruins.exit_position(0)
		s.perform(1,"rogue_next",{"index":1,"revision":revision})
		check(s.raid.area==1,"Cannot select the other doorway from this doorway")
	p.p=s.ruins.exit_position(door)
	var expected: String=s.raid.exits[door].room
	s.perform(1,"rogue_next",{"index":door,"revision":revision})
	check(s.raid.area==2 and s.raid.room==expected,"Second exit enters its advertised destination")
	s.perform(1,"rogue_next",{"index":door,"revision":revision})
	check(s.raid.area==2,"Stale exit input cannot skip rooms")
	# The row before the guardian always offers both guardian doors; jump straight to it.
	var depth_total: int=s.roguelike.depth_count(s)
	s.raid.area=depth_total-1
	s.roguelike.enter(s)
	s.enemies.clear()
	s.roguelike.clear_room(s)
	preload("res://tests/rogue_reward_flow.gd").claim(s,p)
	check(s.raid.exits.size()==2,"The guardian gate always offers two doors")
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
	check(s.raid.floor==2 and s.raid.area==1,"Floor transition enters the next floor's first row")
	check(not s.raid.challenge,"Challenge modifier does not leak into following room")
	# The opening room of a floor is the door the party picked on the previous floor.
	s.raid.route[0]="shop"
	s.roguelike.enter(s)
	check(s.raid.floor==2 and s.raid.area==1 and s.raid.room=="shop","Floor transition supports shop route")
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
	# R5+ (walkability): the route is planned on the map grid and then replayed
	# through the real `map.move()`, instead of walking one hand-picked polyline.
	# The old `(width*.88, ground_y(.425))` waypoint sat inside the blocked wedge
	# between the two roads, so the straight leg into it was rejected by collision
	# and the walker stalled there — a stale test route, not a blocked branch.
	# 2026-10-07: that wedge is gone (`rogue_map.gd` `fork_junction()` merges the
	# junction ground), so the fork is now one open plaza and the walker no longer
	# has to find an angle around an invisible corner.
	for long_room in [false,true]:
		var map=preload("res://scripts/rogue_map.gd").new()
		map.generate(1742)
		map.configure(0,2,long_room)
		var fork := Vector2(map.fork_start,map.lane_center(map.fork_start))
		for index in 2:
			var destination: Vector2=map.exit_position(index)
			check(not map.blocked(destination,BODY_MARGIN),"Doorway has clear collision space in long and compact rooms")
			# A body radius plus 5px of margin must fit along the whole branch.
			check(max_passable_radius(map,fork,destination,GRID)>=BODY_MARGIN,"Branch corridor is wider than the player body")
			var path: Array=bfs_path(map,BODY_MARGIN,fork,destination,GRID)
			check(not path.is_empty(),"A continuous walk exists from the fork to each branch")
			if path.is_empty(): continue
			var walk: Dictionary=replay_path(map,BODY_MARGIN,path)
			check(not walk.stalled and walk.at.distance_to(destination)<15.0,"Player can walk continuously along each branch in long and compact rooms")
			if index==1:
				# 直行路与斜向路之间的地面属于路口广场：从岔口斜着直走上门的整条直线必须畅通。
				var cut := false
				for sample in 200:
					if map.blocked(fork.lerp(destination,float(sample+1)/200.0),BODY_MARGIN): cut=true; break
				check(not cut,"The straight diagonal from the fork into the upper door is walkable")
	# 2026-10-07 · 全地图的分叉口都不许再有隐形墙：从岔口中心到两个门口的整条直线都必须
	# 直接可走，且要留出 BODY_MARGIN 的余量。旧的 `merge_polygons(floor, branch)` 写法会在
	# 两条路之间留下一个必须绕行的楔形空地（实测 30%~56% 的直线被挡）。
	for floor_index in 5:
		for area in range(1,8):
			for long_room in [true,false]:
				var map=preload("res://scripts/rogue_map.gd").new()
				map.generate(1729+floor_index*100+area)
				map.configure(floor_index,area,long_room)
				var fork := Vector2(map.fork_start,map.lane_center(map.fork_start))
				for index in 2:
					var destination: Vector2=map.exit_position(index)
					var clear := true
					for sample in 200:
						if map.blocked(fork.lerp(destination,float(sample+1)/201.0),BODY_MARGIN): clear=false; break
					check(clear,"No air wall between the fork and door %d: f%d a%d %s" % [index,floor_index+1,area,"long" if long_room else "compact"])
	s.queue_free()
	await process_frame
	print("ROGUE ROUTES ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
