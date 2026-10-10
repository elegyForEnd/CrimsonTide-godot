extends SceneTree
const Campaign = preload("res://scripts/story_campaign.gd")
var checks := 0
var failures := 0
func check(value: bool, text: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(text)
func _initialize() -> void: call_deferred("run")
func reach(map, start: Vector2) -> Dictionary:
	var unit := 60
	var begin := Vector2i(start/unit)
	var queue: Array[Vector2i]=[begin]; var seen: Dictionary={begin:true}; var cursor := 0
	while cursor<queue.size():
		var p: Vector2i=queue[cursor]; cursor+=1
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=p+d
			if seen.has(next) or not map.walkable(Vector2(next*unit)+Vector2.ONE*30): continue
			seen[next]=true; queue.append(next)
	return seen
func reached(seen: Dictionary, p: Vector2) -> bool:
	var goal := Vector2i(p/60)
	for x in range(-1,2):
		for y in range(-1,2):
			if seen.has(goal+Vector2i(x,y)): return true
	return false
func run() -> void:
	var c=Campaign.new(); c.save_enabled=false; c.state=c.new_state()
	c.state.accepted=c.content.quests.keys()
	for a in range(1,7):
		c.enter(a,0)
		var seen := reach(c.map,c.hero_at)
		for p in c.map.npc_at: check(reached(seen,p),"camp NPC reached %d %s" % [a,p])
		for s in c.map.outdoor:
			var r=c.map.regions[s]
			check(reached(seen,r.origin+r.spawn),"continuous region reached %d:%d" % [a,s])
			for p in r.anchors+r.side_anchors+r.chests+[r.waypoint]: check(reached(seen,r.origin+p),"outdoor objective/cache reachable %d:%d %s" % [a,s,p])
			c.map.activate(s); c.state.stage=s
			for node in c.objective_nodes(): check(c.map.walkable(node.p) and reached(seen,node.p),"actual task object reached "+node.id)
		for door in c.map.portals:
			if not c.map.regions[door.source].indoor: check(reached(seen,door.p),"dungeon entrance reachable %d:%d" % [a,door.stage])
		for s in c.map.regions:
			if s==0: continue
			if not c.map.regions[s].indoor: continue
			c.enter(a,s); seen=reach(c.map,c.hero_at)
			for p in c.map.anchors+c.map.side_anchors+c.map.regions[s].chests+[c.map.waypoint]: check(reached(seen,p),"dungeon rooms joined %d:%d %s" % [a,s,p])
			for node in c.objective_nodes(): check(c.map.walkable(node.p) and reached(seen,node.p),"actual dungeon task object reached "+node.id)
			for door in c.map.entrances(): check(reached(seen,door.p),"stairs between dungeon floors reached %d:%d" % [a,s])
			var route: PackedVector2Array=c.map.route(c.map.spawn,c.map.anchors[-1])
			check(not route.is_empty() and route[-1].distance_to(c.map.anchors[-1])<100,"navigation reaches dungeon stairs %d:%d" % [a,s])
	# Continuous crossing uses movement, keeps party positions and enemies on revisit.
	c.enter(1,0); c.hero_at=Vector2(1100,1940)
	for i in 110: c.update(.02,Vector2.DOWN)
	check(c.state.stage==1 and c.hero_at.y>2500,"south gate is a continuous walk")
	var after: Vector2=c.hero_at
	check(after.distance_to(c.map.spawn)>0,"crossing does not reset hero to region spawn")
	check("P-M03" in c.state.completed,"continuous exit records prologue")
	var enemy=c.enemies[0]; enemy.hp-=10; var hp: float=enemy.hp
	c.change_sector(0); c.change_sector(1)
	check(c.enemies[0].hp==hp,"sector revisit keeps living enemy state")
	check(not c.travel(1,1),"unactivated waypoint blocked")
	c.hero_at=c.map.waypoint; c.activate_waypoint(); check("1:1" in c.state.waypoints,"waypoint activates through interaction")
	check(c.travel(1,0) and c.hero_at.distance_to(c.map.waypoint)<150,"waypoints travel in either direction")
	c.enter(1,1)
	var r=c.map.regions[1]; var at: Vector2=r.origin+Vector2(3380,1820)
	c.hero_at=at
	for i in 100: c.hero_at=c.map.move(c.hero_at,Vector2(0,-10))
	check(c.map.height_at(c.hero_at)>120,"stairs climb onto terrace")
	for i in 100: c.hero_at=c.map.move(c.hero_at,Vector2(0,10))
	check(c.map.height_at(c.hero_at)<45,"natural shoulder descends continuously beyond the former stair")
	var cache: Dictionary=c.nearby_chests()[0]; c.hero_at=cache.p
	check(c.open_cache(cache) and not c.open_cache(cache),"exploration cache reward is unique")
	var door: Dictionary=c.map.portals[0]; c.hero_at=door.p; c.use_entrance(door)
	check(c.map.layer>0 and c.state.stage==door.stage,"entrance enters separate dungeon")
	c.hero_at=c.map.spawn; c.use_entrance(c.map.entrances()[0])
	check(c.map.layer==0 and c.hero_at.distance_to(door.p)<180,"dungeon stair returns to exact surface doorway")
	c.enter(1,7)
	var deeper: Dictionary=c.map.entrances()[-1]; c.hero_at=deeper.p; c.use_entrance(deeper)
	check(c.state.stage==8,"optional cave has a second floor")
	c.hero_at=c.map.spawn; c.use_entrance(c.map.entrances()[0])
	check(c.state.stage==7 and c.map.layer==7,"optional lower floor returns to its parent floor")
	c.enter(1,8); c.save_enabled=true; c.path="user://story-geography-roundtrip.json"
	check(c.save_campaign(),"optional floor save succeeds")
	var loaded=Campaign.new(); loaded.load_campaign(c.path)
	check(loaded.state.stage==8 and loaded.map.layer==8,"optional floor survives reload")
	check(loaded.state.waypoints==c.state.waypoints and loaded.state.opened_chests==c.state.opened_chests,"activated travel and caches persist")
	check(loaded.explored==c.explored,"exploration fog persists")
	print("story geography: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
