extends SceneTree
const Screen = preload("res://scripts/story_screen.gd")
const Art = preload("res://scripts/story_portrait_art.gd")
const View = preload("res://scripts/story_portrait_view.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
func _initialize() -> void:run.call_deferred()
func click(at: Vector2) -> void:
	Input.warp_mouse(at)
	var motion := InputEventMouseMotion.new();motion.position=at;Input.parse_input_event(motion);await process_frame
	var down := InputEventMouseButton.new();down.position=at;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;Input.parse_input_event(down);await process_frame
	var up := InputEventMouseButton.new();up.position=at;up.button_index=MOUSE_BUTTON_LEFT;Input.parse_input_event(up);await process_frame
func capture(name: String) -> void:
	if not "--capture-vn-full-dialogue" in OS.get_cmdline_user_args():return
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/vn-full-dialogue-"+name+".png")==OK,"actual whole portrait UI "+name)
func run() -> void:
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	var unique_paths: Dictionary={}
	for hero in 3:
		check(Art.description(hero).get("ready",false),"all72 whole portraits ready for hero "+str(hero))
		for costume in Art.COSTUMES:
			for pose in Art.POSES:
				for emotion in Art.EXPRESSIONS:
					var data := Art.layers(hero,emotion,costume,pose)
					check(data.body!=null and data.body.get_size()==Vector2(2160,3840),"whole portrait canvas "+str(hero)+costume+pose+emotion)
					check(data.face==null and data.whole_portrait,"no face replacement or expression layers")
					unique_paths[data.path]=true
	check(unique_paths.size()==216,"216 distinct whole-image resources")
	check(Art.textures.size()<=Art.CACHE_LIMIT,"texture cache bounded")
	var view := View.new();view.size=Vector2(480,745);root.add_child(view)
	view.set_actor("hero:0",null,"neutral","regular","front");var neutral=view.texture
	view.set_actor("hero:0",null,"smile","regular","front")
	check(view.get_child_count()==1 and view.body.texture==view.texture and view.texture!=neutral,"one TextureRect selects a completely different PNG")
	view.set_actor("hero:0",null,"determined","regular","front");check(view.expression=="neutral","legacy authored mood gracefully maps to an available full portrait")
	view.queue_free();await process_frame
	var screen=Screen.new();root.add_child(screen);screen.campaign.save_enabled=false;screen.start("user://vn-full-fixture.json");screen.set_physics_process(false)
	var c=screen.campaign;c.state=c.new_state();c.enter(1,0);c.save_enabled=false
	for hero in 3:
		var actor := "hero:%d" % hero
		var pages: Array=[]
		for i in 8:pages.append({"speaker":["绯月","雪璃","鸦羽"][hero],"text":"灯还亮着，我们一起回去。","actor":actor,"left":actor,"right":"","expression":Art.EXPRESSIONS[i]})
		screen.show_dialogue("完整立绘差分",pages);var ui=screen.dialogue;ui.set_process(false);ui.reveal_all()
		var before := JSON.stringify(c.state);var bounds: Vector2=ui.left.size
		ui.index=4;ui.show_page();ui.reveal_all();await process_frame
		check(ui.left.expression=="worried" and ui.left.get_child_count()==1,"actual dialogue uses a whole generated expression portrait")
		check(ui.left.size==bounds,"expression preserves viewport bounds")
		await capture(Art.HERO_KEYS[hero]+"-regular-worried")
		ui.toggle_wardrobe();ui._process(100);ui.advance();check(ui.index==4,"appearance selector pauses reading")
		await click(ui.wardrobe.global_position+Vector2(155+240+112,120+130*hero+21))
		check(ui.left.costume=="home" and screen.dialogue_outfits.get(actor)=="home","native clothing button selects the intended hero's home outfit")
		await click(ui.wardrobe.global_position+Vector2(155+240+112,169+130*hero+19))
		check(ui.left.pose=="turn" and ui.left.costume=="home" and ui.left.expression=="worried","native pose button independent from clothing and emotion")
		check(ui.left.texture==Art.layers(hero,"worried","home","turn").body,"UI displays the correct complete combination image")
		ui.toggle_wardrobe();await capture(Art.HERO_KEYS[hero]+"-home-turn")
		ui.choose_costume(actor,"travel");ui.choose_pose(actor,"crossed")
		check(JSON.stringify(c.state)==before,"appearance cannot change equipment, money, quests or combat state")
		ui.index=7;ui.show_page();ui.reveal_all();await capture(Art.HERO_KEYS[hero]+"-travel-surprised")
		check(ui.left.expression=="surprised" and ui.left.pose=="crossed" and ui.left.costume=="travel","page progression retains costume and pose independently of mood")
		ui.toggle_wardrobe();ui.toggle_log();check(ui.wardrobe==null and ui.log_view!=null,"backlog and selectors remain mutually exclusive")
		ui.toggle_log()
	screen.save_dialogue_outfits();check(not FileAccess.file_exists(c.path+".dialogue-outfits.json"),"temporary preview never saves preferences")
	c.save_enabled=true;screen.save_dialogue_outfits();c.save_enabled=false;var prefs: Dictionary=screen.dialogue_outfits.duplicate();screen.load_dialogue_read()
	check(screen.dialogue_outfits==prefs,"three wardrobe choices roundtrip outside gameplay save schema")
	DirAccess.remove_absolute(c.path+".dialogue-outfits.json")
	screen.set_active(false);check(Art.textures.is_empty(),"story exit clears full portrait cache")
	screen.free();for i in 5:await process_frame
	print("whole story portrait variants: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
