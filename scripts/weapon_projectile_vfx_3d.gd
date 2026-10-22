extends Node3D
## Native-world presentation only. Call observe and advance once per simulation frame.
## Simulation (x,y) -> world (x,z), terrain and flight height -> world y, all * .01.
const Builder=preload("res://scripts/weapon_vfx_mesh_3d.gd")
const UNIT := .01
const MAX_FLIGHTS := 96
const MAX_HISTORY := 24
const MAX_RIBBON_POINTS := 48
const MAX_PARTICLES := 384
const HISTORY_LIFE := .24
const DESPAWN_LIFE := .15
const Profiles=preload("res://scripts/weapon_effect_profiles.gd")
const Weapon=preload("res://scripts/weapon_vfx.gd")
const Mechanics=preload("res://scripts/weapon_mechanics.gd")
const Art=preload("res://scripts/weapon_image_art.gd")
const Motion=preload("res://scripts/weapon_motion_design.gd")
const ProjectileDesign=preload("res://scripts/weapon_projectile_design.gd")
const Paint=preload("res://scripts/weapon_hybrid_material.gd")
const ReferenceArt=preload("res://scripts/weapon_batch_art.gd")
const SPATIAL=preload("res://resources/weapon_projectile_vfx_3d.gdshader")
var camera: Camera3D
var height_at: Callable
var body_gain := 1.0
var flights: Dictionary={}
var particles: Array[Dictionary]=[]
var clock := 0.0
var particle_batch: MultiMeshInstance3D
static var sphere: SphereMesh
static var quad: QuadMesh

func _ready() -> void:
	if sphere==null:
		sphere=SphereMesh.new(); sphere.radius=.5; sphere.height=1.0; sphere.radial_segments=8; sphere.rings=4
	if quad==null: quad=QuadMesh.new(); quad.size=Vector2.ONE
	particle_batch=MultiMeshInstance3D.new()
	particle_batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particle_batch.multimesh=MultiMesh.new()
	particle_batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	particle_batch.multimesh.use_colors=true
	particle_batch.multimesh.mesh=sphere
	particle_batch.multimesh.instance_count=MAX_PARTICLES
	particle_batch.multimesh.visible_instance_count=0
	var mat := ShaderMaterial.new(); mat.shader=SPATIAL; mat.set_shader_parameter("particle_mode",true)
	particle_batch.material_override=mat
	add_child(particle_batch)

func world_point(at: Vector2, height: float=0.0) -> Vector3:
	var terrain := float(height_at.call(at)) if height_at.is_valid() else 0.0
	return Vector3(at.x*UNIT,(terrain+height)*UNIT,at.y*UNIT)

func reset() -> void:
	for flight in flights.values(): release_flight(flight)
	flights.clear(); particles.clear(); clock=0
	if is_instance_valid(particle_batch): particle_batch.multimesh.visible_instance_count=0

func release_flight(flight: Dictionary) -> void:
	var root: Node3D=flight.get("root",null)
	if not is_instance_valid(root): return
	if root.get_parent(): root.get_parent().remove_child(root)
	root.queue_free()

func camera_point() -> Vector3:
	return to_local(camera.global_position) if is_instance_valid(camera) else Vector3(0,10,8)

static func side_vector(tangent: Vector3, point: Vector3, eye: Vector3) -> Vector3:
	var side := tangent.cross((eye-point).normalized())
	if side.length_squared()<.000001: side=tangent.cross(Vector3.UP)
	if side.length_squared()<.000001: side=Vector3.RIGHT
	return side.normalized()

static func material_code(material_name: String) -> float:
	return float({"metal":1,"storm":2,"frost":3,"feather":4,"soul":5,"void":5,"blood":6,"stone":7,"tide":8,"sun":9,"star":9,"mirror":10,"bell":11,"cloth":12}.get(material_name,0))

static func ribbon_behavior(profile: Dictionary) -> Dictionary:
	var shape: Array={"blood":[.78,.55,1.45],"metal":[.48,1.20,2.45],"cloth":[.90,.45,1.45],
		"frost":[.62,.90,1.85],"storm":[.40,1.50,3.0],"tide":[1.0,.42,1.25],
		"stone":[.68,1.10,2.15],"feather":[.72,.68,1.55],"void":[.82,1.35,2.20],
		"bell":[.56,.72,1.70],"sun":[.66,.88,2.10],"star":[.58,1.0,1.95],
		"mirror":[.52,1.25,2.65],"soul":[.92,.48,1.20]}.get(str(profile.material),[.65,.85,1.8])
	return {"width":float(shape[0])*(.8+float(profile.spread)*.20),"taper":float(shape[1]),
		"decay":float(shape[2])+.15*float(profile.impact.compression)}

