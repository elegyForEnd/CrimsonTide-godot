extends RefCounted
## Dedicated 606 artwork; no old weapon design or shared material selection.
const BASE="res://assets/combat/weapon-606-action-v1/"
const SHADER=preload("res://resources/weapon_606_reference.gdshader")
static var layers: Dictionary={}
static var textures: Dictionary={}

static func metadata(layer: String) -> Dictionary:
	if layers.is_empty() and FileAccess.file_exists(BASE+"manifest.json"):
		layers=JSON.parse_string(FileAccess.get_file_as_string(BASE+"manifest.json")).layers
	return layers.get(layer,{})

static func aspect(layer: String) -> float:
	return float(metadata(layer).get("aspect",1.0))

static func material(layer: String) -> ShaderMaterial:
	var row := metadata(layer)
	if row.is_empty(): return null
	if not textures.has(layer): textures[layer]=load(str(row.file))
	var mat := ShaderMaterial.new(); mat.shader=SHADER
	mat.set_shader_parameter("painted_texture",textures[layer])
	var uv: Array=row.uv
	mat.set_shader_parameter("painted_rect",Vector4(uv[0],uv[1],uv[2],uv[3]))
	mat.set_shader_parameter("soft_layer",layer=="mist")
	return mat

