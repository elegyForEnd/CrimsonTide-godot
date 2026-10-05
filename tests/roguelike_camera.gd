extends SceneTree

var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,1729)
	var field=load("res://scripts/rogue_field.gd").new()
	field.session=s
	field.camera_x=700
	field.camera_y=150
	check(field.camera_target(Vector2(1420,670))==Vector2(700,150),"Movement inside camera dead zone does not move scenery")
	check(field.camera_target(Vector2(1420,860)).y>150,"Walking down scrolls scenery up")
	check(field.camera_target(Vector2(1420,540)).y<150,"Walking up scrolls scenery down")
	check(field.camera_target(Vector2(1600,670)).x>700,"Horizontal following remains active")
	for at in [Vector2.ZERO,Vector2(9999,9999)]:
		var target: Vector2=field.camera_target(at)
		check(target.x>=0 and target.y>=0 and target.x<=s.ruins.extent.x-1440 and target.y<=s.ruins.extent.y-900,"Camera never reveals outside the image")
	check(field.ground_transform()*Vector2(1000,800)==Vector2(300,650),"Ground and effects use both camera coordinates")
	field.free()
	s.queue_free()
	await process_frame
	print("ROGUE CAMERA ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
