extends Node2D
## A density-textured material layer, distinct from the weapon's short sharp body.
## Each released event owns its shader time; no global TIME or live hand following.
const Profiles=preload("res://scripts/weapon_effect_profiles.gd")
const Art=preload("res://scripts/weapon_image_art.gd")
var host: Node2D
var effect: Dictionary={}
var profile: Dictionary={}
var shader_material: ShaderMaterial

func _ready() -> void:
	z_index=-1
	shader_material=ShaderMaterial.new()
	shader_material.shader=preload("res://resources/weapon_density.gdshader")
	material=shader_material
	sync()

func sync() -> void:
	if effect.is_empty(): hide(); return
	if profile.is_empty(): profile=effect.get("presentation",Profiles.profile(int(effect.get("identity",{}).get("weapon",0)),str(effect.get("art_role",""))))
	var lifetime := maxf(.001,float(effect.get("mist_life",effect.life)))
	var phase := clampf(float(effect.age)/lifetime,0,1)
	visible=float(effect.age)>=0 and float(effect.age)<lifetime
	if shader_material:
		shader_material.set_shader_parameter("effect_phase",phase)
		shader_material.set_shader_parameter("flow",float(profile.flow))
		shader_material.set_shader_parameter("shear",float(profile.shear))
	queue_redraw()

func stamp(texture: Texture2D, at: Vector2, size: Vector2, angle: float, color: Color) -> void:
	var ink := Art.mechanic_ink(str(profile.density_source))
	var fit := minf(size.x/ink.size.x,size.y/ink.size.y)
	draw_set_transform_matrix(get_global_transform().affine_inverse()*Transform2D(angle,at))
	draw_texture_rect(texture,Rect2(-ink.get_center()*fit,texture.get_size()*fit),false,color)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if not is_instance_valid(host) or effect.is_empty() or profile.is_empty(): return
	if absf(get_global_transform().determinant())<.000001: return
	var texture := Art.mechanic_texture(str(profile.density_source))
	if texture==null: return
	var age := float(effect.age)
	var t := clampf(age/maxf(.001,float(effect.get("mist_life",effect.life))),0,1)
	var birth := smoothstep(0.0,minf(.022,float(effect.life)*.15),age)
	var strength := birth*pow(1-t,1.25)*minf(.72,float(profile.smoke_gain)*1.8)
	if effect.kind=="echo": strength*=.35
	if strength<.001: return
	var world := host.get_global_transform()
	var at: Vector2=world*Vector2(effect.p)-Vector2(0,float(effect.get("height",0)))
	var aim := world.basis_xform(Vector2(effect.aim)).normalized()
	var r := float(effect.radius)
	var role := str(effect.get("art_role",""))
	var tint := Color(effect.color).lerp(Color("d3dae2"),.18)
	tint.a=strength
	var spread := float(profile.spread)
	var drift := 1-pow(1-t,2)
	if effect.kind in ["beam","chain"]:
		var start := world*Vector2(effect.beam_start_local) if effect.has("beam_start_local") else at-Vector2(0,24)
		var end := world*(Vector2(effect.p)+Vector2(effect.aim)*r)-Vector2(0,float(effect.get("height",0))+24)
		var delta := end-start
		stamp(texture,(start+end)*.5,Vector2(delta.length(),float(effect.get("beam_width",20))*(1.1+drift*.5)),delta.angle(),tint)
		return
	if effect.has("socket_local") and role not in ["motion_spin","motion_heavy_spin","motion_quake","motion_hammer_spin"]:
		var tip: Vector2=world*Vector2(effect.socket_local)
		var grip: Vector2=world*Vector2(effect.get("socket_grip",effect.socket_local))
		at=tip.lerp(grip,.35)
		if effect.has("socket_aim"): aim=Vector2(effect.socket_aim).normalized()
	if role in ["motion_spin","motion_heavy_spin"]:
		# Staggered open folds move around the body; never draw the hit-radius ring.
		for layer in int(profile.attack.layers):
			var a := aim.angle()+float(effect.reverse)*(drift*TAU-layer*1.7)
			var center := at+Vector2.from_angle(a)*r*.38
			var c := Color(tint,tint.a*(1.0-layer*.22))
			stamp(texture,center,Vector2(r*(.9+spread*.35),r*.65),a+PI*.5,c)
	elif role in ["motion_quake","motion_hammer_spin"] or effect.kind=="detonation":
		var ground := at+aim*r*.08
		var size := Vector2(r*(1.0+spread*.4),r*(.55+drift*.25))
		stamp(texture,ground-Vector2(0,r*.12*drift),size,0,tint)
	elif profile.motion=="thrust" or effect.kind=="lance":
		var length := minf(300,r*1.65)
		stamp(texture,at-aim*length*.18,Vector2(length,maxf(12,r*.23)),aim.angle(),tint)
	elif effect.kind in ["muzzle","cast"]:
		stamp(texture,at+aim*r*.22+Vector2(0,-r*.2*drift),Vector2(r*1.6,r*(.85+drift*.35)),aim.angle(),tint)
	else:
		var angle := aim.angle()+float(profile.shear)*.3
		var size := Vector2(r*(1.1+spread*.40),r*(.62+spread*.22))
		stamp(texture,at+aim*r*.12, size, angle,tint)
		if int(profile.attack.layers)>=2:
			stamp(texture,at-aim*r*.15+aim.orthogonal()*r*.10*float(effect.reverse),size*.72,angle-.18*float(effect.reverse),Color(tint,tint.a*.42))
