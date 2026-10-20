extends "res://scripts/weapon_motion_design.gd"
## Unique per-weapon UV artwork + painted material + real attack choreography.
const Paint=preload("res://scripts/weapon_hybrid_material.gd")
var terrain_paint: MeshInstance3D
var heat: MeshInstance3D
var contact_paint: MeshInstance3D
var contact_smoke: MeshInstance3D
var contact_aspect := 1.3
var energy_core := false

func setup(effect: Node3D) -> void:
	super.setup(effect)
	host.body_material=Paint.material(host.profile,true); host.ribbon.material_override=host.body_material
	trail_material=Paint.material(host.profile,true); trail.material_override=trail_material
	host.debris.material_override=Paint.material(host.profile,false,true)
	smoke_material=Paint.smoke(host.profile); host.smoke.material_override=smoke_material
	if slam or bool(host.profile.get("ground_break",false)):
		var impact_material := Paint.impact(host.profile)
		terrain_paint=host.mesh_node(impact_material if impact_material!=null else Paint.material(host.profile,true))
		if index==615: heat=terrain_paint
	if host.kind in ["impact","burst"]:
		var impact_material := Paint.impact(host.profile)
		if impact_material==null and host.kind=="burst":
			var art=preload("res://scripts/weapon_image_art.gd")
			var role := preload("res://scripts/weapon_mechanics.gd").projectile_role(index,str(Catalog.weapon(index).get("spell","star")))
			var source := art.payload_source(index,"projectile",role)
			impact_material=Paint.payload(source)
			var rect: Rect2=art.mechanic_ink(source)
			contact_aspect=rect.size.x/maxf(1,rect.size.y)
			energy_core=true
		if impact_material!=null and not bool(host.data.get("contact_art_covered",false)):
			contact_paint=host.mesh_node(impact_material)
			var key := Paint.impact_key(host.profile)
			if Paint.manifest.has(key):
				var dimensions: Array=Paint.manifest[key].size
				var uv: Array=Paint.manifest[key].uv
				contact_aspect=(float(dimensions[0])*float(uv[2]))/(float(dimensions[1])*float(uv[3]))
		contact_smoke=host.mesh_node(Paint.smoke(host.profile))
	if host.kind=="release":
		var heavy: bool=host.profile.family=="great"
		host.emission_time=.085 if heavy else .065
		if host.action=="heavy": host.emission_time=.13 if heavy else .095
		elif host.action=="art": host.emission_time=.16 if heavy else .12
		host.tail_time=float(spec[1])*(.72 if host.action=="normal" else .94)
		host.life=host.emission_time+host.tail_time+.26
	rebuild()

func hammer_head(_builder,_t: float) -> void:
	# The equipped weapon already animates its head; do not draw a second box.
	pass

func ribbon(builder,soft_builder) -> void:
	var active: float=host.emission_time
	var tail: float=host.tail_time
	var head := 1-pow(1-clampf(float(host.age)/active,0,1),2.2)
	var start := 1-pow(1-clampf((float(host.age)-tail)/active,0,1),2.2)
	var count := (2 if host.action=="heavy" else 3) if centered and not slam else 2 if index in [603,609] else 1
	if host.action=="art" and not slam: count=maxi(2,count)
	for lane in count:
		var delay := lane*(.11 if host.action=="art" else .035)
		var h := clampf(head-delay,0,1); var s := clampf(start-delay,0,1)
		if h<=s or host.age<=0: continue
		var old := Vector3.ZERO; var old_width := Vector3.ZERO; var old_alpha := 0.0
		var segments := 32 if host.detail==0 else 20
		for step in segments+1:
			var u := float(step)/segments
			var t := lerpf(s,h,u)
			var at := point(t,lane)
			var tangent := (point(minf(1,t+.005),lane)-point(maxf(0,t-.005),lane)).normalized()
			var normal := (axis*-tangent.dot(across)+across*tangent.dot(axis)).normalized()
			var taper := pow(maxf(0,sin(u*PI)),.55)
			var thick := span*(.15 if host.action=="normal" else .23 if host.action=="heavy" else .29)
			if host.motion=="thrust": thick*=.38
			if host.profile.material=="storm": thick*=.52
			var width := normal*thick*taper
			if not slam and host.motion!="thrust" and host.profile.material!="storm":
				width=(at-captured)*(.34 if host.action=="normal" else .46)*taper
				at-=width*.65
			var fade := pow(maxf(0,1-maxf(0,float(host.age)-t*active)/tail),.65)
			if step>0:
				strip(builder,old,at,old_width,width,old_alpha,fade,float(step-1)/segments,u,Color.WHITE)
				strip(soft_builder,old,at,old_width*.25,width*.25,old_alpha*.45,fade*.45,float(step-1)/segments,u,host.color.lightened(.30))
			old=at; old_width=width; old_alpha=fade
	if host.profile.material=="storm": return
	# Blade-edge filaments detach; they don't form an additional closed skill ring.
	var age: float=host.age
	if age<=.012 or age>host.emission_time+host.tail_time: return
	for i in (3 if host.action=="normal" else 5):
		var born := float(host.emission_time)*(.30+i*.105)
		var elapsed := age-born
		if elapsed<=0 or elapsed>.17: continue
		var at := point(clampf(born/float(host.emission_time),0,1))
		var velocity := (at-captured).normalized()*span*(.7+i*.07)
		var tip := at+velocity*elapsed-across*span*elapsed*elapsed*.7
		var w := across*span*.003
		var fade := pow(1-elapsed/.17,1.6)
		soft_builder.quad(at-w,at+w,tip-w*.15,tip+w*.15,Color(host.color,fade*.60))

