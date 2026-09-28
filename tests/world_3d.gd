extends SceneTree
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
	var session := TideSession.new()
	root.add_child(session)
	session.solo({"hero":0})
	session.launch(false,1729)
	session.set_physics_process(false)
	var field := Battlefield.new()
	field.session=session
	root.add_child(field)
	await process_frame
	var view: Node3D=field.world_3d
	for resolution in [Vector2i(1280,800),Vector2i(1920,1080),Vector2i(960,900)]:
		root.size=resolution
		await process_frame
		view.sync(session.ruins,Vector2(3200,2400),Vector2(root.size))
		for pos in [Vector2(3000,2100),Vector2(3500,2600),Vector2(3200,2400)]:
			var screen: Vector2=view.project(pos)
			check(view.unproject(screen).distance_to(pos)<0.05,"Mouse ray must land on the displayed ground point")
			check((view.ground_transform()*pos).distance_to(screen)<0.05,"Telegraph and 3D terrain projections must agree")
	check(view.scenery.get_child_count()>100,"Border builds real 3D meshes")
	view.sync_chests(session.ruins.chests)
	check(view.chest_meshes.size()==session.ruins.chests.size(),"Every live chest has a 3D presentation")
	view.sync_chests([])
	check(view.chest_meshes.is_empty(),"Removed chests release their presentation")
	var border_id: int=view.scenery.get_instance_id()
	view.sync(session.ruins,Vector2(3200,2400),Vector2(root.size))
	check(view.scenery.get_instance_id()==border_id,"Camera motion must not rebuild terrain")
	session.players[1].p=session.CITY_GATE
	session.travel_city()
	await process_frame
	view.sync(session.ruins,RoyalCity.GATE,Vector2(root.size))
	check(view.unproject(view.project(RoyalCity.GATE)).distance_to(RoyalCity.GATE)<0.05,"City uses the same mouse projection contract")
	check(view.source.interior,"City transition changes 3D terrain")
	check(view.scenery.get_instance_id()!=border_id,"City replaces border meshes")
	var city_id: int=view.scenery.get_instance_id()
	session.ruins.generate(998)
	view.sync(session.ruins,RoyalCity.GATE,Vector2(root.size))
	check(view.scenery.get_instance_id()!=city_id,"Regenerating the same map object rebuilds scenery")
	view.begin_sprites()
	var pose: Dictionary=field.character_frames.motion_frame(0,"walk",0,0)
	view.submit_sprite(pose.texture,pose.rect,Rect2(),Color.WHITE,Transform2D(0,Vector2(1400,1800)))
	view.end_sprites()
	check(view.used==1 and view.sprites[0].visible,"Actor atlas becomes a visible billboard")
	check(not view.sprites[0].no_depth_test,"Buildings depth-test against actors")
	check(view.sprites[0].billboard==BaseMaterial3D.BILLBOARD_FIXED_Y,"Actor stays upright instead of leaning into terrain")
	view.begin_sprites()
	view.end_sprites()
	check(not view.sprites[0].visible,"Removed enemies cannot leave stale sprites")
	field.hide()
	check(not view.visible,"Leaving gameplay hides 3D scene")
	field.show()
	check(view.visible,"Returning to gameplay restores 3D scene")
	field.queue_free()
	session.queue_free()
	await process_frame
	print("WORLD 3D CHECKS: ",checks," failures: ",failures)
	quit(1 if failures else 0)
