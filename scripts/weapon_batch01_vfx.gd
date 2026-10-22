extends RefCounted
## Reference artwork with per-weapon rhythms, bounded motion trails and painted terrain.
const Builder=preload("res://scripts/weapon_vfx_mesh_3d.gd")
const Assets=preload("res://scripts/weapon_batch_art.gd")
var paint
var index := 607
var tuning: Array=[]
# active normal/heavy/art, tail, history, smoke life, fragment gravity
const TUNING={607:[.045,.065,.055,.12,.12,.24,1.6],608:[.085,.115,.105,.26,.25,.55,.9],612:[.115,.16,.17,.28,.27,.72,2.8],614:[.12,.16,.19,.31,.28,.72,2.5],617:[.10,.14,.15,.24,.23,.64,2.7]}
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
var history_life := .23
const MAX_HISTORY := 32
var history: Array[Dictionary]=[]
var last_history_age := -1.0
var puffs: Array[Dictionary]=[]
var centered := false
var heavy_earth := false
var strike_span := 1.0
var contact_end := Vector3.ZERO
var has_contact_end := false
var actual_shape: RefCounted
var pre_sweep: MeshInstance3D
var shape_tip := Vector3.ZERO
var impact_footprint: MeshInstance3D
var last_actor_sample := -1.0
var rupture := false

func setup(effect: Node3D) -> void:
	host=effect
	index=int(host.profile.canonical)
	paint=Assets.of(index)
	tuning=TUNING.get(index,[.085,.14,.17,.25,.22,.52,2.0])
	history_life=float(tuning[4])
	heavy_earth=index in [612,614,617] or (str(host.profile.family)=="great" and str(host.profile.material) in ["stone","frost","sun"])
	centered=str(host.profile.role) in ["motion_spin","motion_heavy_spin","motion_quake"]
	root=host.data.get("reference_tip",host.origin)
	landing=host.ground+Vector3.UP*.018
	endpoint=host.ground+host.aim*host.reach+Vector3.UP*(root.y-host.ground.y)
	forward=(endpoint-root).normalized()
	if forward.length_squared()<.01: forward=host.aim
	length=maxf(.18,root.distance_to(endpoint))
	strike_span=host.reach
	shape_tip=endpoint if str(host.profile.role)=="motion_thrust" else host.ground+host.aim*host.reach+Vector3.UP*.025
	var view_normal: Vector3=host.camera.global_basis.z if host.camera else Vector3.FORWARD
	across=view_normal.cross(forward).normalized()
	if across.dot(Vector3.UP)<0: across=-across
	thrust=str(host.profile.role)=="motion_thrust"
	if host.kind in ["release","beam","burst"]:
		host.emission_time=float(tuning[0 if host.action=="normal" else 1 if host.action=="heavy" else 2])
		host.tail_time=float(tuning[3])
		host.life=host.emission_time+float(tuning[5])+.18
	elif host.kind=="impact": host.life=float(tuning[5])+.20
	host.body_material=paint.material("surface"); host.ribbon.material_override=host.body_material
	var visual_windup: bool=host.kind=="charge" and str(host.data.source_event.get("kind",""))=="windup" and str(host.profile.family) in ["blade","great"]
	if (host.kind in ["release","beam","burst"] or visual_windup) and preload("res://scripts/weapon_actual_shape.gd").available(index):
		actual_shape=preload("res://scripts/weapon_actual_shape.gd").new()
		var source := ("charged_spell" if host.action=="heavy" or str(host.data.get("sequence_shape",""))=="heavy" else "art") if host.kind in ["beam","burst"] else str(host.data.get("sequence_shape",""))
		if host.kind=="release" and str(host.profile.family)=="magic" and str(host.data.source_event.get("attack_kind","")) in ["beam","burst"]:
			source="heavy" if host.action=="heavy" else "normal"
		actual_shape.setup(index,host.action,source)
		# Painted primary already includes the stroke near the hand. Starting it
		# at the physical sword tip consumed most of short attacks' visible span.
		if index in [607,608]: root=host.origin
		thrust=int(actual_shape.row.get("reveal_mode",0))==1
		shape_tip=endpoint if thrust else host.ground+host.aim*host.reach+Vector3.UP*.025
		sequence_direction()
		if host.kind=="release" and str(host.profile.family)=="magic":
			shape_tip=root+host.aim*minf(host.reach,.55 if host.action=="heavy" else .72 if host.action=="art" else .4)
		if host.kind=="beam":
			root=host.origin; endpoint=host.beam_end; shape_tip=endpoint; thrust=true
		elif host.kind=="burst":
			root=host.ground+Vector3.UP*.025; shape_tip=root+host.aim*host.reach*.70
		if host.kind in ["release","beam","burst"]:
			host.body_material=actual_shape.material
			host.ribbon.material_override=host.body_material
		else: pre_sweep=host.mesh_node(actual_shape.material)
	trail=host.mesh_node(paint.material("trail"))
	if host.kind=="charge" and int(host.data.get("sequence_step",-1))>=0:
		var wake_mat := ShaderMaterial.new(); wake_mat.shader=preload("res://resources/weapon_batch_ground.gdshader")
		trail.material_override=wake_mat
	contact_paint=host.mesh_node(paint.material("impact"))
	if host.kind=="impact" and heavy_earth:
		contact_paint.material_override.set_shader_parameter("visible_v_max",.78)
		var footprint_mat: ShaderMaterial=paint.material("impact")
		footprint_mat.set_shader_parameter("visible_v_min",.78)
		impact_footprint=host.mesh_node(footprint_mat)
	contact_smoke=host.smoke; contact_smoke.material_override=paint.material("mist")
	ground_paint=host.mesh_node(paint.material("ground"))
	var ground_mat := ShaderMaterial.new(); ground_mat.shader=preload("res://resources/weapon_batch_ground.gdshader")
	rupture=index in [611,612,614,615,616,617,618,619,620,623]
	if rupture:
		ground_mat.shader=preload("res://resources/weapon_rupture_decal.gdshader")
		ground_mat.set_shader_parameter("earth_texture",load("res://assets/combat/ground-rupture-v3/earth.png"))
	ground_paint.material_override=ground_mat
	shards=host.debris; shards.material_override=paint.material("shard")
	charge=host.ribbon if host.kind=="charge" else host.mesh_node(paint.material("charge"))
	if host.kind=="charge": charge.material_override=paint.material("charge")
	if host.kind=="release":
		for i in 2:
			var t := .16+i*.22
			var born_at := curve(t)
			if heavy_earth: born_at.y=landing.y+.03
			puffs.append({"born":t*host.emission_time,"at":born_at,"v":host.aim*(.14+i*.035)+Vector3.UP*(.035 if heavy_earth else .07),"size":.15+i*.015,"life":float(tuning[5])*.7,"opacity":.05 if index==607 else .12 if index==608 else .17})
	elif host.kind=="impact":
		for i in 3:
			var angle := (i-1)*.85
			var drift := Vector3(cos(angle),0,sin(angle))
			puffs.append({"born":.045+i*.025,"at":landing+drift*.035,"v":drift*.24+Vector3.UP*.055,"size":(.28 if heavy_earth else .16)+.015*(i%3),"life":float(tuning[5]),"opacity":.055 if index==607 else .12 if index==608 else .18})
	rebuild()

