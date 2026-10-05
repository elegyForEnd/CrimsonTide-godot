extends MultiMeshInstance2D
## Two original 64-segment circles per particle, instanced in one additive pass.
const SHADER=preload("res://resources/particle_glow_batch.gdshader")
static var circle_mesh: ArrayMesh
var buffer := PackedFloat32Array()
var capacity := 1400
func _ready() -> void:
	if circle_mesh==null:
		var vertices := PackedVector3Array()
		var uv := PackedVector2Array()
		var indices := PackedInt32Array()
		for circle in 2:
			var base := vertices.size()
			for i in 65:
				var angle := i*TAU/64.0
				vertices.append(Vector3(cos(angle),sin(angle),0))
				uv.append(Vector2(circle,0))
			vertices.append(Vector3.ZERO); uv.append(Vector2(circle,0))
			for i in 64: indices.append_array(PackedInt32Array([base+65,base+i,base+i+1]))
		var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_INDEX]=indices
		circle_mesh=ArrayMesh.new(); circle_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	multimesh=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_2D
	multimesh.use_colors=true; multimesh.use_custom_data=true
	multimesh.mesh=circle_mesh
	multimesh.instance_count=capacity; multimesh.visible_instance_count=0
	buffer.resize(capacity*16)
	var shader_material := ShaderMaterial.new(); shader_material.shader=SHADER
	material=shader_material
func submit(items: Array[Dictionary], inverse: Transform2D) -> void:
	var count := 0
	for item in items:
		if item.style in ["dust","stone","feather","petal"]: continue
		var pose: Transform2D=inverse*item.pose
		var color: Color=item.color
		var offset := count*16
		buffer[offset]=pose.x.x; buffer[offset+1]=pose.y.x; buffer[offset+2]=0; buffer[offset+3]=pose.origin.x
		buffer[offset+4]=pose.x.y; buffer[offset+5]=pose.y.y; buffer[offset+6]=0; buffer[offset+7]=pose.origin.y
		buffer[offset+8]=color.r; buffer[offset+9]=color.g; buffer[offset+10]=color.b; buffer[offset+11]=color.a
		buffer[offset+12]=item.size
		count+=1
	multimesh.visible_instance_count=count
	if count==0: return
	var inherited_tint := Color.WHITE
	var ancestor: CanvasItem=self
	while ancestor:
		inherited_tint*=ancestor.modulate
		if ancestor.is_set_as_top_level(): break
		ancestor=ancestor.get_parent() as CanvasItem
	material.set_shader_parameter("inherited_tint",inherited_tint)
	multimesh.buffer=buffer