static func resample(history: Array) -> Array:
	var raw: Array=[]
	var length := 0.0
	for point in history:
		if not raw.is_empty():
			var delta: float=Vector3(point.p).distance_to(raw.back().p)
			if delta<.00001:
				raw.back().at=point.at; continue
			length+=delta
		raw.append({"p":point.p,"at":float(point.at),"distance":length})
	if raw.size()<2: return []
	var count := mini(MAX_RIBBON_POINTS,maxi(2,ceili(length/.06)+1))
	var samples: Array=[]
	var segment := 1
	for i in count:
		var distance := length*float(i)/(count-1)
		while segment<raw.size()-1 and distance>float(raw[segment].distance): segment+=1
		var a: Dictionary=raw[segment-1]; var b: Dictionary=raw[segment]
		var t := clampf((distance-float(a.distance))/maxf(.00001,float(b.distance)-float(a.distance)),0,1)
		samples.append({"p":Vector3(a.p).lerp(b.p,t),"at":lerpf(float(a.at),float(b.at),t),"u":float(i)/(count-1)})
	return samples

static func build_geometry(history: Array, eye: Vector3, now: float, profile: Dictionary, color: Color, visual_gain: float=1.0) -> Dictionary:
	var samples := resample(history)
	var vertices := PackedVector3Array(); var uv := PackedVector2Array()
	var colors := PackedColorArray(); var indices := PackedInt32Array()
	var centers := PackedVector3Array(); var widths := PackedFloat32Array()
	var style := ribbon_behavior(profile)
	for i in samples.size():
		var sample: Dictionary=samples[i]
		var u := float(sample.u)
		var tangent: Vector3=Vector3(samples[mini(i+1,samples.size()-1)].p)-Vector3(samples[maxi(0,i-1)].p)
		var side := side_vector(tangent,sample.p,eye)
		var age := maxf(0,now-float(sample.at))
		var fade := pow(maxf(0,1-age/HISTORY_LIFE),float(style.decay)*.60)
		var taper := pow(u,float(style.taper)*.65)*minf(1,(1-u)*7)
		# Dense magic carries a broad translucent wake; metal keeps its narrow cut.
		var width := (.035+float(profile.smoke_gain)*.085+float(profile.impact.compression)*.012)*float(style.width)*taper*sqrt(fade)*(2.1 if profile.family=="magic" else 1.35)*visual_gain
		var tint := Color(color,color.a*fade*.94)
		centers.append(sample.p); widths.append(width)
		vertices.append(Vector3(sample.p)-side*width); vertices.append(Vector3(sample.p)+side*width)
		uv.append(Vector2(u,0)); uv.append(Vector2(u,1)); colors.append(tint); colors.append(tint)
		if i>0:
			var base := i*2
			indices.append_array(PackedInt32Array([base-2,base-1,base,base-1,base+1,base]))
	return {"vertices":vertices,"uv":uv,"colors":colors,"indices":indices,"centers":centers,"widths":widths}

func texture_material(_source: String, body: bool, profile: Dictionary) -> ShaderMaterial:
	if ReferenceArt.enabled(int(profile.canonical)):
		var art=ReferenceArt.of(int(profile.canonical))
		var slot := "projectile" if body else "trail"
		if not art.metadata(slot).is_empty(): return art.material(slot)
	return Paint.material(profile,not body,body)

