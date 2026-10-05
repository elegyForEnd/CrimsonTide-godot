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
	var signatures: Dictionary={}
	for seed_value in [17,1729,982451]:
		for floor_number in range(1,6):
			for wave in range(1,4):
				var reference: Array=[]
				for repeat in 2:
					s.solo({"hero":0,"mode":"roguelike"})
					s.launch(false,seed_value)
					s.raid.floor=floor_number
					s.raid.route=["elite","shop","combat","treasure","boss"]
					s.raid.area=1
					s.roguelike.enter(s)
					s.enemies.clear()
					s.raid.wave=wave
					s.players[1].p=Vector2([330,1120,1990][wave-1],s.ruins.lane_center([330,1120,1990][wave-1]))
					s.roguelike.spawn_wave(s)
					var points: Array=[]
					var species: Dictionary={}
					var min_x := INF
					var max_x := -INF
					for e in s.enemies:
						check(not s.ruins.blocked(e.p,31) and not s.ruins.on_lava(e.p),"Spawn is on safe traversable ground")
						check(e.p.distance_to(s.players[1].p)>=180,"Spawn avoids player")
						for point in points: check(e.p.distance_to(point)>=100,"Monster spawn separation >=100")
						points.append(e.p)
						species[e.rogue_variant]=true
						min_x=minf(min_x,e.p.x)
						max_x=maxf(max_x,e.p.x)
					check(species.size()>=4,"Expanded roster retains at least four distinct species per wave")
					check(max_x-min_x>=400,"Wave spans encounter space")
					if repeat==0: reference=points.duplicate()
					else: check(points==reference,"Same run seed reproduces positions")
				signatures[str(seed_value)+":"+str(floor_number)+":"+str(wave)]=reference
	check(signatures["17:1:1"]!=signatures["1729:1:1"],"Different seeds change spawn positions")
	s.queue_free()
	await process_frame
	print("ROGUE SPAWN ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
