extends "res://scripts/weapon_motion_design.gd"
## Only the two review samples. Geometry is authored here, never cut from concept art.
const SURFACE=preload("res://resources/weapon_sample_surface.gdshader")
var heat: MeshInstance3D
var heat_material: ShaderMaterial

func sample_material(kind: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new(); mat.shader=SURFACE
	mat.set_shader_parameter("surface_kind",kind)
	return mat

func setup(effect: Node3D) -> void:
	super.setup(effect)
	host.body_material=sample_material(0 if index==600 else 4)
	host.ribbon.material_override=host.body_material
	trail_material=sample_material(1); trail.material_override=trail_material
	host.debris.material_override=sample_material(1 if index==600 else 3)
	host.debris.material_override.render_priority=4
	trail_material.render_priority=5
	smoke_material=sample_material(2); host.smoke.material_override=smoke_material
	smoke_material.render_priority=-3
	if index==615:
		heat_material=sample_material(5); heat_material.render_priority=-1
		heat=host.mesh_node(heat_material)
	host.emission_time=.065 if host.action=="normal" else .085 if host.action=="heavy" else .10
	host.tail_time=.075 if host.action=="normal" else .11
	host.life=host.emission_time+host.tail_time+.30
	rebuild()

func sword_point(t: float,lane: int=0) -> Vector3:
	# An orbit about the hand. Even its inner edge follows the same pivot.
	var angle := lerpf(-2.08,1.22,t)
	if host.action=="heavy": angle=lerpf(-1.58,1.18,t)
	if host.action=="art": angle=lerpf(-2.40,1.55,t)+lane*2.30
	if combo_stage%2==1: angle=-angle
	var radius := span*(.66+.22*sin(t*PI))
	return captured+(axis*cos(angle)+across*-sin(angle))*radius

func blood_sheet(body,edge,motes) -> void:
	var lane_count := 2 if host.action=="art" else 1
	for lane in lane_count:
		var age: float=float(host.age)-lane*.075
		var active: float=host.emission_time
		var tail: float=host.tail_time
		var h := 1-pow(1-clampf(age/active,0,1),2.4)
		var s := 1-pow(1-clampf((age-tail)/active,0,1),2.4)
		if h<=s: continue
		var last_outer := Vector3.ZERO; var last_inner := Vector3.ZERO
		var last_a := 0.0
		for i in 65:
			var u := float(i)/64
			var t := lerpf(s,h,u)
			var center := sword_point(t,lane)
			var radial := (center-captured).normalized()
			var shape := pow(sin(u*PI),.55)
			var ragged := .006*sin(t*45)+.003*sin(t*91)
			var thickness := span*(.27 if host.action=="normal" else .38)*shape*(.88+.12*sin(t*13))
			var outer := center+radial*span*ragged*shape
			var inner := outer-radial*thickness*(1+.11*sin(t*41))
			var fade := pow(clampf(1-(age-t*active)/tail,0,1),.70)
			if i>0:
				body.quad(last_inner,last_outer,inner,outer,Color("c70831",fade),float(i-1)/64,u,last_a)
				var width := span*(.006+.010*shape)
				edge.quad(last_outer-radial*width,last_outer,outer-radial*width,outer,Color("ffd0d2",fade*.98),0,1,last_a*.98)
				# Long glints follow the flow inside the blood, not a repeated grid.
				for vein in 3:
					var f := .18+vein*.22+.025*sin(t*17+vein*2.0)
					var a := last_inner.lerp(last_outer,f)
					var b := inner.lerp(outer,f)
					var w := radial*span*.0022*shape
					var glint := pow(maxf(0,sin(t*13+vein*2.1)),3)
					edge.quad(a-w,a+w,b-w,b+w,Color("ff486a",fade*.62*glint),0,1,last_a*.62*glint)
			last_inner=inner; last_outer=outer; last_a=fade
		for tongue in 6:
			var t := .15+tongue*.125
			if t<s or t>h: continue
			var center := sword_point(t,lane)
			var radial := (center-captured).normalized()
			var tangent := (sword_point(minf(1,t+.01),lane)-center).normalized()
			var width := span*(.27 if host.action=="normal" else .38)
			var at := center-radial*width*.70
			var fade := clampf(1-(age-t*active)/tail,0,1)*sin((t-s)/maxf(.001,h-s)*PI)
			for j in 8:
				var u := float(j)/8; var v := float(j+1)/8
				var a := at-radial*span*.16*u+tangent*span*.10*u*u
				var b := at-radial*span*.16*v+tangent*span*.10*v*v
				var w := tangent*span*.016*(1-u)
				body.quad(a-w,a+w,b-w*.7,b+w*.7,Color("c70831",fade*.85))
		# Separate curved ligaments and falling beads shed from the trailing blade.
		for i in 9:
			var born := .025+i*.010
			var elapsed := age-born
			if elapsed<=0 or elapsed>.24: continue
			var t := clampf(born/active,0,1)
			var at := sword_point(t,lane)
			var radial := (at-captured).normalized()
			var tangent := (sword_point(minf(t+.01,1),lane)-at).normalized()
			var velocity := radial*span*(.7+.07*(i%3))+tangent*span*.30
			var previous := at
			var fade := pow(1-elapsed/.24,1.5)
			for j in 7:
				var e := elapsed*float(j+1)/7
				var next := at+velocity*e-across*span*e*e*2.1
				var w := across*span*.007*(1-float(j)/7)
				edge.quad(previous-w,previous+w,next-w*.7,next+w*.7,Color("a80a27",fade*.72))
				previous=next
			shard(motes,previous,velocity.normalized(),across,span*.012*fade,Color("dc103e",fade))

func hammer_wake(body,edge) -> void:
	var active: float=host.emission_time
	var age: float=host.age
	if age>active+.10: return
	var h := .72+.28*clampf(age/active,0,1)
	var s := maxf(0,h-.68)
	var previous := Vector3.ZERO
	for i in 33:
		var t := lerpf(s,h,float(i)/32)
		var at := landing+across*span*.95*(1-pow(t,1.7))-axis*span*.24*(1-t)
		var w := axis*span*.11*sin(float(i)/32*PI)
		var fade := (1-smoothstep(active,active+.10,age))*pow(float(i)/32,.7)
		if i>0:
			body.quad(previous-w,previous+w,at-w,at+w,Color("9e381b",fade*.35))
			for seam in 3:
				var offset := axis*span*(seam-1)*.052
				var thin := axis*span*.003
				edge.quad(previous+offset-thin,previous+offset+thin,at+offset-thin,at+offset+thin,Color("ff9138",fade*.65))
		previous=at

func rock(builder,at: Vector3,size: float,seed: int,fade: float) -> void:
	# Irregular six-sided stones with deliberately lit individual facets.
	var top := at+across*size*.08+axis*size*.12
	for j in 6:
		var a := float(j)*TAU/6+.21*seed
		var b := float(j+1)*TAU/6+.21*seed
		var pa := at+(axis*cos(a)*(1.0+.15*(seed%2))+across*sin(a)*.82)*size*(.65+.12*((j+seed)%3))
		var pb := at+(axis*cos(b)*(1.0+.15*(seed%2))+across*sin(b)*.82)*size*(.65+.12*((j+1+seed)%3))
		var pigment := Color("403638").lightened(.055*(j%3))
		builder.quad(top,pa,pb,pb,Color(pigment,fade))
		if j==1:
			var mid := pa.lerp(pb,.40)
			var w := axis*size*.026
			builder.quad(top-w,top+w,mid-w,mid+w,Color("ed6b23",fade*.62))

func furnace(body,edge,motes,dust) -> void:
	var elapsed := float(host.age)
	if elapsed<0 or elapsed>.48: return
	var power := 1.05 if host.action=="normal" else 1.45 if host.action=="heavy" else 1.75
	var growth := 1-exp(-elapsed*95)
	var fade := 1-smoothstep(.075,.34,elapsed)
	# Ground-oriented, broken radial fissures; no floating circle or duplicate head.
	var side: Vector3=host.aim.cross(Vector3.UP).normalized()
	for lane in 9:
		var angle := lane*2.39996
		var dir: Vector3=(host.aim*cos(angle)+side*sin(angle)).normalized()
		var previous := landing
		for j in 5:
			var u := float(j+1)/5
			var next: Vector3=landing+dir*span*.28*power*growth*u+side*sin(j*5.0+lane)*span*.018*u
			var w: Vector3=dir.cross(Vector3.UP)*span*.014*(1-u*.8)*power
			if j!=lane%4:
				var a := previous.lerp(next,.14)
				edge.quad(a-w,a+w,next-w*.6,next+w*.6,Color("ff9a37",fade*(1-u*.6)*.55))
			previous=next
	# Rising, tapering molten sheets frame the dark stones.
	for lane in 7:
		var x := (lane-3)*span*.065*power
		var height := span*float([.21,.44,.64,.47,.75,.37,.25][lane])*power*growth*(1-smoothstep(.04,.25,elapsed))
		var base := landing+axis*x
		var lean := axis*x*.50
		var previous := base
		for j in 12:
			var t := float(j+1)/12
			var at := base+across*height*t+lean*t*t+axis*sin(t*11+lane)*span*.012
			var w := axis*span*.065*power*pow(1-t,.7)
			body.quad(previous-w,previous+w,at-w*.8,at+w*.8,Color("dc501c",fade*.98*(1-t*.30)))
			var thin := w*.065
			edge.quad(previous-thin,previous+thin,at-thin,at+thin,Color("ffb451",fade*(1-t*.65)*.48))
			previous=at
	for i in 8:
		var dir := axis*cos(i*2.39996)
		var e := maxf(0,elapsed-i*.002)
		var origin: Vector3=landing+axis*span*(i%3-1)*.065
		var at: Vector3=origin+dir*span*e*(1.3+.08*(i%4))+across*span*(e*(1.9+.18*(i%4))-e*e*4.7)
		var size := span*(.075+.021*(i%3))*power*(1-elapsed*.45)
		rock(motes,at,size,i,fade)
	# A low, dense bed of torn rock anchors the plume to the floor.
	for i in 5:
		var at: Vector3=landing+axis*span*(i-2)*.09*power+across*span*.018
		rock(motes,at,span*(.085+.012*(i%3))*power,i+17,fade)
	for i in 18:
		var angle := i*2.39996
		var velocity := axis*cos(angle)*span*1.35+across*span*(.8+absf(sin(angle))*1.8)
		var at := landing+velocity*elapsed-across*span*elapsed*elapsed*3
		shard(edge,at,velocity.normalized(),axis,span*.008*(1-elapsed/.48),Color("ffad48",fade))
	for i in 7:
		var delayed := maxf(0,elapsed-.025)
		var at: Vector3=landing+axis*(i-3)*span*(.045+delayed*.19)*power+across*span*delayed*.28
		var x := axis*span*(.10+delayed*.38)*power
		var y := across*span*(.08+delayed*.20)*power
		var tint := Color("665348",fade*.58*smoothstep(0,.04,elapsed))
		dust.quad(at-x-y,at-x+y,at+x-y,at+x+y,tint)

func rebuild() -> void:
	var body=Builder.new(); var edge=Builder.new(); var motes=Builder.new(); var dust=Builder.new()
	if host.kind=="impact":
		particles(motes,true)
		contact(edge)
	elif index==600: blood_sheet(body,edge,motes)
	elif index==615:
		hammer_wake(body,edge); furnace(body,edge,motes,dust)
	if heat:
		var plume=Builder.new()
		var elapsed := float(host.age)
		if host.kind=="release" and elapsed>0 and elapsed<.48:
			var power := 1.05 if host.action=="normal" else 1.45 if host.action=="heavy" else 1.75
			var growth := 1-exp(-elapsed*95)
			var fade := 1-smoothstep(.065,.31,elapsed)
			for i in 5:
				var x := axis*span*(.14+elapsed*.10)*power
				var y := across*span*(.22+.04*(i%3))*power*growth
				var at := landing+axis*span*(i-2)*.09*power+y*.87
				plume.quad(at-x-y,at-x+y,at+x-y,at+x+y,Color(1,1,1,fade*.80))
		plume.commit(heat)
		heat_material.set_shader_parameter("phase",float(host.age))
	body.commit(host.ribbon); edge.commit(trail); motes.commit(host.debris); dust.commit(host.smoke)
	if host.body_material: host.body_material.set_shader_parameter("phase",float(host.age))
	if smoke_material: smoke_material.set_shader_parameter("phase",float(host.age))

func contact(builder) -> void:
	var age: float=host.age
	if age>=.085: return
	var fade := pow(1-age/.085,2)
	var length := .17 if index==600 else .26
	# A compressed, directional cut at the target, followed by ejected fragments.
	for lane in 3:
		var direction := (axis+across*(lane-1)*.55).normalized()
		var normal := (across-axis*(lane-1)*.55).normalized()
		var at := captured-direction*.035
		var w := normal*(.020 if lane==1 else .008)*fade
		var tip := at+direction*length*(1+age*8)
		builder.quad(at-w,at+w,tip,tip,Color("ffe6ce" if index==615 else "ffe0e4",fade))
