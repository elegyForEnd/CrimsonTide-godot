extends SceneTree
const Combat=preload("res://scripts/weapon_combat_vfx_3d.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func capture(view: SubViewport) -> Image:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func difference(a: Image,b: Image) -> int:
	var x := a.get_data(); var y := b.get_data(); var total := 0
	for i in x.size(): total+=absi(int(x[i])-int(y[i]))
	return total
func run() -> void:
	var view := SubViewport.new(); view.size=Vector2i(480,360); view.own_world_3d=true; view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var world := Node3D.new(); view.add_child(world)
	var camera := Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=4.5
	world.add_child(camera); camera.position=Vector3(0,5,8); camera.look_at(Vector3(0,.6,0)); camera.make_current()
	var wall := MeshInstance3D.new(); var box := BoxMesh.new(); box.size=Vector3(10,5,.25); wall.mesh=box
	wall.position=Vector3(0,1.4,3); var paint := StandardMaterial3D.new(); paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; paint.albedo_color=Color("243341"); wall.material_override=paint; world.add_child(wall)
	var fx=Combat.new(); fx.camera=camera; world.add_child(fx)
	var blocked := await capture(view)
	fx.event({"kind":"strike","p":Vector2(-65,0),"aim":Vector2.RIGHT,"weapon_index":613,"reach":170,"vfx_action":"art","id":1})
	fx.event({"kind":"impact","p":Vector2(65,0),"aim":Vector2.RIGHT,"weapon_index":628,"damage":20,"vfx_action":"heavy","id":2,"enemy_id":3})
	fx.advance(.09)
	check((await capture(view)).get_data()==blocked.get_data(),"World depth occludes painted surfaces, impact parts, tail and smoke together")
	wall.hide()
	var release=fx.effects[0]; var contact=fx.effects[1]
	for effect in fx.effects:
		for child in effect.get_children():
			if child is MeshInstance3D: child.hide()
	var empty := await capture(view)
	var layers := [release.ribbon,release.authored.trail,contact.authored.contact_paint,contact.authored.contact_smoke]
	for i in layers.size():
		var node: MeshInstance3D=layers[i]
		check(is_instance_valid(node) and node.mesh!=null,"Independent layer has actual world geometry")
		node.show(); var isolated := await capture(view)
		check(difference(isolated,empty)>100,"Painted body, tail, impact and smoke each produce their own pixels: "+str(i))
		node.hide()
	fx.reset()
	check((await capture(view)).get_data()==empty.get_data(),"Reset removes every painted and smoke layer")
	view.queue_free(); await process_frame
	print("WEAPON HYBRID LAYERS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