func create_flight(bullet: Dictionary, point: Vector3) -> Dictionary:
	var weapon := int(bullet.weapon_index)
	var action := Profiles.action_of(bullet)
	var profile := Profiles.action_profile(weapon,"",action)
	var color: Color=Weapon.profile(weapon).color
	var root := Node3D.new(); root.name="Projectile_%s" % str(bullet.fx_id); add_child(root)
	var ribbon := MeshInstance3D.new(); ribbon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# ArrayMesh has no renderer RID until its first surface exists. Keep the
	# instance hidden and unbound until a real observed segment is available.
	var mesh := ArrayMesh.new(); ribbon.hide()
	var mat := texture_material(str(profile.blade_source),false,profile)
	ribbon.material_override=mat; root.add_child(ribbon)
	var body := MeshInstance3D.new(); body.mesh=quad
	body.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spell := str(bullet.get("spell",Catalog.weapon(weapon).get("spell","star")))
	var role := Mechanics.projectile_role(weapon,spell)
	var source := Art.payload_source(weapon,"projectile",role)
	if bullet.get("charged",false): source=Art.charged_source(weapon,"projectile",source)
	var payload_material := Paint.payload(source)
	var reference_payload := ""
	if ReferenceArt.enabled(int(profile.canonical)):
		var art=ReferenceArt.of(int(profile.canonical))
		reference_payload="projectile_art" if action=="heavy" or bool(bullet.get("sequence_final",false)) else "projectile"
		if not art.metadata(reference_payload).is_empty(): payload_material=art.material(reference_payload)
	body.material_override=payload_material if payload_material!=null else texture_material(source,true,profile)
	body.hide(); root.add_child(body)
	var silhouette := MeshInstance3D.new()
	silhouette.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var silhouette_mat := Paint.material(profile,false,true)
	silhouette.material_override=silhouette_mat; silhouette.hide(); root.add_child(silhouette)
	var vapor: MeshInstance3D
	if Motion.identity(weapon) in [627,635,637,638,642,646,647]:
		vapor=MeshInstance3D.new(); vapor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vapor.material_override=Paint.smoke(profile); vapor.hide(); root.add_child(vapor)
	var core := MeshInstance3D.new(); core.mesh=sphere
	core.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; core_mat.albedo_color=color
	core.material_override=core_mat; root.add_child(core)
	var body_size := Mechanics.projectile_size(role,weapon)*UNIT
	var ink := Art.mechanic_ink(source)
	var aspect := ink.size.x/maxf(1,ink.size.y)
	if not reference_payload.is_empty():
		var reference=ReferenceArt.of(int(profile.canonical))
		if not reference.metadata(reference_payload).is_empty(): aspect=reference.aspect(reference_payload)
	var extent := maxf(body_size.x,body_size.y)*(1.8 if profile.family=="magic" else 1.45)
	if action!="normal": extent*=1.20
	var paint_size := Vector2(extent,extent/aspect) if aspect>=1 else Vector2(extent*aspect,extent)
	var flight := {"native_body":true,"painted_head":payload_material!=null,"paint_size":paint_size,"vapor":vapor,"silhouette":silhouette,"root":root,"ribbon":ribbon,"mesh":mesh,"material":mat,"body":body,"core":core,"action":action,
		"weapon_index":weapon,"profile":profile,"color":color,"source":source,"role":role,
		"history":[],"p":point,"age":0.0,"gone":0.0,"death":false,"geometry":{},
		"direction":Vector3.FORWARD,"body_size":body_size}
	emit_particles(point,Vector3.UP,profile,color,2,false)
	return flight

func observe(bullets: Array, dt: float) -> void:
	var seen := {}
	for bullet in bullets:
		if not bullet is Dictionary or not bullet.has("fx_id") or not bullet.has("weapon_index") or not bullet.has("p"): continue
		var key: Variant=bullet.fx_id
		if key==null: continue
		seen[key]=true
		var at: Vector2=bullet.p
		var point := world_point(at,float(bullet.get("height",0)))
		if not flights.has(key):
			if flights.size()>=MAX_FLIGHTS: continue
			flights[key]=create_flight(bullet,point)
		var flight: Dictionary=flights[key]
		flight.gone=0.0; flight.death=false
		if not flight.history.is_empty() and point.distance_to(flight.p)>6.0: flight.history.clear()
		var velocity: Vector2=bullet.get("v",Vector2.ZERO)
		if point.distance_squared_to(flight.p)>.000001: flight.direction=(point-Vector3(flight.p)).normalized()
		elif velocity.length_squared()>.000001: flight.direction=Vector3(velocity.x,0,velocity.y).normalized()
		flight.p=point
		flight.history.append({"p":point,"at":clock})
		if flight.history.size()>MAX_HISTORY: flight.history.pop_front()
		while not flight.history.is_empty() and clock-float(flight.history[0].at)>HISTORY_LIFE: flight.history.pop_front()
		update_flight(flight)
	for key in flights.keys():
		if seen.has(key): continue
		var flight: Dictionary=flights[key]
		if not flight.death:
			flight.death=true
			emit_particles(flight.p,-Vector3(flight.direction),flight.profile,flight.color,3,true)
		flight.gone+=maxf(0,dt)
		flight.body.hide(); flight.core.hide()
		if flight.gone>=DESPAWN_LIFE: release_flight(flight); flights.erase(key)
		else: update_flight(flight)