func follow_actor() -> void:
	# A moving anticipation belongs to the current hand and floor, never its
	# cast-start coordinates. Released strokes keep their own world-space wake.
	root=host.origin; landing=host.ground+Vector3.UP*.018
	endpoint=host.ground+host.aim*host.reach+Vector3.UP*(root.y-host.ground.y)
	shape_tip=endpoint if thrust else host.ground+host.aim*host.reach+Vector3.UP*.025
	sequence_direction()

func sequence_direction() -> void:
	var step := int(host.data.get("sequence_step",-1))
	if step<0 or bool(host.data.get("sequence_final",false)): return
	if index==607 and step==1:
		shape_tip=root+host.aim*host.reach*.74+Vector3.UP*host.reach*.52
	elif index==608:
		shape_tip=root+host.aim*host.reach*.94+Vector3.UP*host.reach*(.22 if step==0 else -.22)
	elif index in [612,617]:
		shape_tip=root+host.aim*host.reach*.80+Vector3.UP*host.reach*(.38 if step==0 else -.18)
	elif index not in Assets.IDS and str(host.profile.family) in ["blade","great"]:
		shape_tip=root+host.aim*host.reach*.84+Vector3.UP*host.reach*(.24 if step==0 else -.16)

func actor_wake(builder) -> void:
	if int(host.data.get("sequence_step",-1))<0: return
	if float(host.age)-last_actor_sample>=.016:
		last_actor_sample=host.age
		if history.is_empty() or Vector3(history.back().p).distance_to(root)>.045:
			history.append({"p":root,"born":float(host.age)})
			if puffs.size()<8:
				puffs.append({"born":float(host.age),"at":host.ground+Vector3.UP*.025,"v":-host.aim*.16+Vector3.UP*.06,"size":.12,"life":.30,"opacity":.06 if index==607 else .11})
	while history.size()>MAX_HISTORY: history.pop_front()
	while not history.is_empty() and float(host.age)-float(history[0].born)>.22: history.pop_front()
	var tint: Color={607:Color("bd8eff"),608:Color("e8c48a"),612:Color("ffe0a3"),614:Color("dba767"),617:Color("b788ff")}.get(index,host.color)
	for i in range(1,history.size()):
		var a: Vector3=history[i-1].p; var b: Vector3=history[i].p
		var side: Vector3=(host.camera.global_basis.z if host.camera else Vector3.FORWARD).cross((b-a).normalized()).normalized()*.012
		var alpha := (1-clampf((float(host.age)-float(history[i].born))/.22,0,1))*.48
		builder.quad(a-side,a+side,b-side,b+side,Color(tint,alpha))

