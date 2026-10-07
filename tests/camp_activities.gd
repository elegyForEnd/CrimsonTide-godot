extends SceneTree
const Screen = preload("res://scripts/camp_screen.gd")
const Home = preload("res://scripts/homestead.gd")
var checks := 0
var failures := 0
var screen
var activity
func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(reason)
func _initialize() -> void: call_deferred("run")
func step(seconds: float) -> void:
	var count := maxi(1,ceili(seconds/0.025))
	for i in count:
		activity.step(seconds/count)
		screen.site.refresh_sprites()
func shoot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/home-world-"+name+".png")
func run() -> void:
	root.size = Vector2i(1440,900)
	var profile := Profile.new()
	profile.path = "user://home-world-test.json"
	profile.data.coins = 1000
	var session := TideSession.new()
	root.add_child(session)
	session.set_physics_process(false)
	session.solo({})
	screen = Screen.new()
	root.add_child(screen)
	screen.set_context(session,profile)
	screen.set_process(false)
	screen.site.set_process(false)
	activity = screen.activities
	activity.set_process(false)
	var home := Home.new(profile)
	for hero in 4:
		for action in ["plant","water","harvest","cast","reel"]:
			var first: Dictionary = screen.site.activity_frames.frame(hero,action,0)
			var last: Dictionary = screen.site.activity_frames.frame(hero,action,1)
			check(not first.is_empty() and first.texture.resource_path.contains("home/animations"),"New dedicated action sheet: %d / %s" % [hero,action])
			check(first.region!=last.region,"Action advances through distinct frames: %d / %s" % [hero,action])
			screen.site.hero = hero
			screen.site.hero_activity = action
			screen.site.hero_activity_progress = 0.5
			screen.site.refresh_sprites()
			check(screen.site.sprites[0].texture==first.texture and screen.site.sprites[0].region_enabled,"Actual camp hero renders new regional animation: %d / %s" % [hero,action])
	screen.site.hero = 0
	screen.site.hero_activity = ""
	home.buy("wheat")
	screen.site.hero_at = screen.site.garden_at(0)+Vector2(120,0)
	screen.site.set_camera_focus(screen.site.hero_at,true)
	screen.site.site_focus = screen.site.hero_at
	screen.interact()
	check(activity.action=="plant" and not screen.home_ui.visible,"E at a real bed starts world sowing, no menu")
	check(profile.product_count("wheat_seed")==1 and home.state().plots[0].crop=="","Seed not charged before completed sowing animation")
	step(0.55)
	check(screen.site.hero_activity=="plant" and screen.site.hero_activity_progress>0,"Sowing animation progresses while action is held")
	await shoot("sowing")
	activity.cancel()
	check(profile.product_count("wheat_seed")==1 and home.state().plots[0].crop=="","Cancel sowing costs no seed and yields no crop")
	activity.farm(0)
	step(1.3)
	check(profile.product_count("wheat_seed")==0 and home.state().plots[0].crop=="wheat","Completed animation consumes one seed and plants correct bed")
	check(not activity.busy() and screen.site.hero_activity=="","Work ends and returns to normal locomotion")
	activity.farm(0)
	step(0.55)
	check(activity.action=="water" and not home.state().plots[0].watered,"Water remains pending until tipping animation completes")
	check(activity.particles.size()>0,"Water is emitted in the physical scene")
	await shoot("watering")
	step(1.0)
	check(home.state().plots[0].watered,"Watering commits after animation")
	home.state().plots[0].watered = false
	activity.farm(0)
	home.state().plots[0].planted = home.now()-1000
	step(1.6)
	check(profile.product_count("wheat")==0 and home.state().plots[0].crop=="wheat","Maturing during watering cannot silently turn a water animation into harvesting")
	home.state().plots[0].planted = home.now()-1000
	screen.site.refresh_crops(home.state())
	activity.farm(0)
	step(0.55)
	check(activity.action=="harvest" and profile.product_count("wheat")==0,"Harvest remains pending during picking animation")
	await shoot("harvesting")
	step(0.8)
	check(profile.product_count("wheat")==3 and home.state().plots[0].crop=="","Completed picking yields exactly three and clears plants")
	screen.site.hero_at = screen.site.SPAWN
	activity.farm(1)
	check(not activity.busy(),"Remote plot cannot be operated from another part of map")
	activity.cast()
	check(not activity.busy(),"Fishing cannot start away from pier")
	home.buy("rod")
	home.buy("bait")
	screen.warp_to("fish")
	check(activity.at_pier(),"Travel lands on real pier instead of opening a fishing dialog")
	screen.interact()
	check(activity.action=="fish" and not screen.home_ui.visible and profile.product_count("bait")==4,"Pier E casts into water and charges one bait")
	step(0.4)
	check(screen.site.hero_activity=="cast" and activity.bobber.position.y>0.07,"New cast sprite and airborne bobber travel together")
	await shoot("casting")
	step(0.5)
	check(activity.fishing_phase=="wait" and activity.fishing_line.mesh!=null,"Paid cast reaches water with a real drawn line")
	var before: Vector2 = screen.site.hero_at
	screen.drive_hero(Vector2.RIGHT,1)
	check(screen.site.hero_at==before,"Movement does not drag a fishing animation off the pier")
	var wait: float = activity.wait_time
	step(wait+0.1)
	check(activity.fishing_phase=="bite","Waiting produces a bite without UI controls")
	activity.bite_time = acos(-0.30)/2.6
	activity.step(0)
	await shoot("bite")
	screen.interact()
	check(activity.fishing_phase=="reel" and activity.caught!=null,"Timed real-world E begins reeling and fish flight")
	step(0.5)
	check(screen.site.hero_activity=="reel" and activity.caught.position.y>0.3,"New reel frames and fish jump animate in scene")
	await shoot("reeling")
	step(0.7)
	check(not activity.busy() and profile.product_count("silver")+profile.product_count("moon")+profile.product_count("gold")==1,"Successful reel grants one catch after animation completes")
	activity.reel()
	check(profile.product_count("silver")+profile.product_count("moon")+profile.product_count("gold")==1,"Duplicate reel cannot duplicate fish")
	home.state().last_cast = 0
	activity.cast()
	step(0.9)
	step(activity.wait_time+0.1)
	step(6.1)
	step(1.2)
	check(profile.product_count("silver")+profile.product_count("moon")+profile.product_count("gold")==1,"Ignoring bite times out without an automatic successful catch")
	home.state().last_cast = 0
	activity.cast()
	screen.set_active(false)
	check(not activity.busy() and not activity.home.active_cast and screen.site.hero_activity=="","Leaving camp cancels live animation and model cast")
	screen.set_active(true)
	screen.home_ui.open("garden")
	check(not screen.home_ui.visible and not screen.input_blocked,"Garden menu shortcut routes to world; cannot plant through a menu")
	screen.home_ui.open("fish")
	check(not screen.home_ui.visible,"Fishing menu shortcut routes to pier; cannot catch through a menu")
	screen.home_ui.open("home_shop")
	check(screen.home_ui.visible,"Seed and tackle shop remains a menu")
	screen.home_ui.close()
	# --- items the player drops on the camp floor -----------------------------
	# The bag panel drops whatever is dragged out of it; F picks it back up into the
	# character's carried backpack. The floor keeps records, not just art, and it keeps
	# only the newest 60.
	var floor_before: int=activity.drops.size()
	activity.drop_entry(Catalog.make_equipment("weapon",3,4),Vector2(0,0))
	check(activity.drops.size()==floor_before+1,"a dropped item lands on the camp floor")
	var floor: Dictionary=activity.drops[activity.drops.size()-1]
	check(floor.has("entry") and floor.has("node"),"as a record plus its own node")
	check(str(floor.entry.kind)=="weapon" and int(floor.entry.tier)==4,"keeping the piece's whole identity")
	check(floor.at is Vector2,"and where it lies")
	screen.site.hero_at=Vector2(floor.at)
	check(activity.has_drop_near(screen.site.hero_at),"the floor knows F is standing on it")
	var received: Array = []
	activity.item_receiver=func(entry: Dictionary) -> bool:
		received.append(entry)
		return true
	check(activity.pick_up_nearby(),"F picks a floored item up")
	check(received.size()==1 and str(received[0].kind)=="weapon","and hands it to the bag route with its identity")
	check(activity.drops.size()==floor_before,"leaving the floor empty of that piece")
	# A refusal (no room) keeps the piece exactly where it lies.
	activity.drop_entry(Catalog.make_equipment("gear",1,3),Vector2(0,0))
	var held_count: int=activity.drops.size()
	activity.item_receiver=func(entry: Dictionary) -> bool:
		return false
	screen.site.hero_at=Vector2(activity.drops[held_count-1].at)
	check(not activity.pick_up_nearby(),"a refused pickup reports failure")
	check(activity.drops.size()==held_count,"and the piece stays on the floor")
	activity.item_receiver=Callable()
	# The floor keeps the newest 60 items; the oldest simply goes away.
	for i in 70:
		activity.drop_entry(Catalog.make_equipment("gear",i%3,3),Vector2(0,0))
	var items := 0
	for drop in activity.drops:
		if drop.has("entry"): items+=1
	check(items<=activity.GROUND_ITEM_CAP,"the floor keeps at most the cap in items")
	# Leaving the camp parks the loot as data only; coming back rebuilds it from that.
	activity.stash_drops()
	var nodes := 0
	for drop in activity.drops:
		if drop.has("node"): nodes+=1
	check(nodes==0,"leaving the camp frees every drop node")
	check(activity.drops.size()>0,"while keeping the records")
	activity.restore_drops()
	nodes=0
	for drop in activity.drops:
		if drop.has("node"): nodes+=1
	check(nodes==activity.drops.size(),"and coming back rebuilds them from the data")
	screen.queue_free()
	session.queue_free()
	await process_frame
	DirAccess.remove_absolute(profile.path)
	print("CAMP ACTIVITIES: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