func update_flight(flight: Dictionary) -> void:
	var geometry := build_geometry(flight.history,camera_point(),clock,flight.profile,flight.color,body_gain)
	flight.geometry=geometry
	if geometry.vertices.size()>=4:
		# Build before binding: clearing a mesh that remains in a visible world
		# instance can submit an empty RID to the GL renderer between updates.
		var mesh := ArrayMesh.new()
		var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=geometry.vertices; arrays[Mesh.ARRAY_TEX_UV]=geometry.uv
		arrays[Mesh.ARRAY_COLOR]=geometry.colors; arrays[Mesh.ARRAY_INDEX]=geometry.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		flight.mesh=mesh
		flight.ribbon.mesh=mesh
		flight.ribbon.show()
	else:
		flight.ribbon.hide()
	if is_instance_valid(flight.get("vapor",null)):
		var vapor: MeshInstance3D=flight.vapor
		if geometry.vertices.size()>=4:
			var vertices: PackedVector3Array=geometry.vertices.duplicate()
			var colors: PackedColorArray=geometry.colors.duplicate()
			var tone := Color("68524b") if Motion.identity(int(flight.weapon_index)) in [627,635,637,642] else Color("91a8b4")
			for i in geometry.centers.size():
				var center: Vector3=geometry.centers[i]
				for edge in 2:
					var j: int=i*2+edge
					vertices[j]=center+(vertices[j]-center)*2.7+Vector3.UP*.025
					colors[j]=Color(tone,colors[j].a*.26*pow(maxf(0,1-float(flight.gone)/DESPAWN_LIFE),1.3))
			var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_TEX_UV]=geometry.uv
			arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_INDEX]=geometry.indices
			var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			vapor.mesh=mesh; vapor.show()
		else: vapor.hide()
	flight.material.set_shader_parameter("phase",clock)
	# A vanished head must not leave a bright newest sample that abruptly pops
	# when its root reaches the bounded despawn deadline.
	flight.material.set_shader_parameter("wake_opacity",pow(maxf(0,1-float(flight.gone)/DESPAWN_LIFE),1.5))
	var direction: Vector3=flight.direction
	var side := side_vector(direction,flight.p,camera_point())
	var normal := direction.cross(side).normalized()
	# Scale in the projectile's own axes. Basis.scaled() scales world rows,
	# leaving an oblique side's Z component full-size and making a thin bullet
	# into a tall camera-facing light card.
	flight.body.transform=Transform3D(Basis(direction*flight.paint_size.x*body_gain,side*flight.paint_size.y*body_gain,normal),flight.p)
	flight.body.visible=bool(flight.painted_head) and float(flight.gone)<=0
	flight.core.position=flight.p
	flight.core.scale=Vector3.ONE*maxf(.018,minf(float(flight.body_size.y),.16)*.46)*body_gain
	flight.core.hide()
	if float(flight.gone)>0 or bool(flight.painted_head): flight.silhouette.hide()
	else: ProjectileDesign.draw(flight,direction,side,normal,body_gain)

