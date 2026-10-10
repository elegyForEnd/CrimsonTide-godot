extends RefCounted
## Architectural floors have their own PBR palette, never the soil/road shader.
const FLOOR=preload("res://resources/story_interior_floor.gdshader")
const BASE := "res://assets/story/environment/pbr/"
static var cache: Dictionary={}
static func architectural(region) -> bool:
	return region.indoor and (region.act>=2 or region.layout!="mine")
static func profile(layout: String) -> Dictionary:
	match layout:
		"crypt": return {"base":"crypt_slab","scale":.42,"tint":Color("eeeae1"),"dampness":.12,"zoning":0}
		"library": return {"base":"timber","scale":.48,"tint":Color("b9ada0"),"dampness":0.0,"zoning":0}
		"chapel","cathedral": return {"base":"interior_stone","scale":.55,"tint":Color("d4d5cf"),"dampness":0.0,"zoning":1}
		"castle": return {"base":"interior_stone","scale":.55,"tint":Color("d0d4d4"),"dampness":0.0,"zoning":2}
		_: return {"base":"interior_stone","scale":.55,"tint":Color("c5cbcf"),"dampness":.04,"zoning":0}
static func material(region) -> ShaderMaterial:
	var key := "%d:%d:%s" % [region.act,region.stage,region.layout]
	if cache.has(key): return cache[key]
	var settings := profile(region.layout)
	if region.act>=2:
		settings={"base":"a%d_floor" % region.act,"scale":.45,"tint":Color("eee9e1"),"dampness":.08 if region.act==5 else 0.0,"zoning":0}
		if region.act==3 and region.stage==3: settings.base="a3_wall"
	var mat := ShaderMaterial.new(); mat.shader=FLOOR
	for channel in ["albedo","normal","orm"]:
		mat.set_shader_parameter("base_"+channel,load(BASE+settings.base+"_"+channel+".png"))
		mat.set_shader_parameter("trim_"+channel,load(BASE+("a%d_floor" % region.act if region.act>=2 else "ceremonial_tile")+"_"+channel+".png"))
	mat.set_shader_parameter("floor_tint",settings.tint)
	mat.set_shader_parameter("base_scale",settings.scale)
	mat.set_shader_parameter("trim_scale",.50)
	mat.set_shader_parameter("dampness",settings.dampness)
	mat.set_shader_parameter("zoning",settings.zoning)
	mat.set_shader_parameter("region_origin",region.origin*.01)
	mat.set_shader_parameter("centre_x",region.extent.x*.005)
	mat.set_meta("floor_role",settings.base)
	cache[key]=mat
	return mat
