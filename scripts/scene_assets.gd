extends RefCounted
## CC0 source models are cached; each placement retains the authored mesh/UVs.
const ROOT := "res://assets/vendor/kaykit/"
const STYLE := preload("res://resources/scene_asset.gdshader")
var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"models.json"))
var templates: Dictionary={}
var bounds: Dictionary={}
var styled_materials: Dictionary={}

func _init() -> void:
	registry["nature/tree_1"]="res://assets/vendor/quaternius/NormalTree_1.fbx"
	registry["nature/tree_3"]="res://assets/vendor/quaternius/NormalTree_3.fbx"

func meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D]=[]
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children(): result.append_array(meshes(child))
	return result

func local_bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh in meshes(node):
		var pose := Transform3D.IDENTITY
		var cursor: Node=mesh
		while cursor!=node:
			if cursor is Node3D: pose=cursor.transform*pose
			cursor=cursor.get_parent()
		var box: AABB=pose*mesh.get_aabb()
		result=box if first else result.merge(box)
		first=false
	return result

func instance(key: String, tint: Color, foliage: Color) -> Node3D:
	if not templates.has(key):
		templates[key]=load(registry[key])
	var model: Node3D=templates[key].instantiate()
	if key.begins_with("nature/"):
		# These FBXs contain already Y-up vertices under a +90 degree X node.
		# Cancel that authored node conversion BEFORE measuring/scaling the model.
		# A wrapper preserves the correction when place() sets the fitted scale.
		var authored := model
		model=Node3D.new()
		model.name="UprightTree"
		model.add_child(authored)
		authored.rotation.x=-PI/2
	if not bounds.has(key): bounds[key]=local_bounds(model)
	for mesh in meshes(model):
		for surface in mesh.mesh.get_surface_count():
			var original: BaseMaterial3D=mesh.get_active_material(surface)
			var cache_key := str(original.get_instance_id())+str(tint)+str(foliage)
			if not styled_materials.has(cache_key):
				var style := ShaderMaterial.new()
				style.shader=STYLE
				var texture := original.albedo_texture
				var leaf := false
				if key.begins_with("nature/"):
					leaf=original.resource_name.to_lower().contains("leaves")
					texture=load("res://assets/vendor/quaternius/NormalTree_Leaves.png" if leaf else "res://assets/vendor/quaternius/NormalTree_Bark.png")
				style.set_shader_parameter("atlas",texture)
				style.set_shader_parameter("leaf_surface",leaf)
				style.set_shader_parameter("stone_lift",key.begins_with("dungeon/wall") or key.begins_with("dungeon/rubble"))
				style.set_shader_parameter("tint",tint)
				style.set_shader_parameter("foliage",foliage)
				styled_materials[cache_key]=style
			mesh.set_surface_override_material(surface,styled_materials[cache_key])
	return model

func place(parent: Node3D, key: String, at: Vector3, size: Vector3, tint: Color = Color.WHITE, foliage: Color = Color.WHITE, angle: float = 0.0) -> Node3D:
	var holder := Node3D.new()
	holder.name=key.replace("/","_")
	holder.set_meta("source_model",key)
	parent.add_child(holder)
	var model := instance(key,tint,foliage)
	holder.add_child(model)
	var box: AABB=bounds[key]
	# Explicit dimensions fit wall collision footprints. Zero x/z keeps proportions.
	var factor := Vector3.ONE*size.y/box.size.y
	if size.x>0: factor.x=size.x/box.size.x
	if size.z>0: factor.z=size.z/box.size.z
	model.scale=factor
	model.position=-Vector3(box.get_center().x,box.position.y,box.get_center().z)*factor
	holder.position=at
	holder.rotation.y=angle
	holder.set_meta("fitted_size",box.size*factor)
	return holder

func chest_state(holder: Node3D, opened: bool, empty: bool) -> void:
	var state := int(opened)+int(empty)*2
	if holder.get_meta("chest_state",-1)==state: return
	holder.set_meta("chest_state",state)
	# The downloaded chest exports its lid as a separate mesh at the hinge.
	var lid: Node3D=holder.find_child("*lid*",true,false)
	if lid: lid.rotation.x=deg_to_rad(-105.0) if opened else 0.0
	for mesh in meshes(holder):
		for surface in mesh.mesh.get_surface_count():
			var style: ShaderMaterial=mesh.get_surface_override_material(surface)
			var base_key := "chest_material_%d" % surface
			if not mesh.has_meta(base_key): mesh.set_meta(base_key,style)
			var base: ShaderMaterial=mesh.get_meta(base_key)
			var key := "chest:"+str(base.get_instance_id())+":"+str(empty)
			if not styled_materials.has(key):
				var variant: ShaderMaterial=base.duplicate()
				variant.set_shader_parameter("empty_amount",1.0 if empty else 0.0)
				styled_materials[key]=variant
			mesh.set_surface_override_material(surface,styled_materials[key])
