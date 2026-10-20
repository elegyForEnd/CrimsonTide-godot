extends RefCounted
## Per-weapon originals derived from each complete action storyboard.
const IDS := [607,608,612,614,617]
const BASE := "res://assets/combat/weapon-batch-01/"
const ALL_BASE := "res://assets/combat/weapon-reference-v2/"
const SHADER=preload("res://resources/weapon_606_reference.gdshader")
var index := 607
static var manifests: Dictionary={}
static var textures: Dictionary={}

static func enabled(weapon: int) -> bool:
	return FileAccess.file_exists(folder(weapon)+"manifest.json")

static func folder(weapon: int) -> String:
	return (BASE if weapon in IDS else ALL_BASE)+str(weapon)+"/"

static func of(weapon: int):
	var item=load("res://scripts/weapon_batch_art.gd").new()
	item.index=weapon
	return item

func metadata(layer: String) -> Dictionary:
	if not manifests.has(index):
		var path := folder(index)+"manifest.json"
		manifests[index]=JSON.parse_string(FileAccess.get_file_as_string(path)).layers if FileAccess.file_exists(path) else {}
	return manifests[index].get(layer,{})

func aspect(layer: String) -> float:
	return float(metadata(layer).get("aspect",1.0))

func material(layer: String) -> ShaderMaterial:
	var row := metadata(layer)
	if row.is_empty(): return null
	var path := str(row.file)
	if not textures.has(path): textures[path]=load(path)
	var mat := ShaderMaterial.new(); mat.shader=SHADER
	mat.set_shader_parameter("painted_texture",textures[path])
	var uv: Array=row.uv
	mat.set_shader_parameter("painted_rect",Vector4(uv[0],uv[1],uv[2],uv[3]))
	mat.set_shader_parameter("soft_layer",layer=="mist")
	mat.set_shader_parameter("coverage_power",.60 if layer in ["impact","shard"] and index in [612,614,617] else 1.0)
	return mat
