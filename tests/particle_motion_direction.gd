extends SceneTree
const Particles=preload("res://scripts/combat_particles.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func aligned(a: Vector2, b: Vector2) -> bool:
	return a.normalized().dot(b.normalized())>.99999
func run() -> void:
	var engine=Particles.new(); root.add_child(engine)
	var worlds := [Transform2D.IDENTITY,Transform2D(.6,Vector2(1.4,.45),0,Vector2(70,90)),Transform2D(-.4,Vector2(-1.2,.6),0,Vector2(30,10))]
	for style in ["spark","ember","electric","soul","water","charge_spark","charge_electric"]:
		for velocity in [Vector2(80,130),Vector2(-120,-30),Vector2(0,-90)]:
			engine.reset(); engine.spawn(Vector2(15,20),velocity,Color.CYAN,style)
			check(aligned(Vector2.from_angle(engine.particles[0].angle),velocity),"Streak starts aligned before simulation: "+style)
			for step in 2:
				if step>0: engine.advance(.05)
				var particle: Dictionary=engine.particles[0]
				for world in worlds:
					engine.prepare_draw_items(world)
					var pose: Transform2D=engine.draw_items[0].pose
					check(aligned(pose.x,world.basis_xform(particle.v)),"Visible stroke follows transformed velocity: "+style)
					engine.glow_batch.submit(engine.draw_items,world.affine_inverse())
					# Inspect the submitted instance buffer; headless uses a dummy renderer.
					var data: PackedFloat32Array=engine.glow_batch.buffer
					var glow_pose: Transform2D=world*Transform2D(Vector2(data[0],data[4]),Vector2(data[1],data[5]),Vector2(data[3],data[7]))
					check(glow_pose.is_equal_approx(pose),"Batched glow and stroke share the same pose: "+style)
	for style in ["petal","feather","ice","stone","star"]:
		engine.reset(); engine.spawn(Vector2.ZERO,Vector2(80,130),Color.WHITE,style)
		var initial: float=engine.particles[0].angle
		engine.particles[0].spin=2.0
		engine.advance(.05)
		check(is_equal_approx(float(engine.particles[0].angle),initial+.1),"Material fragments retain their spin: "+style)
	engine.reset(); engine.spawn(Vector2.ZERO,Vector2.ZERO,Color.WHITE,"spark")
	engine.prepare_draw_items(Transform2D.IDENTITY)
	check(engine.draw_items[0].pose.x.is_finite(),"Stationary streak has a finite initial pose")
	engine.advance(.05)
	check(aligned(Vector2.from_angle(engine.particles[0].angle),engine.particles[0].v),"Initially stationary streak follows gravity once moving")
	engine.queue_free(); await process_frame
	print("PARTICLE MOTION DIRECTION ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
