extends RefCounted
## Hand-authored trajectories and material construction, independent of concept PNGs.
const Builder=preload("res://scripts/weapon_vfx_mesh_3d.gd")
const SHADER=preload("res://resources/weapon_sculpted_material.gdshader")
const MAP=[624,600,612,636,637,638,639,640,641,642,643,644,601,602,613,614,625,17,18,19,20]
# Forward / cross-stroke coordinates in the captured attack plane. Curves are
# silhouette decisions, not randomly perturbed copies of one universal slash.
const CURVES={
600:[[.12,-.28],[.55,-.45],[.94,-.04],[.65,.39],[.18,.30]],
601:[[.04,.0],[.28,-.018],[.67,-.012],[.96,.0]],
602:[[.08,-.20],[.66,-.46],[.86,.02],[.49,.42],[.13,.18],[.39,-.08]],
603:[[.12,-.35],[.48,-.16],[.87,.10],[.60,.38]],
604:[[.18,-.30],[.72,-.29],[.93,.02],[.58,.31]],
605:[[.10,.18],[.36,.09],[.68,-.13],[.78,-.26]],
606:[[.17,-.34],[.54,-.30],[.88,.02],[.62,.30]],
607:[[.12,-.32],[.46,-.27],[.84,-.03],[.69,.31]],
608:[[.18,-.30],[.48,-.23],[.78,-.02],[.64,.31]],
609:[[.18,-.24],[.56,-.33],[.89,.04],[.56,.36]],
610:[[.17,-.25],[.55,-.30],[.87,.02],[.59,.29]],
611:[[.14,-.34],[.53,-.26],[.89,.10],[.55,.38]],
612:[[.20,-.55],[.62,-.45],[.87,-.08],[.68,.40],[.29,.48]],
613:[[.11,-.40],[.48,-.54],[.91,-.11],[.83,.31],[.34,.48]],
614:[[.12,-.27],[.61,-.41],[.89,.10],[.52,.40]],
615:[[.29,-.65],[.53,-.51],[.68,-.16],[.70,.34]],
616:[[.20,-.49],[.59,-.36],[.91,.04],[.64,.46]],
617:[[.29,-.57],[.61,-.42],[.79,-.03],[.69,.38]],
618:[[.49,-.68],[.58,-.40],[.64,-.03],[.62,.49]],
619:[[.56,-.69],[.62,-.43],[.65,-.03],[.65,.40]],
620:[[.17,-.48],[.52,-.32],[.86,.12],[.59,.44]],
621:[[.03,.12],[.33,.04],[.69,-.03],[.97,-.04]],
622:[[.13,-.40],[.66,-.49],[.89,-.02],[.53,.46],[.16,.25]],
623:[[.20,-.51],[.57,-.37],[.87,.06],[.55,.44]],
624:[[.0,.0],[.14,.0],[.28,.01]],625:[[.0,.0],[.18,-.02],[.34,.01]],
626:[[.0,.0],[.21,.01],[.32,.0]],627:[[.0,.0],[.18,-.04],[.30,.03]],
628:[[.0,.0],[.19,-.02],[.32,.0]],629:[[.0,.0],[.17,.025],[.29,-.01]],
630:[[.0,.0],[.20,.0],[.36,.0]],631:[[.0,-.025],[.16,-.025],[.30,.02]],
632:[[.0,.0],[.17,-.03],[.31,-.01]],633:[[.0,.0],[.21,.0],[.39,.0]],
634:[[.0,.0],[.18,.02],[.30,.0]],635:[[.0,.0],[.14,-.05],[.26,-.12]],
636:[[.0,.0],[.15,-.07],[.31,-.02]],637:[[.0,.0],[.15,-.08],[.30,.02]],
638:[[.0,.0],[.20,.0],[.37,.0]],639:[[.0,.0],[.15,-.025],[.31,.015]],
640:[[.0,.08],[.18,-.08],[.33,-.02]],641:[[.0,.03],[.17,.015],[.36,.0]],
642:[[.0,.04],[.15,-.10],[.31,-.03]],643:[[.25,-.13],[.05,-.10],[.02,.08],[.18,.12]],
644:[[.0,.0],[.19,-.015],[.37,.0]],645:[[.0,-.08],[.14,.03],[.30,-.04]],
646:[[.0,.10],[.12,-.08],[.29,-.01]],647:[[.0,.06],[.13,-.09],[.29,-.02]],
17:[[.10,-.21],[.46,-.23],[.72,.02],[.43,.25]],
18:[[.0,.0],[.12,-.06],[.26,.02]],
19:[[.19,-.45],[.47,-.31],[.77,.07],[.51,.38]],
20:[[.13,-.33],[.55,-.43],[.80,.0],[.45,.37],[.18,.21]]}
# material width, coherent tail in seconds, shedding count, flow character
const MAT={"metal":[.075,.095,2,0],"blood":[.19,.16,4,1],"tide":[.26,.18,5,2],
"frost":[.16,.12,4,3],"storm":[.045,.07,2,4],"stone":[.24,.12,5,5],
"cloth":[.14,.13,3,10],"soul":[.17,.22,3,7],"void":[.17,.18,3,8],
"mirror":[.11,.11,3,9],"feather":[.10,.12,3,10],"star":[.10,.12,3,11],
"sun":[.13,.12,3,12],"bell":[.085,.16,2,13]}
var host: Node3D
var index := 600
var spec: Array=[]
var axis := Vector3.RIGHT
var across := Vector3.UP
var captured := Vector3.ZERO
var landing := Vector3.ZERO
var span := 1.0
var slam := false
var centered := false
var trail: MeshInstance3D
var trail_material: ShaderMaterial
var smoke_material: ShaderMaterial
var cached_paths: Array=[]
var combo_stage := 0

