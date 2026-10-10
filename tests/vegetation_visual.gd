extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	var scene := Node3D.new(); root.add_child(scene)
	var kit=preload("res://scripts/story_asset_kit.gd").new()
	var raw: Node3D=kit.instance("woodland_tree",scene,Vector3(-2,0,0))
	var reveal: Node3D=kit.instance("woodland_tree",scene,Vector3(2,0,0))
	kit.prepare_reveal(reveal); kit.reveal(reveal,1)
	for branch in raw.find_children("*","MeshInstance3D",true,false): branch.lod_bias=100
	for branch in reveal.find_children("*","MeshInstance3D",true,false): branch.lod_bias=100
	kit.instance("woodland_fern",scene,Vector3(0,0,2))
	var camera := Camera3D.new(); scene.add_child(camera); camera.position=Vector3(0,6,9); camera.look_at(Vector3(0,1.4,0))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=7; camera.make_current()
	var sun := DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-50,-30,0); sun.light_energy=1.2; scene.add_child(sun)
	var env := Environment.new(); env.background_mode=Environment.BG_COLOR; env.background_color=Color("899aa9")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color.WHITE; env.ambient_light_energy=.6
	camera.environment=env
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/vegetation-material-check.png")
	scene.queue_free(); await process_frame; quit()
