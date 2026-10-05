extends SceneTree
const Geometry = preload("res://scripts/boss_geometry.gd")
const Choreo = preload("res://scripts/boss_choreography.gd")
const SHAPE_SHADER = preload("res://resources/boss_damage_shape.gdshader")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(400,400)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var container := Node2D.new()
	container.position=Vector2(200,200)
	viewport.add_child(container)
	var rect := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader=SHAPE_SHADER
	mat.set_shader_parameter("art_texture",load("res://assets/bosses/imagegen/bell_dial.png"))
	mat.set_shader_parameter("tone",Color("b8caff"))
	mat.set_shader_parameter("active",true)
	mat.set_shader_parameter("opacity",1.0)
	mat.set_shader_parameter("cover_count",0)
	rect.material=mat
	container.add_child(rect)
	var mismatch := 0
	for shape in ["circle","ring","cone","line","lane","gap_ring","arc","capsule"]:
		for angle in [0.0,.7,PI,PI*1.5]:
			var h := {"p":Vector2(200,200),"aim":Vector2.from_angle(angle),"shape":shape,"radius":95.0,"inner":0.0,"arc":.9,"gap":.65,"choreographed":true}
			if shape in ["ring","gap_ring","arc"]: h.inner=55.0
			if shape in ["lane","capsule"]: h.inner=19.0
			container.rotation=angle
			var bounds := Geometry.bounds(h)
			rect.position=bounds.position
			rect.size=bounds.size
			var fit := Geometry.art_fit(h,Vector2(1280,1280))
			check(absf(fit.x/1280-fit.y/1280)<.000001,"Square effect never stretches at any hazard orientation")
			var oblong_fit := Geometry.art_fit(h,Vector2(1536,1024))
			check(absf(oblong_fit.x/1536-oblong_fit.y/1024)<.000001,"Non-square texture preserves native aspect ratio")
			var uniforms := Geometry.shader_data(h)
			for key in uniforms: mat.set_shader_parameter(key,uniforms[key])
			await process_frame
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			for y in range(75,326,9):
				for x in range(75,326,9):
					var point := Vector2(x+.5,y+.5)
					var lit := image.get_pixel(x,y).a>.001
					var hit := Geometry.contains(h,point)
					check(lit==hit,"GPU effect mask equals damage: %s / %s" % [shape,point])
					if lit!=hit: mismatch+=1
			if shape=="gap_ring" and angle==.7: image.save_png("user://boss-safe-gap.png")
	# Time-varying origins, aim and radius feed exactly the same predicate.
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero":0})
	s.launch(false,1729)
	s.set_physics_process(false)
	# The CPU and GPU also agree on the shadow behind an intact cover object.
	s.enemies=[{"id":900,"p":Vector2(250,200),"hp":65.0,"boss_construct":true,"construct_cover":true}]
	var cover_h := {"p":Vector2(200,200),"aim":Vector2.RIGHT,"shape":"lane","radius":150.0,"inner":44.0,"cover":true,"choreographed":true}
	container.rotation=0
	var cover_bounds := Geometry.bounds(cover_h)
	rect.position=cover_bounds.position
	rect.size=cover_bounds.size
	for key in Geometry.shader_data(cover_h): mat.set_shader_parameter(key,Geometry.shader_data(cover_h)[key])
	mat.set_shader_parameter("cover_count",1)
	var cover_uniforms := PackedVector3Array([Vector3(50,0,35)])
	while cover_uniforms.size()<8: cover_uniforms.append(Vector3.ZERO)
	mat.set_shader_parameter("covers",cover_uniforms)
	await process_frame
	await RenderingServer.frame_post_draw
	var covered_image := viewport.get_texture().get_image()
	for y in range(130,270,7):
		for x in range(180,370,7):
			var point := Vector2(x+.5,y+.5)
			check((covered_image.get_pixel(x,y).a>.001)==(Geometry.contains(cover_h,point) and not Choreo.cover_blocks(s,cover_h,point)),"GPU cover shadow equals actual protection")
	for frame in 15:
		var h := {"shape":"gap_ring","p":Vector2(frame*7,frame*3),"aim":Vector2.from_angle(frame*.13),"radius":90.0+frame*4,"inner":45.0+frame*2,"arc":.9,"gap":.65,"choreographed":true}
		for x in range(-170,171,17):
			for y in range(-170,171,17):
				var point := Vector2(x,y)
				check(s.expedition.hazard_contains(h,point)==Geometry.contains(h,point),"Moving campaign collision uses shared geometry")
				check(s.roguelike.combat.contains(h,point)==Geometry.contains(h,point),"Moving rogue collision uses shared geometry")
	# Painted horizontal entities must obey the same mask, rather than extending past it.
	rect.visible=false
	var white := Image.create(400,400,false,Image.FORMAT_RGBA8); white.fill(Color.WHITE)
	var sprite := Sprite2D.new(); sprite.texture=ImageTexture.create_from_image(white)
	var birth := ShaderMaterial.new(); birth.shader=load("res://resources/boss_entity_birth.gdshader")
	birth.set_shader_parameter("clip_ground",true)
	sprite.material=birth; container.add_child(sprite)
	for shape_name in ["circle","cone","lane","gap_ring","capsule"]:
		for angle in [0.0,PI*.5,PI,PI*1.5]:
			var h := {"p":Vector2(200,200),"aim":Vector2.from_angle(angle),"shape":shape_name,"radius":95.0,"inner":35.0 if shape_name=="gap_ring" else 19.0 if shape_name in ["capsule","lane"] else 0.0,"arc":.9,"gap":.65}
			container.rotation=angle
			for key in ["shape","radius","inner","arc","gap"]: birth.set_shader_parameter(key,Geometry.shader_data(h)[key])
			await process_frame; await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			for y in range(80,321,8):
				for x in range(80,321,8):
					var point := Vector2(x+.5,y+.5)
					check((image.get_pixel(x,y).a>.001)==Geometry.contains(h,point),"Painted entity clips to the exact warning / damage footprint")
	s.queue_free()
	viewport.queue_free()
	await process_frame
	print("BOSS DAMAGE GEOMETRY ",checks," checks, ",failures," failures; GPU mismatches=",mismatch)
	quit(1 if failures else 0)
