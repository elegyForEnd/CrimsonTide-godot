extends RefCounted
## New choreography read from the user reference, dedicated to weapon 606.
const Builder=preload("res://scripts/weapon_vfx_mesh_3d.gd")
const Paint=preload("res://scripts/weapon_606_reference_art.gd")
var host: Node3D
var slam := false
var landing := Vector3.ZERO
var trail: MeshInstance3D
var contact_paint: MeshInstance3D
var contact_smoke: MeshInstance3D
var ground_paint: MeshInstance3D
var shards: MeshInstance3D
var charge: MeshInstance3D
var forward := Vector3.RIGHT
var across := Vector3.UP
var root := Vector3.ZERO
var endpoint := Vector3.ZERO
var length := 1.0
var thrust := false
const HISTORY_LIFE := .23
const MAX_HISTORY := 32
var history: Array[Dictionary]=[]
var last_history_age := -1.0
var puffs: Array[Dictionary]=[]

func setup(effect: Node3D) -> void:
	host=effect
	root=host.data.get("reference_tip",host.origin)
	landing=host.ground+Vector3.UP*.018
	endpoint=host.ground+host.aim*host.reach+Vector3.UP*(root.y-host.ground.y)
	forward=(endpoint-root).normalized()
	if forward.length_squared()<.01: forward=host.aim
	length=maxf(.18,root.distance_to(endpoint))
	var view_normal: Vector3=host.camera.global_basis.z if host.camera else Vector3.FORWARD
	across=view_normal.cross(forward).normalized()
	if across.dot(Vector3.UP)<0: across=-across
	thrust=str(host.profile.role)=="motion_thrust"
	if host.kind=="release":
		host.emission_time=.075 if host.action=="normal" else .11 if host.action=="heavy" else .12
		host.tail_time=.15 if host.action=="normal" else .22 if host.action=="heavy" else .26
		host.life=.64
	elif host.kind=="impact": host.life=.68
	host.body_material=Paint.material("surface"); host.ribbon.material_override=host.body_material
	trail=host.mesh_node(Paint.material("trail"))
	contact_paint=host.mesh_node(Paint.material("impact"))
	contact_smoke=host.smoke; contact_smoke.material_override=Paint.material("mist")
	ground_paint=host.mesh_node(Paint.material("ground"))
	shards=host.debris; shards.material_override=Paint.material("shard")
	charge=host.ribbon if host.kind=="charge" else host.mesh_node(Paint.material("charge"))
	if host.kind=="charge": charge.material_override=Paint.material("charge")
	if host.kind=="release":
		for i in 4:
			var t := .16+i*.22
			puffs.append({"born":t*host.emission_time,"at":curve(t),"v":host.aim*(.14+i*.035)+Vector3.UP*.055,"size":.15+i*.015,"life":.34+i*.025,"opacity":.16})
	elif host.kind=="impact":
		for i in 7:
			var angle := i*2.39996
			var drift := Vector3(cos(angle),0,sin(angle))
			puffs.append({"born":.02+i*.009,"at":landing+drift*.035,"v":drift*(.25+i*.025)+Vector3.UP*(.06+.012*(i%3)),"size":.23+.025*(i%3),"life":.46+.03*(i%3),"opacity":.24})
	rebuild()

func quad(builder,center: Vector3,x: Vector3,y: Vector3,alpha: float) -> void:
	if alpha<=.001: return
	builder.quad(center-x+y,center-x-y,center+x+y,center+x-y,Color(1,1,1,alpha))

func fade(start: float,end: float) -> float:
	return 1-smoothstep(start,end,float(host.age))

func curve(t: float) -> Vector3:
	if thrust: return root.lerp(endpoint,t)
	var reverse := -1.0 if int(host.data.get("combo",0))%2 else 1.0
	var angle := lerpf(-.70,.72,t)*reverse
	var reach: float=host.reach
	return host.origin+forward*(cos(angle)*reach*.80)+across*(sin(angle)*reach*.66)