func quad(builder,center: Vector3,x: Vector3,y: Vector3,alpha: float) -> void:
	if alpha<=.001: return
	builder.quad(center-x+y,center-x-y,center+x+y,center+x-y,Color(1,1,1,alpha))

func fade(start: float,end: float) -> float:
	return 1-smoothstep(start,end,float(host.age))

func catch_contact(at: Vector3) -> void:
	if has_contact_end: return
	has_contact_end=true
	contact_end=Vector3(at.x,host.ground.y+.025,at.z) if heavy_earth else at
	if thrust and actual_shape==null: endpoint=at; length=root.distance_to(endpoint)
	if heavy_earth and not centered and actual_shape==null:
		strike_span=maxf(.55,Vector2(at.x-host.ground.x,at.z-host.ground.z).length()/.82)
	for i in puffs.size():
		if float(puffs[i].born)<=float(host.age): continue
		var next_at := curve(.16+i*.22)
		if heavy_earth: next_at.y=landing.y+.03
		puffs[i].at=next_at

func curve(t: float) -> Vector3:
	if thrust: return root.lerp(endpoint,t)
	if index not in Assets.IDS:
		return root.lerp(shape_tip,t)+across*sin(t*PI)*host.reach*(.18 if str(host.profile.family)=="great" else .10)
	var reverse := -1.0 if int(host.data.get("combo",0))%2 else 1.0
	var reach: float=strike_span
	var a: Vector3=host.aim
	var up := Vector3.UP
	var cross := Vector3(-a.z,0,a.x)
	if centered:
		var angle := lerpf(-PI*1.75,0.0,t)
		var radius := reach*(.62 if host.action=="normal" else .82)
		return host.ground+(a*cos(angle)+cross*sin(angle))*radius+up*(.12 if index==614 else .38)
	if index==607:
		var angle := lerpf(-.65,.52,t)*reverse
		return host.origin+forward*(cos(angle)*reach*.74)+across*sin(angle)*reach*.48
	if index==608:
		var angle := lerpf(-.42,.61,t)*reverse
		return host.origin+forward*(.18+sin(t*PI)*.55)*reach+across*sin(angle)*reach*.45
	if index==612:
		if host.action=="normal": return host.origin+a*reach*(.20+sin(t*PI)*.55)+across*reach*lerpf(-.42,.30,t)*reverse
		var s := 1-t
		var begin: Vector3=host.origin-a*reach*.12+up*reach*.72
		var bend: Vector3=host.origin+a*reach*.62+up*reach*.58
		var end: Vector3=contact_end if has_contact_end else host.ground+a*reach*.82+up*.04
		return begin*s*s+bend*2*s*t+end*t*t
	if index==614:
		return host.ground+a*(.18+t*.68)*reach+cross*sin(t*PI)*reach*.28*reverse+up*(.09+sin(t*PI)*reach*.12)
	# 617's reference is swept blade history around the hand, not a flying ribbon.
	var pivot: Vector3=host.data.get("reference_pivot",host.origin)
	var end: Vector3=contact_end if has_contact_end else host.ground+a*reach*.82+up*.04
	var normal: Vector3=host.camera.global_basis.z if host.camera else Vector3.FORWARD
	var radius := end-pivot
	radius-=normal*radius.dot(normal)
	var opening := .95 if host.action=="normal" else 1.65 if host.action=="heavy" else 2.10
	return pivot+radius.rotated(normal,opening*(1-t))*(.73+.27*t)

