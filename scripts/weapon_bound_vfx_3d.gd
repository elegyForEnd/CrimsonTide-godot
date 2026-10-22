extends RefCounted
## Original painted release placed once in the attack area, oriented to mouse aim.
## Its animated mesh and smoke share this captured footprint; no sprite following.
const Art=preload("res://scripts/weapon_image_art.gd")
const Builder=preload("res://scripts/weapon_vfx_mesh_3d.gd")
const MAX_HISTORY=24
var host: Node3D
var painting: MeshInstance3D
var trail: MeshInstance3D
var material: ShaderMaterial
var source := ""
var history: Array=[]
var contact := Vector2.ZERO
var aspect := Vector2.ONE
var center := Vector3.ZERO
var axis := Vector3.RIGHT
var across := Vector3.UP
var extent := 1.0
var attached := false
var weapon_length := .6

func setup(effect: Node3D) -> void:
	host=effect
	var index := int(host.data.weapon_index)
	var stage := clampi(int(host.data.get("combo",0)),0,2)
	# Restore the per-weapon colored originals, including authored combo variants.
	source="weapon_%d_%s" % [Art.canonical(index),["release","return","finisher"][stage]]
	if not ResourceLoader.exists(Art.BASE+source+".png"): source="weapon_%d_release" % Art.canonical(index)
	if host.action=="heavy": source=Art.charged_source(index,"release",source)
	elif host.action=="art": source=Art.release_source(index,str(host.profile.role),stage,true)
	var texture := Art.mechanic_texture(source)
	if texture==null: return
	var ink := Art.mechanic_ink(source)
	aspect=ink.size/maxf(ink.size.x,ink.size.y)
	contact=Art.mechanic_contact(str(host.profile.role),aspect,source)
	material=ShaderMaterial.new(); material.shader=preload("res://resources/weapon_painted_release_3d.gdshader")
	material.set_shader_parameter("painting",texture)
	material.set_shader_parameter("ink_origin",ink.position/texture.get_size())
	material.set_shader_parameter("ink_size",ink.size/texture.get_size())
	painting=host.ribbon; painting.material_override=material
	trail=host.mesh_node(host.body_material)
	painting.hide(); trail.hide()
	var camera: Camera3D=host.camera
	var global_origin: Vector3=host.to_global(host.origin)
	var global_forward: Vector3=host.to_global(host.origin+host.aim)
	var direction: Vector2=(camera.unproject_position(global_forward)-camera.unproject_position(global_origin)).normalized() if camera else Vector2.RIGHT
	if direction.length_squared()<.01: direction=Vector2.RIGHT
	var right: Vector3=camera.global_basis.x if camera else Vector3.RIGHT
	var up: Vector3=camera.global_basis.y if camera else Vector3.UP
	var inverse: Basis=host.global_transform.basis.inverse()
	axis=inverse*(right*direction.x-up*direction.y)
	across=inverse*(right*direction.y+up*direction.x)
	# Reach selects the footprint once, within a stable size tier per action.
	extent=clampf(float(host.reach)*.80,.80,1.30) if host.action=="normal" else clampf(float(host.reach)*.82,1.15,1.80) if host.action=="heavy" else clampf(float(host.reach)*.85,1.45,2.10)
	center=host.origin+host.aim*minf(float(host.reach)*.48,extent*.58)
	weapon_length=extent*.55
	attached=true

func trajectory(u: float) -> Vector3:
	if host.motion in ["thrust","recoil"]:
		return center+axis*extent*(u-.5)*.85+across*extent*sin(u*PI)*float(host.profile.shear)*.035
	if host.motion in ["chop","crosscut"]:
		return center+axis*extent*((u-.5)*.35+sin(u*PI)*float(host.profile.shear)*.09)+across*extent*(.5-u)*(.68+float(host.profile.spread)*.08)
	var angle := lerpf(-1.3,1.3,u)+sin(u*PI)*float(host.profile.shear)*.16
	var radius := .46+u*.04+sin(u*PI)*float(host.profile.spread)*.05
	return center+axis*extent*(cos(angle)*radius-.14)+across*extent*sin(angle)*.42

func smoke_point(u: float) -> Vector3:
	return trajectory(u)

func rebuild() -> void:
	if painting==null or not attached: return
	var age: float=host.age
	var active: float=host.emission_time
	var tail: float=host.tail_time
	var fade := 1.0-smoothstep(active,active+tail,age)
	var x := axis*aspect.x*extent*.5
	var y := across*aspect.y*extent*.5
	var body=Builder.new()
	body.quad(center-x-y,center-x+y,center+x-y,center+x+y,Color(host.color,.88 if host.action=="normal" else .96))
	body.commit(painting)
	material.set_shader_parameter("reveal",smoothstep(0,active*.45,age))
	material.set_shader_parameter("fade",fade)
	material.set_shader_parameter("phase",age)
	painting.visible=fade>.005
	history.clear()
	var head := minf(1.0,age/active)
	for i in MAX_HISTORY:
		var u := head*float(i)/(MAX_HISTORY-1)
		var tip := trajectory(u)
		history.append({"tip":tip,"grip":tip-across*extent*.10,"at":u*active})
	var ribbon=Builder.new()
	for i in range(1,history.size()):
		var a: Dictionary=history[i-1]; var b: Dictionary=history[i]
		var old := pow(maxf(0,1-(age-float(a.at))/(tail+.12)),1.2)
		var fresh := pow(maxf(0,1-(age-float(b.at))/(tail+.12)),1.2)
		if fresh<=0: continue
		if Vector3(a.tip).distance_to(b.tip)<.004: continue
		var start: Vector3=Vector3(a.grip).lerp(a.tip,.28)
		var end: Vector3=Vector3(b.grip).lerp(b.tip,.28)
		var outward_a := (Vector3(a.tip)-Vector3(a.grip))*.18
		var outward_b := (Vector3(b.tip)-Vector3(b.grip))*.18
		ribbon.quad(start,Vector3(a.tip)+outward_a,end,Vector3(b.tip)+outward_b,Color(host.color,fresh*.26),float(i-1)/maxi(1,history.size()-1),float(i)/maxi(1,history.size()-1),old*.26,1.0)
	ribbon.commit(trail)
