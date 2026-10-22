extends RefCounted
## Actual curved artwork keeps its shape; one affine placement aligns hand and tip.
const SHADER=preload("res://resources/weapon_actual_shape.gdshader")
var row: Dictionary={}
var material: ShaderMaterial
var action := "art"

static func available(weapon: int) -> bool:
	return FileAccess.file_exists(preload("res://scripts/weapon_batch_art.gd").folder(weapon)+"shapes.json")

func setup(weapon: int,selected: String,source: String="") -> void:
	action=selected
	var document: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preload("res://scripts/weapon_batch_art.gd").folder(weapon)+"shapes.json"))
	row=document.clips.get(source,document.clips[selected]) if not source.is_empty() else document.clips[selected]
	material=ShaderMaterial.new(); material.shader=SHADER
	material.set_shader_parameter("atlas",load(str(row.file)))
	var rects := PackedVector4Array(); var limits := PackedVector2Array()
	for r in row.frame_rects: rects.append(Vector4(r[0],r[1],r[2],r[3]))
	for r in row.frame_bounds: limits.append(Vector2(r[0],r[1]))
	material.set_shader_parameter("frame_rects",rects)
	material.set_shader_parameter("frame_bounds",limits)
	material.set_shader_parameter("canvas_aspect",float(row.canvas_aspect))
	material.set_shader_parameter("pivot",Vector2(row.pivot[0],row.pivot[1]))
	material.set_shader_parameter("contact",Vector2(row.contact[0],row.contact[1]))
	material.set_shader_parameter("reveal_mode",int(row.get("reveal_mode",0)))
	material.set_shader_parameter("face_density",.40 if weapon==612 else 1.0)
	material.set_shader_parameter("coverage_power",.70 if weapon==614 else 1.0)

func draw(builder,pivot_world: Vector3,tip_world: Vector3,camera: Camera3D,age: float,active: float,contact_age: float=-1,cross_gain: float=1.0) -> void:
	if age<=0: return
	var since_peak := maxf(0,age-active)
	if contact_age>=0: since_peak=maxf(0,age-contact_age)
	var tail := .19 if action=="normal" else .29 if action=="heavy" else .34
	var alpha := smoothstep(0,.010,age)*(1-smoothstep(tail*.60,tail,since_peak))
	if alpha<=.001: return
	var stage: float=clampf(age/maxf(.01,active),0,1)
	if since_peak>.025: stage=1+clampf((since_peak-.025)/maxf(.01,tail-.025),0,1)*2
	material.set_shader_parameter("phase",stage)
	material.set_shader_parameter("reveal",1-pow(1-clampf(age/maxf(.01,active),0,1),2.6))
	material.set_shader_parameter("tail_start",smoothstep(.10,tail,since_peak)*.55)
	var aspect := float(row.canvas_aspect)
	var a := Vector2(float(row.pivot[0]),-float(row.pivot[1])/aspect)
	var b := Vector2(float(row.contact[0]),-float(row.contact[1])/aspect)
	var d := b-a
	var normal := camera.global_basis.z if camera else Vector3.FORWARD
	var world_direction := tip_world-pivot_world
	world_direction-=normal*world_direction.dot(normal)
	var distance := world_direction.length()
	if distance<.12: return
	var axis := world_direction/distance
	var cross := normal.cross(axis).normalized()*cross_gain
	var along := d.normalized()
	var right := axis*along.x-cross*along.y
	var up := axis*along.y+cross*along.x
	var scale := distance/d.length()
	var top_left := pivot_world+right*(-a.x)*scale+up*(-a.y)*scale
	var top_right := top_left+right*scale
	var bottom_left := top_left-up*scale/aspect
	var bottom_right := top_right-up*scale/aspect
	builder.quad(top_left,bottom_left,top_right,bottom_right,Color(1,1,1,alpha))
