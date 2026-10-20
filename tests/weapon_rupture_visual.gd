extends SceneTree
const Combat=preload("res://scripts/weapon_combat_vfx_3d.gd")
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var view := SubViewport.new(); view.size=Vector2i(480,360); view.own_world_3d=true; view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var camera := Camera3D.new(); view.add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=6; camera.position=Vector3(0,6,9); camera.look_at(Vector3.ZERO); camera.make_current()
	var fx=Combat.new(); fx.camera=camera; view.add_child(fx)
	fx.event({"kind":"strike","weapon_index":614,"p":Vector2(-100,0),"aim":Vector2.RIGHT,"id":1,"reach":285,"vfx_action":"art"})
	fx.advance(.25)
	var ground: MeshInstance3D=fx.effects.back().authored.ground_paint
	check(ground.visible and ground.mesh!=null,"The actual terrain layer has geometry")
	check(ground.material_override.shader.resource_path.ends_with("weapon_rupture_decal.gdshader"),"Terrain uses painted decal shader")
	var texture: Texture2D=ground.material_override.get_shader_parameter("earth_texture")
	check(texture!=null and texture.resource_path.ends_with("earth.png"),"Original stone texture is bound at runtime")
	var vertices: PackedVector3Array=ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v in vertices: check(absf(v.y-vertices[0].y)<.001,"Rupture lies flat on terrain")
	# Isolate the ground from the bright main stroke to verify visible textured pixels.
	for effect in fx.effects:
		for child in effect.get_children():
			if child is GeometryInstance3D and child!=ground: child.hide()
	await process_frame; await RenderingServer.frame_post_draw
	var bytes := view.get_texture().get_image().get_data(); var pixels := 0
	for i in range(3,bytes.size(),4):
		if int(bytes[i])>15: pixels+=1
	check(pixels>100,"Isolated ground texture renders visible pixels on GPU")
	fx.advance(2)
	check(fx.effects.is_empty(),"Ground residue expires with its effect")
	print("RUPTURE VISUAL ",failures," failures")
	quit(1 if failures else 0)
