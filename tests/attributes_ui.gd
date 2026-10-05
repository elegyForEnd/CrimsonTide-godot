extends SceneTree

var failures := 0

func check(ok: bool, reason: String) -> void:
	if not ok:
		failures+=1
		push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://attributes-ui-test.json"
	app.profile.data=Profile.new().data.duplicate(true)
	app.session.solo(app.config())
	app.show_camp_forge()
	await process_frame
	var vigor_button: Button=app.overlay.get_node("Attribute_vigor")
	check(not vigor_button.disabled,"Initial allocation button is available")
	vigor_button.pressed.emit()
	await process_frame
	check(app.profile.data.attributes.vigor==11 and app.profile.attribute_points()==4,"Actual UI click allocates one permanent point")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/attributes-forge.png")
	app.close_modal()
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	app.session.enemies.clear()
	var p: Dictionary=app.session.players[1]
	p.mana=p.max_mana
	var click := InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_RIGHT
	click.pressed=true
	app._unhandled_input(click)
	check(p.art_cd>0 and p.mana==p.max_mana-WeaponArts.of(int(p.weapon)).mana,"Right click casts current weapon art")
	app.update_hud()
	check(app.hud.mana.text.contains("蓝量") and app.hud.mpbar.size.x<220,"HUD shows the consumed blue mana")
	check(app.hud.art.text.contains(str(WeaponArts.of(int(p.weapon)).name)),"HUD names the weapon art")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/attributes-hud.png")
	p.art_cd=0
	p.cast_time=0
	p.attack=0
	app.toggle_bag()
	var before: float=p.mana
	app._input(click)
	check(p.art_cd==0 and p.mana==before,"Inventory right click remains item rotation")
	app.close_bag()
	app.pause_menu()
	app._unhandled_input(click)
	check(p.art_cd==0 and p.mana==before,"Modal blocks right-click combat")
	app.queue_free()
	DirAccess.remove_absolute("user://attributes-ui-test.json")
	await process_frame
	print("ATTRIBUTES UI: ",failures," failures")
	quit(1 if failures else 0)
