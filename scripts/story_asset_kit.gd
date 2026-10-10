extends RefCounted
## Shared original Blender meshes + offline CC0 PBR palette, story mode only.
const BASE := "res://assets/story/environment/"
const FOLIAGE = preload("res://resources/story_foliage.gdshader")
const OCCLUSION = preload("res://resources/story_occlusion.gdshader")
var scenes: Dictionary={}
var materials: Dictionary={}
var vendor_tree_mesh: Mesh
var vendor_tree_transform := Transform3D.IDENTITY
func refresh_tree(root: Node3D) -> void:
	if vendor_tree_mesh==null:
		var source: Node3D=load(BASE+"models/woodland_tree.glb").instantiate()
		var mesh: MeshInstance3D=source.find_children("*","MeshInstance3D",true,false)[0]
		vendor_tree_mesh=mesh.mesh; vendor_tree_transform=mesh.transform; source.free()
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		mesh.mesh=vendor_tree_mesh; mesh.transform=vendor_tree_transform; mesh.lod_bias=4.0
		for i in mesh.mesh.get_surface_count(): mesh.set_surface_override_material(i,null)
	prepare_reveal(root)

func pbr(name: String, tint: Color = Color.WHITE, scale: float = 1.0) -> StandardMaterial3D:
	var key := name+str(tint)+str(scale)
	if materials.has(key): return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color=tint
	mat.albedo_texture=load(BASE+"pbr/"+name+"_albedo.png")
	mat.normal_enabled=true; mat.normal_texture=load(BASE+"pbr/"+name+"_normal.png")
	mat.normal_scale=.72
	mat.ao_enabled=true; mat.ao_texture=load(BASE+"pbr/"+name+"_orm.png")
	mat.ao_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness_texture=mat.ao_texture
	mat.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.roughness=.95
	mat.metallic=1.0; mat.metallic_texture=mat.ao_texture
	mat.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_scale=Vector3.ONE*scale
	materials[key]=mat
	return mat

func surface(name: String) -> Material:
	if materials.has(name): return materials[name]
	var mat: Material
	match name:
		"Masonry": mat=pbr("masonry",Color("b7bbbf"))
		"Trim": mat=pbr("masonry",Color("e2d7bc"),1.4)
		"Timber": mat=pbr("timber",Color("a3a19c"),.85)
		"Bark": mat=pbr("bark",Color("a3a19c"),.65)
		"Slate": mat=pbr("slate",Color("64758d"),.8); mat.normal_scale=.25
		"Rock":
			mat=pbr("rock",Color("a6aeb3"),.65)
			mat.uv1_triplanar=true
		"Iron": mat=pbr("iron",Color("9e9fa1"))
		"Cloth": mat=pbr("cloth",Color("713141"))
		"Linen": mat=pbr("cloth",Color("dad1b4"))
		"Paper":
			mat=StandardMaterial3D.new(); mat.albedo_color=Color("b6a478"); mat.roughness=.96
		"Leaf":
			mat=ShaderMaterial.new(); mat.shader=FOLIAGE
		_:
			mat=StandardMaterial3D.new()
			mat.albedo_color={"Iron":Color("343a43"),"Gold":Color("9e7945"),"Glass":Color("eeae61"),"Cloth":Color("6b2438"),"Dark":Color("101822")}.get(name,Color("7c7c75"))
			mat.roughness=.88
			if name in ["Iron","Gold"]: mat.metallic=.65; mat.roughness=.52
			if name=="Glass": mat.emission_enabled=true; mat.emission=Color("e4913f"); mat.emission_energy_multiplier=.7
	materials[name]=mat
	return mat

func instance(model: String, parent: Node3D, at: Vector3, scale: Vector3 = Vector3.ONE, angle: float = 0) -> Node3D:
	if not scenes.has(model): scenes[model]=load(BASE+"models/"+model+".glb")
	var node: Node3D=scenes[model].instantiate()
	parent.add_child(node); node.position=at; node.scale=scale; node.rotation.y=angle
	if model in ["woodland_tree","woodland_fern"]:
		if model=="woodland_tree": node.set_meta("licensed_tree",true)
		return node
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var original: Material=mesh.mesh.surface_get_material(i)
			mesh.set_surface_override_material(i,surface(original.resource_name if original else "Masonry"))
	return node

func prepare_reveal(root: Node3D) -> void:
	if RenderingServer.get_current_rendering_method()=="gl_compatibility": return
	for mesh in mesh_nodes(root):
		mesh.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
		var converted := false
		for i in mesh.mesh.get_surface_count():
			var original: Material=mesh.get_active_material(i)
			if not original is StandardMaterial3D or not original.albedo_texture: continue
			var key := "reveal:"+str(original.get_instance_id())
			if not materials.has(key):
				var mat := ShaderMaterial.new(); mat.shader=OCCLUSION
				if original.cull_mode==BaseMaterial3D.CULL_DISABLED:
					if not materials.has("double_sided_reveal"):
						var shader := Shader.new(); shader.code=OCCLUSION.code.replace("depth_draw_opaque","depth_draw_opaque, cull_disabled")
						materials["double_sided_reveal"]=shader
					mat.shader=materials.double_sided_reveal
				mat.set_shader_parameter("albedo_map",original.albedo_texture)
				mat.set_shader_parameter("normal_map",original.normal_texture)
				mat.set_shader_parameter("orm_map",original.roughness_texture)
				mat.set_shader_parameter("tint",original.albedo_color)
				mat.set_shader_parameter("uv_scale",original.uv1_scale.x)
				mat.set_shader_parameter("uv_axes",Vector2(1.0,original.uv1_scale.y/maxf(.001,original.uv1_scale.x)))
				mat.set_shader_parameter("uv_offset",Vector2(original.uv1_offset.x,original.uv1_offset.y))
				mat.set_shader_parameter("alpha_cut",original.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED)
				materials[key]=mat
			mesh.set_surface_override_material(i,materials[key])
			converted=true
		# A node-level override otherwise masks all newly assigned fade surfaces.
		if converted: mesh.material_override=null

func reveal(root: Node3D, amount: float) -> void:
	root.visible=amount>.001
	if RenderingServer.get_current_rendering_method()=="gl_compatibility": return
	for mesh in mesh_nodes(root):
		var supported := false
		for i in mesh.mesh.get_surface_count():
			var mat: Material=mesh.get_active_material(i)
			if mat is ShaderMaterial and "instance uniform float reveal" in mat.shader.code: supported=true; break
		if supported: mesh.set_instance_shader_parameter("reveal",amount)

func mesh_nodes(root: Node3D) -> Array:
	var found: Array=root.find_children("*","MeshInstance3D",true,false)
	if root is MeshInstance3D: found.push_front(root)
	return found

func grass_mesh() -> Mesh:
	if not scenes.has("grass_tuft"): scenes["grass_tuft"]=load(BASE+"models/grass_tuft.glb")
	var root: Node3D=scenes.grass_tuft.instantiate()
	var mesh: Mesh=root.find_children("*","MeshInstance3D",true,false)[0].mesh
	root.free()
	return mesh

func fern_mesh() -> Mesh:
	if not scenes.has("woodland_fern"): scenes["woodland_fern"]=load(BASE+"models/woodland_fern.glb")
	var root: Node3D=scenes.woodland_fern.instantiate()
	var mesh: Mesh=root.find_children("*","MeshInstance3D",true,false)[0].mesh
	root.free(); return mesh
