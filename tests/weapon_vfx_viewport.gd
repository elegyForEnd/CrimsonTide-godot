extends SceneTree
const View=preload("res://scripts/weapon_vfx_viewport.gd")
const Combat=preload("res://scripts/weapon_combat_vfx_3d.gd")
var checks := 0
var failures := 0
class Field extends Control:
	var scroll := Vector2(800,300)
	var mount := Vector2(440,330)
	func camera_offset() -> Vector2: return scroll
	func weapon_effect_socket(_id: int) -> Dictionary:
		return {"tip":get_global_transform()*(mount+Vector2(45,0)),"grip":get_global_transform()*mount,"stroke_pivot":get_global_transform()*mount,"charge_points":[get_global_transform()*mount,get_global_transform()*(mount+Vector2(45,0)),get_global_transform()*(mount+Vector2(20,20))],"charge_paths":[[get_global_transform()*mount,get_global_transform()*(mount+Vector2(45,0))],[get_global_transform()*(mount+Vector2(20,20)),get_global_transform()*(mount+Vector2(30,30))]],"active":true}
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var field := Field.new(); field.size=Vector2(1440,900); field.scale=Vector2.ONE*1.25; field.position=Vector2(30,40); root.add_child(field)
	var view=View.new(); view.field=field; field.add_child(view)
	var fx=Combat.new(); fx.camera=view.view_camera; fx.socket_provider=view.socket; view.world.add_child(fx)
	for scroll in [Vector2.ZERO,Vector2(800,300),Vector2(3200,1700)]:
		field.scroll=scroll; view.sync()
		for p in [Vector2(100,250),Vector2(900,600),Vector2(1450,1100)]:
			for height in [0.0,55.0,150.0]:
				var global_point: Vector3=view.world.to_global(Vector3(p.x*.01,height*.01,p.y*.01))
				var actual: Vector2=view.view_camera.unproject_position(global_point)
				check(actual.distance_to(p-scroll-Vector2(0,height))<.05,"Spatial composite matches flat map projection and upright height at all scroll positions")
	var event := {"kind":"windup","p":field.scroll+Vector2(440,385),"aim":Vector2.RIGHT,"weapon_index":638,"id":1,"windup":1.0}
	fx.event(event); fx.advance(.03)
	var before: Vector3=fx.effects[0].origin
	field.mount+=Vector2(35,-15); fx.advance(.02)
	var projected: Vector2=view.view_camera.unproject_position(view.world.to_global(fx.effects[0].origin))
	check(projected.distance_to(field.mount+Vector2(45,0))<.05 and before!=fx.effects[0].origin,"Staff windup follows its actual head socket under Canvas scaling")
	fx.reset(); event.kind="hold_charge"
	for scale_factor in [.75,1.0,1.5,2.0]:
		field.scale=Vector2.ONE*scale_factor
		fx.event(event); fx.advance(.1)
		var charge=fx.charges[1]
		var local_socket: Dictionary=view.socket(1)
		var canvas_socket: Dictionary=field.weapon_effect_socket(1)
		for i in local_socket.charge_points.size():
			check((field.get_global_transform()*Vector2(local_socket.charge_points[i])).distance_to(canvas_socket.charge_points[i])<.01,"Every gathering point converts from Canvas to viewport coordinates")
			var actual: Vector2=view.view_camera.unproject_position(view.world.to_global(charge.data.charge_sites[i]))
			check(actual.distance_to(local_socket.charge_points[i])<.05,"Gathering projects exactly onto weapon under UI scaling")
		for i in local_socket.charge_paths.size():
			for j in local_socket.charge_paths[i].size():
				var actual: Vector2=view.view_camera.unproject_position(view.world.to_global(charge.data.charge_paths[i][j]))
				check(actual.distance_to(local_socket.charge_paths[i][j])<.05,"Independent blade contours preserve their points without connecting separate tracks")
		field.mount+=Vector2(20,-5); fx.advance(.02)
		var moved: Dictionary=view.socket(1)
		check(view.view_camera.unproject_position(view.world.to_global(charge.data.charge_sites[0])).distance_to(moved.charge_points[0])<.05,"Held contour follows movement after scaled spawn")
		fx.reset()
	fx.body_gain=1.55; fx.melee_reach_gain=1.25
	event.weapon_index=613
	event.kind="strike"; event.reach=600; fx.event(event); fx.advance(.03)
	check(is_equal_approx(fx.effects[0].reach,6.0) and fx.effects[0].authored!=null and fx.effects[0].bound==null,"Aimed release uses captured reach and native authored surfaces")
	var captured: Vector3=fx.effects[0].origin
	field.mount+=Vector2(100,0); fx.advance(.02)
	check(fx.effects[0].origin==captured,"Released composite stays in world history rather than following next animation frame")
	field.hide(); view.sync()
	check(view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Hidden field stops its offscreen spatial renderer")
	field.queue_free(); await process_frame
	print("WEAPON VFX VIEWPORT ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