static func identity(weapon: int) -> int: return MAP[weapon] if weapon>=0 and weapon<21 else weapon
static func material(profile: Dictionary,ribbon: bool=true) -> ShaderMaterial:
	var item: Array=MAT.get(str(profile.material),MAT.metal)
	var weapon := int(profile.get("canonical",-1))
	var mat := ShaderMaterial.new(); mat.shader=SHADER
	var substance := int(item[3])
	if weapon in [605,627,642]: substance=6
	if weapon in [611,630,644]: substance=9
	mat.set_shader_parameter("substance",substance)
	mat.set_shader_parameter("ribbon_mode",ribbon)
	mat.set_shader_parameter("softness",.05 if int(item[3]) in [0,3,9] else .18)
	return mat

func setup(effect: Node3D) -> void:
	host=effect; index=identity(int(host.data.weapon_index))
	combo_stage=clampi(int(host.data.get("combo",0)),0,2)
	spec=MAT.get(str(host.profile.material),MAT.metal)
	captured=host.origin; span=host.reach
	centered=preload("res://scripts/weapon_mechanics.gd").body_centered(str(host.profile.role))
	slam=str(host.profile.role)=="motion_quake" or index in [615,619]
	landing=host.ground+Vector3.UP*.025
	if not centered: landing+=host.aim*span*.67
	elif slam: landing+=host.aim*span*.32
	var camera: Camera3D=host.camera
	if camera:
		var inverse: Basis=host.global_transform.basis.inverse()
		var global_start: Vector3=host.to_global(captured)
		var direction: Vector2=(camera.unproject_position(host.to_global(captured+host.aim))-camera.unproject_position(global_start)).normalized()
		if direction.length_squared()<.01: direction=Vector2.RIGHT
		axis=inverse*(camera.global_basis.x*direction.x-camera.global_basis.y*direction.y)
		across=inverse*(camera.global_basis.x*direction.y+camera.global_basis.y*direction.x)
	else: axis=host.aim; across=Vector3.UP
	var peak: float=host.profile.attack.peak
	host.emission_time=clampf(peak,.085,.17) if host.action=="normal" else clampf(peak,.14,.26) if host.action=="heavy" else clampf(peak,.16,.30)
	if host.action=="normal" and combo_stage==2: host.emission_time+=.018
	host.tail_time=float(spec[1])*(1.25 if host.action!="normal" else 1.0)
	if host.kind=="impact": host.emission_time=.025; host.tail_time=.23
	if host.kind=="beam": host.emission_time=.025; host.tail_time=.15
	host.life=host.emission_time+host.tail_time+.24
	# The emission footprint is immutable. Sample its choreography once instead
	# of evaluating spline landmarks and trigonometry for every vertex/frame.
	for lane in 3:
		var samples := PackedVector3Array()
		for i in 65: samples.append(curve_point(float(i)/64,lane))
		cached_paths.append(samples)
	host.body_material=material(host.profile,true); host.ribbon.material_override=host.body_material
	host.debris.material_override=material(host.profile,false)
	trail_material=material(host.profile,true); trail=host.mesh_node(trail_material)
	smoke_material=material({"material":"soul"},true); host.smoke.material_override=smoke_material
	rebuild()