func particles(builder,impact: bool=false) -> void:
	if not impact: super.particles(builder,false); return
	var duration := .20 if host.profile.material in ["metal","storm"] else .31
	var elapsed: float=host.age
	if elapsed<=0 or elapsed>=duration: return
	var fade := pow(1-elapsed/duration,1.2)
	var count := 5 if host.action=="normal" else 8
	for i in count:
		var angle := i*2.39996+index*.13
		var direction := (axis*cos(angle)+across*sin(angle)).normalized()
		var speed := .50+float(i%3)*.19
		var at := captured+direction*(.025+elapsed*speed)-across*elapsed*elapsed*.8
		if host.profile.material=="void": at=captured+direction*(.22-elapsed*.60)
		var size := (.030 if host.profile.material=="metal" else .070)+.014*(i%3)
		shard(builder,at,direction,across,size*fade,Color(host.color,fade))
	# A short bright contact cut precedes the colored fragments.
	if elapsed<.065:
		var n := across*.014*(1-elapsed/.065)
		builder.quad(captured-axis*.065-n,captured-axis*.065+n,captured+axis*.11-n*.1,captured+axis*.11+n*.1,Color(host.color.lerp(Color.WHITE,.60),fade))

func ground_impact(builder,mist) -> void:
	var elapsed := float(host.age)-float(host.emission_time)*.88
	if elapsed<0 or elapsed>.34: return
	var fade := 1-smoothstep(.065,.34,elapsed)
	var power := .72 if host.action=="normal" else 1.05 if host.action=="heavy" else 1.25
	for i in (5 if host.action=="normal" else 8):
		var angle := i*2.39996+index*.17
		var direction: Vector3=host.aim.rotated(Vector3.UP,angle)
		var at: Vector3=landing+direction*span*(.04+elapsed*.8)*power
		var lift := maxf(0,elapsed*2.6-elapsed*elapsed*6.0)*power
		slab(builder,at+Vector3.UP*lift,direction,minf(.16,span*.09)*power*(.75+.15*(i%3)),fade,i)
		if i%3==0:
			var spread := axis*span*(.12+elapsed*.28)*power
			var height := across*span*(.06+elapsed*.20)*power
			var center := at+height*.7
			mist.quad(center-spread+height,center-spread-height,center+spread+height,center+spread-height,Color("80746a",fade*.30))

