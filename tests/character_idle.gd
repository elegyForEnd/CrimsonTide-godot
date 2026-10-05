extends SceneTree
const Idle = preload("res://scripts/character_idle.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var frames := CharacterFrames.new()
	var animator := Idle.new()
	var signatures: Dictionary={}
	var weapons: Array=[]
	for w in 21: weapons.append(w)
	for w in 48: weapons.append(600+w)
	for weapon: int in weapons:
		var spec := Idle.profile(weapon)
		check(not signatures.has(str(spec)),"Weapon idle handling is distinct: "+str(weapon))
		signatures[str(spec)]=true
		for hero in 4:
			var pose := frames.held_idle_frame(hero,weapon)
			check(pose.get("idle_generated",false),"Uses new ImageGen idle art")
			var regions: Dictionary={}
			for index in 6:
				var other := frames.held_idle_frame(hero,weapon,float(spec[0])*index/6.0+.001)
				regions[str(other.texture.region)]=true
				check(is_equal_approx(other.rect.size.x/other.texture.region.size.x,other.rect.size.y/other.texture.region.size.y),"Idle art uses uniform scale")
			check(regions.size()==4,"Four generated poses play in a loop")
			if weapon>=600: check(pose.has("grip") and str(pose.texture.atlas.resource_path).contains("unarmed"),"Run weapon attaches to empty-hand sprite")
			if weapon==0: check(str(pose.texture.atlas.resource_path).contains("rifle"),"Rifle uses its own held art")
			if weapon==20 and hero==3: check(str(pose.texture.atlas.resource_path).contains("scythe"),"Soul scythe uses scythe art")
			var data := Idle.geometry(pose,weapon,.8,1.0)
			check(data.points.size()==(Idle.COLS+1)*(Idle.ROWS+1),"Complete continuous mesh")
			check(data.indices.size()<=Idle.COLS*Idle.ROWS*6 and data.indices.size()>Idle.COLS*Idle.ROWS*5,"Every joint cell draws")
			var max_motion := 0.0
			for time in [.0,.5,1.7,3.2,8.1]:
				check(Idle.displacement(CharacterMetrics.FOOT_OFFSET,CharacterMetrics.FOOT_OFFSET,weapon,time,1.0).is_zero_approx(),"Ground pivot stays planted")
				check(Idle.displacement(CharacterMetrics.FOOT_OFFSET+Vector2(8,-5),CharacterMetrics.FOOT_OFFSET,weapon,time,1.0).is_zero_approx(),"Boots do not slide")
				var motion := Idle.displacement(Vector2(25,-45),CharacterMetrics.FOOT_OFFSET,weapon,time,1.0)
				max_motion=maxf(max_motion,motion.length())
				check(motion.length()<6,"Idle stays restrained")
			check(max_motion>.1,"Upper body actually animates")
			for uv: Vector2 in data.uvs: check(uv.x>=0 and uv.y>=0 and uv.x<=1 and uv.y<=1,"UV stays inside source")
			var mirror: PackedVector3Array= Idle.mesh(data,true,.6,-1).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var upright: PackedVector3Array= Idle.mesh(data,true,.6,1).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			check(is_equal_approx(mirror[55].x,-upright[55].x) and is_equal_approx(mirror[55].y,upright[55].y),"Left/right mirror keeps ground height")
	var p := {"id":1,"hero":0,"weapon":1,"motion":"idle","status":"active"}
	animator.tick(p,.1)
	check(animator.sample(p).blend>0 and animator.sample(p).blend<1,"Smooth idle entry")
	animator.tick(p,.3)
	check(is_equal_approx(animator.sample(p).blend,1),"Settles into idle")
	for state in [{"motion":"run"},{"motion":"walk"},{"motion":"dodge"},{"swing_time":.2},{"cast_time":.4},{"height":40},{"build_landing_time":.1},{"status":"down"}]:
		var actor := p.duplicate(); actor.merge(state,true)
		check(not Idle.active(actor),"Active action overrides idle: "+str(state))
		animator.tick(actor,.1)
		check(is_zero_approx(animator.sample(actor).blend),"No idle deformation during action")
	animator.tick(p,.4); p.weapon=2; animator.tick(p,.1)
	check(is_zero_approx(animator.sample(p).blend),"Switch weapon starts its new stance gently")
	print("CHARACTER IDLE ",checks," checks / ",failures," failures / 69 weapon profiles, 4 heroes")
	quit(1 if failures else 0)
