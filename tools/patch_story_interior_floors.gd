extends SceneTree
## Change the authored floor materials in place; UV2/geometry/dressing survive.
const Campaign=preload("res://scripts/story_campaign.gd")
const Floors=preload("res://scripts/story_floor_palette.gd")
const GROUND=preload("res://resources/story_ground.gdshader")
func _initialize() -> void:
	var c=Campaign.new(); c.save_enabled=false; c.state=c.new_state(); c.enter(1,9)
	var path := "res://scenes/story/opening-9.tscn"
	var scene: Node3D=load(path).instantiate(); var changed := 0
	var kit=preload("res://scripts/story_asset_kit.gd").new()
	var region=c.map.regions[9]
	for mesh in scene.find_children("*","MeshInstance3D",true,false):
		var mat: Material=mesh.material_override
		var at := Vector2(mesh.position.x,mesh.position.z)*100
		var structure := false
		for stair in region.stairs:
			if stair.rect.grow(1).has_point(at) or stair.terrace.grow(1).has_point(at): structure=true
		# Generated waypoint plinths share the old masonry material, but aren't floors.
		if mat is ShaderMaterial and mat.shader==Floors.FLOOR and not structure and mesh.mesh.get_aabb().size.y>.44 and mesh.mesh.get_aabb().size.y<.46 and at.distance_to(region.waypoint)<180:
			mesh.material_override=kit.pbr("masonry",Color("bcc4ce")); changed+=1; continue
		var ground: bool=mat is ShaderMaterial and mat.shader==GROUND
		var platform: bool=mat is StandardMaterial3D and mat.albedo_texture!=null and "masonry_albedo" in mat.albedo_texture.resource_path
		if ground or (platform and structure):
			mesh.material_override=Floors.material(c.map.regions[9]); changed+=1
	var packed := PackedScene.new(); packed.pack(scene)
	var error := ResourceSaver.save(packed,path)
	print("ARCHITECTURAL_FLOORS ",changed," error=",error)
	scene.free(); quit(1 if error!=OK else 0)