func swept_blade(builder,head: float,start: float,opacity: float) -> void:
	var pivot: Vector3=host.data.get("reference_pivot",host.origin)
	var count := 36 if host.detail==0 else 20
	var old_inner := Vector3.ZERO
	var old_outer := Vector3.ZERO
	var old_alpha := 0.0
	var band := .22 if host.action=="normal" else .43 if host.action=="heavy" else .56
	for i in count+1:
		var u := float(i)/count
		var t := lerpf(start,head,u)
		var outer := curve(t)
		var thickness := band*pow(maxf(0,sin(u*PI)),.35)
		var inner := outer-(outer-pivot)*thickness
		var alpha := opacity*smoothstep(0,.12,u)*(.58 if host.action=="normal" else .90)
		if i>0:
			# V=1 is the bright outer cutting edge; the dark face lies inward.
			builder.quad(old_inner,old_outer,inner,outer,Color(1,1,1,alpha),float(i-1)/count,u,old_alpha)
		old_inner=inner; old_outer=outer; old_alpha=alpha

func release(builder) -> void:
	var age: float=host.age
	var active: float=host.emission_time
	var tail: float=host.tail_time
	if actual_shape!=null:
		var pivot: Vector3=root if thrust else host.data.get("reference_pivot",host.origin)
		if host.kind=="burst": pivot=root
		if str(actual_shape.row.get("placement","blade"))=="ground_wave": pivot=host.ground+host.aim*.15+Vector3.UP*.018
		var offset: float=active if bool(host.data.get("shape_prepared",false)) else 0.0
		var contact: float=float(host.data.get("batch_contact_age",-1))
		if contact>=0: contact+=offset
		var cross_gain := (.55 if host.action=="heavy" else .28) if host.kind=="beam" else 1.0
		actual_shape.draw(builder,pivot,shape_tip,host.camera,age+offset,active,contact,cross_gain)
		return
	var head := 1-pow(1-clampf(age/active,0,1),2.4)
	var start := clampf((age-active-.025)/tail,0,1)
	if centered: start=maxf(start,head-.38)
	if start>=head or age<=0: return
	var segments := 28 if host.detail==0 else 16
	var opacity := fade(active+.025,active+tail)
	if host.data.has("batch_contact_age"):
		var since_contact := age-float(host.data.batch_contact_age)
		opacity*=1-smoothstep(.035 if index==617 else .025,.16 if index==617 else .095,since_contact)
	if opacity<=.001: return
	if index==617:
		swept_blade(builder,head,start,opacity)
		return
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
			if step==0:
				if side.dot(across)<0: side=-side
			elif side.dot(old_width)<0: side=-side
		var half_width: float=length/maxf(2.6,float(paint.aspect("surface")))*.5
		if not thrust: half_width=host.reach*(.075 if index==607 else .12 if index==608 else .16 if index==612 else .12 if index==614 else .26)
		if host.action=="normal": half_width*=.70
		if host.action=="heavy": half_width*=1.15
		if not thrust: half_width*=pow(maxf(0,sin(u*PI)),.55)
		var width := side*half_width
		var alpha := opacity*smoothstep(0,.012,age)
		if step>0:
			builder.quad(previous+old_width,previous-old_width,at+width,at-width,Color(1,1,1,alpha),float(step-1)/segments,u,old_alpha)
		previous=at; old_width=width; old_alpha=alpha
	# Detached fragments use the material from this weapon's own storyboard.
	var count := 0 if heavy_earth else 1
	for i in count:
		var born := .022+i*.017
		var elapsed := age-born
		if elapsed<=0 or elapsed>.19: continue
		var at := curve(clampf(.30+i*.22,0,head))
		var side := -1.0 if i%2 else 1.0
		at+=across*side*length*(.035+elapsed*.16)
		var f := (1-elapsed/.19)*.44
		var size: float=length*(.012 if index==607 else .045 if index==608 else .065)
		quad(shard_builder,at,forward*size,across*size/paint.aspect("shard"),f)

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
	while not history.is_empty() and float(host.age)-float(history[0].born)>history_life: history.pop_front()