func release(builder) -> void:
	var age: float=host.age
	var active: float=host.emission_time
	var tail: float=host.tail_time
	var head := 1-pow(1-clampf(age/active,0,1),2.4)
	var start := clampf((age-active-.025)/tail,0,1)
	if start>=head or age<=0: return
	var segments := 28 if host.detail==0 else 16
	var opacity := fade(active+.025,active+tail)
	var previous := Vector3.ZERO
	var old_width := Vector3.ZERO
	var old_alpha := 0.0
	for step in segments+1:
		var u := float(step)/segments
		var t := lerpf(start,head,u)
		var at := curve(t)
		var side := across
		if not thrust:
			var tangent := (curve(minf(1,t+.004))-curve(maxf(0,t-.004))).normalized()
			side=(host.camera.global_basis.z if host.camera else Vector3.FORWARD).cross(tangent).normalized()
			if side.dot(across)<0: side=-side
		var half_width := length/maxf(2.6,Paint.aspect("surface"))*.5
		if not thrust: half_width=host.reach*(.13 if host.action=="normal" else .19)
		if host.action=="heavy": half_width*=1.15
		var width := side*half_width
		var alpha := opacity*smoothstep(0,.012,age)
		if step>0:
			builder.quad(previous+old_width,previous-old_width,at+width,at-width,Color(1,1,1,alpha),float(step-1)/segments,u,old_alpha)
		previous=at; old_width=width; old_alpha=alpha
	# A few independent crystalline facets trail the main cutting surface.
	var count := 2 if host.action=="normal" else 3
	for i in count:
		var born := .022+i*.017
		var elapsed := age-born
		if elapsed<=0 or elapsed>.19: continue
		var at := curve(clampf(.30+i*.22,0,head))
		var side := -1.0 if i%2 else 1.0
		at+=across*side*length*(.035+elapsed*.16)
		var f := (1-elapsed/.19)*.44
		quad(shard_builder,at,forward*length*.075,across*length*.075/Paint.aspect("shard"),f)

var shard_builder

func record_history() -> void:
	if host.kind!="release" or float(host.age)<=last_history_age: return
	last_history_age=host.age
	if host.age<=host.emission_time:
		var t := 1-pow(1-clampf(float(host.age)/float(host.emission_time),0,1),2.4)
		var at := curve(t)
		if history.is_empty(): history.append({"p":curve(0),"born":0.0})
		if Vector3(history.back().p).distance_to(at)>.002: history.append({"p":at,"born":float(host.age)})
	elif not history.is_empty() and float(history.back().born)<float(host.emission_time):
		history.append({"p":curve(1),"born":float(host.emission_time)})
	while history.size()>MAX_HISTORY: history.pop_front()
	while not history.is_empty() and float(host.age)-float(history[0].born)>HISTORY_LIFE: history.pop_front()

func draw_history(builder) -> void:
	if history.size()<2: return
	for i in range(1,history.size()):
		var a: Dictionary=history[i-1]; var b: Dictionary=history[i]
		var tangent := (Vector3(b.p)-Vector3(a.p)).normalized()
		var normal: Vector3=(host.camera.global_basis.z if host.camera else Vector3.FORWARD).cross(tangent).normalized()
		var old_age := float(host.age)-float(a.born)
		var new_age := float(host.age)-float(b.born)
		var old_alpha := pow(maxf(0,1-old_age/HISTORY_LIFE),1.3)*.75
		var alpha := pow(maxf(0,1-new_age/HISTORY_LIFE),1.3)*.75
		var width := (.016+old_age*.12)*(1.0 if host.action=="normal" else 1.35)
		var u0 := float(i-1)/float(history.size()-1)
		var u1 := float(i)/float(history.size()-1)
		builder.quad(Vector3(a.p)+normal*width,Vector3(a.p)-normal*width,Vector3(b.p)+normal*width,Vector3(b.p)-normal*width,Color(1,1,1,alpha),u0,u1,old_alpha)

func draw_smoke(builder) -> void:
	for puff in puffs:
		var elapsed := float(host.age)-float(puff.born)
		var lifetime := float(puff.life)
		if elapsed<=0 or elapsed>=lifetime: continue
		var progress := elapsed/lifetime
		var alpha := smoothstep(0,.045,elapsed)*pow(1-progress,1.5)*float(puff.opacity)
		var position: Vector3=puff.at+Vector3(puff.v)*elapsed
		var size := float(puff.size)*(1+progress*1.8)
		var right: Vector3=host.camera.global_basis.x if host.camera else forward
		var up: Vector3=host.camera.global_basis.y if host.camera else across
		var angle := sin(float(puff.born)*31.0)*.12+progress*.09
		var x := (right*cos(angle)+up*sin(angle))*size
		var y := (-right*sin(angle)+up*cos(angle))*size/Paint.aspect("mist")
		quad(builder,position,x,y,alpha)