func local_point(t: float,lane: int=0) -> Vector2:
	if centered and not slam:
		# Three successive cuts cover the action without drawing a closed border.
		var heavy: bool=host.action=="heavy"
		var angle := -.95+lane*TAU/(2.0 if heavy else 3.0)+t*(1.35 if heavy else 1.60)
		if host.action=="normal" and combo_stage==2: angle+=t*.20
		return Vector2(cos(angle),sin(angle))*((.48+t*.32) if heavy else (.74+lane*.035))
	if host.motion=="thrust" and host.profile.family in ["blade","great"]:
		var lateral := sin(t*PI)*(.018 if index!=603 else .045)*(1.0 if lane%2==0 else -1.0)
		return Vector2(.05+(pow(t,.72) if host.action=="normal" and combo_stage==2 else t)*.90,lateral)
	var points: Array=CURVES.get(index,CURVES[600])
	var u := clampf(t,0,1)*(points.size()-1)
	var at := mini(int(u),points.size()-2)
	var a := Vector2(points[at][0],points[at][1])
	var b := Vector2(points[at+1][0],points[at+1][1])
	# Hermite interpolation keeps the blade tangent continuous through landmarks.
	var before: Array=points[maxi(0,at-1)]; var after: Array=points[mini(points.size()-1,at+2)]
	var m0 := (b-Vector2(before[0],before[1]))*.5
	var m1 := (Vector2(after[0],after[1])-a)*.5
	var f := u-at
	var p := a*(2*f*f*f-3*f*f+1)+m0*(f*f*f-2*f*f+f)+b*(-2*f*f*f+3*f*f)+m1*(f*f*f-f*f)
	if host.action=="heavy" and host.profile.family in ["blade","great"]:
		if host.motion=="thrust": p=Vector2(.06+.88*t,.035*sin(t*PI))
		else: p=Vector2(.25+sin(t*PI*.75)*.56,lerpf(-.60,.44,t))
	elif host.action=="art" and lane>0:
		p.y=-p.y if lane%2 else p.y
		p.x+=.035*lane; p.y+=.035*lane
	if index==603: p.y*=1.0 if lane%2==0 else -1.0
	if index==609: p+=Vector2(-.04*lane,.09*lane)
	if host.action=="normal":
		if combo_stage==2:
			p.x+=.055*sin(t*PI)
			p.y=lerpf(-.42,.40,t)+sin(t*PI)*.09
		p.y*=float(host.reverse)
	return p

func point(t: float,lane: int=0) -> Vector3:
	if not cached_paths.is_empty():
		var samples: PackedVector3Array=cached_paths[clampi(lane,0,2)]
		var u := clampf(t,0,1)*64
		var i := mini(int(u),63)
		return samples[i].lerp(samples[i+1],u-i)
	return curve_point(t,lane)

func curve_point(t: float,lane: int=0) -> Vector3:
	if slam:
		var start: Vector3=landing+across*minf(1.0,span*.82)-axis*span*.16
		return start.lerp(landing,pow(clampf(t,0,1),2.1 if combo_stage==2 and host.action=="normal" else 1.7))
	var p := local_point(t,lane)
	return captured+axis*p.x*span-across*p.y*span

func strip(builder,a: Vector3,b: Vector3,wa: Vector3,wb: Vector3,alpha_a: float,alpha_b: float,u: float,v: float,tint: Color) -> void:
	builder.quad(a-wa,a+wa,b-wb,b+wb,Color(tint,alpha_b),u,v,alpha_a)

