extends Node
## A single north-up photograph of the shipped scene, shared by atlas and HUD.
## The temporary scene is released after capture; no second game simulation runs.
var campaign
var texture: Texture2D
var zone_key := ""
var generation := 0
var source_path := ""

func refresh() -> void:
	var geo=campaign.terrain()
	var trial: bool=not campaign.state.trial_task.is_empty()
	var key: String=geo.key+(":trial" if trial else "")
	if zone_key==key: return
	zone_key=key; texture=null; generation+=1
	var ticket := generation
	if DisplayServer.get_name()=="headless": return
	source_path=geo.scene_path(RenderingServer.get_current_rendering_method()=="gl_compatibility")
	if not ResourceLoader.exists(source_path): return
	var viewport := SubViewport.new()
	viewport.size=Vector2i(768,768); viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var packed: PackedScene=load(source_path)
	var scene: Node3D=packed.instantiate()
	viewport.add_child(scene)
	if trial:
		# The same sea plane as World.build(), in native scene coordinates.
		var sea := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size=Vector2(24,52); sea.mesh=plane
		var water := ShaderMaterial.new(); water.shader=preload("res://resources/story_water.gdshader"); sea.material_override=water
		var sea_at: Vector2=geo.native(Vector2(-330,900))*.01
		sea.position=Vector3(sea_at.x,geo.height(Vector2(-330,900))-.24,sea_at.y); viewport.add_child(sea)
	for node in scene.find_children("*","Camera3D",true,false): node.queue_free()
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("151b26")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("c3d1df")
	environment.environment.ambient_light_energy=.75
	viewport.add_child(environment)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	var extra: Vector2=Vector2(720*geo.ratio.x,0) if trial else Vector2.ZERO
	var extent: Vector2=geo.region.extent+extra
	camera.size=maxf(extent.x,extent.y)*.01
	camera.far=400.0
	var center: Vector2=(geo.region.origin-extra+extent*.5)*.01
	camera.position=Vector3(center.x,150,center.y)
	viewport.add_child(camera)
	camera.look_at(Vector3(center.x,0,center.y),Vector3.FORWARD)
	camera.current=true
	# Allow queued editor cameras and lightmaps to settle before photographing.
	await get_tree().process_frame
	if ticket==generation:
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if ticket==generation:
			var photo := viewport.get_texture().get_image()
			if not photo.is_empty(): texture=ImageTexture.create_from_image(photo)
	viewport.queue_free()
