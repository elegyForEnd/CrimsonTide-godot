extends RefCounted
## Bounded mesh builder shared by the world-space release layers.
var vertices := PackedVector3Array()
var uvs := PackedVector2Array()
var texture_weights := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()

func quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color,from_uv: float=0.0,to_uv: float=1.0,tail_alpha: float=-1.0,texture_weight: float=0.0) -> void:
	var start := vertices.size()
	vertices.append_array(PackedVector3Array([a,b,c,d]))
	uvs.append_array(PackedVector2Array([Vector2(from_uv,0),Vector2(from_uv,1),Vector2(to_uv,0),Vector2(to_uv,1)]))
	for i in 4: texture_weights.append(Vector2(texture_weight,0))
	var old := Color(color,color.a if tail_alpha<0 else tail_alpha)
	colors.append_array(PackedColorArray([old,old,color,color]))
	indices.append_array(PackedInt32Array([start,start+1,start+2,start+1,start+3,start+2]))

func commit(target: MeshInstance3D) -> void:
	if vertices.is_empty(): target.hide(); return
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_TEX_UV2]=texture_weights
	arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_INDEX]=indices
	# Build the next mesh completely before replacing the visible instance.
	# Clearing the attached mesh briefly invalidates its renderer RID on GLES.
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	target.mesh=mesh; target.show()
