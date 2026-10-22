extends SceneTree
const Combat=preload("res://scripts/weapon_combat_vfx_3d.gd")
const Paint=preload("res://scripts/weapon_606_reference_art.gd")
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
	var camera := Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=3.3
	world.add_child(camera); camera.position=Vector3(0,5,8); camera.look_at(Vector3(0,.5,0)); camera.make_current()
	var fx=Combat.new(); fx.camera=camera; world.add_child(fx)
	var empty := await capture(view)
	for layer in ["surface","impact","mist","ground","shard","charge","trail"]:
		var row := Paint.metadata(layer)
		check(str(row.get("file","")).begins_with("res://assets/combat/weapon-606-action-v1/"),"Each layer uses its new storyboard-derived asset")
		var image: Image=load(str(row.file)).get_image()
		check(image!=null and image.detect_alpha()!=Image.ALPHA_NONE,"Every original has transparency")
	for action in ["normal","heavy","art"]:
		fx.event({"kind":"strike","p":Vector2(-70,0),"aim":Vector2.RIGHT,"weapon_index":606,"reach":190,"attack_kind":"thrust" if action!="normal" else "cone","vfx_action":action,"id":1})
		fx.advance(.045)
		var release := await capture(view)
		check(difference(release,empty)>200,"New release is visible: "+action)
		var effect=fx.effects[0]
		check(effect.authored.history.size()>1 and effect.authored.trail.visible,"A moving attack leaves a separate sampled history trail")
		check(effect.authored.contact_smoke.visible,"A swing emits its own thin vapor before target contact")
		var saved: Array=[]
		for child in effect.get_children():
			if child is MeshInstance3D:
				saved.append([child,child.visible]); child.hide()
		for node in [effect.authored.trail,effect.authored.contact_smoke]:
			node.show()
			check(difference(await capture(view),empty)>50,"Trail and emitted vapor independently produce visible pixels")
			node.hide()
		for item in saved: item[0].visible=item[1]
		check(not effect.authored.contact_paint.visible,"A miss never fabricates a target ice shatter")
		check(effect.authored.ground_paint.visible,"Frost extends under the real attack path before target contact")
		var frost_arrays: Array=effect.authored.ground_paint.mesh.surface_get_arrays(0)
		for vertex in frost_arrays[Mesh.ARRAY_VERTEX]:
			check(absf(vertex.y-.018)<.001,"Path frost stays flat on the floor")
		fx.event({"kind":"impact","p":Vector2(80,0),"aim":Vector2.RIGHT,"weapon_index":606,"damage":20,"vfx_action":action,"id":1,"enemy_id":3})
		fx.advance(.055)
		var contact=fx.effects.back()
		check(difference(await capture(view),release)>200,"Real contact changes the rendered frame: "+action)
		for item in fx.effects:
			for child in item.get_children():
				if child is MeshInstance3D: child.hide()
		for node in [contact.authored.contact_paint,contact.authored.contact_smoke,contact.authored.ground_paint,contact.authored.shards]:
			node.show()
			check(difference(await capture(view),empty)>50,"Contact layer independently contributes pixels: "+action)
			node.hide()
		fx.advance(.8)
		check(fx.effects.is_empty() and difference(await capture(view),empty)==0,"Every released/contact layer cleans up after dissipation")
	fx.event({"kind":"hold_charge","p":Vector2.ZERO,"aim":Vector2.RIGHT,"weapon_index":606,"hold_time":.65,"id":1})
	fx.advance(2.0)
	check(fx.charges.has(1) and difference(await capture(view),empty)>50,"Held ice gathering survives full charge")
	fx.event({"kind":"hold_cancel","id":1})
	check(fx.effects.is_empty() and difference(await capture(view),empty)==0,"Cancel removes charge artwork immediately")
	var wall := MeshInstance3D.new(); var box := BoxMesh.new(); box.size=Vector3(10,5,.25); wall.mesh=box
	wall.position=Vector3(0,1.4,3); var paint := StandardMaterial3D.new(); paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; paint.albedo_color=Color("243341"); wall.material_override=paint; world.add_child(wall)
	var blocked := await capture(view)
	fx.event({"kind":"impact","p":Vector2.ZERO,"aim":Vector2.RIGHT,"weapon_index":606,"damage":20,"id":1,"enemy_id":4})
	fx.advance(.06)
	check(difference(await capture(view),blocked)==0,"World depth occludes the new painted effects")
	fx.reset(); view.queue_free(); await process_frame
	print("WEAPON 606 REFERENCE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
