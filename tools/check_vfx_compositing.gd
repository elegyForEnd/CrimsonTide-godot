extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(128,128); root.content_scale_size=root.size
	RenderingServer.set_default_clear_color(Color.BLACK)
	var view := SubViewport.new(); view.size=Vector2i(128,128); view.transparent_bg=true; view.own_world_3d=true; root.add_child(view)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var camera := Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=2; camera.position=Vector3(0,0,2); view.add_child(camera)
	var mesh := MeshInstance3D.new(); mesh.mesh=QuadMesh.new(); view.add_child(mesh)
	var mat := StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color=Color(1,0,0,.5); mesh.material_override=mat
	var sprite := Sprite2D.new(); sprite.texture=view.get_texture(); sprite.position=Vector2(64,64); root.add_child(sprite)
	for i in 4: await process_frame; RenderingServer.force_draw(false)
	var raw := view.get_texture().get_image().get_pixel(64,64)
	var mixed := root.get_texture().get_image().get_pixel(64,64)
	print("HALF RED raw=",raw," canvas=",mixed)
	var corrected := ShaderMaterial.new(); corrected.shader=preload("res://resources/weapon_vfx_composite.gdshader"); sprite.material=corrected
	for i in 3: await process_frame; RenderingServer.force_draw(false)
	var result := root.get_texture().get_image().get_pixel(64,64)
	print("HALF RED corrected=",result)
	var ok := absf(result.r-raw.r)<.012 and result.r>mixed.r*1.8
	if not ok: push_error("The canvas pass attenuates transparent 3D output a second time")
	print("VFX COMPOSITING ","PASS" if ok else "FAIL")
	quit(0 if ok else 1)
