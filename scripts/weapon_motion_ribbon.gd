extends Node2D
## A swept strip is rebuilt from an authored release trajectory and a bounded
## temporal window. This is actual changing geometry, not a rotated full arc.
## Time is event-local: seeking, slow motion and replay give the same result.
const Profiles=preload("res://scripts/weapon_effect_profiles.gd")
const SEGMENTS=28
const MAX_MOTES=18
var host: Node2D
var effect: Dictionary={}
var profile: Dictionary={}
var shader_material: ShaderMaterial
var drawn_meshes: Array[ArrayMesh]=[]

static func supported(fx: Dictionary) -> bool:
	return fx.has("identity") and fx.has("art_role") and str(fx.get("kind","")) in ["slash","echo","lance","spin","cast","muzzle","beam","chain","detonation"]

func _ready() -> void:
	z_index=-1
	shader_material=ShaderMaterial.new()
	shader_material.shader=preload("res://resources/weapon_motion_ribbon.gdshader")
	material=shader_material
	sync()

func duration() -> float:
	return clampf(float(effect.get("life",.3))*.58,.055,.24)

func residue() -> float:
	return clampf(float(profile.get("attack",{}).get("tail",.3))*.33,.07,.20)

func sync() -> void:
	if effect.is_empty(): hide(); return
	if profile.is_empty(): profile=effect.get("presentation",Profiles.profile(int(effect.identity.weapon),str(effect.art_role)))
	var age := float(effect.age)
	visible=age>0 and age<duration()+residue()+.08
	if shader_material:
		shader_material.set_shader_parameter("phase",maxf(0,age)/duration())
		shader_material.set_shader_parameter("flow",float(profile.flow))
		shader_material.set_shader_parameter("shear",float(profile.shear))
	queue_redraw()

func origin_world() -> Vector2:
	if effect.has("socket_grip") and profile.motion not in ["spin","chop"]:
		return host.get_global_transform()*Vector2(effect.socket_grip)
	return host.get_global_transform()*Vector2(effect.p)-Vector2(0,float(effect.get("height",0))+24)

func aim_world() -> Vector2:
	if effect.has("socket_aim"): return Vector2(effect.socket_aim).normalized()
	return host.get_global_transform().basis_xform(Vector2(effect.aim)).normalized()

func path(u: float, lane: int=0) -> Vector2:
	var r := float(effect.radius)
	var motion := str(profile.motion)
	var reverse := float(effect.get("reverse",1))
	var forward := aim_world()
	var side := forward.orthogonal()*reverse
	var o := origin_world()
	var ease := 1-pow(1-clampf(u,0,1),2.2)
	var offset := float(lane)*.035
	if effect.kind in ["beam","chain"]:
		var start: Vector2=host.get_global_transform()*Vector2(effect.get("beam_start_local",effect.p))
		return start+forward*r*u+side*sin(u*PI)*r*.012*lane
	if motion in ["sweep","hook","spin","wave"]:
		var arc := TAU*.90 if motion=="spin" else PI*1.05 if motion=="hook" else PI*.78
		var a := (-arc*.52+arc*ease)*reverse+offset
		var rad := r*(.78+.12*sin(u*PI)-absf(float(lane))*.04)
		return o+forward.rotated(a)*rad
	if motion=="chop":
		return o+forward*r*(.12+ease*.66)+Vector2(0,-r*.72*(1-ease))+side*r*offset
	if motion in ["thrust","recoil"]:
		return o+forward*r*(.10+ease*.82)+side*r*offset
	# Casts peel upward/forward; the planes share an origin, never a closed ring.
	var fan := float(lane)*.36
	return o+forward.rotated(fan)*r*(.12+ease*.72)+side*r*sin(u*PI)*(.13+lane*.05)

func strip(age: float, lane: int=0) -> Dictionary:
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var dt := duration()
	var tail := residue()
	var head := minf(1,age/dt)
	var start := maxf(0,(age-tail)/dt)
	if start>=head or age<=0: return {"vertices":vertices,"uv":uv,"colors":colors,"indices":indices}
	var inv := get_global_transform().affine_inverse()
	var tint := Color(effect.color).lerp(Color.WHITE,.17)
	var width := float(effect.radius)*(.08+float(profile.spread)*.13)/(1+absf(float(lane))*.55)
	if profile.motion in ["recoil","thrust"] or effect.kind in ["beam","chain"]: width*=.35
	for i in SEGMENTS+1:
		var u := lerpf(start,head,float(i)/SEGMENTS)
		var point := path(u,lane)
		var tangent := (path(minf(1,u+.002),lane)-path(maxf(0,u-.002),lane)).normalized()
		var n := tangent.orthogonal()
		var elapsed := age-u*dt
		var alpha := pow(maxf(0,1-elapsed/tail),1.2)*smoothstep(0,.065,u)*(.62 if lane==0 else .26)
		alpha*=smoothstep(0,.008,age)
		if effect.kind=="echo": alpha*=.36
		var taper := .15+.85*sin(PI*clampf((u-start)/maxf(.001,head-start),0,1))
		for edge in 2:
			vertices.append(inv*(point+n*(float(edge)-.5)*width*taper))
			uv.append(Vector2(u,float(edge)))
			colors.append(Color(tint,alpha))
		if i<SEGMENTS:
			var base := i*2
			indices.append_array(PackedInt32Array([base,base+1,base+2,base+1,base+3,base+2]))
	return {"vertices":vertices,"uv":uv,"colors":colors,"indices":indices}

func draw_strip(data: Dictionary) -> void:
	if data.vertices.is_empty(): return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=data.vertices
	arrays[Mesh.ARRAY_TEX_UV]=data.uv
	arrays[Mesh.ARRAY_COLOR]=data.colors
	arrays[Mesh.ARRAY_INDEX]=data.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	# Canvas drawing stores the RID, so retain the Resource until the next draw.
	drawn_meshes.append(mesh)
	draw_mesh(mesh,null)

func _draw() -> void:
	drawn_meshes.clear()
	if not visible or not is_instance_valid(host) or profile.is_empty(): return
	if absf(get_global_transform().determinant())<.000001: return
	var age := float(effect.age)
	for lane in mini(3,int(profile.attack.layers)):
		draw_strip(strip(age,lane))
	# Each mote has its own birth position, velocity and death. The release head
	# keeps moving while older fragments drift off the earlier swept trajectory.
	var inv := get_global_transform().affine_inverse()
	var tint := Color(effect.color).lerp(Color.WHITE,.3)
	var r := float(effect.radius)
	for i in MAX_MOTES:
		var u := (float(i)+.5)/MAX_MOTES
		var lived := age-u*duration()
		var life := residue()*(.65+fposmod(i*.618, .5))
		if lived<=0 or lived>=life: continue
		var direction := (path(minf(1,u+.01))-path(maxf(0,u-.01))).normalized()
		var velocity := direction.rotated(sin(i*2.4)*.8)*r*(.16+fposmod(i*.37,.3))
		var p := path(u)+velocity*lived+Vector2(0,-12*lived)
		var alpha := pow(1-lived/life,1.6)*.6
		var size := (1.0+float(i%3)*.45)*(1-lived/life)
		var n := direction.orthogonal()*size
		var ends := PackedVector2Array([inv*(p-direction*size*2),inv*(p+n),inv*(p+direction*size*2),inv*(p-n)])
		draw_polygon(ends,PackedColorArray([Color(tint,alpha)]),PackedVector2Array([Vector2(0,.5),Vector2(.5,0),Vector2(1,.5),Vector2(.5,1)]))
