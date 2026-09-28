extends SceneTree
## Run with a rendering backend (not --headless). Checks actual depth-buffer pixels.
const Presentation = preload("res://scripts/world_3d.gd")
var view: Node3D
var texture: ImageTexture
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func capture(at: Vector2, tag: String, legacy: bool = false) -> int:
	view.begin_sprites()
	view.submit_sprite(texture,Rect2(-20,-110,40,110),Rect2(),Color.WHITE,Transform2D(0,at))
	view.end_sprites()
	if legacy: view.sprites[0].scale.y*=view.view_camera.global_basis.y.dot(Vector3.UP)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	frame.save_png("res://build/sprite-depth-"+tag+".png")
	var count := 0
	for y in frame.get_height():
		for x in frame.get_width():
			var color := frame.get_pixel(x,y)
			if color.r>0.8 and color.b>0.8 and color.g<0.2: count+=1
	return count

func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)

func run() -> void:
	root.size=Vector2i(800,600)
	view=Presentation.new()
	root.add_child(view)
	var world := Ruins.new()
	world.generate(4441043)
	view.sync(world,Vector2(1000,1200),Vector2(root.size))
	for child in view.scenery.get_children():
		view.scenery.remove_child(child)
		child.queue_free()
	var source := Image.create(40,110,false,Image.FORMAT_RGBA8)
	source.fill(Color.MAGENTA)
	texture=ImageTexture.create_from_image(source)
	var front := Vector2(1000,1216)
	var baseline := await capture(front,"baseline")
	view.prism(PackedVector2Array([Vector2(800,800),Vector2(1200,800),Vector2(1200,1200),Vector2(800,1200)]),75,Color("8a8297"))
	var outside := await capture(front,"cliff-front")
	check(baseline>2000,"Billboard is visible before testing occlusion")
	check(outside>=baseline*0.98,"Standing in front of a cliff must not clip the upper body")
	# Prove the test catches the original camera-facing quad, not just disabled depth.
	view.sprites[0].billboard=BaseMaterial3D.BILLBOARD_ENABLED
	var old_mode := await capture(front,"old-mode",true)
	check(old_mode<outside*0.8,"Old tilted billboard reproduces the clipping")
	view.sprites[0].billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
	view.box(Rect2(800,800,400,400),300,Color("756d83"))
	var behind := await capture(Vector2(1000,780),"wall-behind")
	check(behind<baseline*0.1,"A real foreground wall still occludes the actor")
	print("SPRITE DEPTH: baseline=",baseline," front=",outside," old=",old_mode," behind=",behind," failures=",failures)
	view.queue_free()
	await process_frame
	# Also capture the real hero atlas beside a generated cliff, matching the report.
	var session := TideSession.new()
	root.add_child(session)
	session.solo({"hero":0})
	session.launch(false,4441043)
	session.set_physics_process(false)
	session.enemies.clear()
	var cliff: Dictionary={}
	var distance := INF
	for feature in session.ruins.features:
		if feature.kind!="cliff": continue
		var d: float=feature.p.distance_to(Vector2(950,1750))
		if d<distance:
			distance=d
			cliff=feature
	var edge: Vector2=cliff.p
	for vertex in cliff.polygon:
		if vertex.y>edge.y: edge=vertex
	edge.y+=18
	check(not session.ruins.blocked(edge),"Reproduction stands outside the authoritative cliff collision")
	session.players[1].p=edge
	var field := Battlefield.new()
	field.session=session
	field.camera=edge
	root.add_child(field)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/sprite-depth-hero-fixed.png")
	field.queue_free()
	session.queue_free()
	await process_frame
	quit(1 if failures else 0)
