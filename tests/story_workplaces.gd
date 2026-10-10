extends SceneTree
const Campaign=preload("res://scripts/story_campaign.gd")
const Screen=preload("res://scripts/story_screen.gd")
var checks := 0
var failures := 0
var screen
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var c=Campaign.new(); c.save_enabled=false; c.state=c.new_state(); c.enter(1,0)
	var r=c.map.regions[0]
	for item in r.dressing:
		check(ResourceLoader.exists("res://assets/story/environment/models/"+item.model+".glb"),"asset exists: "+item.id)
		if item.has("footprint"):
			check(not r.walkable(item.position,1),"solid furniture blocks feet: "+item.id)
	for building in r.buildings:
		var centre: Vector2=building.rect.get_center()
		check(r.walkable(centre),"usable interior centre: "+str(building.role))
		check(is_equal_approx(r.height_at(centre),6),"feet on real foundation")
		var from: Vector2=building.door+Vector2(0,70)
		var to: Vector2=centre+Vector2(0,20)
		var moved: Vector2=c.map.move(from,to-from)
		check(moved.distance_to(to)<1,"walk through door to interior: "+str(building.role))
		check(c.map.move(to,from-to).distance_to(from)<1,"walk out of interior")
	for stage in [0,1,7]:
		var suffix := "-compat" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ""
		var scene: Node=load("res://scenes/story/opening-%d%s.scn" % [stage,suffix]).instantiate()
		check(scene.has_node("CraftedSetDressing"),"authored scene contains workplace dressing")
		if not scene.has_node("CraftedSetDressing"):
			scene.free(); continue
		var found: Dictionary={}
		for node in scene.get_node("CraftedSetDressing").get_children():
			found[node.get_meta("dressing_id")]=node
		for item in c.map.regions[stage].dressing:
			check(found.has(item.id),"actual scene placement: "+item.id)
			if found.has(item.id) and item.has("footprint"):
				check(found[item.id].get_meta("movement_footprint")==item.rect,"same authored and logical footprint")
		scene.free()
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(3840,2160); DisplayServer.window_set_size(root.size)
		screen=Screen.new(); root.add_child(screen); screen.campaign.save_enabled=false
		screen.start("user://workplace-test-unused.json"); screen.campaign.state=screen.campaign.new_state(); screen.campaign.enter(1,0)
		screen.set_physics_process(false); screen.photo_mode=true; screen.hud.hide()
		screen.world.zoom=7.5
		for role in 6:
			var building=screen.campaign.map.regions[0].buildings[role]
			screen.campaign.hero_at=building.rect.get_center()+Vector2(0,20)
			for i in 3: screen.campaign.allies[i]=screen.campaign.hero_at+Vector2(0,250+i*70)
			for i in 30:
				screen.world.sync_story(Vector2(1440,900),.03); await process_frame
			var house: Node3D=screen.world.scenery.find_child("service_%d" % role,true,false)
			var side: Node3D=house.find_child("Side*",true,false)
			check(side!=null and not side.visible,"camera-facing wall reveals furniture")
			if RenderingServer.get_current_rendering_method()!="gl_compatibility":
				for part in [side,house.find_child("Roof*",true,false),house.find_child("Front*",true,false)]:
					for mesh in screen.world.environment_builder.kit.mesh_nodes(part):
						check(mesh.get_active_material(0) is ShaderMaterial,"real fade shader includes mesh root")
						check(mesh.gi_mode==GeometryInstance3D.GI_MODE_DISABLED,"hidden parts do not leave baked occlusion")
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			check(image.get_size()==Vector2i(3840,2160),"actual 4K interior output")
			var label := "compat-" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else ""
			image.save_png("res://build/story-workplace-%s%d.png" % [label,role])
		screen.queue_free(); await process_frame
	print("story workplaces: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
