@tool
extends MultiMeshInstance3D
## CPU-authoritative transforms survive headless packing (Dummy RIDs do not).
@export var source_mesh: Mesh
@export var source_transforms: Array[Transform3D]=[]
func _ready() -> void:
	if source_mesh==null or source_transforms.is_empty(): return
	var fresh := MultiMesh.new(); fresh.transform_format=MultiMesh.TRANSFORM_3D
	fresh.mesh=source_mesh; fresh.instance_count=source_transforms.size()
	var bounds := AABB(); var first := true
	for i in source_transforms.size():
		fresh.set_instance_transform(i,source_transforms[i])
		var box: AABB=source_transforms[i]*source_mesh.get_aabb()
		bounds=box if first else bounds.merge(box); first=false
	fresh.custom_aabb=bounds; multimesh=fresh
func prepare_capture() -> void:
	# Never serialize the renderer's instance buffer in a headless process.
	var empty := MultiMesh.new(); empty.transform_format=MultiMesh.TRANSFORM_3D
	empty.mesh=source_mesh; multimesh=empty
