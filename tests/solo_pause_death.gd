extends SceneTree

var checks := 0
var failures := 0
var finishes := 0

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Attach the launcher script after entering the tree to exercise its prewarm
	# handoff without starting the video / rendering transition in headless mode.
	var launcher := CanvasLayer.new()
	root.add_child(launcher)
	launcher.set_script(load("res://scripts/boot.gd"))
	launcher._prewarm_attach(load("res://scenes/main.tscn"))
	var app = launcher.login_instance
	check(app.process_mode==Node.PROCESS_MODE_DISABLED and not app.can_process(),"prewarmed login stays inactive behind launcher")
	launcher._activate_prewarmed_login()
	check(app.process_mode==Node.PROCESS_MODE_ALWAYS,"launcher preserves pause-safe UI processing")
	launcher.queue_free()
	app.profile.path="user://test-solo-pause-death.json"
	app.session.changed.disconnect(app.on_lobby)
	app.session.finished.connect(func(): finishes+=1)
	var escape := InputEventKey.new()
	escape.keycode=KEY_ESCAPE
	escape.physical_keycode=KEY_ESCAPE
	escape.pressed=true
	for mode in ["expedition","roguelike"]:
		app.session.solo({"hero":0,"mode":mode})
		app.session.launch(false,20261009)
		var p: Dictionary=app.session.players[app.session.my_id()]
		if mode=="roguelike":
			app.session.perform(p.id,"rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})
		app.ultimate.play(0,false)
		app.sync_solo_pause()
		check(paused,"solo cinematic preserves its own world pause")
		await create_timer(0.05).timeout
		check(paused,"UI processing does not release cinematic pause")
		app.ultimate.stop()
		root.push_input(escape)
		check(paused and app.modal,"%s Escape pauses the world" % mode)
		check(app.can_process() and not app.session.can_process() and not app.field.can_process() and not app.rogue_field.can_process(),"UI remains active while simulation and both worlds pause")
		var before: float=app.session.elapsed
		await create_timer(0.12).timeout
		check(app.session.elapsed==before,"%s time freezes while menu is open" % mode)
		app.show_settings()
		check(paused,"settings preserve pause")
		root.push_input(escape)
		check(not paused and not app.modal,"Escape resumes after closing menu")
		var bag := InputEventKey.new()
		bag.keycode=KEY_TAB
		bag.physical_keycode=KEY_TAB
		bag.pressed=true
		root.push_input(bag)
		check(paused and app.inventory_open,"%s bag pauses immediately" % mode)
		before=app.session.elapsed
		var hp: float=p.hp
		await create_timer(0.12).timeout
		check(app.session.elapsed==before and p.hp==hp,"%s open bag freezes time and damage" % mode)
		app.pause_menu()
		app.close_modal()
		check(paused and app.inventory_open,"closing a modal over inventory keeps pause")
		root.push_input(escape)
		check(not paused and not app.inventory_open,"Escape closes bag and resumes")
		await create_timer(0.12).timeout
		check(app.session.elapsed>before,"%s simulation resumes" % mode)
		root.push_input(bag)
		check(paused and app.inventory_open,"%s Tab reopens bag" % mode)
		root.push_input(bag)
		check(not paused and not app.inventory_open,"%s Tab closes paused bag" % mode)
		root.push_input(escape)
		var resume: Button=null
		for child in app.overlay.get_children():
			if child is Button and child.text=="继续探索": resume=child
		check(resume!=null and resume.can_process(),"%s resume button stays interactive while paused" % mode)
		if resume!=null: resume.pressed.emit()
		check(not paused and not app.modal,"%s resume button closes pause menu" % mode)
		if mode=="expedition":
			var chest: Dictionary=app.session.ruins.chests[0]
			chest.p=p.p
			chest.items=[{"kind":"scrap","count":1,"x":0,"y":0,"rot":false}]
			chest.searched=0
			app.toggle_bag()
			check(paused,"ordinary bag pauses before switching to search")
			check(app.open_search(0,p),"search opens from an already open bag")
			check(not paused and app.inventory_open,"search overlay immediately resumes the world")
			before=app.session.elapsed
			await create_timer(0.75).timeout
			check(app.session.elapsed>before and app.session.searched_units(chest)>0,"search timer reveals chest items while its window is open")
			check(not paused,"fully revealed loot window also keeps world running")
			app.pause_menu()
			check(paused,"Escape menu can still pause over a search window")
			app.close_modal()
			check(not paused,"closing menu restores live search")
			app.close_bag()
			app.toggle_bag()
			check(paused,"ordinary bag pauses again after leaving search")
			app.close_bag()
		app.session.set_physics_process(false)
		p.invuln=0.0
		var count_before := finishes
		app.session.hurt(p,100000.0)
		check(p.status=="dead" and not app.session.running,"%s lethal damage ends run immediately" % mode)
		check(app.page_name=="results" and not paused,"%s death shows settlement without pause" % mode)
		check(finishes==count_before+1 and not app.session.results[p.id].escaped,"death emits one failed settlement")
		before=app.session.elapsed
		app.session.simulate(1.0)
		app.session.settle()
		check(app.session.elapsed==before and finishes==count_before+1,"finished simulation and repeated settlement remain stopped")
		app.session.set_physics_process(true)
	# A hosted room is still multiplayer even before another player joins.
	check(app.session.host({"hero":0,"mode":"expedition"})==OK,"host starts for multiplayer regression")
	if app.session.online:
		app.session.launch(false,20261009)
		app.session.set_physics_process(false)
		app.pause_menu()
		check(not paused,"multiplayer menu keeps world running")
		app.close_modal()
		app.toggle_bag()
		check(not paused,"multiplayer inventory keeps world running")
		app.close_bag()
		var p: Dictionary=app.session.players[app.session.my_id()]
		p.invuln=0.0
		app.session.hurt(p,100000.0)
		check(p.status=="down" and app.session.running,"multiplayer preserves teammate rescue")
	app.session.disconnect_room()
	app.queue_free()
	await process_frame
	await process_frame
	print("SOLO PAUSE / DEATH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