func ribbon(builder,soft_builder) -> void:
	var active: float=host.emission_time
	var tail: float=host.tail_time
	var head := clampf(host.age/active,0,1)
	var start := maxf(0,(host.age-tail)/active)
	if head<=start or host.age<=0: return
	var count := (2 if host.action=="heavy" else 3) if centered and not slam else 2 if index in [603,609] else 1
	if host.action=="art" and not slam: count=maxi(2,count)
	var segments: int=[26,18,12][host.detail]
	for lane in count:
		var delay := lane*(.07 if host.action=="art" else .025)
		var h := clampf(head-delay,0,1)
		var s := clampf(start-delay,0,1)
		if h<=s: continue
		var old := Vector3.ZERO; var old_width := Vector3.ZERO; var old_alpha := 0.0
		for step in segments+1:
			var t := lerpf(s,h,float(step)/segments)
			var at := point(t,lane)
			var tangent := (point(minf(1,t+.003),lane)-point(maxf(0,t-.003),lane)).normalized()
			var basis: Basis=host.global_transform.basis
			var normal := basis.inverse()*((basis*tangent).cross(host.camera.global_basis.z if host.camera else Vector3.FORWARD).normalized())
			if normal.length_squared()<.01: normal=across.normalized()
			var thick := span*float(spec[0])*(.70 if host.action=="normal" else 1.05 if host.action=="heavy" else .88)
			if host.profile.family in ["ranged","magic"]: thick*=.60
			var taper := pow(maxf(0,sin(PI*(t-s)/maxf(.01,h-s))),.65)
			var width := normal*thick*(.06+taper*.94)*.5
			var blade_plane: bool=not slam and host.profile.family in ["blade","great"] and host.motion!="thrust" and int(spec[3])!=4
			if blade_plane:
				var fill := .48 if int(spec[3]) in [1,2,7,8,10] else .29
				width=(at-captured)*fill*(.04+taper*.96)*.5
				at-=width
			if index==613: width*=1.0+.14*sin(t*PI*3-host.age*5)
			var elapsed := maxf(0,float(host.age)-(t+delay)*active)
			var fade := pow(maxf(0,1-elapsed/tail),1.35)*smoothstep(0,.014,float(host.age))
			if host.profile.material in ["storm","mirror"]: fade*=.75+.25*sin(t*34+lane)
			if step>0:
				strip(builder,old,at,old_width,width,old_alpha,fade,float(step-1)/segments,float(step)/segments,host.color)
				if host.profile.material in ["blood","tide","soul","cloth"]:
					strip(soft_builder,old-across*thick*.10,at-across*thick*.10,old_width*.54,width*.54,old_alpha*.19,fade*.19,float(step-1)/segments,float(step)/segments,host.color.darkened(.20))
			old=at; old_width=width; old_alpha=fade
	if slam: hammer_head(builder,head)

func hammer_head(builder,t: float) -> void:
	if host.age>host.emission_time+.055: return
	var at := point(t)
	var x := axis*span*.11; var y := across*span*.09
	var offset := (axis+across)*span*.035
	var fade := 1.0-smoothstep(host.emission_time,host.emission_time+.055,float(host.age))
	var dark := Color(Color("29252b") if index==615 else host.color.darkened(.72),fade)
	var face := Color(Color("50464d") if index==615 else host.color.darkened(.42),fade)
	builder.quad(at-x-y,at-x+y,at+x-y,at+x+y,dark)
	builder.quad(at-x+y,at-x+y+offset,at+x+y,at+x+y+offset,face)
	builder.quad(at+x-y,at+x+y,at+x-y+offset,at+x+y+offset,face.darkened(.20))
	var seam := x*.055
	builder.quad(at-y*.70-seam,at-y*.70+seam,at+y*.65-seam,at+y*.65+seam,Color(host.color,fade*.82))

func shard(builder,at: Vector3,along: Vector3,side: Vector3,size: float,tint: Color) -> void:
	var a := along*size; var b := side*size*.42
	builder.quad(at-a,at-b,at+b,at+a,tint)

