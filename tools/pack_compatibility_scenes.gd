extends SceneTree
func _initialize() -> void:
	var paths: Array[String]=[]
	for stage in [0,1,2,3,4,7,9]: paths.append("res://scenes/story/opening-%d" % stage)
	for act in range(2,7):
		for stage in range(9):
			var path := "res://scenes/story/act%d-%d" % [act,stage]
			if FileAccess.file_exists(path+".tscn"): paths.append(path)
	for path in paths:
		var node: Node3D=load(path+".tscn").instantiate()
		for fog in node.find_children("*","FogVolume",true,false): fog.free()
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			mesh.set_instance_shader_parameter("reveal",null)
			for i in mesh.mesh.get_surface_count():
				var mat: Material=mesh.get_active_material(i)
				if mat is ShaderMaterial and "instance uniform float reveal" in mat.shader.code:
					var converted: ShaderMaterial=mat.duplicate(); var shader := Shader.new()
					shader.code=mat.shader.code.replace("instance uniform float reveal","uniform float reveal")
					converted.shader=shader; mesh.set_surface_override_material(i,converted)
		for multi in node.find_children("*","MultiMeshInstance3D",true,false):
			if multi.material_override is ShaderMaterial:
				var mat: ShaderMaterial=multi.material_override.duplicate(); var shader := Shader.new()
				shader.code=mat.shader.code.replace("instance uniform float reveal","uniform float reveal"); mat.shader=shader; multi.material_override=mat
		var packed := PackedScene.new(); packed.pack(node)
		ResourceSaver.save(packed,path+"-compat.scn",ResourceSaver.FLAG_COMPRESS); node.free()
	quit()