func draw_history(builder) -> void:
	# For 617 the broad swept blade IS the trail. A second full-image ribbon
	# would duplicate the reference's silhouette rather than add residual motion.
	if index==617: return
	if history.size()<2: return
	for i in range(1,history.size()):
		var a: Dictionary=history[i-1]; var b: Dictionary=history[i]
		var tangent := (Vector3(b.p)-Vector3(a.p)).normalized()
		var normal: Vector3=(host.camera.global_basis.z if host.camera else Vector3.FORWARD).cross(tangent).normalized()
		var old_age := float(host.age)-float(a.born)
		var new_age := float(host.age)-float(b.born)
		var old_alpha := pow(maxf(0,1-old_age/history_life),1.3)*.26
		var alpha := pow(maxf(0,1-new_age/history_life),1.3)*.26
		var width := (.011+old_age*.055)*(1.0 if host.action=="normal" else 1.25)
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
		var y: Vector3=(-right*sin(angle)+up*cos(angle))*size/float(paint.aspect("mist"))
		quad(builder,position,x,y,alpha)

func contact(impact_builder,mist_builder,ground_builder) -> void:
	var age: float=host.age
	var power := .85 if host.action=="normal" else 1.08 if host.action=="heavy" else 1.04
	if int(host.data.get("sequence_step",-1))>=0 and not bool(host.data.get("sequence_final",false)): power*=.72
	if str(host.profile.family)=="magic" and host.action in ["heavy","art"]: power*=.65
	var extent := (.85 if index==607 else 1.05 if index==608 else 2.10 if index==612 else 1.85 if index==614 else 1.15)*power
	var reveal := 1-exp(-age*110)
	var center: Vector3=host.origin+forward*extent*(.0 if index==607 else -.20 if index==608 else 0.0)
	if heavy_earth: center=landing+across*extent/float(paint.aspect("impact"))*.28*reveal
	var alpha := fade(.018,.13) if index==607 else fade(.08,.33) if index==608 else fade(.12,.44)
	if index!=608 and not (index==614 and host.action=="art") and not bool(host.data.get("contact_art_covered",false)):
		quad(impact_builder,center,forward*extent*.5,across*extent/paint.aspect("impact")*.5*reveal,alpha)
	for i in (2 if host.action=="normal" else 4):
		var elapsed := age-(.01+i*.003)
		var particle_life := .15 if index==607 else .45 if index==608 else .52
		if elapsed<=0 or elapsed>particle_life: continue
		var angle := -.65+i*.38
		var direction := (forward*cos(angle)+across*sin(angle)).normalized()
		var velocity := .6+float(i%3)*.29
		var base: Vector3=landing+Vector3.UP*.04 if heavy_earth else host.origin
		var lift := (1.1+.15*(i%3))*elapsed if heavy_earth else 0.0
		var at: Vector3=base+direction*(.04+elapsed*velocity*power)+Vector3.UP*(lift-elapsed*elapsed*float(tuning[6]))
		var size := ((.025+.008*(i%3)) if index==607 else (.10+.025*(i%3)) if index==608 else (.17+.04*(i%3)))*power
		var shard_axis := (direction+across*.24).normalized()
		var shard_side: Vector3=(host.camera.global_basis.z if host.camera else Vector3.FORWARD).cross(shard_axis).normalized()
		var aspect: float=paint.aspect("shard")
		var xsize: float=size if aspect>=1 else size*aspect
		var ysize: float=size/aspect if aspect>=1 else size
		if heavy_earth:
			if at.y<landing.y-.025: continue
			at+=Vector3.UP*size*.60
		quad(shard_builder,at,shard_axis*xsize,shard_side*ysize,(1-smoothstep(particle_life*.4,particle_life,elapsed))*.84)

func draw_impact_footprint(builder) -> void:
	if index==614 and host.action=="art": return
	var age: float=host.age
	var power := .72 if host.action=="normal" else 1.0 if host.action=="heavy" else 1.12
	var width := (2.10 if index==612 else 1.85 if index==614 else 1.15)*power
	var height: float=width/float(paint.aspect("impact"))
	var depth := Vector3(-host.aim.z,0,host.aim.x)
	if host.camera!=null and depth.dot(host.camera.global_basis.z)<0: depth=-depth
	var projection: float=absf(depth.dot(host.camera.global_basis.y)) if host.camera else .75
	height/=maxf(.25,projection)
	var center := landing-depth*height*.28
	var alpha := fade(.12,.44)*(1-exp(-age*110))
	quad(builder,center,host.aim*width*.5,-depth*height*.5,alpha)

