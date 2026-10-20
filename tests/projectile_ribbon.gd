extends SceneTree
## CPU geometry and lifecycle contracts for the existing projected overlay.
const Finish=preload("res://scripts/combat_finish.gd")
const Ribbon=preload("res://scripts/weapon_projectile_ribbon.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var finish=Finish.new(); root.add_child(finish)
	finish.projector=func(p: Vector2): return p*Vector2(1.1,.65)+Vector2(20,30)
	var bullet={"fx_id":7,"p":Vector2(20,100),"weapon_index":646,"height":20.0}
	finish.observe([bullet],.02)
	check(finish.trails[7].ribbon.geometry.vertices.is_empty(),"A single observed position never invents a projectile wake")
	finish.advance(.02); bullet.p=Vector2(130,100); bullet.height=30.0; finish.observe([bullet],.02)
	finish.advance(.02); bullet.p=Vector2(130,180); bullet.height=44.0; finish.observe([bullet],.02)
	var trail: Dictionary=finish.trails[7]
	var node=trail.ribbon
	var geometry: Dictionary=node.geometry
	check(geometry.centers.size()>trail.points.size() and geometry.centers.size()<=Ribbon.MAX_SAMPLES,"Observed path is distance-resampled with a hard point budget")
	check(geometry.vertices.size()==geometry.centers.size()*2 and geometry.indices.size()==(geometry.centers.size()-1)*6,"Ribbon is an indexed continuous triangle strip")
	check(geometry.uv[0]==Vector2.ZERO and geometry.uv[-1]==Vector2.ONE,"Longitudinal UV covers the complete sampled path")
	check(geometry.centers[0].is_equal_approx(finish.projected(Vector2(20,100))-Vector2(0,20)),"Tail uses the original historical height and projection")
	check(geometry.centers[-1].is_equal_approx(finish.projected(bullet.p)-Vector2(0,44)),"Head ends exactly at the real latest height and position")
	check(is_zero_approx(float(geometry.widths[0])) and is_zero_approx(float(geometry.widths[-1])),"Both mesh ends taper to zero width")
	var interior_width := 0.0
	for width in geometry.widths: interior_width=maxf(interior_width,width)
	check(interior_width>0 and interior_width<8,"Interior has bounded material-dependent thickness")
	if "--gpu" in OS.get_cmdline_user_args():
		# Optional real-renderer checkpoint compiles and draws the live mesh shader.
		await process_frame; await RenderingServer.frame_post_draw
	for vertex in geometry.vertices: check(vertex.is_finite(),"Projected ribbon vertices are finite")
	for uv in geometry.uv: check(uv.x>=0 and uv.x<=1 and uv.y>=0 and uv.y<=1,"Triangle UVs remain finite and normalized")
	for index in geometry.indices: check(index>=0 and index<geometry.vertices.size(),"Every ribbon triangle references a valid vertex")
	var original_points: Array=trail.points.duplicate(true)
	var snapshot: Dictionary=bullet.duplicate(true)
	finish.advance(.02); finish.observe([snapshot],.02)
	check(finish.trails.size()==1 and finish.trails[7].ribbon==node,"Snapshot replacement retains the stable-ID ribbon instance")
	check(original_points[0].height==20.0 and trail.points[0].height==20.0,"Later projectile heights cannot drag historical wake vertices")
	bullet.p+=Vector2(900,0); finish.observe([bullet],.02)
	check(trail.points.size()==1 and node.geometry.vertices.is_empty(),"Teleport clears the entire ribbon instead of bridging the discontinuity")
	finish.reset()
	var stationary={"fx_id":8,"p":Vector2(50,50),"weapon_index":624}
	for frame in 5: finish.advance(.02); finish.observe([stationary],.02)
	check(finish.trails[8].ribbon.geometry.vertices.is_empty(),"A stationary projectile never creates a fictional ribbon")
	finish.reset()
	for frame in 40:
		bullet.p=Vector2(frame*5,50); bullet.height=0
		finish.advance(.006); finish.observe([bullet],.02)
	check(finish.trails[7].points.size()<=Finish.TRAIL_HISTORY_POINTS and finish.trails[7].ribbon.geometry.centers.size()<=Ribbon.MAX_SAMPLES,"History and resampled mesh budgets are independently bounded")
	finish.advance(.2); finish.observe([],.2)
	check(finish.trails.is_empty() and finish.wakes.get_child_count()==0,"Removed stable ID releases its mesh and shader instance")
	var bullets: Array=[]
	for i in 110: bullets.append({"fx_id":i,"p":Vector2(i,80),"weapon_index":600+i%48})
	var untouched: Array=bullets.duplicate(true)
	finish.observe(bullets,.02)
	check(bullets==untouched,"Ribbon sampling cannot modify authoritative projectile data")
	check(finish.trails.size()==Finish.MAX_TRAILS and finish.wakes.get_child_count()==Finish.MAX_TRAILS,"Existing total trail budget also bounds ribbon nodes")
	finish.reset()
	check(finish.wakes.get_child_count()==0 and finish.trails.is_empty(),"Reset removes all mesh resources from the persistent overlay container")
	finish.queue_free(); await process_frame; await process_frame
	print("PROJECTILE RIBBON ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
