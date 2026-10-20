extends SceneTree
const VFX=preload("res://scripts/weapon_projectile_vfx_3d.gd")
const Profiles=preload("res://scripts/weapon_effect_profiles.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var camera := Camera3D.new(); world.add_child(camera); camera.position=Vector3(3,6,7)
	var fx=VFX.new(); world.add_child(fx); fx.camera=camera
	fx.height_at=func(p: Vector2): return 10+p.x*.1
	check(fx.world_point(Vector2(100,200),30).is_equal_approx(Vector3(1,.5,2)),"Simulation and terrain/flight height map to native 3D metres")
	fx.observe([{"p":Vector2.ZERO,"weapon_index":624}],.02)
	check(fx.flights.is_empty(),"Missing authoritative identity cannot invent a world projectile")
	var bullet={"fx_id":11,"p":Vector2(30,80),"height":20.0,"weapon_index":638,"spell":"needle","v":Vector2(600,0)}
	var original: Dictionary=bullet.duplicate(true)
	fx.observe([bullet],.02)
	check(bullet==original,"3D VFX cannot mutate authoritative projectile data")
	var flight: Dictionary=fx.flights[11]
	check(flight.profile==Profiles.action_profile(638,"","normal") and flight.weapon_index==638,"Actual projectile carries an independent exact weapon and normal-action profile")
	check(flight.body is MeshInstance3D and flight.ribbon is MeshInstance3D and flight.core is MeshInstance3D,"Body and ribbon are native world meshes")
	check(flight.geometry.vertices.is_empty(),"One source position cannot invent a wake")
	check(not flight.ribbon.visible and flight.ribbon.mesh==null,"A newborn ribbon cannot submit an empty ArrayMesh to the renderer")
	check(fx.particles.size()==2,"Real projectile birth owns its small independent particle burst")
	var birth_position: Vector3=fx.particles[0].p
	fx.advance(-.2)
	check(fx.clock==0 and fx.particles[0].p==birth_position and fx.particles[0].age==0,"Negative elapsed time cannot reverse particle motion or age")
	for i in range(1,6):
		fx.advance(.025)
		bullet.p=Vector2(30+i*26,80+i*i*3); bullet.height=20+i*4
		fx.observe([bullet],.025)
	var geometry: Dictionary=flight.geometry
	check(geometry.centers.size()>flight.history.size() and geometry.centers.size()<=VFX.MAX_RIBBON_POINTS,"World arc-length interpolation creates a bounded continuous ribbon")
	check(geometry.vertices.size()==geometry.centers.size()*2 and geometry.indices.size()==(geometry.centers.size()-1)*6,"Native ribbon has indexed 3D triangles and paired UV edges")
	check(geometry.centers[0].is_equal_approx(fx.world_point(Vector2(30,80),20)),"Historical terrain and flight elevation remain captured at the tail")
	check(geometry.centers[-1].is_equal_approx(fx.world_point(bullet.p,bullet.height)),"World mesh head ends exactly at the observed authoritative point")
	check(flight.body.position.is_equal_approx(flight.p),"Body plane is located in native world coordinates")
	check(geometry.uv[0]==Vector2.ZERO and geometry.uv[-1]==Vector2.ONE,"Mesh carries continuous longitudinal/transverse UV")
	check(is_zero_approx(geometry.widths[0]) and is_zero_approx(geometry.widths[-1]),"Native ribbon closes at both ends")
	var has_spatial_depth := false
	for vertex in geometry.vertices:
		check(vertex.is_finite(),"World mesh vertices stay finite")
		if vertex.y>.01 and vertex.z>.01: has_spatial_depth=true
	check(has_spatial_depth,"Ribbon contains world height and depth rather than screen coordinates")
	for index in geometry.indices: check(index>=0 and index<geometry.vertices.size(),"All indexed world triangles reference valid vertices")
	var captured_centers: PackedVector3Array=geometry.centers.duplicate()
	camera.position+=Vector3(3,0,-1)
	fx.advance(0)
	check(flight.geometry.centers==captured_centers,"Moving Camera3D changes facing but cannot move the world path")
	var snapshot: Dictionary=bullet.duplicate(true)
	fx.observe([snapshot],.02)
	check(fx.flights.size()==1 and fx.flights[11].root==flight.root,"Snapshot replacement preserves native stable-ID mesh identity")
	bullet.p+=Vector2(900,0); fx.observe([bullet],.02)
	check(flight.history.size()==1 and flight.geometry.vertices.is_empty(),"Teleport breaks world ribbon without a false bridge")
	check(not flight.ribbon.visible,"Teleport hides stale ribbon geometry before the next real segment exists")
	var before_death: int=fx.particles.size()
	fx.observe([],.05)
	check(not flight.body.visible and fx.particles.size()==before_death+3,"Real despawn hides the body and owns one independent death burst")
	var first_fade := float(flight.material.get_shader_parameter("wake_opacity"))
	check(first_fade>0 and first_fade<1,"Despawn begins continuous wake attenuation before root removal")
	fx.observe([],.05)
	check(fx.particles.size()==before_death+3,"Missing snapshot cannot repeat a death burst every frame")
	check(float(flight.material.get_shader_parameter("wake_opacity"))<first_fade,"Every despawn frame attenuates the remaining wake")
	fx.observe([],.06)
	check(fx.flights.is_empty(),"Missing projectiles remove all native mesh nodes after .15 seconds")
	fx.advance(.5)
	check(fx.particles.is_empty() and fx.particle_batch.multimesh.visible_instance_count==0,"Birth/death particle geometry expires independently")
	fx.reset()
	for index in range(600,648):
		fx.observe([{"fx_id":index,"p":Vector2(index,80),"weapon_index":index,"height":20}],.001)
		check(fx.flights[index].profile==Profiles.action_profile(index,"","normal"),"All 48 weapon identities and action profiles are explicitly retained in 3D")
	check(fx.particles.size()<=VFX.MAX_PARTICLES,"World particle budget remains bounded")
	fx.reset()
	var bullets: Array=[]
	for i in 130: bullets.append({"fx_id":i,"p":Vector2(i,40),"weapon_index":624})
	fx.observe(bullets,.02)
	check(fx.flights.size()==VFX.MAX_FLIGHTS,"Native projectile mesh budget is capped at 96")
	for frame in 40:
		fx.advance(.006)
		bullets[0].p+=Vector2(1,0); fx.observe(bullets,.006)
	check(fx.flights[0].history.size()<=VFX.MAX_HISTORY and fx.flights[0].geometry.centers.size()<=VFX.MAX_RIBBON_POINTS,"History and distance-interpolated mesh budgets remain bounded")
	fx.reset()
	check(fx.flights.is_empty() and fx.particles.is_empty() and fx.get_child_count()==1,"Reset removes every flight root and retains only the persistent particle batch")
	world.queue_free(); await process_frame; await process_frame
	print("WEAPON PROJECTILE VFX 3D ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