func charging(builder) -> void:
	var hold := str(host.data.source_event.get("kind",""))=="hold_charge"
	var progress := clampf(float(host.age)/maxf(.08,float(host.data.get("windup",.3))),0,1)
	var alpha := (.23+.50*progress)*(1.0 if hold else fade(host.emission_time*.75,host.emission_time+.10))
	var pulse := 1.0+sin(float(host.age)*5.0)*.035
	if host.data.has("ready_age"):
		var since_ready := float(host.age)-float(host.data.ready_age)
		if since_ready>=0 and since_ready<.12: pulse+=.20*(1-since_ready/.12)
	var extent := (.20+.10*progress)*pulse
	if heavy_earth: extent*=.80
	var center: Vector3=host.origin-forward*.07
	quad(builder,center,forward*extent,across*extent/paint.aspect("charge"),alpha)
	var sites: Array=host.data.get("charge_sites",[])
	for i in mini(2,sites.size()):
		var at: Vector3=sites[i]
		quad(builder,at,forward*.035,across*.035/paint.aspect("charge"),alpha*.48)

func coherent_ground(builder) -> void:
	if not rupture or host.kind not in ["release","impact"]: return
	var age: float=host.age
	var impact: bool=host.kind=="impact"
	var alpha := smoothstep(.015,.06,age)*(1-smoothstep(.32,.82,age))
	if alpha<=.001: return
	var span: float=minf(strike_span,host.reach)*(.38 if host.action=="normal" else .72)
	if impact: span=.55 if host.action=="normal" else 1.0
	var center: Vector3=landing if impact else host.ground+host.aim*(span*.5+.12)+Vector3.UP*.021
	var side := Vector3(-host.aim.z,0,host.aim.x)
	var head := clampf(age/(.06 if impact else maxf(.06,host.emission_time)),0,1)
	ground_paint.material_override.set_shader_parameter("reveal",head*1.07)
	# One continuous painted wound, revealed along the blow; no white wire mesh.
	builder.quad(center-host.aim*span*.5-side*span*.21,center-host.aim*span*.5+side*span*.21,center+host.aim*span*.5-side*span*.21,center+host.aim*span*.5+side*span*.21,Color(1,1,1,alpha*.9))

func rebuild() -> void:
	if host==null: return
	var main=Builder.new(); var wake=Builder.new(); shard_builder=Builder.new()
	var impact=Builder.new(); var mist=Builder.new(); var ground=Builder.new(); var gathered=Builder.new()
	var preparation=Builder.new()
	var footprint=Builder.new()
	if host.kind in ["release","beam","burst"]:
		release(main)
		record_history()
		draw_history(wake)
		coherent_ground(ground)
	elif host.kind=="impact": contact(impact,mist,ground)
	elif host.kind=="charge":
		charging(gathered)
		actor_wake(wake)
		if pre_sweep!=null:
			var duration: float=maxf(.02,float(host.data.get("windup",.3)))
			var progress: float=clampf((float(host.age)/duration-.55)/.45,0,1)
			var active: float=float(tuning[0 if host.action=="normal" else 1 if host.action=="heavy" else 2])
			var pivot: Vector3=root if thrust else host.origin
			if str(actual_shape.row.get("placement","blade"))=="ground_wave": pivot=host.ground+host.aim*.15+Vector3.UP*.018
			actual_shape.draw(preparation,pivot,shape_tip,host.camera,progress*active,active)
	if host.kind=="impact": coherent_ground(ground)
	if impact_footprint!=null: draw_impact_footprint(footprint)
	draw_smoke(mist)
	main.commit(host.ribbon); wake.commit(trail); shard_builder.commit(shards)
	impact.commit(contact_paint); mist.commit(contact_smoke); ground.commit(ground_paint); gathered.commit(charge)
	if pre_sweep!=null: preparation.commit(pre_sweep)
	if impact_footprint!=null: footprint.commit(impact_footprint)
	for node in [host.ribbon,trail,contact_paint,shards]:
		var mat: ShaderMaterial=node.material_override
		if mat:
			mat.set_shader_parameter("dissolve",smoothstep(.10,.40,float(host.age))*.6 if host.kind!="charge" else 0.0)
