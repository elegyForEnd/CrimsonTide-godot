extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var Map = preload("res://scripts/rogue_map.gd")
	for area in [1,3,5]:
		var map=Map.new()
		map.generate(1729+area)
		map.configure(0,area,true)
		var patches: Array=map.backdrop_quads()
		check(patches.size()==1,"Artwork uses one uniform projection")
		for patch in patches:
			for i in patch.points.size():
				check((patch.points[i]/map.extent).is_equal_approx(patch.uv[i]),"Artwork UV and collision coordinates share the same projection")
		# Test the exterior after corridor union, not former interior seams.
		for i in map.floor_polygon.size():
			var a: Vector2=map.floor_polygon[i]
			var b: Vector2=map.floor_polygon[(i+1)%map.floor_polygon.size()]
			var inward: Vector2=-(b-a).orthogonal().normalized()
			if not map.inside_floor((a+b)/2+inward*15.2): inward=-inward
			var at: Vector2=(a+b)/2+inward*15.2
			if map.blocked(at,15): continue
			for frame in 10:
				var before: Vector2=at
				at=map.move(at,-inward*8,15)
				check((at-before).dot(inward)<0.001,"Holding into curved boundary never pushes player backwards")
			var final: Vector2=at
			for frame in 10: at=map.move(at,-inward*8,15)
			check(at.distance_to(final)<0.01,"Player remains still at boundary after reaching it")
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,1729)
	s.enemies.clear()
	var p: Dictionary=s.players[1]
	p.invuln=999
	# Position legal for movement's 15px radius but inside the former 20px snap zone.
	var a: Vector2=s.ruins.top_edge[2]
	var b: Vector2=s.ruins.top_edge[3]
	var inward: Vector2=-(b-a).orthogonal().normalized()
	p.p=(a+b)/2+inward*17
	check(not s.ruins.blocked(p.p,15) and s.ruins.blocked(p.p,20),"Probe recreates the former snapping condition")
	var before: Vector2=p.p
	s.inputs[1]={"move":Vector2.ZERO,"aim":Vector2.RIGHT,"fire":false,"interact":false}
	for frame in 20: s.simulate(0.016)
	check(p.p==before,"Full simulation does not teleport stationary player away from edge")
	p.dodge_time=s.DODGE_DURATION
	p.dodge_dir=-inward
	before=p.p
	for frame in 20: s.simulate(0.016)
	check((p.p-before).dot(inward)<=0.01,"Dodge stops against boundary without recoil")
	s.queue_free()
	await process_frame
	print("ROGUE GEOMETRY ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