func slab(builder,at: Vector3,direction: Vector3,size: float,fade: float,seed: int) -> void:
	var side := direction.cross(Vector3.UP).normalized()*size*(.75+.12*(seed%3))
	var length := direction*size*.65
	var height := Vector3.UP*size*(.35+.08*(seed%2))
	var lean := direction*size*.14
	var a := at-side-length; var b := at+side-length
	var c := at-side+length; var d := at+side+length
	var rock := Color("4d4944").lerp(host.color,.12)
	if index==619: rock=Color("454a5e")
	builder.quad(a,a+height+lean,b,b+height+lean,Color(rock.darkened(.25),fade))
	builder.quad(b,b+height+lean,d,d+height+lean,Color(rock.darkened(.10),fade))
	builder.quad(a+height+lean,c+height*.85+lean,b+height+lean,d+height*.85+lean,Color(rock.lightened(.12),fade))
	if index in [615,620]:
		var start := a+height+lean; var end := d+height*.85+lean
		var seam := side*.055
		strip(builder,start,end,seam,seam*.5,fade*.80,fade*.60,0,1,host.color)

func particles(builder,impact: bool=false) -> void:
	var count := int(spec[2])+(3 if impact else 0)
	count=mini(count,3 if host.detail==2 else 7)
	for i in count:
		var born: float=.006+i*.006 if impact else float(host.emission_time)*(.48+i*.08)
		var elapsed: float=float(host.age)-born
		var duration := .14+float(i%3)*.045
		if elapsed<=0 or elapsed>=duration: continue
		var u := .43+float(i)*.10
		var at := captured if impact else point(minf(u,.94),i%2 if index in [603,609] else 0)
		var angle := i*2.39996+float(index%7)*.2
		var velocity := (axis*cos(angle)+across*sin(angle))*(.30 if impact else .18)
		if int(spec[3]) in [1,2,5]: velocity-=Vector3.UP*elapsed*1.8
		at+=velocity*elapsed
		var fade := pow(1-elapsed/duration,1.4)
		var tint: Color=host.color.darkened(.48) if int(spec[3])==5 else host.color
		shard(builder,at,velocity.normalized(),across.normalized(),(.018 if not impact else .033)*(1-elapsed/duration*.45),Color(tint,fade*.75))

func ground_impact(builder,mist) -> void:
	var elapsed := float(host.age)-float(host.emission_time)*.90
	if elapsed<0 or elapsed>.30: return
	var power := .45 if host.action=="normal" else 1.0
	var fade := pow(1-elapsed/.30,1.4)
	var count := 4 if host.action=="normal" else 6
	for i in count:
		var angle := i*2.39996+float(index%5)*.31
		var direction: Vector3=host.aim.rotated(Vector3.UP,angle)
		var distance := span*(.055+elapsed*.85)*(.7+float(i%3)*.12)*power
		var at: Vector3=landing+direction*distance
		var lift := maxf(0,elapsed*(.8+float(i%3)*.15)-elapsed*elapsed*3.1)*power
		var size := minf(.13,span*.07)*power*(.8+float(i%3)*.20)
		slab(builder,at+Vector3.UP*lift,direction,size,fade,i)
		var front: Vector3=at+direction*elapsed*.25
		var spread := axis*size*(1+elapsed*4)
		strip(mist,front,front+across*.035,spread,spread*.7,fade*.10,fade*.08,0,1,Color("777168"))

