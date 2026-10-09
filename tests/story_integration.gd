extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, text: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(text)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.show_title()
	var entry := false
	for child in app.page.get_children():
		if child is Button and child.text.contains("故事模式"): entry=true
	check(entry,"title exposes story mode")
	app.go_story("user://story-integration-fixture.json")
	var screen=app.story_screen
	screen.campaign.save_enabled=false
	screen.campaign.state=screen.campaign.new_state()
	screen.campaign.enter(1,0)
	check(app.page_name=="story" and screen.active,"story entry activates independent mode")
	check(not app.session.running and not app.field.visible and not app.rogue_field.visible,"old raid does not run behind story")
	# Walk the real simulation over the south trigger, rather than calling south_gate.
	screen.campaign.hero_at=Vector2(1100,1850)
	for i in 160: screen.campaign.update(0.02,Vector2.DOWN)
	check(screen.campaign.state.stage==1,"walking down automatically changes to first map")
	check(screen.campaign.current_main().id=="A1-M01","walking opens first quest")
	screen.campaign.hero_at=Vector2(1100,2510)
	for i in 100: screen.campaign.update(0.02,Vector2.UP)
	check(screen.campaign.state.stage==0,"walking back north returns to camp")
	screen.campaign.hero_at=Vector2(1500,590); screen.interact()
	check(screen.modal,"healer interaction opens services")
	screen.close_panel()
	app.show_title()
	check(not screen.active and not screen.world.visible,"title hides story geometry")
	app.go_camp()
	check(app.page_name=="ground" and not screen.active,"expedition camp remains accessible")
	app.go_story("user://story-integration-fixture.json")
	check(app.page_name=="story" and not app.camp.visible,"returning to story closes expedition camp")
	root.size=Vector2i(1920,1080); app.fit_ui()
	var point: Vector2=screen.campaign.hero_at
	var projected: Vector2=screen.project(point)
	check((screen.get_global_transform_with_canvas()*projected).distance_to(screen.world.project(point))<0.01,"projected markers stay aligned in a scaled viewport")
	screen.show_menu()
	check(screen.modal,"story menu pauses its own simulation")
	screen.close_panel()
	app.show_title()
	app.queue_free()
	await process_frame
	print("story integration: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