func rebuild() -> void:
	super.rebuild()
	if is_instance_valid(contact_paint):
		var contact=Builder.new()
		var age: float=host.age
		if age>0 and age<.34:
			var fade := 1-smoothstep(.07,.34,age)
			var extent := 1.1 if host.action=="normal" else 1.55 if host.action=="heavy" else 1.85
			if host.kind=="burst": extent=maxf(extent,span*1.7)
			var growth := 1-exp(-age*95)
			if energy_core and index==643: growth=1-smoothstep(0,.32,age)*.58
			var x := axis*extent*.5
			var y := across*extent/contact_aspect*.5*growth
			var base: Vector3=host.ground+Vector3.UP*.035
			var center := base+y
			if energy_core: center=captured
			contact.quad(center-x+y,center-x-y,center+x+y,center+x-y,Color(1,1,1,fade))
		contact.commit(contact_paint)
	if is_instance_valid(contact_smoke):
		var vapor=Builder.new()
		var age: float=host.age
		if age>.025 and age<.44:
			var fade := (1-smoothstep(.09,.44,age))*smoothstep(.025,.07,age)
			var x := axis*(.26+age*.4); var y := across*(.14+age*.25)
			var center: Vector3=host.ground+across*.12+across*age*.25
			vapor.quad(center-x+y,center-x-y,center+x+y,center+x-y,Color(Paint.smoke_tint(host.profile),fade*.34))
		vapor.commit(contact_smoke)
	if not is_instance_valid(terrain_paint): return
	var painted=Builder.new()
	var elapsed := float(host.age)-float(host.emission_time)*.88
	if host.kind=="release" and elapsed>0 and elapsed<.32:
		var fade := 1-smoothstep(.075,.32,elapsed)
		var growth := 1-exp(-elapsed*70)
		var power := .80 if host.action=="normal" else 1.05 if host.action=="heavy" else 1.25
		var x := axis*span*.56*power
		var y := across*span*.43*power*growth
		var center := landing+y
		painted.quad(center-x+y,center-x-y,center+x+y,center+x-y,Color(1,1,1,fade))
	painted.commit(terrain_paint)

func beam(builder) -> void:
	var fade := 1-smoothstep(.045,.22,float(host.age))
	var vector: Vector3=host.beam_end-captured
	var previous := captured
	var last_width := across*float(host.width)*.34
	for i in 17:
		var u := float(i+1)/17
		var at := captured+vector*u
		if index==639: at+=across*host.width*sin(i*2.7+index)*.38
		var width := across*float(host.width)*(.38+.10*sin(i*2.1))
		strip(builder,previous,at,last_width,width,fade,fade,float(i)/17,u,Color.WHITE)
		previous=at; last_width=width

func launch(builder,mist) -> void:
	var duration := .11 if host.action=="normal" else .16
	var fade := pow(maxf(0,1-float(host.age)/duration),.8)
	if host.profile.family=="ranged":
		if index in [625,626,628,632,634]:
			var opening := .05 if host.action=="normal" else .025 if host.action=="heavy" else .10
			var pull := .10 if host.action=="normal" else .19 if host.action=="heavy" else .055
			var length := .25 if host.action=="normal" else .36 if host.action=="heavy" else .30
			for lane in 2:
				var sign_y := lane*2-1
				var at := captured+across*sign_y*opening
				strip(builder,at-axis*pull,at+axis*length,across*.045,across*.020,fade*.8,fade*.6,0,1,Color.WHITE)
		else:
			var length := .32 if host.action=="normal" else .49 if host.action=="heavy" else .40
			var width := .11 if host.action=="normal" else .085 if host.action=="heavy" else .16
			strip(builder,captured-axis*.035,captured+axis*length,across*width,across*.025,fade,fade*.8,0,1,Color.WHITE)
		var smoke_age := maxf(0,float(host.age)-.02)
		var smoke_fade := 1-smoothstep(.055,.32,smoke_age)
		var at := captured+across*smoke_age*.4-axis*smoke_age*.20
		var x := axis*(.11+smoke_age*.18); var y := across*(.08+smoke_age*.15)
		mist.quad(at-x+y,at-x-y,at+x+y,at+x-y,Color("aba19b",smoke_fade*.32))
	else:
		var count := 3 if host.action=="normal" else 1 if host.action=="heavy" else 4
		for lane in count:
			var offset := (lane-float(count-1)*.5)*(.09 if host.action=="normal" else .11)
			var a := captured-axis*.09+across*offset
			var b := captured+axis*((.27+.045*lane) if host.action=="normal" else .48 if host.action=="heavy" else .34+.035*lane)+across*offset*.30
			strip(builder,a,b,across*(.095 if host.action=="heavy" else .055),across*.016,fade*.85,fade,0,1,Color.WHITE)
