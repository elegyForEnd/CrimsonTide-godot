extends SceneTree

const Map=preload("res://scripts/rogue_map.gd")
var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void: call_deferred("run")

func reachable_exits(map) -> Array[bool]:
	var origin := Vector2(map.width*.70,map.lane_center(map.width*.70))
	var visited := {Vector2i.ZERO:true}
	var queue: Array[Vector2i]=[Vector2i.ZERO]
	var head := 0
	var reached: Array[bool]=[false,false]
	while head<queue.size():
		var cell: Vector2i=queue[head]
		head+=1
		var at := origin+Vector2(cell)*10
		for index in 2:
			if at.distance_to(map.exit_position(index))<16 and map.move(at,map.exit_position(index)-at,20).distance_to(map.exit_position(index))<1: reached[index]=true
		if reached[0] and reached[1]: return reached
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+direction
			if visited.has(next): continue
			var point := origin+Vector2(next)*10
			if point.x<map.width*.68 or map.blocked(point,20): continue
			if map.move(at,point-at,20).distance_to(point)>1: continue
			visited[next]=true
			queue.append(next)
	return reached

func run() -> void:
	# Fixed artwork samples independent of manifest edits: paving, then scenery.
	var samples := [
		["f3-treasure",Vector2(.95,.30),Vector2(.95,.41)],
		["f3-a7",Vector2(.90,.35),Vector2(.95,.59)],
		["f3-forge",Vector2(.95,.35),Vector2(.95,.45)],
		["f3-gamble",Vector2(.93,.38),Vector2(.95,.50)],
		["f2-talent",Vector2(.90,.32),Vector2(.95,.66)],
		["f5-a5",Vector2(.85,.41),Vector2(.85,.55)],
	]
	for floor_index in 5:
		for kind in ["a1","a2","a3","a4","a5","a6","a7","shop","treasure","talent","curse","event","forge","gamble","mirror"]:
			var area: int=int(kind.substr(1)) if kind.begins_with("a") else 1
			var room: String="" if area<=5 and kind.begins_with("a") else "combat" if kind.begins_with("a") else kind
			if kind=="a6": area=2
			elif kind=="a7": area=4
			var key := "f%d-%s" % [floor_index+1,kind]
			for long_room in [false,true]:
				var map=Map.new()
				map.generate(1729); map.configure(floor_index,area,long_room,room)
				for sample in samples:
					if sample[0]!=key: continue
					check(not map.blocked(sample[1]*map.extent,15),"Audited paving is reachable: "+key)
					check(map.blocked(sample[2]*map.extent,15),"Audited scenery is excluded: "+key)
				var reachable := reachable_exits(map)
				for index in 2:
					check(not map.blocked(map.exit_position(index),25),"Doorway clearance: %s long=%s exit=%d" % [key,long_room,index])
					check(reachable[index],"Both roads remain connected: %s long=%s exit=%d" % [key,long_room,index])
	print("FORK ALIGNMENT ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
