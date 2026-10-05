extends SceneTree
# Campaign terrain + actual enemy submission, without combat VFX or networking.
var session: TideSession
var field: Battlefield
var enemy_template: Dictionary
var stage := -1
var age := 0.0
var times: Array[float] = []
var ai_times: Array[float] = []
var cases := [
	{"name":"terrain_only", "count":0, "kind":0, "ai":false},
	{"name":"one_small_terrain", "count":1, "kind":0, "ai":false},
	{"name":"one_large_terrain", "count":1, "kind":14, "ai":false},
	{"name":"40_small_terrain", "count":40, "kind":0, "ai":false},
	{"name":"40_large_terrain", "count":40, "kind":14, "ai":false},
	{"name":"40_large_ai", "count":40, "kind":14, "ai":true},
	{"name":"40_small_ai", "count":40, "kind":0, "ai":true},
]
func _initialize() -> void: call_deferred("run")
func stop_fx(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is CanvasItem: node.hide()
	for child in node.get_children(): stop_fx(child)
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(1280,800)
	session=TideSession.new(); root.add_child(session)
	session.solo({"hero":0}); session.launch(false,1729)
	session.set_physics_process(false)
	for candidate in session.enemies:
		if not candidate.get("mini_boss",false) and not candidate.get("raid_boss",false):
			enemy_template=candidate.duplicate(true)
			break
	assert(not enemy_template.is_empty())
	session.players[1].p=session.ruins.sites[0].p
	field=Battlefield.new(); field.session=session; root.add_child(field)
	for child in field.get_children():
		if child!=field.world_3d: stop_fx(child)
	field.camera=session.players[1].p
	next_case()
func next_case() -> void:
	stage+=1
	if stage>=cases.size(): quit(); return
	age=0.0; times.clear(); ai_times.clear()
	session.enemies.clear(); session.bullets.clear()
	var center: Vector2=session.players[1].p
	for i in int(cases[stage].count):
		# Bypass habitat population limits to guarantee the requested test count.
		var e := enemy_template.duplicate(true)
		e.id=10000+i; e.type=int(cases[stage].kind)
		e.p=center+Vector2(-220+(i%10)*45,180+(i/10)*35)
		e.home=e.p; e.hp=10000.0; e.max_hp=10000.0
		session.enemies.append(e)
	print("START "+str(cases[stage].name)+" enemies="+str(session.enemies.size()))
func _process(dt: float) -> bool:
	if stage<0: return false
	age+=dt
	var start := Time.get_ticks_usec()
	if cases[stage].ai:
		for e in session.enemies: e.cd=99.0; e.p=e.home
		session.update_enemies(1.0/60.0)
	if age>.75:
		times.append(dt*1000)
		ai_times.append((Time.get_ticks_usec()-start)/1000.0)
	if age>=2.5:
		times.sort(); ai_times.sort()
		print(JSON.stringify({"case":cases[stage].name,"frames":times.size(),"frame_median_ms":times[times.size()/2],"frame_p95_ms":times[int(times.size()*.95)],"ai_median_ms":ai_times[ai_times.size()/2],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}))
		next_case()
	return false
