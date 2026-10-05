extends SceneTree
# Deterministic reference rendering for every particle style and world projection.
const Current=preload("res://scripts/combat_particles.gd")
const Reference=preload("res://output/performance-reference/combat_particles.gd")
var engines: Array=[]
var views: Array[SubViewport]=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for script in [Reference,Current]:
		var view := SubViewport.new()
		view.size=Vector2i(1000,700); view.disable_3d=true; view.transparent_bg=true
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(view); views.append(view)
		var engine: Node2D=script.new(); view.add_child(engine); engines.append(engine)
	var styles := ["spark","ice","star","stone","dust","feather","petal","electric","soul","water","ember"]
	DirAccess.make_dir_recursive_absolute("res://output/particle-equivalence")
	for projection in 3:
		for engine in engines:
			engine.reset(); engine.rng.seed=1729
			engine.modulate=Color.WHITE if projection==0 else Color(.65,.8,.9,.7)
			engine.transform=Transform2D(0,Vector2(0,0)) if projection==0 else Transform2D(.16,Vector2(1,.62),0,Vector2(30,55)) if projection==1 else Transform2D(-.12,Vector2(-.9,.7),0,Vector2(960,90))
			for i in styles.size():
				var at := Vector2(110+(i%6)*135,150+(i/6)*260)
				engine.burst(at,Vector2.RIGHT,Color(.3,.6,.9,.85),styles[i],24,1.2,PI)
				engine.start("gather"+str(i),at,Vector2.RIGHT,Color(.8,.2,.4,.7),styles[i],"gather",1.0,35,30)
		for frame in 5:
			for engine in engines:
				for i in styles.size():
					if frame==1: engine.move("gather"+str(i),Vector2(115+(i%6)*135,145+(i/6)*260))
					if frame==3: engine.stop("gather"+str(i))
				engine.advance(.065)
			if var_to_bytes(engines[0].particles)!=var_to_bytes(engines[1].particles):
				push_error("Particle simulation changed"); quit(1); return
			await process_frame
			await RenderingServer.frame_post_draw
			for i in 2: views[i].get_texture().get_image().save_png("res://output/particle-equivalence/%d-%d-%s.png" % [projection,frame,"before" if i==0 else "after"])
	print("PARTICLE EQUIVALENCE: 15 identical simulation snapshots; PNG pairs saved")
	quit()
