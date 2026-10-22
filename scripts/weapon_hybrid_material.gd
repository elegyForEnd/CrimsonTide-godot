extends RefCounted
const Art=preload("res://scripts/weapon_image_art.gd")
const SHADER=preload("res://resources/weapon_hybrid_surface.gdshader")
const BASE="res://assets/combat/weapon-hybrid-v7/"
static var manifest: Dictionary={}
static var textures: Dictionary={}

static func impact_key(profile: Dictionary) -> String:
	var key := material_key(profile)
	if key=="sun" and int(profile.get("canonical",-1)) in [612,614]: key="stone"
	return key+"-impact" if key in ["stone","frost","tide","heat"] else ""

static func impact(profile: Dictionary) -> ShaderMaterial:
	if manifest.is_empty(): material(profile)
	var key := impact_key(profile)
	if not manifest.has(key): return null
	var row: Dictionary=manifest[key]
	var texture: Texture2D=load(str(row.file)) if ResourceLoader.exists(str(row.file)) else null
	if texture==null: return missing_art_material()
	var mat := ShaderMaterial.new(); mat.shader=preload("res://resources/weapon_crystal_painted.gdshader")
	mat.set_shader_parameter("painted_texture",texture)
	var uv: Array=row.uv
	mat.set_shader_parameter("painted_rect",Vector4(uv[0],uv[1],uv[2],uv[3]))
	mat.set_shader_parameter("ribbon_mode",false)
	if int(profile.get("canonical",-1)) in [612,614]:
		mat.set_shader_parameter("retint_color",Color("ffb851"))
		mat.set_shader_parameter("retint_amount",.85)
	return mat

static func smoke(profile: Dictionary) -> ShaderMaterial:
	var source := str(profile.get("smoke_source","density_dust_v3"))
	var key := material_key(profile)
	if key=="frost": source="density_cold_v3"
	elif key=="heat": source="density_heat_v3"
	elif key=="tide": source="density_wind_v3"
	var texture: Texture2D=Art.mechanic_texture(source)
	if texture==null: texture=Art.mechanic_texture("density_wind_v3"); source="density_wind_v3"
	var rect := Art.mechanic_ink(source); var size := texture.get_size()
	var mat := ShaderMaterial.new(); mat.shader=preload("res://resources/weapon_hybrid_smoke.gdshader")
	mat.set_shader_parameter("density",texture)
	mat.set_shader_parameter("density_rect",Vector4(rect.position.x/size.x,rect.position.y/size.y,rect.size.x/size.x,rect.size.y/size.y))
	return mat

static func smoke_tint(profile: Dictionary) -> Color:
	return {"blood":Color("662937"),"frost":Color("a6cddd"),"tide":Color("94c3ce"),"heat":Color("725148"),"soul":Color("8e78a8"),"void":Color("594a72"),"sun":Color("b2a080"),"bell":Color("a7b9ae")}.get(material_key(profile),Color("9b9b9e"))

static func payload(source: String) -> ShaderMaterial:
	var texture: Texture2D=Art.mechanic_texture(source)
	if texture==null: return null
	var rect := Art.mechanic_ink(source)
	var size := texture.get_size()
	var mat := ShaderMaterial.new()
	mat.shader=preload("res://resources/weapon_crystal_painted.gdshader")
	mat.set_shader_parameter("painted_texture",texture)
	mat.set_shader_parameter("painted_rect",Vector4(rect.position.x/size.x,rect.position.y/size.y,rect.size.x/size.x,rect.size.y/size.y))
	mat.set_shader_parameter("ribbon_mode",false)
	return mat

static func material_key(profile: Dictionary) -> String:
	var weapon := int(profile.get("canonical",profile.get("index",-1)))
	if weapon in [605,615,620,627,635,637,642]: return "heat"
	if weapon==614: return "sun"
	if weapon in [611,630,644]: return "void"
	return str(profile.material)

static func material(profile: Dictionary,ribbon: bool=true,solid: bool=false) -> ShaderMaterial:
	if manifest.is_empty() and FileAccess.file_exists(BASE+"materials.json"):
		manifest=JSON.parse_string(FileAccess.get_file_as_string(BASE+"materials.json"))
	var key := material_key(profile)
	var source := str(profile.get("blade_source","weapon_%d_surface_v5" % int(profile.get("canonical",600))))
	var identity: Texture2D=Art.mechanic_texture(source)
	# 原画缺件（刚 pull 还没导入）时不能再往下走：identity 是 null，`get_size()`
	# 会直接抛错，而把 null 交给 shader 又会画出整片白块。给一层透明材质兜底。
	if identity==null: return missing_art_material()
	var rect := Art.mechanic_ink(source)
	var size := identity.get_size()
	var row: Dictionary=manifest.get(key,{})
	var detail_path := str(row.get("file",BASE+"metal.png"))
	if not textures.has(detail_path): textures[detail_path]=load(detail_path) if ResourceLoader.exists(detail_path) else identity
	var mat := ShaderMaterial.new(); mat.shader=SHADER
	mat.set_shader_parameter("identity_texture",identity)
	mat.set_shader_parameter("painted_detail",textures[detail_path])
	mat.set_shader_parameter("identity_rect",Vector4(rect.position.x/size.x,rect.position.y/size.y,rect.size.x/size.x,rect.size.y/size.y))
	var uv: Array=row.get("uv",[0,0,1,1])
	mat.set_shader_parameter("detail_rect",Vector4(uv[0],uv[1],uv[2],uv[3]))
	mat.set_shader_parameter("ribbon_mode",ribbon)
	mat.set_shader_parameter("solid_mode",solid)
	mat.set_shader_parameter("energy_gain",1.35 if key in ["storm","star","sun","heat"] else .72 if key in ["stone","void"] else 1.0)
	return mat

## 素材缺件时的兜底：用同一套 painted shader + 一张全透明贴图，渲染结果等于"什么都不画"。
## 为什么不是直接返回 null：调用方会把材质直接塞给 `material_override` /
## `body_material` 并在后面调 `set_shader_parameter()`，null 会二次崩；而把 null 贴图
## 交给 shader 会因为 uniform 默认白图画出整片白块（2026-10-22 用户报"特效变成白色方块"）。
static var _blank_texture: ImageTexture
static func missing_art_material() -> ShaderMaterial:
	if _blank_texture==null:
		var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
		image.fill(Color(1,1,1,0))
		_blank_texture=ImageTexture.create_from_image(image)
	var mat := ShaderMaterial.new()
	mat.shader=preload("res://resources/weapon_crystal_painted.gdshader")
	mat.set_shader_parameter("painted_texture",_blank_texture)
	mat.set_shader_parameter("ribbon_mode",false)
	return mat
