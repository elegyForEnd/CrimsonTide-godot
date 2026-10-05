extends SceneTree
const Screen = preload("res://scripts/camp_screen.gd")
const Home = preload("res://scripts/homestead.gd")
var failures := 0
var checks := 0
func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(reason)
func buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	if node is Button: found.append(node)
	for child in node.get_children(): found.append_array(buttons(child))
	return found
func press_named(node: Node, title: String) -> bool:
	for action in buttons(node):
		if action.text==title and not action.disabled:
			action.pressed.emit()
			return true
	return false
func _initialize() -> void:
	call_deferred("run")
func shoot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	capture.save_png("res://build/home-"+name+".png")
	if name=="overview":
		capture.get_region(Rect2i(14,14,438,132)).save_png("res://build/home-heading-detail.png")
		capture.get_region(Rect2i(604,806,690,80)).save_png("res://build/home-navigation-detail.png")
		capture.get_region(Rect2i(14,142,300,606)).save_png("res://build/home-facilities-detail.png")
		capture.get_region(Rect2i(1070,14,356,192)).save_png("res://build/home-squad-detail.png")
	if name=="squad-full":
		capture.get_region(Rect2i(1070,14,356,320)).save_png("res://build/home-squad-full-detail.png")
func run() -> void:
	root.size = Vector2i(1440,900)
	var profile := Profile.new()
	profile.path = "user://homestead-ui-test.json"
	profile.data.coins = 900
	var session := TideSession.new()
	root.add_child(session)
	session.set_physics_process(false)
	session.solo({})
	var screen := Screen.new()
	root.add_child(screen)
	screen.set_context(session,profile)
	await process_frame
	var site = screen.site
	check(site.stations.size()==10,"All original and home facilities exist")
	check(not FileAccess.get_file_as_string("res://scripts/camp_site.gd").contains("Ruins.new"),"Home never creates or samples expedition generator")
	check(not site.is_walkable(site.LAKE.get_center()),"Water blocks walking")
	check(site.is_walkable(Vector2(4000,2390)),"Dock over water is traversable")
	check(not site.is_walkable(Vector2(800,1200)),"Home bounds are enforced by map itself")
	for station in site.stations:
		screen.warp_to(station.id)
		check(site.is_walkable(site.hero_at),"Safe facility arrival: "+str(station.id))
		check(site.station_at(site.hero_at).get("id","")==station.id,"Arrival is inside interaction range: "+str(station.id))
	site.hero_at = site.SPAWN
	await shoot("overview")
	if DisplayServer.get_name()!="headless":
		var original_players: Dictionary = session.players.duplicate(true)
		for i in 3:
			var guest: Dictionary = original_players.values()[0].duplicate(true)
			guest.id = 100+i
			guest.hero = i+1
			guest.name = ["很长的守夜人名字示例","巡夜者","烬灯"][i]
			guest.ready = i%2==0
			session.players[guest.id] = guest
		screen.refresh_roster()
		await shoot("squad-full")
		session.players = original_players
		screen.refresh_roster()
	screen.home_map.open()
	check(screen.input_blocked and screen.home_map.visible,"Map guide blocks camp controls")
	check(screen.home_map.get_child(1).size==Vector2(660,660),"Illustrated map fits guide and hotspot coordinate space")
	await shoot("map-guide")
	screen.home_map.travel("garden")
	check(not screen.home_map.visible and site.station_at(site.hero_at).id=="garden","Map routes to real interactive station")
	var home := Home.new(profile)
	home.buy("wheat")
	home.plant(0,"wheat")
	home.buy("carrot")
	home.plant(1,"carrot")
	home.buy("herb")
	home.plant(3,"herb")
	home.state().plots[0].planted = home.now()-500
	home.state().plots[1].planted = home.now()-140
	site.refresh_crops(home.state())
	check(site.crop_layer.get_child_count()==36,"Mature beds use generated crop sprites; younger plants have stems and leaves")
	screen.site.hero_at = Vector2(1720,2140)
	screen.site.set_camera_focus(screen.site.hero_at,true)
	screen.hud.hide()
	screen.marker_layer.hide()
	await shoot("crops")
	screen.hud.show()
	screen.marker_layer.show()
	screen.warp_to("garden")
	screen.interact()
	check(not screen.home_ui.visible,"Garden interaction is in the world, not a modal")
	screen.activities.cancel()
	for id in ["home_shop","kitchen"]:
		screen.warp_to(id)
		screen.interact()
		check(screen.home_ui.visible and screen.home_ui.section==id,"Only trading and cooking open menus: "+id)
		await shoot(id+"-panel")
		if id=="home_shop":
			var coins: int = profile.data.coins
			var seeds: int = home.state().seeds.wheat
			check(press_named(screen.home_ui,"购买  12 ◈"),"Image card purchase is interactive")
			check(profile.data.coins==coins-12 and home.state().seeds.wheat==seeds+1,"Card purchase commits currency and seed")
			check(press_named(screen.home_ui,"出售"),"Sell tab opens harvest cards")
			home.state().stock.wheat = 1
			screen.home_ui.build()
			check(press_named(screen.home_ui,"出售  +9 ◈") and home.state().stock.wheat==0,"Harvest image card sells one item")
		else:
			home.state().stock.wheat = 3
			screen.home_ui.build()
			check(press_named(screen.home_ui,"烹饪") and home.state().meals.bread==1,"Cooking card consumes recipe ingredients")
			check(press_named(screen.home_ui,"携带") and home.state().prepared=="bread","Meal card prepares expedition meal")
			await shoot("kitchen-prepared")
			check(press_named(screen.home_ui,"卸下餐食") and home.state().prepared=="","Meal can be unprepared")
		check(press_named(screen.home_ui,"i"),"Info button opens rules")
		await process_frame
		var help_dialog: AcceptDialog
		for child in screen.get_children():
			if child is AcceptDialog: help_dialog = child
		check(help_dialog!=null and help_dialog.visible and screen.input_blocked,"Info dialog blocks world controls")
		if help_dialog:
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				help_dialog.get_texture().get_image().save_png("res://build/home-info-"+id+".png")
			help_dialog.hide()
			await process_frame
		check(screen.input_blocked and screen.home_ui.visible,"Closing info retains menu input block")
		check(screen.home_ui.panel.get_global_rect().end.y<=900,"Image card panel fits viewport")
		screen.home_ui.close()
		check(not screen.input_blocked,"Closing menu frees world controls")
	home.buy("rod")
	home.buy("bait")
	screen.warp_to("fish")
	screen.interact()
	check(screen.activities.action=="fish" and not screen.home_ui.visible,"Pier starts a physical cast")
	screen.activities.set_process(false)
	screen.activities.step(0.9)
	screen.activities.step(screen.activities.wait_time+0.1)
	screen.activities.bite_time = acos(-0.30)/2.6
	screen.activities.step(0)
	await shoot("fishing-bite")
	check(press_named(screen.hud,"i"),"HUD info opens controls guide")
	for child in screen.get_children():
		if child is AcceptDialog: child.hide()
	await process_frame
	check(not screen.input_blocked,"HUD info restores world input")
	screen.set_active(false)
	check(not screen.activities.busy() and not screen.input_blocked,"Leaving camp cancels cast and frees controls")
	screen.set_active(true)
	screen.warp_to("fish")
	await shoot("lake")
	screen.queue_free()
	session.queue_free()
	await process_frame
	DirAccess.remove_absolute(profile.path)
	print("HOMESTEAD UI: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