# Visible projectile identity is native moving geometry as well as a painted part.
# Motion follows the real projectile; decorative lobes never move its hit centre.
func update_payload_silhouette(flight: Dictionary,forward: Vector3,side: Vector3,up: Vector3) -> void:
	if float(flight.gone)>0: flight.silhouette.hide(); return
	var spec: Dictionary=flight.profile.signature
	var motif := str(spec.motif)
	var builder=Builder.new()
	var center: Vector3=flight.p
	var size := clampf(float(flight.body_size.x)*.55,.12,.50)*.35*body_gain
	if flight.action=="heavy": size*=1.25
	var tint := Color(flight.color,.36)
	var count := mini(2,int(spec.count))
	if flights.size()>40: count=mini(count,2)
	var opening := float(spec.opening)
	var bias := float(spec.bias)
	var elapsed := float(flight.age)
	if motif in ["sabot","beak","obsidian","ice","prism"]:
		# Long sabot / dark lance / several ice needles / convergent prism facets.
		for i in count:
			var offset := (float(i)-float(count-1)*.5)*size*opening*.65
			var at := center+side*offset-forward*absf(offset)*(.8+bias)
			var tip := at+forward*size*(.75+bias)
			var tail := at-forward*size*(.65+bias*.5)
			var broad := side*size*(.04 if motif in ["ice","sabot"] else .16)*(.6+opening)
			builder.quad(tail,at-broad,tip,at+broad,tint)
	elif motif in ["feather","thorn"]:
		for i in count:
			var at := center-forward*size*(.14+i*.22)
			var wing := side*size*opening*(1-float(i)/(count+1))
			builder.quad(at-forward*size*.4-wing,at-wing*.55,at+forward*size*.45,at+wing*.55,tint)
	elif motif=="lightning":
		var previous := center-forward*size
		for i in 7:
			var at := center+forward*size*(float(i)/3-1)+side*sin(i*2.3+floor(elapsed*22))*size*opening*.42
			payload_strip(builder,previous,at,up*size*.025,tint); previous=at
	elif motif in ["moon","mirror"]:
		for lane in (2 if motif=="mirror" else 1):
			var previous := center-forward*size
			for i in 10:
				var t := float(i+1)/10
				var at := center+forward*size*(t*2-1)+side*size*(sin(t*PI)*(.9 if motif=="moon" else .3)+lane*.6)
				payload_strip(builder,previous,at,side*size*.06*sin(t*PI),tint); previous=at
	elif motif in ["soul","void","wick"]:
		for lane in count:
			var previous := center
			for i in 7:
				var t := float(i+1)/7
				var angle: float= t*4+elapsed*(2 if motif!="void" else -3)+lane*TAU/count
				var at := center-forward*t*size*2+(side*cos(angle)+up*sin(angle))*sin(t*PI)*size*opening*.46
				payload_strip(builder,previous,at,side*size*.065*(1-t),tint); previous=at
	elif motif in ["star","sunray","chime"]:
		for i in count:
			var angle: float= float(i)*TAU/count+elapsed*(1 if motif=="chime" else .25)
			var ray := side*cos(angle)+up*sin(angle)
			var at := center+ray*size*(.35+opening)
			payload_strip(builder,center,at,forward*size*.06,tint)
	elif motif=="meteor":
		for i in count:
			var angle: float= i*2.4+elapsed
			var across := (side*cos(angle)+up*sin(angle))*size*(.12+opening*.18)
			builder.quad(center-forward*size*(1.5+bias),center-across,center+forward*size*.5,center+across,tint)
	else: # Flying folded covenant pages.
		for i in count:
			var angle: float= elapsed*1.4+i*2.4
			var at := center-forward*size*i*.27
			var across := (side*cos(angle)+up*sin(angle))*size*opening*.38
			builder.quad(at-forward*size*.4-across,at-forward*size*.4+across,at+forward*size*.4-across*.3,at+forward*size*.4+across*.3,tint)
	builder.commit(flight.silhouette)

func payload_strip(builder,a: Vector3,b: Vector3,across: Vector3,tint: Color) -> void:
	builder.quad(a-across,a+across,b-across,b+across,tint)

func emit_particles(at: Vector3, direction: Vector3, profile: Dictionary, color: Color, count: int, dying: bool) -> void:
	for i in count:
		if particles.size()>=MAX_PARTICLES: particles.pop_front()
		var phase := float(i)*2.39996+clock*.71
		var spread := Vector3(cos(phase),.35+absf(sin(phase)),sin(phase))
		var velocity := direction*(.12 if dying else .08)+spread*(.10+float(profile.smoke_gain)*.32)
		particles.append({"p":at,"v":velocity,"age":0.0,"life":.16+float(profile.impact.decay)*.28,
			"color":color,"size":.016+float(profile.smoke_gain)*.025,"gravity":.18 if profile.material in ["soul","cloth"] else -.55})

func advance(dt: float) -> void:
	dt=maxf(0,dt)
	clock+=dt
	for flight in flights.values():
		flight.age+=maxf(0,dt); update_flight(flight)
	for i in range(particles.size()-1,-1,-1):
		var particle: Dictionary=particles[i]
		particle.age+=maxf(0,dt)
		if particle.age>=particle.life: particles.remove_at(i); continue
		particle.v.y+=float(particle.gravity)*dt
		particle.p+=Vector3(particle.v)*dt
	update_particles()

func update_particles() -> void:
	if not is_instance_valid(particle_batch): return
	var multimesh := particle_batch.multimesh
	multimesh.visible_instance_count=particles.size()
	for i in particles.size():
		var particle: Dictionary=particles[i]
		var t := float(particle.age)/float(particle.life)
		var size := float(particle.size)*(1-t*.5)
		multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),particle.p))
		multimesh.set_instance_color(i,Color(particle.color,(1-t)*.60))

