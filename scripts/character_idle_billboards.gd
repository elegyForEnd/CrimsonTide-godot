extends Node3D
const Idle = preload("res://scripts/character_idle.gd")
var pool: Dictionary = {}
var shadows: Dictionary = {}

func begin() -> void:
	for node: MeshInstance3D in pool.values(): node.hide()
	for node: MeshInstance3D in shadows.values(): node.hide()

func submit(id: int, data: Dictionary, at: Vector3, camera: Camera3D, facing: float, tint: Color = Color.WHITE, shadow_texture: Texture2D = null) -> void:
	if not pool.has(id):
		var node := MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		mat.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
		node.material_override=mat
		add_child(node); pool[id]=node
	var node: MeshInstance3D=pool[id]
	node.mesh=Idle.mesh(data,true,camera.global_basis.y.dot(Vector3.UP),facing)
	node.material_override.albedo_texture=data.texture
	node.material_override.albedo_color=tint
	node.position=at
	node.show()
	if shadow_texture!=null:
		if not shadows.has(id):
			var shadow := MeshInstance3D.new()
			var plane := PlaneMesh.new(); plane.size=Vector2(.62,.40)
			shadow.mesh=plane
			var mat := StandardMaterial3D.new()
			mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_texture=shadow_texture; mat.albedo_color=Color(0,0,0,.35)
			shadow.material_override=mat
			add_child(shadow); shadows[id]=shadow
		shadows[id].position=at-Vector3(0,.01,0)
		shadows[id].show()
