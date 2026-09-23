extends SceneTree

# The hidden recruit in the camp, the lobby, the world and the report. This is a
# UI test: it needs a real window (`--path . --script tests/recruit_ui.gd`),
# because it presses buttons and measures where they were drawn.

var app: Node
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("RECRUIT UI FAIL: "+description)

func hero_button(name_text: String) -> Button:
	for child in app.page.get_children():
		if child is Button and str(child.text)==name_text:
			return child
	return null

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-recruit-ui.json"
	app.profile.data.hero=0
	app.profile.data.unlocks={}
	await create_timer(0.4).timeout
	print("RECRUIT UI: scene up")

	# --- locked: the camp shows exactly the three shipped heroes ------------
	app.session.solo(app.config())
	app.show_camp()
	await process_frame
	print("RECRUIT UI: camp drawn, roster=%d" % app.profile.roster_size())
	check(app.profile.roster_size()==3,"a fresh save has a three hero roster")
	check(hero_button("墓煜")==null and hero_button("墓煜 ✦")==null,"the recruit is not on the roster yet")
	check(hero_button("绯月")!=null and hero_button("雪璃")!=null and hero_button("鸦羽")!=null,"all three shipped heroes are selectable")
	check(app.portrait(app.page,3,Vector2(-400,-400),80,true)!=null,"a portrait can be built for the recruit without failing")
	print("RECRUIT UI: locked camp checked")

	# --- unlocked: she appears, and choosing her reaches the session --------
	app.profile.unlock("muyu")
	app.session.configure(app.config())
	app.show_camp()
	await process_frame
	print("RECRUIT UI: unlocked camp drawn, roster=%d" % app.profile.roster_size())
	check(app.profile.roster_size()==4,"reaching the hidden ending grows the roster")
	var button := hero_button("墓煜 ✦")
	check(button!=null,"the recruit has a button of her own")
	if button:
		button.pressed.emit()
		await process_frame
		check(app.profile.data.hero==3,"clicking her selects her")
		check(int(app.session.players[1].hero)==3,"the choice reaches the session")
	app.show_camp()
	await process_frame
	print("RECRUIT UI: unlocked camp checked")

	# --- she can actually fight --------------------------------------------
	app.session.solo({"hero":3})
	app.session.launch(false,777)
	app.session.set_physics_process(false)
	app.session.enemies.clear()
	app.session.spawn_timer=999999
	app.page_name="game"
	await process_frame
	print("RECRUIT UI: raid launched")
	var walker: Dictionary=app.session.players[1]
	check(int(walker.hero)==3,"the raid starts with the recruit")
	check(Catalog.is_starter(int(walker.weapon)),"she sets out with her issue weapon")
	check(Catalog.weapon_name(int(walker.weapon))=="湮魂之镰","and that weapon is the soul reaper scythe")
	check(int(walker.ammo)==int(Catalog.HEROES[3].clip),"her clip comes from her own row")
	for motion in ["walk","run","dodge"]:
		var pose: Dictionary=app.field.character_frames.motion_frame(3,motion,3.0,0.0)
		check(not pose.is_empty() and pose.texture!=null,"%s has a frame for the recruit" % motion)
	for weapon in [1,2,3]:
		var pose: Dictionary=app.field.character_frames.attack_frame(3,weapon,2)
		check(not pose.is_empty() and pose.texture!=null,"weapon family %d has a frame for the recruit" % weapon)
	print("RECRUIT UI: frames checked")
	app.session.attack(walker)
	check(walker.pending_strike,"she can swing")
	app.session.update_soul_reaps(0.01)
	print("RECRUIT UI: combat checked")

	# --- the report names the hidden ending --------------------------------
	app.session.players[1]["hidden_ending"]=true
	app.session.settle()
	print("RECRUIT UI: settled")
	await process_frame
	check(bool(app.session.results[1].get("hidden",false)),"the report carries the hidden flag")
	check(int(app.session.results[1].coins)>0,"the report still pays out")
	check(app.profile.has_recruit(3),"the ending leaves the recruit unlocked in the save")
	print("RECRUIT UI: report checked")

	app.queue_free()
	await process_frame
	print("RECRUIT UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
