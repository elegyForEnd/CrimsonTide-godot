extends Node2D
## Continuous UV mesh along observed projectile history. No predicted positions.
const Art=preload("res://scripts/weapon_image_art.gd")
const SHADER=preload("res://resources/weapon_projectile_ribbon.gdshader")
const MAX_SAMPLES := 48
const SAMPLE_SPACING := 6.0
var host: Node2D
var trail: Dictionary={}
var geometry: Dictionary={}
var mesh: ArrayMesh
var density: Texture2D
var shader_material: ShaderMaterial

func _ready() -> void:
	shader_material=ShaderMaterial.new(); shader_material.shader=SHADER
	material=shader_material
	sync()

static func material_code(material_name: String) -> float:
	return float({"metal":1,"storm":2,"frost":3,"feather":4,"soul":5,"void":5,"blood":6,"stone":7,"tide":8,"sun":9,"star":9,"mirror":10,"bell":11,"cloth":12}.get(material_name,0))

static func resample(observed: Array, projector: Callable, fallback_height: float) -> Array:
	var raw: Array=[]
	var distance := 0.0
	for point in observed:
		var screen: Vector2=projector.call(point.p)-Vector2(0,float(point.get("height",fallback_height)))
		if not raw.is_empty():
			var step: float=screen.distance_to(raw.back().p)
			if step<.001:
				raw.back().at=point.at
				continue
			distance+=step
		raw.append({"p":screen,"at":float(point.at),"distance":distance})
	if raw.size()<2 or distance<.001: return []
	var count := mini(MAX_SAMPLES,maxi(2,ceili(distance/SAMPLE_SPACING)+1))
	var samples: Array=[]
	var segment := 1
	for i in count:
		var at := distance*float(i)/(count-1)
		while segment<raw.size()-1 and at>float(raw[segment].distance): segment+=1
		var a: Dictionary=raw[segment-1]; var b: Dictionary=raw[segment]
		var weight := clampf((at-float(a.distance))/maxf(.0001,float(b.distance)-float(a.distance)),0,1)
		samples.append({"p":Vector2(a.p).lerp(b.p,weight),"at":lerpf(float(a.at),float(b.at),weight),"u":float(i)/(count-1),"distance":at})
	return samples

static func build(samples: Array, inverse: Transform2D, color: Color, behavior: Dictionary, now: float, life: float, profile: Dictionary) -> Dictionary:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var centers := PackedVector2Array()
	var widths := PackedFloat32Array()
	for i in samples.size():
		var sample: Dictionary=samples[i]
		var u := float(sample.u)
		var a: Vector2=samples[maxi(0,i-1)].p
		var b: Vector2=samples[mini(samples.size()-1,i+1)].p
		var normal := (b-a).normalized().orthogonal()
		var age := maxf(0,now-float(sample.at))
		var fade := pow(maxf(0,1-age/maxf(.001,life)),float(behavior.decay)*.60)
		var taper := pow(u,float(behavior.taper)*.65)*minf(1.0,(1-u)*7)
		var width := (3.0+float(profile.smoke_gain)*3.5+float(profile.impact.compression))*float(behavior.width)*taper*sqrt(fade)
		var tint := Color(color,color.a*fade*.72)
		centers.append(sample.p); widths.append(width)
		for side in 2:
			var point: Vector2=inverse*(Vector2(sample.p)+normal*width*(-1 if side==0 else 1))
			vertices.append(Vector3(point.x,point.y,0))
			uv.append(Vector2(u,float(side))); colors.append(tint)
		if i>0:
			var base := i*2
			indices.append_array(PackedInt32Array([base-2,base-1,base,base-1,base+1,base]))
	return {"vertices":vertices,"uv":uv,"colors":colors,"indices":indices,"centers":centers,"widths":widths}

func sync() -> void:
	if not is_instance_valid(host) or trail.is_empty() or absf(get_global_transform().determinant())<.000001: return
	var samples := resample(trail.points,host.projected,float(trail.lift))
	geometry=build(samples,get_global_transform().affine_inverse(),trail.color,host.trail_behavior(trail.profile),float(host.clock),float(host.TRAIL_LIFE),trail.profile)
	mesh=ArrayMesh.new()
	if geometry.vertices.size()>=4:
		var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=geometry.vertices; arrays[Mesh.ARRAY_TEX_UV]=geometry.uv
		arrays[Mesh.ARRAY_COLOR]=geometry.colors; arrays[Mesh.ARRAY_INDEX]=geometry.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	density=Art.mechanic_texture(str(trail.profile.density_source))
	if shader_material and density:
		var ink := Art.mechanic_ink(str(trail.profile.density_source))
		var size := Vector2(density.get_size())
		shader_material.set_shader_parameter("density_rect",Vector4(ink.position.x/size.x,ink.position.y/size.y,ink.size.x/size.x,ink.size.y/size.y))
		shader_material.set_shader_parameter("effect_phase",float(host.clock))
		shader_material.set_shader_parameter("flow",float(trail.profile.flow))
		shader_material.set_shader_parameter("shear",float(trail.profile.shear))
		shader_material.set_shader_parameter("material_code",material_code(str(trail.profile.material)))
	queue_redraw()

func _draw() -> void:
	if mesh and mesh.get_surface_count()>0 and density: draw_mesh(mesh,density)