func burst(builder) -> void:
	var fade := pow(maxf(0,1-float(host.age)/.25),1.4)
	var spread: float=float(host.reach)*clampf(float(host.age)/.15,.04,.86)
	if index==643:
		# Displaced space closes inward. An outward blast would reverse its meaning.
		for lane in 3:
			var angle := lane*2.1+.32
			var collapse := clampf(float(host.age)/.25,0,1)
			var previous := captured
			var old_width := Vector3.ZERO
			for step in 15:
				var t := float(step)/14
				var theta := angle-t*1.35
				var direction := axis*cos(theta)+across*sin(theta)
				var radial: float=host.reach*(1-t)*(.82-collapse*.60)
				var at := captured+direction*radial
				var normal := axis*-sin(theta)+across*cos(theta)
				var width: Vector3=normal*host.reach*sin(t*PI)*.14*(1-collapse*.55)
				if step>0: strip(builder,previous,at,old_width,width,fade*.85,fade*.85,float(step-1)/14,t,host.color.darkened(.36))
				previous=at; old_width=width
		return
	if index in [645,646,647]:
		for lane in 3:
			var progress := clampf(float(host.age)/.25,0,1)
			var opening := (1-progress*.75) if index==646 else sin(progress*PI)
			var spread_x := .15 if index==646 else .26 if index==645 else .31
			var at: Vector3=captured+axis*host.reach*(lane-1)*spread_x*opening
			if index==646: at+=across*host.reach*progress*.24
			var height: Vector3=across*host.reach*((.30+.07*lane) if index==646 else (.13+.03*lane) if index==647 else (.17+.06*lane))*opening
			var edge: Vector3=axis*host.reach*(.055 if index==646 else .16 if index==647 else .11)*opening
			var fold: Vector3=axis*host.reach*.04*sin(float(host.age)*12+lane)
			builder.quad(at-height-edge,at+height-edge,at-height*.7+edge+fold,at+height*.9+edge,Color(host.color,fade*.7))
		return
	if index==639:
		for lane in 5:
			var angle := lane*2.39996
			var direction := axis*cos(angle)+across*sin(angle)
			var previous := captured
			for step in 4:
				var at: Vector3=captured+direction*spread*float(step+1)/4+across*host.reach*sin(step*4+lane)*.065
				var n: Vector3=axis*host.reach*.007
				strip(builder,previous,at,n,n,fade,fade*.7,0,1,host.color)
				previous=at
		return
	var count := 5 if host.action=="normal" else 7
	for i in count:
		var angle := i*2.39996+index*.13
		var direction := axis*cos(angle)+across*sin(angle)
		var at: Vector3=captured+direction*spread*(.7+.1*(i%3))
		var tint: Color=host.color.darkened(.55) if index==637 else host.color
		shard(builder,at,direction.normalized(),across.normalized(),minf(.25 if index==637 else .15,spread*(.24 if index==637 else .12)),Color(tint,fade*.85))
		if index==637: shard(builder,at,direction.normalized(),across.normalized(),minf(.06,spread*.06),Color(host.color,fade*.9))

func beam(builder) -> void:
	var fade := 1.0-smoothstep(.025,.17,float(host.age))
	var vector: Vector3=host.beam_end-captured
	var n: Vector3=vector.cross(host.camera.global_basis.z if host.camera else Vector3.FORWARD).normalized()*float(host.width)*.14
	var previous := captured
	for i in 9:
		var u := float(i+1)/9
		var at := captured+vector*u
		if index==639: at+=across*host.width*sin(i*2.7+index)*.65
		var size := .50+.40*sin(i*2.4+index*.13)
		strip(builder,previous,at,n*size,n*(.3+size*.45),fade*.75,fade*.85,float(i)/9,u,host.color)
		previous=at
		if i in [1,4,7]:
			if index==641:
				var x: Vector3=vector.normalized()*host.width*.38
				var y: Vector3=across*host.width*.60
				builder.quad(at-x-y,at-x+y,at+x-y*.35,at+x+y*.65,Color(host.color,fade*.38))
			elif index==636:
				shard(builder,at+across*host.width*sin(i)*.34,axis.normalized(),across.normalized(),host.width*.13,Color(host.color,fade))
			elif index==640:
				var last: Vector3=at-across*host.width*.38
				for step in 8:
					var t := float(step+1)/8
					var next: Vector3=at+axis*host.width*sin(t*PI)*.42+across*host.width*(t-.5)*.76
					strip(builder,last,next,n*.35,n*.35,fade*.65,fade*.65,0,1,host.color)
					last=next