func path_frost(builder) -> void:
	var age: float=host.age
	var head := 1-pow(1-clampf(age/float(host.emission_time),0,1),2.4)
	var alpha := smoothstep(.012,.060,age)*fade(.22,.57)*(.40 if host.action=="normal" else .62)
	if alpha<=.001 or head<=.001: return
	var segments := 18 if host.detail==0 else 10
	var half_width := float(host.reach)/Paint.aspect("ground")*(.25 if host.action=="normal" else .50)
	var previous := Vector3.ZERO
	var previous_side := Vector3.ZERO
	for i in segments+1:
		var t := head*float(i)/segments
		var at: Vector3
		var tangent: Vector3
		if thrust:
			at=host.ground+host.aim*lerpf(.20,float(host.reach),t)
			tangent=host.aim
		else:
			at=curve(t)
			tangent=curve(minf(1,t+.005))-curve(maxf(0,t-.005))
			tangent.y=0
		at.y=landing.y
		var side := Vector3(-tangent.z,0,tangent.x).normalized()*half_width
		if i>0:
			builder.quad(previous+previous_side,previous-previous_side,at+side,at-side,Color(1,1,1,alpha),head*float(i-1)/segments,t)
		previous=at; previous_side=side

func contact(impact_builder,mist_builder,ground_builder) -> void:
	var age: float=host.age
	var power := .72 if host.action=="normal" else 1.0 if host.action=="heavy" else 1.12
	var extent := 1.12*power
	var reveal := 1-exp(-age*110)
	# The painted contact root is 28% from the left edge, not the image center.
	var center: Vector3=host.origin+forward*extent*.22
	quad(impact_builder,center,forward*extent*.5,across*extent/Paint.aspect("impact")*.5*reveal,fade(.055,.24))
	if age>.025:
		var ground_axis: Vector3=host.aim.normalized()
		var side := Vector3(-ground_axis.z,0,ground_axis.x)
		var ground_width := 1.18*power
		quad(ground_builder,landing,ground_axis*ground_width*.5,side*ground_width/Paint.aspect("ground")*.5,fade(.22,.60)*.72*smoothstep(.02,.07,age))
	for i in (4 if host.action=="normal" else 7):
		var elapsed := age-(.01+i*.003)
		if elapsed<=0 or elapsed>.34: continue
		var angle := (-.9+i*.29)+(1.7 if i%4==0 else 0.0)
		var direction := (forward*cos(angle)+across*sin(angle)).normalized()
		var velocity := .6+float(i%3)*.29
		var at: Vector3=host.origin+direction*(.04+elapsed*velocity*power)-Vector3.UP*elapsed*elapsed*1.2
		var size := (.12+.035*(i%3))*power
		var shard_axis := (direction+across*.24).normalized()
		var shard_side: Vector3=(host.camera.global_basis.z if host.camera else Vector3.FORWARD).cross(shard_axis).normalized()
		quad(shard_builder,at,shard_axis*size,shard_side*size/Paint.aspect("shard"),fade(.12,.35)*.84)

func charging(builder) -> void:
	var hold := str(host.data.source_event.get("kind",""))=="hold_charge"
	var progress := clampf(float(host.age)/maxf(.08,float(host.data.get("windup",.3))),0,1)
	var alpha := (.23+.50*progress)*(1.0 if hold else fade(host.emission_time*.75,host.emission_time+.10))
	var pulse := 1.0+sin(float(host.age)*5.0)*.035
	if host.data.has("ready_age"):
		var since_ready := float(host.age)-float(host.data.ready_age)
		if since_ready>=0 and since_ready<.12: pulse+=.20*(1-since_ready/.12)
	var extent := (.20+.10*progress)*pulse
	var center: Vector3=host.origin-forward*.07
	quad(builder,center,forward*extent,across*extent/Paint.aspect("charge"),alpha)
	var sites: Array=host.data.get("charge_sites",[])
	for i in mini(8,sites.size()):
		var at: Vector3=sites[i]
		quad(builder,at,forward*.035,across*.035/Paint.aspect("charge"),alpha*.48)

func rebuild() -> void:
	if host==null: return
	var main=Builder.new(); var wake=Builder.new(); shard_builder=Builder.new()
	var impact=Builder.new(); var mist=Builder.new(); var ground=Builder.new(); var gathered=Builder.new()
	if host.kind=="release":
		release(main)
		record_history()
		draw_history(wake)
		path_frost(ground)
	elif host.kind=="impact": contact(impact,mist,ground)
	elif host.kind=="charge": charging(gathered)
	draw_smoke(mist)
	main.commit(host.ribbon); wake.commit(trail); shard_builder.commit(shards)
	impact.commit(contact_paint); mist.commit(contact_smoke); ground.commit(ground_paint); gathered.commit(charge)
	for node in [host.ribbon,trail,contact_paint,shards]:
		var mat: ShaderMaterial=node.material_override
		if mat:
			mat.set_shader_parameter("dissolve",smoothstep(.10,.40,float(host.age))*.6 if host.kind!="charge" else 0.0)
