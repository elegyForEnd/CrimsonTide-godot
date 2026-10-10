extends SceneTree
const Region=preload("res://scripts/story_region.gd")
const EnvironmentBuilder=preload("res://scripts/story_environment.gd")
var checks := 0
var failures := 0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
func _initialize() -> void:
	var builder=EnvironmentBuilder.new()
	var cell := Rect2(3200,1350,100,100); var hole := Rect2(3230,1390,300,420)
	var pieces: Array[Rect2]=builder.cut_rectangles([cell],hole)
	var area := 0.0
	for piece in pieces:
		check(not piece.intersection(hole).has_area(),"terrain does not cover stair footprint")
		area+=piece.get_area()
	check(is_equal_approx(area,cell.get_area()-cell.intersection(hole).get_area()),"clipping preserves all non-overlapping ground")
	var region=Region.new(); region.build(1,1,"field",false)
	var small_trees := 0
	for prop in region.props:
		if (prop.key.begins_with("nature/tree") or "tree_dead" in prop.key) and prop.size.y<=450:
			small_trees+=1; check(not prop.blocking,"small decorative tree is not solid")
	check(small_trees>20,"actual field contains non-blocking trees")
	for stair in region.stairs:
		check(region.height_at(stair.terrace.get_center())>120,"terrace logical elevation preserved")
		check(region.base_height_at(stair.terrace.get_center())<stair.top,"base terrain is separate from raised platform")
	# Inspect the actual packed terrain, rather than only its clipping helper.
	if ResourceLoader.exists("res://scenes/story/opening-1.scn"):
		var scene: Node3D=load("res://scenes/story/opening-1.scn").instantiate()
		var origin := Vector2(-1300,2500)
		var overlapping := 0
		for mesh in scene.find_children("*","MeshInstance3D",true,false):
			if not mesh.material_override is ShaderMaterial or mesh.material_override.shader!=builder.GROUND: continue
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array=mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				if indices.is_empty():
					for i in vertices.size(): indices.append(i)
				for i in range(0,indices.size(),3):
					var center: Vector3=(vertices[indices[i]]+vertices[indices[i+1]]+vertices[indices[i+2]])/3
					var p := Vector2(center.x,center.z)*100-origin
					for stair in region.stairs:
						if stair.terrace.grow(-.01).has_point(p) or stair.rect.grow(-.01).has_point(p): overlapping+=1
		check(overlapping==0,"packed terrain has no triangles under the platform or stairs")
		scene.free()
	print("surface overlap: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
