extends SceneTree
const Library = preload("res://scripts/scene_assets.gd")
const Layout = preload("res://scripts/scene_asset_layout.gd")
const Presentation = preload("res://scripts/world_3d.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func run() -> void:
	var library := Library.new()
	var parent := Node3D.new()
	root.add_child(parent)
	for key in library.registry:
		var model := library.place(parent,key,Vector3.ZERO,Vector3(2,3,1))
		var actual := library.local_bounds(model)
		check(actual.size.is_equal_approx(Vector3(2,3,1)),key+": imported transforms fit requested dimensions")
		check(absf(actual.position.y)<0.001,key+": authored origin is grounded")
		if key.begins_with("nature/"):
			var native: AABB=library.bounds[key]
			check(native.size.y>native.size.x and native.size.y>native.size.z*1.5,key+": tree grows upward before resizing")
			for mesh in library.meshes(model):
				var world_pose := Transform3D.IDENTITY
				var cursor: Node=mesh
				while cursor!=model:
					world_pose=cursor.transform*world_pose
					cursor=cursor.get_parent()
				check((world_pose.basis*Vector3.UP).normalized().dot(Vector3.UP)>0.999,key+": authored trunk axis remains vertical")
		for mesh in library.meshes(model):
			for surface in mesh.mesh.get_surface_count():
				var style: ShaderMaterial=mesh.get_surface_override_material(surface)
				check(style.get_shader_parameter("atlas") is Texture2D,key+": external atlas resolves")
		model.free()
	for key in ["dungeon/chest","dungeon/chest_gold"]:
		var chest := library.place(parent,key,Vector3.ZERO,Vector3(0.48,0.34,0.32))
		var lid: Node3D=chest.find_child("*lid*",true,false)
		check(lid!=null,key+": lid hinge exists")
		library.chest_state(chest,true,false)
		check(lid!=null and absf(lid.rotation.x)>1.0,key+": opened chest uses its real lid")
		library.chest_state(chest,false,false)
		check(lid!=null and is_zero_approx(lid.rotation.x),key+": close resets lid")
		chest.free()
	var world := Ruins.new()
	world.generate(1729)
	var view := Presentation.new()
	root.add_child(view)
	view.sync(world,Ruins.SPAWN,Vector2(1280,800))
	for item in world.decor:
		var spec := Layout.building(item)
		if spec.is_empty(): continue
		var rect: Rect2=spec.rect
		check(world.blocked(rect.get_center()),"Building interior blocks simulation movement")
		var found := false
		for node in view.scenery.get_children():
			if node.get_meta("source_model","")!=spec.model: continue
			if Vector2(node.position.x,node.position.z).distance_to(rect.get_center()*0.01)>0.001: continue
			var size: Vector3=node.get_meta("fitted_size")
			check(Vector2(size.x,size.z).distance_to(rect.size*0.01)<0.001,"Model agrees with authoritative footprint")
			found=true
		check(found,"Every collision building has a real visible asset")
	view.free()
	parent.free()
	print("SCENE ASSET CHECKS: ",checks," failures: ",failures)
	quit(1 if failures else 0)
