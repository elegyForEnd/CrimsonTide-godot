extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(tag: String) -> void:
	await create_timer(0.65).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/rogue-chest-"+tag+".png")
func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-chest-visual.json"
	await process_frame
	var s: TideSession=app.session
	s.solo({"hero":0,"mode":"roguelike","rogue_rerolls":2})
	s.launch(false,1729)
	s.set_physics_process(false)
	s.enemies.clear()
	var p: Dictionary=s.players[1]
	s.roguelike.clear_room(s)
	p.p=s.raid.reward_chest.p-Vector2(55,0)
	await capture("closed")
	s.perform(1,"rogue_loot")
	s.elapsed+=0.3
	await capture("burst")
	s.elapsed+=2
	await capture("ground")
	p.p=s.raid.reward_drops[0].p
	s.perform(1,"rogue_loot")
	assert(p.rogue_selection.offers.size()==3)
	await capture("selection")
	var reward_ui: Control=app.rogue_panel.get_child(0)
	var nodes: Array=[reward_ui]
	while not nodes.is_empty():
		var node: Node=nodes.pop_back()
		nodes.append_array(node.get_children())
		if node is Label:
			var lines: int=node.get_line_count()
			var required: float=node.get_theme_font("font").get_height(node.get_theme_font_size("font_size"))*lines+2*maxi(0,lines-1)
			assert(required<=node.size.y+0.1,"Reward text clipped: "+node.text)
	assert(reward_ui.selected==-1 and reward_ui.take.disabled and reward_ui.share.disabled)
	var card: Button=reward_ui.find_child("RewardCard0",true,false)
	var click := InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.position=card.get_global_transform_with_canvas()*(card.size/2)
	click.pressed=true
	root.push_input(click,true)
	click.pressed=false
	root.push_input(click,true)
	await process_frame
	assert(reward_ui.selected==0 and not reward_ui.share.disabled)
	await capture("selected")
	click.position=reward_ui.share.get_global_transform_with_canvas()*(reward_ui.share.size/2)
	click.pressed=true
	root.push_input(click,true)
	click.pressed=false
	root.push_input(click,true)
	await process_frame
	assert(p.rogue_selection.is_empty())
	await capture("shared")
	app.queue_free()
	await process_frame
	print("ROGUE CHEST VISUAL PASS")
	quit()
