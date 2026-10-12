extends Node
## Live 3D skeletal render in a transparent viewport, composed in existing Y order.
## Rogue maps are painted 2D; this does not claim per-limb scene depth occlusion.
const Actor := preload("res://scripts/boss_actor_3d.gd")
var views: Dictionary={}
const LIMIT := 2
const DRAW_RECT := Rect2(-220,-335,440,440)

func reset() -> void:
	for data in views.values(): data.view.queue_free()
	views.clear()

func sync(enemies: Array, dt: float, clock: float, visible_field: bool) -> void:
	if not visible_field:
		for data in views.values(): data.view.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	var live: Dictionary={}
	for e: Dictionary in enemies:
		if not Actor.supports(e,"rogue"): continue
		var key := str(e.id); live[key]=true
		if not views.has(key):
			if views.size()>=LIMIT: continue
			views[key]=_make_view()
		var data: Dictionary=views[key]
		data.view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		data.actor.sync(e,dt,clock)
		data.snapshot=e.duplicate(true)
	for key in views.keys():
		if live.has(key): continue
		var data: Dictionary=views[key]
		if data.actor.death_age<2.6:
			data.snapshot.hp=0; data.actor.sync(data.snapshot,dt,clock)
		else: data.view.queue_free(); views.erase(key)

func _make_view() -> Dictionary:
	var view := SubViewport.new(); view.size=Vector2i(640,640); view.transparent_bg=true
	view.own_world_3d=true; view.msaa_3d=Viewport.MSAA_2X; add_child(view)
	var world := Node3D.new(); view.add_child(world)
	var actor := Actor.new(); world.add_child(actor); actor.target_scale=1.0; actor.set_variant(true)
	var camera := Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=4.4; camera.position=Vector3(0,4.5,7); world.add_child(camera)
	camera.look_at(Vector3(0,1.22,0)); camera.make_current()
	var sun := DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-38,-35,0); sun.light_energy=1.7; sun.shadow_enabled=false; world.add_child(sun)
	var rim := DirectionalLight3D.new(); rim.rotation_degrees=Vector3(-22,155,0); rim.light_color=Color("b6bbf2"); rim.light_energy=.9; world.add_child(rim)
	var env := WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color(0,0,0,0)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color=Color("9bacc1"); env.environment.ambient_light_energy=.55
	env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC; world.add_child(env)
	return {"view":view,"actor":actor,"snapshot":{}}

func draws(e: Dictionary) -> bool: return views.has(str(e.get("id","")))
func texture(e: Dictionary) -> Texture2D:
	var data: Dictionary=views.get(str(e.id),{})
	return data.view.get_texture() if not data.is_empty() else null

func draw_corpses(canvas: CanvasItem, camera_offset: Vector2) -> void:
	for data in views.values():
		if data.actor.death_age<0: continue
		canvas.draw_set_transform(data.snapshot.p-camera_offset)
		canvas.draw_texture_rect(data.view.get_texture(),DRAW_RECT,false,Color(1,1,1,clampf((2.6-data.actor.death_age)/.6,0,1)))
	canvas.draw_set_transform(-camera_offset)
