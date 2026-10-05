extends SceneTree
# Isolates campaign sprite rendering. No AI, terrain, particles or networking.
const World = preload("res://scripts/world_3d.gd")
var view: Node3D
var textures: Array[Texture2D] = []
var stage := -1
var age := 0.0
var times: Array[float] = []
var updates: Array[float] = []
var cases := [
	{"name":"one_small", "count":1, "height":82.0, "cut":2, "update":true},
	{"name":"one_large", "count":1, "height":240.0, "cut":2, "update":true},
	{"name":"40_small_prepass", "count":40, "height":82.0, "cut":2, "update":true},
	{"name":"40_large_prepass", "count":40, "height":240.0, "cut":2, "update":true},
	{"name":"40_large_discard", "count":40, "height":240.0, "cut":1, "update":true},
	{"name":"40_large_blend", "count":40, "height":240.0, "cut":0, "update":true},
	{"name":"40_large_frozen", "count":40, "height":240.0, "cut":2, "update":false},
]
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(1280,800)
	view=World.new()
	root.add_child(view)
	view.view_camera.size=8.0
	view.view_camera.position=Vector3(7.2,24,23.5)
	view.view_camera.look_at(Vector3(7.2,0,4.5))
	for file in ["crystal-hare-nocturne","moon-monolith-colossus","sunken-bell-carcass"]:
		textures.append(load("res://assets/enemies/"+file+".png"))
	next_case()
func submit() -> void:
	var c: Dictionary=cases[stage]
	view.begin_sprites()
	for i in int(c.count):
		var h: float=c.height
		var pos := Vector2(300+(i%10)*85,300+(i/10)*95)
		var frame := int(age*8)%12
		view.submit_sprite(textures[i%textures.size()],Rect2(-h*.75,-h,h*1.5,h*1.5),Rect2((frame%4)*256,(frame/4)*256,256,256),Color.WHITE,Transform2D(0,pos))
	view.end_sprites()
func next_case() -> void:
	stage+=1
	if stage>=cases.size(): quit(); return
	age=0.0
	times.clear(); updates.clear()
	submit()
	for sprite in view.sprites: sprite.alpha_cut=cases[stage].cut
func _process(dt: float) -> bool:
	if stage<0: return false
	age+=dt
	var start := Time.get_ticks_usec()
	if cases[stage].update: submit()
	if age>.5:
		times.append(dt*1000)
		updates.append((Time.get_ticks_usec()-start)/1000.0)
	if age>=2.0:
		times.sort(); updates.sort()
		print(JSON.stringify({"case":cases[stage].name,"frames":times.size(),"frame_median_ms":times[times.size()/2],"frame_p95_ms":times[int(times.size()*.95)],"submit_median_ms":updates[updates.size()/2],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}))
		next_case()
	return false