func electricity(builder) -> void:
	if index not in [607,617]: return
	var start: float=.035 if index==607 else float(host.emission_time)*.75
	var elapsed: float=float(host.age)-start
	if elapsed<0 or elapsed>.075: return
	var fade := pow(1-elapsed/.075,1.3)
	var center := point(.72)
	for lane in 3:
		var direction := axis*cos(lane*2.3)+across*sin(lane*2.3)
		var previous := center
		for step in 3:
			var at := center+direction*span*(step+1)*.065+across*span*sin(step*3.2+lane)*.025
			var n := across*span*.0035
			strip(builder,previous,at,n,n*.6,fade*.85,fade*.65,0,1,host.color)
			previous=at

func facets(builder) -> void:
	if int(spec[3]) not in [3,9] and index not in [611,630]: return
	for i in (3 if host.detail<2 else 2):
		var u := .40+i*.17
		var elapsed: float=float(host.age)-u*float(host.emission_time)
		if elapsed<0 or elapsed>.11: continue
		var at := point(u)
		var tangent := (point(minf(1,u+.015))-point(maxf(0,u-.015))).normalized()
		var side := tangent.cross(host.camera.global_basis.z if host.camera else Vector3.FORWARD).normalized()
		var size := span*(.055 if host.action=="normal" else .085)
		if host.motion=="thrust": size=minf(size,float(host.width)*.40)
		var fade := (1-elapsed/.11)*.65
		shard(builder,at,tangent,side,size,Color(host.color.darkened(.30),fade))
		shard(builder,at+side*size*.10,tangent,side,size*.52,Color(host.color.lightened(.25),fade*.55))

func launch(builder,mist) -> void:
	var duration := .10 if host.action=="normal" else .14 if host.action=="heavy" else .12
	var fade := pow(maxf(0,1-float(host.age)/duration),.75)
	if host.profile.family=="ranged":
		if str(host.profile.role)=="release_bow":
			var opening := .045 if host.action=="normal" else .022 if host.action=="heavy" else .075
			var pullback := .055 if host.action=="normal" else .12 if host.action=="heavy" else .035
			var forward := .08 if host.action=="normal" else .06 if host.action=="heavy" else .13
			for lane in 2:
				var at := captured+across*(lane*2-1)*opening
				strip(builder,at-axis*pullback,at+axis*forward,across*.012,across*.006,fade*.50,fade*.35,0,1,host.color)
		else:
			var length := .16 if host.action=="normal" else .24 if host.action=="heavy" else .20
			strip(builder,captured,captured+axis*length,across*.045,across*.002,fade*.95,fade*.65,0,1,host.color.lightened(.18))
			var smoke_age := maxf(0,float(host.age)-.025)
			var smoke_fade := pow(maxf(0,1-smoke_age/.20),1.4)
			var at := captured+across*smoke_age*.20
			strip(mist,at,at-axis*(.08+smoke_age*.15)+across*.025,across*.025,across*.016,smoke_fade*.12,smoke_fade*.06,0,1,Color("aaa6a0"))
	else:
		var count := 3 if host.action=="normal" else 5 if host.action=="heavy" else 4
		for lane in count:
			var angle := lane*2.39996+index*.13
			var at := captured+(axis*cos(angle)+across*sin(angle))*.055
			shard(builder,at,axis.normalized(),across.normalized(),.035 if lane else .055,Color(host.color,fade*.85))

func rebuild() -> void:
	var main=Builder.new(); var secondary=Builder.new(); var motes=Builder.new(); var mist=Builder.new()
	if host.kind=="impact": particles(motes,true)
	elif host.kind=="beam": beam(main)
	elif host.kind=="burst": burst(main); particles(motes,true)
	else:
		if host.profile.family in ["ranged","magic"]: launch(main,mist)
		else: ribbon(main,secondary)
		particles(motes)
		electricity(secondary)
		facets(motes)
		if slam or bool(host.profile.get("ground_break",false)): ground_impact(motes,mist)
	main.commit(host.ribbon); secondary.commit(trail); motes.commit(host.debris); mist.commit(host.smoke)
	host.body_material.set_shader_parameter("phase",float(host.age)*2.0)
	trail_material.set_shader_parameter("phase",float(host.age)*1.4)
	smoke_material.set_shader_parameter("phase",float(host.age))
