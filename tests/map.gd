extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(text)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for seed_value in [1,1729,9899]:
		var world := Ruins.new()
		world.generate(seed_value)
		var queue: Array[Vector2i]=[Vector2i(Ruins.SPAWN/40)]
		var visited := {queue[0]:true}
		var cursor := 0
		while cursor<queue.size():
			var cell := queue[cursor]
			cursor+=1
			for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i=cell+delta
				if visited.has(next) or world.blocked(Vector2(next)*40): continue
				visited[next]=true
				queue.append(next)
		for chest in world.chests:
			check(not world.blocked(chest.p),"Chest collision")
			check(visited.has(Vector2i((chest.p/40).round())),"Chest unreachable: "+str(chest.p))
		for site in world.sites: check(visited.has(Vector2i((site.p/40).round())),"Site unreachable: "+site.name)
		for pos in world.exits: check(visited.has(Vector2i((pos/40).round())),"Exit unreachable: "+str(pos))
		for bridge in world.bridges:
			var center: Vector2=bridge.get_center()
			check(world.clear_line(center-Vector2(260,0),center+Vector2(260,0)),"Bridge crossing blocked")
		check(world.blocked(Vector2(Ruins.river_x(1600),1600)),"River prevents traversal")
		for feature in world.features: check(world.blocked(feature.p),"Lake or cliff blocks walking")
		check(world.blocked(Vector2(70,70)),"Sea blocks traversal")
	var session := TideSession.new()
	root.add_child(session)
	session.solo({"hero":0})
	session.launch(false,1729)
	session.set_physics_process(false)
	check(session.safe_radius()>Ruins.CENTER.length(),"Full map starts safe")
	session.raid.time=session.duration
	check(is_equal_approx(session.safe_radius(),540) and not session.ruins.blocked(session.safe_center()),"Dawn circle surrounds a walkable random arena")
	for enemy in session.enemies: check(not session.ruins.blocked(enemy.p,25),"Enemy spawns on land")
	session.queue_free()
	await process_frame
	print("MAP CHECKS: ",checks," failures: ",failures)
	quit(1 if failures else 0)
