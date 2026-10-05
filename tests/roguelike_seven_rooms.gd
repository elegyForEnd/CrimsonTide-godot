extends SceneTree

var checks := 0
var failures := 0
const Map = preload("res://scripts/rogue_map.gd")
const Graph = preload("res://scripts/rogue_graph.gd")

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var s=TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike"})
	check(s.launch(false,1729),"Run starts")
	var p: Dictionary=s.players[1]
	while not p.rogue_selection.is_empty():
		s.perform(1,"rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})
	s.roguelike.tick(s,.016)
	# R5: rooms come from the per-floor node graph, so a node offers whatever the graph links
	# (one or two doors) instead of a fixed seven-slot template and two random destinations.
	var seen := {}
	for seed in 200:
		for floor_number in range(1,6):
			var graph: Dictionary=Graph.build(seed,floor_number)
			var nodes: Array=graph.get("order",[])
			check(nodes.size()>=7 and nodes.size()<=10,"Node count stays between seven and ten")
			for id in nodes:
				var entry: Dictionary=Graph.node(graph,str(id))
				var nexts: Array=Graph.neighbors(graph,str(id))
				if str(entry.kind)=="boss":
					check(nexts.is_empty(),"The floor guardian is the only dead end")
				else:
					check(nexts.size()>=1 and nexts.size()<=2,"Every other node offers one or two doors")
				seen[str(entry.kind)]=true
			check(Graph.neighbors(graph,str(graph.boss)).is_empty(),"No node follows the floor guardian")
	check(seen.size()==11,"All eleven room kinds can appear: "+str(seen.keys()))
	s.rng.seed=1729
	s.raid.floor=1
	s.raid.area=1
	s.raid.route=[]
	s.roguelike.new_floor(s)
	for f in 5:
		var depth_total: int=s.roguelike.depth_count(s)
		check(depth_total>=7 and depth_total<=9,"Floor keeps seven to nine node rows")
		for depth in range(1,depth_total+1):
			check(s.raid.floor==f+1 and s.raid.area==depth,"Room progression follows the node depth")
			# Follow the actual offered destination through the public exit action.
			s.roguelike.enter(s)
			check((s.raid.room=="boss")==(depth==depth_total),"Floor guardian is the last node of the floor")
			check(s.raid.exits.size()>=1 and s.raid.exits.size()<=2,"Exit count is one or two")
			for index in s.raid.exits.size(): check(not s.ruins.blocked(s.ruins.exit_position(index),20),"Exit on ground")
			p.rogue_selection={}; p.build_reward_queue=[]
			var index := (depth+1)%2 if s.raid.exits.size()==2 else 0
			p.p=s.ruins.exit_position(index)
			p.status="active"
			s.raid.phase="rogue_exit"
			var expected: String=s.raid.exits[index].room
			s.perform(1,"rogue_next",{"index":index,"revision":s.raid.revision})
			if depth<depth_total: check(s.raid.room==expected,"Chosen destination entered")
	check(not s.running and s.raid.ended,"Final boss exits finish the run")
	var art=preload("res://scripts/rogue_art.gd").new()
	for f in 5:
		for room in ["shop","talent","treasure"]:
			var map=Map.new(); map.generate(1729); map.configure(f,4,false,room)
			var peer=Map.new(); peer.generate(1729); peer.configure(f,4,false,room)
			check(peer.floor_polygon==map.floor_polygon and peer.extent==map.extent,"Matching safe geometry for peers")
			check(map.obstacles.is_empty() and map.terrain_hazards.is_empty(),"Safe room has no combat obstacles or lava")
			check(not map.blocked(Vector2(330,map.lane_center(330)),20),"Safe entrance")
			var texture: Texture2D=art.region_background(f,4,room)
			check(texture!=null and absf(float(texture.get_width())/texture.get_height()-3.0)<.02,"Safe map aspect ratio")
			check(map.blocked(Vector2(map.width*.50,map.extent.y*.40),20),"Background is outside safe lane")
			check(map.blocked(Vector2(map.width*.50,map.extent.y*.93),20),"Foreground is outside safe lane")
			for exit_index in 2:
				check(not map.blocked(map.exit_position(exit_index),25),"Safe exit clearance")
				var at := Vector2(map.width*.70,map.lane_center(map.width*.70))
				var points: Array=[]
				if exit_index==0:
					for x in [.75,.80,.85,.90,.95]: points.append(Vector2(map.width*x,map.lane_center(map.width*x)))
				else:
					var b: Array=map.region.branch
					points.append(map.uv_point([b[0][0],(b[0][1]+b[-1][1])/2]))
					for i in range(1,5): points.append(map.uv_point([b[i][0],(b[i][1]+b[11-i][1])/2]))
				points.append(map.exit_position(exit_index))
				for waypoint in points:
					at=map.move(at,waypoint-at,20)
					check(at.distance_to(waypoint)<1,"Safe fork is continuously walkable: f%d %s" % [f+1,room])
		art.region_backgrounds.clear()
	for f in 5:
		var backgrounds := {}
		for area in range(1,8):
			var key: String=Map.region_key(f,area,"combat")
			backgrounds[key]=true
			check(art.region_background(f,area,"combat")!=null,"Each combat slot has packaged artwork")
			if area not in [2,4]: continue
			var map=Map.new(); map.generate(1729); map.configure(f,area,true,"combat")
			var start := Vector2(330,map.lane_center(330))
			for x in range(350,int(map.width*.78),40):
				var waypoint := Vector2(x,map.lane_center(x))
				start=map.move(start,waypoint-start,20)
				check(start.distance_to(waypoint)<1,"Additional combat avenue reachable")
			for exit_index in 2:
				var at := Vector2(map.width*.70,map.lane_center(map.width*.70))
				var points: Array=[]
				if exit_index==0:
					for x in [.75,.80,.85,.90,.95]: points.append(Vector2(map.width*x,map.lane_center(map.width*x)))
				else:
					var b: Array=map.region.branch
					points.append(map.uv_point([b[0][0],(b[0][1]+b[-1][1])/2]))
					for i in range(1,5): points.append(map.uv_point([b[i][0],(b[i][1]+b[11-i][1])/2]))
				points.append(map.exit_position(exit_index))
				for waypoint in points:
					at=map.move(at,waypoint-at,20)
					check(at.distance_to(waypoint)<1,"Additional combat fork reachable")
			for prop in map.obstacles: check(map.footprint_on_ground(prop.p,prop.radius),"Additional obstacles stay on ground")
		check(backgrounds.size()==7,"Seven distinct combat backgrounds per floor")
		art.region_backgrounds.clear()
	s.queue_free()
	await process_frame
	print("SEVEN ROOMS ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
