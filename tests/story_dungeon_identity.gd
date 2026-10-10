extends SceneTree
## Verify actual architectural diversity and cache identity, not renamed skins.
const Campaign=preload("res://scripts/story_campaign.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=Campaign.new(); c.state=c.new_state(); c.save_enabled=false
	var families: Dictionary={}; var footprints: Dictionary={}; var envelopes: Dictionary={}; var counts: Dictionary={}; var grades: Dictionary={}
	for act in range(1,7):
		c.enter(act,0)
		for stage in c.map.regions:
			var r=c.map.regions[stage]
			if not r.indoor: continue
			var plan: Dictionary=r.exploration_plan
			families[plan.layout_family]=true; footprints[JSON.stringify(plan.boundary)+JSON.stringify(plan.voids)]=true
			envelopes[str(r.extent)]=true; counts[plan.chambers.size()]=true; grades[JSON.stringify(plan.grade_bands)+plan.grade_axis]=true
			var outlines: Array=[plan.boundary]; outlines.append_array(plan.voids)
			check(outlines.size()==plan.edge_styles.size(),"every visible edge has an authored boundary language")
			for i in outlines.size(): check(outlines[i].size()==plan.edge_styles[i].size(),"styles refer to real footprint segments")
			if plan.layout_family in ["tower","observatory","shipyard","garden","grotto"]: check(plan.wall_fraction<.1,"open/rock typologies do not become a high-walled compound")
			if plan.layout_family in ["shipyard","cistern","pumphouse"]: check(plan.void_surface=="water" and not plan.voids.is_empty(),"basins separate walkable quays and bridges")
			if plan.layout_family=="theatre": check(plan.chambers[3].boundary.size()>=4 and plan.grade_bands.size()==2 and plan.grade_bands[0].kind=="ramp","theatre seating slope leads to a connected stage rise")
			if "--packed" not in OS.get_cmdline_user_args(): continue
			var stem := "opening-%d" % stage if act==1 else "act%d-%d" % [act,stage]
			var suffix := "-compat" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ""
			var node: Node3D=load("res://scenes/story/"+stem+suffix+".scn").instantiate()
			for gi in node.find_children("*","LightmapGI",true,false): gi.light_data=null; gi.free()
			var floor_node: Node=node.get_node("AuthoredDungeonFloor")
			check(floor_node.get_meta("layout_family","")==plan.layout_family and floor_node.get_meta("exploration_revision",0)==2,"playable cache uses the new architecture")
			var actual: Dictionary={}
			for part in node.find_children("*","Node3D",true,false):
				if part.has_meta("edge_style"): actual[part.get_meta("edge_style")]=true
			for style in plan.edge_styles[0]:
				if style not in ["none","rock"]: check(actual.has(style),"authored wall/rail/arcade/ruin exists in playable cache")
			if plan.void_surface=="water":
				var water := 0
				for mesh in node.get_node("CentralStructures").get_children():
					if mesh is MeshInstance3D and mesh.material_override is ShaderMaterial and mesh.material_override.shader==preload("res://resources/story_water.gdshader"):
						water+=1
						var bottom := INF; var top := -INF
						for v in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: bottom=minf(bottom,v.y); top=maxf(top,v.y)
						check(top-bottom<.001,"basin surface remains horizontal across regional stair profiles")
				check(water==plan.voids.size(),"real basin water sits below the floor, not over walkable ground")
			if plan.natural:
				check(node.has_node("SurroundingBedrock"),"excavation sits inside real nonwalkable bedrock")
				var mesh: MeshInstance3D=node.get_node("SurroundingBedrock")
				var arrays: Array=mesh.mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]; var indices := PackedInt32Array()
				if arrays[Mesh.ARRAY_INDEX]!=null: indices=arrays[Mesh.ARRAY_INDEX]
				if indices.is_empty():
					for i in vertices.size(): indices.append(i)
				var covered := 0
				for i in range(0,indices.size(),3):
					var p: Vector3=(vertices[indices[i]]+vertices[indices[i+1]]+vertices[indices[i+2]])/3
					if r.floor_contains(Vector2(p.x,p.z)*100): covered+=1
				check(indices.size()>3000 and covered==0,"surrounding rock never fills the actual walkable excavation")
			node.free()
	check(families.size()>=18,"at least eighteen spatial typologies")
	check(footprints.size()==30,"no dungeon is an identical footprint copy")
	check(envelopes.size()>=10 and counts.size()>=4,"envelopes and space counts are not one fixed lattice")
	check(grades.size()>=20,"grade sequences belong to individual plans")
	print("dungeon identity: %d checks, %d failures; families=%d footprints=%d envelopes=%d counts=%d grades=%d" % [checks,failures,families.size(),footprints.size(),envelopes.size(),counts.size(),grades.size()]); quit(1 if failures else 0)
